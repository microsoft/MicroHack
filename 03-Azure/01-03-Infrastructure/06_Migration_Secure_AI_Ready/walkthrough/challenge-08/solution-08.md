# Walkthrough Challenge 8 - Replatform the selected migrated web workload to Azure App Service

[Previous Challenge Solution](../challenge-07/solution-07.md) - **[Home](../../Readme.md)** - [Finish](../../challenges/finish.md)

Duration: 40 minutes

Continue with the same track selected in Challenge 7:

* **Track A:** Windows Server / IIS
* **Track B:** Ubuntu Linux / Apache

Complete only your selected track.

## Task 1: Discover the web application before choosing a target (10 minutes)

Azure Migrate's at-scale web-app migration flow supports ASP.NET web apps on Windows IIS servers hosted in VMware environments. This Hack uses Hyper-V, and the integrated flow doesn't support the Linux/Apache workload. We will deliberately inspect and manually replatform the selected migrated workload.

### Track A - Inventory Windows/IIS

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

### Track B - Inventory Linux/Apache

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

### Complete the discovery record

| Area | Track A finding | Track B finding |
| --- | --- | --- |
| Site/service | `Default Web Site` / `W3SVC` | Default Apache virtual host / `apache2` |
| Content path | `C:\inetpub\wwwroot` | `/var/www/html` |
| Binding | HTTP, normally port 80 | HTTP, normally `*:80` |
| Runtime/modules | No server-side runtime used by the site | No server-side runtime/module used by the site |
| Content | Static HTML, CSS, and images | Static HTML, CSS, and images |
| External dependencies | None required to render the page | None required to render the page |
| Persistent/session state | None | None |
| Machine-specific values | Hostname, platform, and web server in stable `data-workload-value` fields | Hostname, platform, and web server in stable `data-workload-value` fields |

The source is a static artifact. A Windows App Service worker can host it regardless of whether it came from Windows/IIS or Linux/Apache.

## Task 2: Make the content portable and create the package (10 minutes)

### Track A - PowerShell package

```powershell
$siteRoot = 'C:\inetpub\wwwroot'
$indexPath = Join-Path $siteRoot 'index.html'
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

$packageDirectory = 'C:\temp'
$packagePath = Join-Path $packageDirectory 'microhack-app.zip'
New-Item -Path $packageDirectory -ItemType Directory -Force | Out-Null
Remove-Item -Path $packagePath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$siteRoot\*" -DestinationPath $packagePath -Force

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
}

Get-Item -Path $packagePath | Select-Object FullName, Length, LastWriteTime
```

### Track B - Linux package

Keep the same Bash session open through Task 6 so the recorded variables remain available. Create a temporary, user-owned staging copy. This keeps `/var/www/html` and its ownership unchanged:

```bash
set -euo pipefail

site_root="/var/www/html"
staging_dir="$(mktemp -d)"
package_path="$HOME/microhack-app.zip"

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
    rm -rf "${staging_dir}"
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
  rm -rf "${staging_dir}"
  exit 1
}

rm -rf "${staging_dir}"
ls -lh "${package_path}"
```

For both tracks, the archive must contain `index.html` at its root, not under `wwwroot/`, `html/`, or another parent directory.

## Task 3: Create the low-cost Windows App Service target (7 minutes)

The target is a Windows App Service plan for both tracks. Static files are portable; the source OS does not determine the worker OS.

### Track A - Create from Azure Cloud Shell

Open Azure Cloud Shell in the portal, select **PowerShell**, and run:

```powershell
$destinationRg = 'destination-rg'
$location = az group show `
    --name $destinationRg `
    --query location `
    --output tsv

$suffix = (Get-Random -Minimum 100000 -Maximum 999999).ToString()
$planName = "asp-mh-replatform-$suffix"
$appName = "mh-web-$suffix"

az appservice plan create `
    --name $planName `
    --resource-group $destinationRg `
    --location $location `
    --sku B1

az webapp create `
    --name $appName `
    --resource-group $destinationRg `
    --plan $planName

az webapp update `
    --name $appName `
    --resource-group $destinationRg `
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

### Track B - Install Azure CLI if needed and sign in

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

Sign in with device code and verify the active subscription:

```bash
az login --use-device-code
az account list --output table

read -r -p "Enter the target subscription ID: " subscription_id
az account set --subscription "${subscription_id}"
az account show \
  --query '{subscription:name,subscriptionId:id,tenantId:tenantId,user:user.name}' \
  --output table
```

Complete the sign-in in the browser using the displayed code. Do not paste passwords, tokens, or publishing credentials into the shell or lab notes.

Create the target:

