# Walkthrough Challenge 8 - Replatform a migrated web workload to Azure App Service

[Previous Challenge Solution](../challenge-07/solution-07.md) - **[Home](../../Readme.md)** - [Finish](../../challenges/finish.md)

Duration: 45 minutes

Select one path for the guided exercise:

* **Path A:** Windows Server / IIS to Windows App Service
* **Path B:** Ubuntu Linux / Apache to Linux App Service

Complete one path during the standard challenge time. If time permits, complete both paths with distinct App Service plans and distinct globally unique web-app names. Windows and Linux apps require plans for their respective operating systems.

## Task 1: Select and inspect a web workload (10 minutes)

Azure Migrate's at-scale web-app migration flow supports ASP.NET web apps on Windows IIS servers hosted in VMware environments. This Hack uses Hyper-V, and the integrated flow doesn't support the Linux/Apache workload. We will deliberately inspect and manually replatform the selected migrated workload.

### Path A - Inventory Windows/IIS

Connect with Azure Bastion and run in elevated Windows PowerShell:

```powershell
Import-Module WebAdministration

Get-Website | Select-Object Name, State, PhysicalPath, ApplicationPool
Get-WebBinding | Select-Object protocol, bindingInformation
Get-ChildItem IIS:\AppPools |
    Select-Object Name, State, managedRuntimeVersion, managedPipelineMode
Get-ChildItem -Path 'C:\inetpub\wwwroot' -Recurse -File |
    Select-Object FullName, Extension, Length
Get-ChildItem -Path 'C:\inetpub\wwwroot' -Recurse -File |
    Group-Object Extension |
    Sort-Object Count -Descending |
    Select-Object Name, Count

Get-Content -Path 'C:\inetpub\wwwroot\index.html'
(Invoke-WebRequest -Uri 'http://localhost/' -UseBasicParsing -TimeoutSec 10).StatusCode
```

### Path B - Inventory Linux/Apache

Connect with Azure Bastion and run in Bash:

```bash
sudo apache2ctl -S
sudo apache2ctl -M
sudo systemctl show apache2 \
  --property=ActiveState,SubState,UnitFileState

sudo find /var/www/html -type f \
  -printf '%p\t%f\t%s bytes\n' | sort

sudo find /var/www/html -type f -printf '%f\n' |
  awk -F. 'NF > 1 {print "." $NF}' |
  sort | uniq -c | sort -nr

sudo find /var/www/html -type f \
  \( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.json' \) \
  -exec grep -HnEi \
  'localhost|127\.0\.0\.1|/var/|/home/|mysql|postgres|connection(string)?' {} + || true

sudo sed -n '1,120p' /var/www/html/index.html
curl --fail --silent --show-error --output /dev/null \
  --write-out 'HTTP %{http_code}\n' http://localhost/
```

Review enabled virtual hosts/modules and any dependency matches. A text match is a prompt to investigate, not proof of a dependency.

Review the output for required runtimes, databases, machine-local dependencies, and session state. This site is a portable static artifact containing HTML, CSS, and images; only its hostname, platform, and web-server metadata is machine-specific.

There is no additional Azure Migrate portal action to perform here. The inventory is the evidence for choosing an App Service target.

## Task 2: Make the content portable and create the package (10 minutes)

### Path A - PowerShell package

Create a staging copy so packaging doesn't modify the IIS source content:

```powershell
$siteRoot = 'C:\inetpub\wwwroot'
$packageDirectory = 'C:\temp'
$stagingDirectory = Join-Path $packageDirectory 'microhack-app'
$packagePath = Join-Path $packageDirectory 'microhack-app.zip'

New-Item -Path $packageDirectory -ItemType Directory -Force | Out-Null
Remove-Item -Path $stagingDirectory -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path $packagePath -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $siteRoot -Destination $stagingDirectory -Recurse

$indexPath = Join-Path $stagingDirectory 'index.html'
$html = Get-Content -Path $indexPath -Raw
$html = $html -replace '(<dd\b[^>]*\bdata-workload-value="hostname"[^>]*>)[^<]*(</dd>)', '${1}Azure App Service${2}'
$html = $html -replace '(<dd\b[^>]*\bdata-workload-value="platform"[^>]*>)[^<]*(</dd>)', '${1}Managed PaaS${2}'
$html = $html -replace '(<dd\b[^>]*\bdata-workload-value="web-server"[^>]*>)[^<]*(</dd>)', '${1}Azure App Service${2}'
Set-Content -Path $indexPath -Value $html -Encoding UTF8

$updatedHtml = Get-Content -Path $indexPath -Raw
$expectedMetadata = [ordered]@{
    hostname = 'Azure App Service'
    platform = 'Managed PaaS'
    'web-server' = 'Azure App Service'
}
foreach ($field in $expectedMetadata.Keys) {
    $pattern = 'data-workload-value="' + [regex]::Escape($field) +
        '"[^>]*>\s*' + [regex]::Escape($expectedMetadata[$field]) + '\s*</dd>'
    if ($updatedHtml -notmatch $pattern) {
        throw "Expected App Service metadata was not written: $field"
    }
}

Compress-Archive -Path "$stagingDirectory\*" -DestinationPath $packagePath -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
try {
    $archive.Entries | Select-Object FullName, Length
    if ($null -eq $archive.GetEntry('index.html')) {
        throw 'index.html is not at the ZIP root.'
    }
}
finally {
    $archive.Dispose()
    Remove-Item -Path $stagingDirectory -Recurse -Force
}

Get-Item -Path $packagePath | Select-Object FullName, Length, LastWriteTime
```

### Path B - Linux package

Keep the same Bash session open through Task 6 so the recorded variables remain available. Create a temporary, user-owned staging copy. This keeps `/var/www/html` and its ownership unchanged:

```bash
set -euo pipefail

site_root="/var/www/html"
staging_dir="$(mktemp -d)"
package_path="$HOME/microhack-app.zip"

cleanup_staging() {
  rm -rf "${staging_dir}"
}
trap cleanup_staging EXIT

sudo cp -a "${site_root}/." "${staging_dir}/"
sudo chown -R "$(id -u):$(id -g)" "${staging_dir}"

sed -E -i \
  -e 's#(<dd[^>]*data-workload-value="hostname"[^>]*>)[^<]*(</dd>)#\1Azure App Service\2#' \
  -e 's#(<dd[^>]*data-workload-value="platform"[^>]*>)[^<]*(</dd>)#\1Managed PaaS\2#' \
  -e 's#(<dd[^>]*data-workload-value="web-server"[^>]*>)[^<]*(</dd>)#\1Azure App Service\2#' \
  "${staging_dir}/index.html"

while IFS='|' read -r field expected_value; do
  grep -Eq \
    "data-workload-value=\"${field}\"[^>]*>${expected_value}</dd>" \
    "${staging_dir}/index.html" || {
    echo "Expected App Service metadata was not written: ${field}" >&2
    exit 1
  }
done <<'EOF'
hostname|Azure App Service
platform|Managed PaaS
web-server|Azure App Service
EOF

if ! command -v zip >/dev/null 2>&1 ||
   ! command -v unzip >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y zip unzip
fi

rm -f "${package_path}"
(
  cd "${staging_dir}"
  zip -r "${package_path}" .
)

unzip -l "${package_path}"
unzip -Z1 "${package_path}" | grep -Fxq 'index.html' || {
  echo "index.html is not at the ZIP root." >&2
  exit 1
}

cleanup_staging
trap - EXIT
ls -lh "${package_path}"
```

For both paths, the archive must contain `index.html` at its root, not under `wwwroot/`, `html/`, or another parent directory.