```bash
set -euo pipefail

destination_rg="destination-rg"
location="$(az group show \
  --name "${destination_rg}" \
  --query location \
  --output tsv)"
suffix="$(date +%s)-${RANDOM}"
plan_name="asp-mh-replatform-${suffix}"
app_name="mh-web-${suffix}"

az appservice plan create \
  --name "${plan_name}" \
  --resource-group "${destination_rg}" \
  --location "${location}" \
  --sku B1

az webapp create \
  --name "${app_name}" \
  --resource-group "${destination_rg}" \
  --plan "${plan_name}"

az webapp update \
  --name "${app_name}" \
  --resource-group "${destination_rg}" \
  --https-only true

az webapp show \
  --name "${app_name}" \
  --resource-group "${destination_rg}" \
  --query '{name:name,host:defaultHostName,httpsOnly:httpsOnly,state:state}' \
  --output table

printf 'Plan name: %s\nWeb app name: %s\nHTTPS URL: https://%s.azurewebsites.net\n' \
  "${plan_name}" "${app_name}" "${app_name}"
```

The omitted `--is-linux` flag creates a Windows plan. `B1` is the lowest Basic dedicated tier and incurs charges until the plan is deleted.

## Task 4: Deploy with supported App Service ZIP deployment (5 minutes)

### Track A - Kudu ZIP deploy

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

### Track B - Deploy the local ZIP

The variables from Task 3 remain in the same Bash session:

```bash
package_path="${HOME}/microhack-app.zip"

az webapp deploy \
  --resource-group "${destination_rg}" \
  --name "${app_name}" \
  --src-path "${package_path}" \
  --type zip
```

App Service extracts the package into `D:\home\site\wwwroot`. Do not configure Deployment Center source control; neither track requires GitHub or Azure DevOps integration.

## Task 5: Validate HTTPS, assets, and independence (5 minutes)

### Track A - Validate and stop IIS

Run in Windows PowerShell, replacing the placeholder:

```powershell
$appName = '<recorded-web-app-name>'
$appUrl = "https://$appName.azurewebsites.net"
$home = Invoke-WebRequest -Uri "$appUrl/" -UseBasicParsing -TimeoutSec 30
$home.StatusCode
$home.Content -match 'data-workload-value="platform"[^>]*>Managed PaaS</dd>'

$assets = @('stylesheet.css', 'GitHub_Logo.png', 'MSLogo.png', 'MSicon.png')
foreach ($asset in $assets) {
    $response = Invoke-WebRequest -Uri "$appUrl/$asset" -UseBasicParsing -TimeoutSec 30
    [pscustomobject]@{
        Asset = $asset
        StatusCode = $response.StatusCode
        Bytes = $response.RawContentLength
    }
}

Stop-Service -Name W3SVC -Force
Get-Service -Name W3SVC
(Invoke-WebRequest -Uri $appUrl -UseBasicParsing -TimeoutSec 30).StatusCode
```

`W3SVC` must be `Stopped` while App Service still returns `200`. To preserve the original site after the proof, run:

```powershell
Start-Service -Name W3SVC
```

### Track B - Validate and stop Apache

```bash
app_url="https://${app_name}.azurewebsites.net"

curl --fail --silent --show-error "${app_url}/" |
  grep -E 'data-workload-value="platform"[^>]*>Managed PaaS</dd>'

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

sudo systemctl stop apache2
sudo systemctl is-active apache2 || true

curl --fail --silent --show-error --output /dev/null \
  --write-out 'App Service after Apache stop: HTTP %{http_code}\n' \
  "${app_url}/"
```

`apache2` must be inactive while App Service still returns `200`. To preserve the original site after the proof:

```bash
sudo systemctl enable apache2
sudo systemctl start apache2
sudo systemctl is-active apache2
```

For both tracks, visually check the HTTPS page and assets. App Service has its own public endpoint and is not a backend of the Azure Load Balancer used for the migrated VMs.

## Task 6: Record the architecture decision and clean up (3 minutes)

The lab used App Service to demonstrate a managed PaaS replatform. For this static-only workload, compare the production options:

| Target | Fit for this workload |
| --- | --- |
| Azure Storage static website | Likely best for the simplest, lowest-cost hosting of public HTML, CSS, and images; no web server is required. |
| Azure Static Web Apps | Strong fit when global static delivery, integrated authentication, APIs, custom routing, and repository-driven CI/CD are desired. |
| Azure App Service | Valid but more capable and typically more expensive than needed for static-only content; appropriate if server-side code or App Service features will be added. |

Document which target you would choose and why.

### Optional resource cleanup

Do not delete resources automatically. If the lab owner approves cleanup, delete the web app and plan with the variables from your track's shell:

Track A, Azure Cloud Shell PowerShell:

```powershell
az webapp delete `
    --resource-group $destinationRg `
    --name $appName

az appservice plan delete `
    --resource-group $destinationRg `
    --name $planName `
    --yes
```

Track B, Bash:

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

### Track B - Sign out

Whether or not you delete the resources, remove the interactive Azure CLI session from the migrated VM:

```bash
az logout
az account clear
```

Interactive sign-in is appropriate for this guided lab. Signing out and clearing the local subscription cache reduce credential exposure on the VM. No publishing credentials were used or exposed.

You successfully completed Challenge 8 and the Hack.