## Task 3: Verify Azure scope and create the App Service target (10 minutes)

The Bicep deployment names the destination resource group `MHBox-<UserSuffix>-destination-rg`, where `<UserSuffix>` is the deployer's user principal name before `@`. Find the exact name under **Resource groups** in the Azure portal. After selecting the intended subscription, you can also run `az group list --query "[?ends_with(name, '-destination-rg')].[name,location]" --output table`.

Replace every placeholder below before running a resource command. Keep the same shell open through Task 6 so the verified context and resource variables remain available. If you reopen a shell, repeat the subscription and resource-group checks.

### Path A - Create a Windows target from Azure Cloud Shell

Open Azure Cloud Shell in the portal and select **PowerShell**. Verify the Az PowerShell and Azure CLI contexts before creating anything:

```powershell
$subscriptionId = '<REPLACE-WITH-SUBSCRIPTION-ID>'
$destinationRg = 'MHBox-<UserSuffix>-destination-rg'

if ([string]::IsNullOrWhiteSpace($subscriptionId) -or
    $subscriptionId -eq '<REPLACE-WITH-SUBSCRIPTION-ID>') {
    throw 'Replace $subscriptionId with the Hack subscription ID.'
}
if ([string]::IsNullOrWhiteSpace($destinationRg) -or
    $destinationRg -match '[<>]') {
    throw 'Replace $destinationRg with the exact destination resource-group name.'
}

if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    Connect-AzAccount -UseDeviceAuthentication | Out-Null
}
$azContext = Set-AzContext -SubscriptionId $subscriptionId

az account set --subscription $subscriptionId
if ($LASTEXITCODE -ne 0) {
    throw 'Azure CLI could not select the requested subscription.'
}
$cliContextJson = az account show `
    --query '{subscription:name,subscriptionId:id,tenantId:tenantId,user:user.name}' `
    --output json
if ($LASTEXITCODE -ne 0) {
    throw 'Azure CLI could not display the active subscription.'
}
$cliContext = $cliContextJson | ConvertFrom-Json

[pscustomobject]@{
    Subscription   = $azContext.Subscription.Name
    SubscriptionId = $azContext.Subscription.Id
    TenantId       = $azContext.Tenant.Id
    User           = $azContext.Account.Id
} | Format-Table
$cliContext | Format-Table

if ($azContext.Subscription.Id -ne $cliContext.subscriptionId) {
    throw 'Az PowerShell and Azure CLI are using different subscriptions.'
}

$resourceGroup = Get-AzResourceGroup -Name $destinationRg -ErrorAction Stop
$location = $resourceGroup.Location
$resourceGroup | Select-Object ResourceGroupName, Location
```

> [!WARNING]
> Stop if either displayed context isn't the Hack subscription or if the resource group isn't your `MHBox-<UserSuffix>-destination-rg`.

Create the Windows plan and app:

```powershell
$suffix = [guid]::NewGuid().ToString('N').Substring(0, 10)
$planName = "asp-mh-win-$suffix"
$appName = "mh-web-win-$suffix"

az appservice plan create `
    --name $planName `
    --resource-group $destinationRg `
    --location $location `
    --sku B1 `
    --is-linux false

az webapp create `
    --name $appName `
    --resource-group $destinationRg `
    --plan $planName `
    --https-only true

az webapp show `
    --name $appName `
    --resource-group $destinationRg `
    --query '{name:name,host:defaultHostName,httpsOnly:httpsOnly,state:state}' `
    --output table

Write-Host "Plan name: $planName"
Write-Host "Web app name: $appName"
Write-Host "HTTPS URL: https://$appName.azurewebsites.net"
```

Record `$planName` and `$appName`.

### Path B - Install Azure CLI if needed and verify scope

Run from the migrated Ubuntu VM. First check for Azure CLI:

```bash
if command -v az >/dev/null 2>&1; then
  az version
else
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  az version
fi
```

The conditional uses the current Microsoft-supported Debian/Ubuntu installation script only when `az` is missing.

Sign in with device code, replace both placeholders, and verify the exact subscription and destination resource group:

```bash
set -euo pipefail

subscription_id='<REPLACE-WITH-SUBSCRIPTION-ID>'
destination_rg='MHBox-<UserSuffix>-destination-rg'

if [[ -z "${subscription_id}" ||
      "${subscription_id}" == '<REPLACE-WITH-SUBSCRIPTION-ID>' ]]; then
  echo 'Replace subscription_id with the Hack subscription ID.' >&2
  exit 1
fi
if [[ -z "${destination_rg}" ||
      "${destination_rg}" == *'<'* ||
      "${destination_rg}" == *'>'* ]]; then
  echo 'Replace destination_rg with the exact destination resource-group name.' >&2
  exit 1
fi

az login --use-device-code
az account set --subscription "${subscription_id}"
az account show \
  --query '{subscription:name,subscriptionId:id,tenantId:tenantId,user:user.name}' \
  --output table

location="$(az group show \
  --name "${destination_rg}" \
  --query location \
  --output tsv)"
if [[ -z "${location}" ]]; then
  echo "Could not resolve ${destination_rg} in the active subscription." >&2
  exit 1
fi
printf 'Destination resource group: %s (%s)\n' \
  "${destination_rg}" "${location}"
```

Complete the sign-in in the browser using the displayed code. Do not paste passwords, tokens, or publishing credentials into the shell or lab notes.

> [!WARNING]
> Stop if the displayed subscription, tenant, or user doesn't identify the Hack subscription, or if the resource group isn't your `MHBox-<UserSuffix>-destination-rg`.

Resolve the newest advertised Node.js LTS runtime and create a Linux target:

```bash
set -euo pipefail

runtime_candidates="$(
  az webapp list-runtimes \
    --os-type linux \
    --runtime node \
    --output tsv
)"
runtime="$(
  printf '%s\n' "${runtime_candidates}" |
    awk 'tolower($0) ~ /^node:[0-9]+-lts$/ { print }' |
    sort -t: -k2,2Vr |
    sed -n '1p'
)"
if [[ -z "${runtime}" ]]; then
  echo 'No supported NODE:<major>-lts Linux runtime was returned.' >&2
  printf '%s\n' "${runtime_candidates}" >&2
  exit 1
fi

suffix="$(date -u +%Y%m%d%H%M%S)-$(printf '%04d' "$((RANDOM % 10000))")"
plan_name="asp-mh-linux-${suffix}"
app_name="mh-web-linux-${suffix}"
startup_command='pm2 serve /home/site/wwwroot $PORT --no-daemon'

az appservice plan create \
  --name "${plan_name}" \
  --resource-group "${destination_rg}" \
  --location "${location}" \
  --sku B1 \
  --is-linux true

az webapp create \
  --name "${app_name}" \
  --resource-group "${destination_rg}" \
  --plan "${plan_name}" \
  --runtime "${runtime}" \
  --https-only true

az webapp config appsettings set \
  --resource-group "${destination_rg}" \
  --name "${app_name}" \
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=false \
  --output none

az webapp config set \
  --resource-group "${destination_rg}" \
  --name "${app_name}" \
  --startup-file "${startup_command}" \
  --output none

az webapp show \
  --name "${app_name}" \
  --resource-group "${destination_rg}" \
  --query '{name:name,host:defaultHostName,httpsOnly:httpsOnly,state:state}' \
  --output table

az webapp config show \
  --name "${app_name}" \
  --resource-group "${destination_rg}" \
  --query '{runtime:linuxFxVersion,startup:appCommandLine}' \
  --output table

printf 'Runtime: %s\nPlan name: %s\nWeb app name: %s\nHTTPS URL: https://%s.azurewebsites.net\n' \
  "${runtime}" "${plan_name}" "${app_name}" "${app_name}"
```

`az webapp list-runtimes` is the source of truth for currently available built-in runtimes. The script chooses the highest advertised Node.js LTS major version and fails rather than inventing a fallback. PM2 runs in the foreground, listens on the App Service-provided `$PORT`, and serves the ready-to-run static ZIP from `/home/site/wwwroot`. `B1` incurs charges until the plan is deleted.

## Task 4: Deploy with supported App Service ZIP deployment (5 minutes)

### Path A - Kudu ZIP deploy

Keep the browser on the Windows VM so it can access `C:\temp\microhack-app.zip`.

1. Open the new web app in the Azure portal.
2. Select **Development Tools** > **Advanced Tools** > **Go**.
3. In Kudu, select **Tools** > **Zip Push Deploy**.
4. Drag `C:\temp\microhack-app.zip` into the file explorer area.
5. Wait until Kudu reports **Deployment successful**.

If the package is available in a shell with Azure CLI, this is an equivalent supported path:

```powershell
az webapp deploy `
    --resource-group $destinationRg `
    --name $appName `
    --src-path '<path-to-microhack-app.zip>' `
    --type zip
```

Windows ZIP deployment extracts the package into `D:\home\site\wwwroot`.

### Path B - Deploy the local ZIP

The variables from Task 3 remain in the same Bash session:

```bash
package_path="${HOME}/microhack-app.zip"

unzip -Z1 "${package_path}" | grep -Fxq 'index.html' || {
  echo 'index.html is not at the ZIP root.' >&2
  exit 1
}

az webapp deploy \
  --resource-group "${destination_rg}" \
  --name "${app_name}" \
  --src-path "${package_path}" \
  --type zip
```

Linux ZIP deployment extracts the package into `/home/site/wwwroot`. Build automation remains disabled because the ZIP is already complete and PM2 serves it directly. Do not configure Deployment Center source control; neither path requires GitHub or Azure DevOps integration.

## Task 5: Validate HTTPS, assets, and independence (5 minutes)

### Path A - Validate and stop IIS

Run in Windows PowerShell, replacing the placeholder:

```powershell
$appName = '<recorded-web-app-name>'
$appUrl = "https://$appName.azurewebsites.net"
$home = $null
foreach ($attempt in 1..18) {
    try {
        $home = Invoke-WebRequest -Uri "$appUrl/" -UseBasicParsing -TimeoutSec 30
        break
    }
    catch {
        Start-Sleep -Seconds 10
    }
}
if ($null -eq $home -or $home.StatusCode -ne 200) {
    throw 'The App Service home page did not become ready within three minutes.'
}

$requiredMetadata = @(
    'data-workload-value="hostname"[^>]*>Azure App Service</dd>'
    'data-workload-value="platform"[^>]*>Managed PaaS</dd>'
    'data-workload-value="web-server"[^>]*>Azure App Service</dd>'
)
foreach ($pattern in $requiredMetadata) {
    if ($home.Content -notmatch $pattern) {
        throw "The App Service page is missing expected metadata: $pattern"
    }
}

$assets = @('stylesheet.css', 'GitHub_Logo.png', 'MSLogo.png', 'MSicon.png')
foreach ($asset in $assets) {
    $response = Invoke-WebRequest -Uri "$appUrl/$asset" -UseBasicParsing -TimeoutSec 30
    [pscustomobject]@{
        Asset = $asset
        StatusCode = $response.StatusCode
        Bytes = $response.RawContentLength
    }
}

try {
    Stop-Service -Name W3SVC -Force
    Get-Service -Name W3SVC
    $independentResponse = Invoke-WebRequest `
        -Uri $appUrl `
        -UseBasicParsing `
        -TimeoutSec 30
    if ($independentResponse.StatusCode -ne 200) {
        throw 'App Service failed while IIS was stopped.'
    }
}
finally {
    Set-Service -Name W3SVC -StartupType Automatic
    Start-Service -Name W3SVC
}
Get-Service -Name W3SVC
```

`W3SVC` must be stopped during the independent App Service check and running again afterward.

### Path B - Validate and stop Apache

```bash
set -euo pipefail

app_url="https://${app_name}.azurewebsites.net"
home_html=''
for attempt in $(seq 1 18); do
  if home_html="$(curl --fail --silent --show-error "${app_url}/")"; then
    break
  fi
  sleep 10
done
if [[ -z "${home_html}" ]]; then
  echo 'The App Service home page did not become ready within three minutes.' >&2
  exit 1
fi

for expected in \
  'data-workload-value="hostname"[^>]*>Azure App Service</dd>' \
  'data-workload-value="platform"[^>]*>Managed PaaS</dd>' \
  'data-workload-value="web-server"[^>]*>Azure App Service</dd>'; do
  grep -Eq "${expected}" <<<"${home_html}" || {
    echo "The App Service page is missing expected metadata: ${expected}" >&2
    exit 1
  }
done

for asset in stylesheet.css GitHub_Logo.png MSLogo.png MSicon.png; do
  curl --fail --silent --show-error --output /dev/null \
    --write-out "${asset}: HTTP %{http_code}, %{size_download} bytes\n" \
    "${app_url}/${asset}"
done

az webapp show \
  --resource-group "${destination_rg}" \
  --name "${app_name}" \
  --query '{state:state,httpsOnly:httpsOnly,host:defaultHostName}' \
  --output table

restore_apache() {
  sudo systemctl enable --now apache2 >/dev/null
}
trap restore_apache EXIT

sudo systemctl stop apache2
sudo systemctl is-active apache2 || true
curl --fail --silent --show-error --output /dev/null \
  --write-out 'App Service after Apache stop: HTTP %{http_code}\n' \
  "${app_url}/"

restore_apache
trap - EXIT
sudo systemctl is-active apache2
```

The exit trap restores Apache even when the independence check fails. `apache2` must be inactive during the App Service check and active again afterward.

For both paths, visually check the HTTPS page and assets. App Service has its own public endpoint and remains independent of the migrated VM networking.

## Task 6: Record the architecture decision and clean up (3 minutes)

The lab used App Service to demonstrate a managed PaaS replatform. For this static-only workload, compare the production options:

| Target | Fit for this workload |
| --- | --- |
| Azure Storage static website | Likely best for the simplest, lowest-cost hosting of public HTML, CSS, and images; no web server is required. |
| Azure Static Web Apps | Strong fit when global static delivery, integrated authentication, APIs, custom routing, and repository-driven CI/CD are desired. |
| Azure App Service | Valid but more capable and typically more expensive than needed for static-only content; appropriate if server-side code or App Service features will be added. |

Document which target you would choose and why.

### Optional resource cleanup

Do not delete resources automatically. If the lab owner approves cleanup, delete the web app and plan with the variables from your path's shell:

Path A, Azure Cloud Shell PowerShell:

```powershell
az webapp delete `
    --resource-group $destinationRg `
    --name $appName

az appservice plan delete `
    --resource-group $destinationRg `
    --name $planName `
    --yes
```

Path B, Bash:

```bash
az webapp delete \
  --resource-group "${destination_rg}" \
  --name "${app_name}"

az appservice plan delete \
  --resource-group "${destination_rg}" \
  --name "${plan_name}" \
  --yes
```

Deleting only the web app does not stop App Service plan charges.

### Path B - Sign out

Whether or not you delete the resources, remove the interactive Azure CLI session from the migrated VM:

```bash
az logout
az account clear
```

Interactive sign-in is appropriate for this guided lab. Signing out and clearing the local subscription cache reduce credential exposure on the VM. No publishing credentials were used or exposed.

You successfully completed Challenge 8 and the Hack.
