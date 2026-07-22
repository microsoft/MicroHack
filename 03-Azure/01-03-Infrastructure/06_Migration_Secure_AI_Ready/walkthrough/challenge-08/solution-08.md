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

> [!NOTE]
> Paste each Path B Bash block into the Azure Bastion browser SSH terminal as one complete block, then wait for its completion or failure status before continuing. Each block runs its fail-fast commands in a child Bash process while leaving terminal input available for device-code sign-in. If a command fails, the child stops and control returns to your SSH prompt without changing your login shell options or traps. Correct the reported error and rerun that block before continuing.

```bash
if bash /dev/fd/3 3<<'PATH_B_INVENTORY'
set -euo pipefail

sudo apache2ctl -S
sudo apache2ctl -M
systemctl_args=(show apache2 --property=ActiveState,SubState,UnitFileState)
sudo systemctl "${systemctl_args[@]}"

file_list_args=(/var/www/html -type f -printf '%p\t%f\t%s bytes\n')
sudo find "${file_list_args[@]}" | sort

sudo find /var/www/html -type f -printf '%f\n' |
  awk -F. 'NF > 1 {print "." $NF}' |
  sort | uniq -c | sort -nr

dependency_pattern='localhost|127\.0\.0\.1|/var/|/home/|mysql|postgres|connection(string)?'
dependency_find_args=(/var/www/html -type f '(' -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.json' ')' -exec grep -HnEi "${dependency_pattern}" '{}' +)
sudo find "${dependency_find_args[@]}" || true

sudo sed -n '1,120p' /var/www/html/index.html
curl_args=(--fail --silent --show-error --output /dev/null --write-out 'HTTP %{http_code}\n')
curl "${curl_args[@]}" http://localhost/
PATH_B_INVENTORY
then
  echo 'Path B inventory completed.'
else
  path_b_status=$?
  printf 'Path B step failed; your SSH session remains open (status %d).\n' "${path_b_status}" >&2
  echo 'Correct the error and rerun this block before continuing.' >&2
fi
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

Create a temporary, user-owned staging copy. This keeps `/var/www/html` and its ownership unchanged, and the published package path is reconstructed by later blocks:

```bash
if bash /dev/fd/3 3<<'PATH_B_PACKAGE'
set -euo pipefail

site_root='/var/www/html'
staging_dir="$(mktemp -d)"
package_path="${HOME}/microhack-app.zip"
package_tmp="$(mktemp --tmpdir="${HOME}" '.microhack-app.XXXXXXXX.zip')"
rm -f "${package_tmp}"

cleanup_package() {
  local status=$?
  trap - EXIT
  rm -rf "${staging_dir}" || true
  rm -f "${package_tmp}" || true
  return "${status}"
}
trap cleanup_package EXIT

sudo cp -a "${site_root}/." "${staging_dir}/"
sudo chown -R "$(id -u):$(id -g)" "${staging_dir}"

sed_args=(
  -E
  -i
  -e 's#(<dd[^>]*data-workload-value="hostname"[^>]*>)[^<]*(</dd>)#\1Azure App Service\2#'
  -e 's#(<dd[^>]*data-workload-value="platform"[^>]*>)[^<]*(</dd>)#\1Managed PaaS\2#'
  -e 's#(<dd[^>]*data-workload-value="web-server"[^>]*>)[^<]*(</dd>)#\1Azure App Service\2#'
)
sed "${sed_args[@]}" "${staging_dir}/index.html"

if ! command -v zip >/dev/null 2>&1 ||
   ! command -v unzip >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y zip unzip
fi

(
  cd "${staging_dir}"
  zip -qr "${package_tmp}" .
)

archive_entries="$(unzip -Z1 "${package_tmp}")"
required_assets=(
  'index.html'
  'stylesheet.css'
  'GitHub_Logo.png'
  'MSLogo.png'
  'MSicon.png'
)
for asset in "${required_assets[@]}"; do
  if ! grep -Fxq "${asset}" <<<"${archive_entries}"; then
    echo "Required asset is missing from the ZIP root: ${asset}" >&2
    false
  fi
done

archive_html="$(unzip -p "${package_tmp}" index.html)"
metadata_checks=(
  'hostname|Azure App Service'
  'platform|Managed PaaS'
  'web-server|Azure App Service'
)
for check in "${metadata_checks[@]}"; do
  field="${check%%|*}"
  expected_value="${check#*|}"
  if ! grep -Eq "data-workload-value=\"${field}\"[^>]*>${expected_value}</dd>" <<<"${archive_html}"; then
    echo "Expected App Service metadata is missing from the ZIP: ${field}" >&2
    false
  fi
done
if grep -Eq '<(HOSTNAME|PLATFORM|WEB_SERVER)>' <<<"${archive_html}"; then
  echo 'The ZIP still contains unresolved workload template tokens.' >&2
  false
fi

mv -f "${package_tmp}" "${package_path}"
ls -lh "${package_path}"
PATH_B_PACKAGE
then
  echo 'Path B package completed.'
else
  path_b_status=$?
  printf 'Path B step failed; your SSH session remains open (status %d).\n' "${path_b_status}" >&2
  echo 'Correct the error and rerun this block before continuing.' >&2
fi
```

For both paths, the archive must contain `index.html` and all four image/style assets at its root, not under `wwwroot/`, `html/`, or another parent directory. Path B keeps any previously published `$HOME/microhack-app.zip` unchanged until a replacement ZIP passes every check and is moved into place atomically.

## Task 3: Verify Azure scope and create the App Service target (10 minutes)

The Bicep deployment names the destination resource group `MHBox-<UserSuffix>-destination-rg`, where `<UserSuffix>` is the deployer's user principal name before `@`. Find the exact name under **Resource groups** in the Azure portal. After selecting the intended subscription, you can also run `az group list --query "[?ends_with(name, '-destination-rg')].[name,location]" --output table`.

Replace every placeholder below before running a resource command. Each Path B block repeats the required subscription and resource-group values and derives the same stable plan and app names, so it can be rerun from a new SSH session.

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

Run from the migrated Ubuntu VM. Replace both placeholders. The block installs Azure CLI when it is missing or unhealthy, then signs in and verifies the exact scope:

```bash
if bash /dev/fd/3 3<<'PATH_B_SCOPE'
set -euo pipefail

subscription_id='<REPLACE-WITH-SUBSCRIPTION-ID>'
destination_rg='MHBox-<UserSuffix>-destination-rg'
installer_path="$(mktemp)"

cleanup_installer() {
  local status=$?
  trap - EXIT
  rm -f "${installer_path}" || true
  return "${status}"
}
trap cleanup_installer EXIT

if [[ -z "${subscription_id}" ||
      "${subscription_id}" == '<REPLACE-WITH-SUBSCRIPTION-ID>' ]]; then
  echo 'Replace subscription_id with the Hack subscription ID.' >&2
  false
fi
if [[ -z "${destination_rg}" ||
      "${destination_rg}" == *'<'* ||
      "${destination_rg}" == *'>'* ]]; then
  echo 'Replace destination_rg with the exact destination resource-group name.' >&2
  false
fi

if ! command -v az >/dev/null 2>&1 ||
   ! az version >/dev/null 2>&1; then
  installer_curl_args=(--fail --silent --show-error --location --output "${installer_path}")
  curl "${installer_curl_args[@]}" 'https://aka.ms/InstallAzureCLIDeb'
  sudo bash "${installer_path}"
fi
az version

az login --use-device-code
az account set --subscription "${subscription_id}"
account_show_args=(account show --query '{subscription:name,subscriptionId:id,tenantId:tenantId,user:user.name}' --output table)
az "${account_show_args[@]}"

active_subscription_id="$(az account show --query id --output tsv)"
destination_rg="$(az group show --name "${destination_rg}" --query name --output tsv)"
location="$(az group show --name "${destination_rg}" --query location --output tsv)"
if [[ -z "${location}" ]]; then
  echo "Could not resolve ${destination_rg} in the active subscription." >&2
  false
fi

name_suffix="$(
  printf '%s\0%s' "${active_subscription_id}" "${destination_rg}" |
    sha256sum |
    cut -c1-12
)"
plan_name="asp-mh-linux-${name_suffix}"
app_name="mh-web-linux-${name_suffix}"

printf 'Destination resource group: %s (%s)\nPlan name: %s\nWeb app name: %s\n' "${destination_rg}" "${location}" "${plan_name}" "${app_name}"
PATH_B_SCOPE
then
  echo 'Path B scope verification completed.'
else
  path_b_status=$?
  printf 'Path B step failed; your SSH session remains open (status %d).\n' "${path_b_status}" >&2
  echo 'Correct the error and rerun this block before continuing.' >&2
fi
```

Complete the sign-in in the browser using the displayed code. Do not paste passwords, tokens, or publishing credentials into the shell or lab notes. The stable 12-character suffix is derived only from Azure's validated subscription ID and canonical destination resource-group name; it contains no secret and is reproduced by every later block.

> [!WARNING]
> Stop if the displayed subscription, tenant, or user doesn't identify the Hack subscription, or if the resource group isn't your `MHBox-<UserSuffix>-destination-rg`.

Resolve the newest advertised Node.js LTS runtime and create a Linux target:

```bash
if bash /dev/fd/3 3<<'PATH_B_CREATE'
set -euo pipefail

subscription_id='<REPLACE-WITH-SUBSCRIPTION-ID>'
destination_rg='MHBox-<UserSuffix>-destination-rg'

if [[ -z "${subscription_id}" ||
      "${subscription_id}" == '<REPLACE-WITH-SUBSCRIPTION-ID>' ]]; then
  echo 'Replace subscription_id with the Hack subscription ID.' >&2
  false
fi
if [[ -z "${destination_rg}" ||
      "${destination_rg}" == *'<'* ||
      "${destination_rg}" == *'>'* ]]; then
  echo 'Replace destination_rg with the exact destination resource-group name.' >&2
  false
fi

command -v az >/dev/null
az account set --subscription "${subscription_id}"
active_subscription_id="$(az account show --query id --output tsv)"
destination_rg="$(az group show --name "${destination_rg}" --query name --output tsv)"
location="$(az group show --name "${destination_rg}" --query location --output tsv)"

name_suffix="$(
  printf '%s\0%s' "${active_subscription_id}" "${destination_rg}" |
    sha256sum |
    cut -c1-12
)"
plan_name="asp-mh-linux-${name_suffix}"
app_name="mh-web-linux-${name_suffix}"
startup_command='pm2 serve /home/site/wwwroot $PORT --no-daemon'

runtime_list_args=(webapp list-runtimes --os-type linux --runtime node --output tsv)
runtime_candidates="$(az "${runtime_list_args[@]}")"
runtime="$(
  printf '%s\n' "${runtime_candidates}" |
    awk 'tolower($0) ~ /^node:[0-9]+-lts$/ { print }' |
    sort -t: -k2,2Vr |
    sed -n '1p'
)"
if [[ -z "${runtime}" ]]; then
  echo 'No supported NODE:<major>-lts Linux runtime was returned.' >&2
  printf '%s\n' "${runtime_candidates}" >&2
  false
fi

plan_list_args=(appservice plan list --resource-group "${destination_rg}" --query "[?name=='${plan_name}'].id | [0]" --output tsv)
plan_id="$(az "${plan_list_args[@]}")"
if [[ -z "${plan_id}" ]]; then
  plan_create_args=(appservice plan create --name "${plan_name}" --resource-group "${destination_rg}" --location "${location}" --sku B1 --is-linux true --output none)
  az "${plan_create_args[@]}"
  plan_id="$(az appservice plan show --name "${plan_name}" --resource-group "${destination_rg}" --query id --output tsv)"
  echo "Created Linux App Service plan: ${plan_name}"
else
  plan_is_linux="$(az appservice plan show --name "${plan_name}" --resource-group "${destination_rg}" --query reserved --output tsv)"
  plan_location="$(az appservice plan show --name "${plan_name}" --resource-group "${destination_rg}" --query location --output tsv)"
  plan_sku="$(az appservice plan show --name "${plan_name}" --resource-group "${destination_rg}" --query sku.name --output tsv)"
  normalized_plan_location="${plan_location// /}"
  normalized_location="${location// /}"
  if [[ "${plan_is_linux,,}" != 'true' ||
        "${normalized_plan_location,,}" != "${normalized_location,,}" ||
        "${plan_sku^^}" != 'B1' ]]; then
    echo "Existing plan ${plan_name} isn't a compatible Linux B1 plan in ${location}." >&2
    false
  fi
  echo "Reusing compatible Linux App Service plan: ${plan_name}"
fi

app_list_args=(webapp list --resource-group "${destination_rg}" --query "[?name=='${app_name}'].id | [0]" --output tsv)
app_id="$(az "${app_list_args[@]}")"
if [[ -z "${app_id}" ]]; then
  app_create_args=(webapp create --name "${app_name}" --resource-group "${destination_rg}" --plan "${plan_name}" --runtime "${runtime}" --https-only true --output none)
  az "${app_create_args[@]}"
  echo "Created Linux web app: ${app_name}"
else
  existing_plan_id="$(az webapp show --name "${app_name}" --resource-group "${destination_rg}" --query serverFarmId --output tsv)"
  existing_https_only="$(az webapp show --name "${app_name}" --resource-group "${destination_rg}" --query httpsOnly --output tsv)"
  existing_runtime="$(az webapp config show --name "${app_name}" --resource-group "${destination_rg}" --query linuxFxVersion --output tsv)"
  existing_runtime_canonical="${existing_runtime/|/:}"
  if [[ "${existing_plan_id,,}" != "${plan_id,,}" ||
        "${existing_https_only,,}" != 'true' ||
        -z "${existing_runtime_canonical}" ]] ||
     ! grep -Fxiq "${existing_runtime_canonical}" <<<"${runtime_candidates}"; then
    echo "Existing app ${app_name} isn't compatible with the intended plan, HTTPS setting, or supported Node LTS runtimes." >&2
    false
  fi
  echo "Reusing compatible Linux web app: ${app_name} (${existing_runtime})"
  runtime="${existing_runtime_canonical}"
fi

appsettings_args=(webapp config appsettings set --resource-group "${destination_rg}" --name "${app_name}" --settings SCM_DO_BUILD_DURING_DEPLOYMENT=false --output none)
az "${appsettings_args[@]}"
startup_args=(webapp config set --resource-group "${destination_rg}" --name "${app_name}" --startup-file "${startup_command}" --output none)
az "${startup_args[@]}"
app_show_args=(webapp show --name "${app_name}" --resource-group "${destination_rg}" --query '{name:name,host:defaultHostName,httpsOnly:httpsOnly,state:state}' --output table)
az "${app_show_args[@]}"
config_show_args=(webapp config show --name "${app_name}" --resource-group "${destination_rg}" --query '{runtime:linuxFxVersion,startup:appCommandLine}' --output table)
az "${config_show_args[@]}"

printf 'Runtime: %s\nPlan name: %s\nWeb app name: %s\nHTTPS URL: https://%s.azurewebsites.net\n' "${runtime}" "${plan_name}" "${app_name}" "${app_name}"
PATH_B_CREATE
then
  echo 'Path B resource creation completed.'
else
  path_b_status=$?
  printf 'Path B step failed; your SSH session remains open (status %d).\n' "${path_b_status}" >&2
  echo 'Correct the error and rerun this block before continuing.' >&2
fi
```

`az webapp list-runtimes` is the source of truth for currently available built-in runtimes. The block chooses the highest advertised Node.js LTS major version for a new app and fails rather than inventing a fallback. On rerun, it reuses only the same Linux B1 plan and HTTPS-enabled app when their plan association and Node LTS runtime remain compatible. PM2 runs in the foreground, listens on the App Service-provided `$PORT`, and serves the ready-to-run static ZIP from `/home/site/wwwroot`. `B1` incurs charges until the plan is deleted.

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

Replace both placeholders. This block reconstructs the package, plan, and app values and confirms the packaged content again before deployment:

```bash
if bash /dev/fd/3 3<<'PATH_B_DEPLOY'
set -euo pipefail

subscription_id='<REPLACE-WITH-SUBSCRIPTION-ID>'
destination_rg='MHBox-<UserSuffix>-destination-rg'
package_path="${HOME}/microhack-app.zip"

if [[ -z "${subscription_id}" ||
      "${subscription_id}" == '<REPLACE-WITH-SUBSCRIPTION-ID>' ]]; then
  echo 'Replace subscription_id with the Hack subscription ID.' >&2
  false
fi
if [[ -z "${destination_rg}" ||
      "${destination_rg}" == *'<'* ||
      "${destination_rg}" == *'>'* ]]; then
  echo 'Replace destination_rg with the exact destination resource-group name.' >&2
  false
fi
if [[ ! -f "${package_path}" ]]; then
  echo "Package not found: ${package_path}" >&2
  false
fi

archive_entries="$(unzip -Z1 "${package_path}")"
for asset in index.html stylesheet.css GitHub_Logo.png MSLogo.png MSicon.png; do
  if ! grep -Fxq "${asset}" <<<"${archive_entries}"; then
    echo "Required asset is missing from the ZIP root: ${asset}" >&2
    false
  fi
done
archive_html="$(unzip -p "${package_path}" index.html)"
metadata_checks=(
  'hostname|Azure App Service'
  'platform|Managed PaaS'
  'web-server|Azure App Service'
)
for check in "${metadata_checks[@]}"; do
  field="${check%%|*}"
  expected_value="${check#*|}"
  if ! grep -Eq "data-workload-value=\"${field}\"[^>]*>${expected_value}</dd>" <<<"${archive_html}"; then
    echo "Expected App Service metadata is missing from the ZIP: ${field}" >&2
    false
  fi
done
if grep -Eq '<(HOSTNAME|PLATFORM|WEB_SERVER)>' <<<"${archive_html}"; then
  echo 'The ZIP still contains unresolved workload template tokens.' >&2
  false
fi

command -v az >/dev/null
az account set --subscription "${subscription_id}"
active_subscription_id="$(az account show --query id --output tsv)"
destination_rg="$(az group show --name "${destination_rg}" --query name --output tsv)"
name_suffix="$(
  printf '%s\0%s' "${active_subscription_id}" "${destination_rg}" |
    sha256sum |
    cut -c1-12
)"
plan_name="asp-mh-linux-${name_suffix}"
app_name="mh-web-linux-${name_suffix}"
app_list_args=(webapp list --resource-group "${destination_rg}" --query "[?name=='${app_name}'].id | [0]" --output tsv)
app_id="$(az "${app_list_args[@]}")"
if [[ -z "${app_id}" ]]; then
  echo "Web app ${app_name} doesn't exist. Complete Task 3 first." >&2
  false
fi

printf 'Plan name: %s\nWeb app name: %s\nPackage: %s\n' "${plan_name}" "${app_name}" "${package_path}"

deploy_args=(webapp deploy --resource-group "${destination_rg}" --name "${app_name}" --src-path "${package_path}" --type zip)
az "${deploy_args[@]}"
PATH_B_DEPLOY
then
  echo 'Path B ZIP deployment completed.'
else
  path_b_status=$?
  printf 'Path B step failed; your SSH session remains open (status %d).\n' "${path_b_status}" >&2
  echo 'Correct the error and rerun this block before continuing.' >&2
fi
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

Replace both placeholders. Readiness is bounded to approximately three minutes: at most 18 five-second requests with up to 17 five-second waits.

```bash
if bash /dev/fd/3 3<<'PATH_B_VALIDATE'
set -euo pipefail

subscription_id='<REPLACE-WITH-SUBSCRIPTION-ID>'
destination_rg='MHBox-<UserSuffix>-destination-rg'

if [[ -z "${subscription_id}" ||
      "${subscription_id}" == '<REPLACE-WITH-SUBSCRIPTION-ID>' ]]; then
  echo 'Replace subscription_id with the Hack subscription ID.' >&2
  false
fi
if [[ -z "${destination_rg}" ||
      "${destination_rg}" == *'<'* ||
      "${destination_rg}" == *'>'* ]]; then
  echo 'Replace destination_rg with the exact destination resource-group name.' >&2
  false
fi

command -v az >/dev/null
az account set --subscription "${subscription_id}"
active_subscription_id="$(az account show --query id --output tsv)"
destination_rg="$(az group show --name "${destination_rg}" --query name --output tsv)"
name_suffix="$(
  printf '%s\0%s' "${active_subscription_id}" "${destination_rg}" |
    sha256sum |
    cut -c1-12
)"
plan_name="asp-mh-linux-${name_suffix}"
app_name="mh-web-linux-${name_suffix}"
app_url="https://${app_name}.azurewebsites.net"
printf 'Plan name: %s\nWeb app name: %s\nHTTPS URL: %s\n' "${plan_name}" "${app_name}" "${app_url}"

home_html=''
readiness_curl_args=(--fail --silent --show-error --max-time 5)
for ((attempt = 1; attempt <= 18; attempt++)); do
  if home_html="$(curl "${readiness_curl_args[@]}" "${app_url}/")"; then
    break
  fi
  if (( attempt < 18 )); then
    sleep 5
  fi
done
if [[ -z "${home_html}" ]]; then
  echo 'The App Service home page did not become ready within approximately three minutes.' >&2
  false
fi

expected_metadata=(
  'data-workload-value="hostname"[^>]*>Azure App Service</dd>'
  'data-workload-value="platform"[^>]*>Managed PaaS</dd>'
  'data-workload-value="web-server"[^>]*>Azure App Service</dd>'
)
for expected in "${expected_metadata[@]}"; do
  grep -Eq "${expected}" <<<"${home_html}" || {
    echo "The App Service page is missing expected metadata: ${expected}" >&2
    false
  }
done

for asset in stylesheet.css GitHub_Logo.png MSLogo.png MSicon.png; do
  asset_curl_args=(--fail --silent --show-error --output /dev/null --write-out "${asset}: HTTP %{http_code}, %{size_download} bytes\n")
  curl "${asset_curl_args[@]}" "${app_url}/${asset}"
done

app_show_args=(webapp show --resource-group "${destination_rg}" --name "${app_name}" --query '{state:state,httpsOnly:httpsOnly,host:defaultHostName}' --output table)
az "${app_show_args[@]}"

if ! sudo systemctl is-active --quiet apache2; then
  echo 'Apache must be running before the source-independence test.' >&2
  false
fi

apache_may_be_stopped=0
restore_apache_once() {
  if (( ! apache_may_be_stopped )); then
    return 0
  fi
  if sudo systemctl start apache2 >/dev/null &&
     sudo systemctl is-active --quiet apache2; then
    apache_may_be_stopped=0
    return 0
  fi
  apache_may_be_stopped=0
  echo 'Apache restoration failed; start apache2 manually before continuing.' >&2
  return 1
}
cleanup_validation() {
  local status=$?
  trap - EXIT
  if (( apache_may_be_stopped )) &&
     ! restore_apache_once; then
    status=1
  fi
  return "${status}"
}
trap cleanup_validation EXIT

apache_may_be_stopped=1
sudo systemctl stop apache2
if sudo systemctl is-active --quiet apache2; then
  echo 'Apache is still running after the stop command.' >&2
  false
fi
independence_curl_args=(--fail --silent --show-error --output /dev/null --max-time 30 --write-out 'App Service after Apache stop: HTTP %{http_code}\n')
curl "${independence_curl_args[@]}" "${app_url}/"

restore_apache_once
trap - EXIT
sudo systemctl is-active apache2
PATH_B_VALIDATE
then
  echo 'Path B validation and source restoration completed.'
else
  path_b_status=$?
  printf 'Path B step failed; your SSH session remains open (status %d).\n' "${path_b_status}" >&2
  echo 'Correct the error and rerun this block before continuing.' >&2
fi
```

The child-shell trap makes one restoration attempt if any command fails after Apache might have stopped. It clears itself before reporting a restoration failure, so it cannot recurse. `apache2` must be inactive during the App Service check and active again afterward.

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

Do not delete resources automatically. If the lab owner approves cleanup, delete the web app and plan. Path B reconstructs its stable names from the validated subscription and resource group:

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
if bash /dev/fd/3 3<<'PATH_B_CLEANUP'
set -euo pipefail

subscription_id='<REPLACE-WITH-SUBSCRIPTION-ID>'
destination_rg='MHBox-<UserSuffix>-destination-rg'

if [[ -z "${subscription_id}" ||
      "${subscription_id}" == '<REPLACE-WITH-SUBSCRIPTION-ID>' ]]; then
  echo 'Replace subscription_id with the Hack subscription ID.' >&2
  false
fi
if [[ -z "${destination_rg}" ||
      "${destination_rg}" == *'<'* ||
      "${destination_rg}" == *'>'* ]]; then
  echo 'Replace destination_rg with the exact destination resource-group name.' >&2
  false
fi

command -v az >/dev/null
az account set --subscription "${subscription_id}"
active_subscription_id="$(az account show --query id --output tsv)"
destination_rg="$(az group show --name "${destination_rg}" --query name --output tsv)"
name_suffix="$(
  printf '%s\0%s' "${active_subscription_id}" "${destination_rg}" |
    sha256sum |
    cut -c1-12
)"
plan_name="asp-mh-linux-${name_suffix}"
app_name="mh-web-linux-${name_suffix}"
printf 'Plan name: %s\nWeb app name: %s\n' "${plan_name}" "${app_name}"

cleanup_failed=0
app_list_args=(webapp list --resource-group "${destination_rg}" --query "[?name=='${app_name}'].id | [0]" --output tsv)
app_id="$(az "${app_list_args[@]}")"
if [[ -n "${app_id}" ]]; then
  app_delete_args=(webapp delete --resource-group "${destination_rg}" --name "${app_name}")
  if ! az "${app_delete_args[@]}"; then
    echo "Could not delete web app ${app_name}." >&2
    cleanup_failed=1
  fi
else
  echo "Web app is already absent: ${app_name}"
fi

plan_list_args=(appservice plan list --resource-group "${destination_rg}" --query "[?name=='${plan_name}'].id | [0]" --output tsv)
plan_id="$(az "${plan_list_args[@]}")"
if [[ -n "${plan_id}" ]]; then
  plan_delete_args=(appservice plan delete --resource-group "${destination_rg}" --name "${plan_name}" --yes)
  if ! az "${plan_delete_args[@]}"; then
    echo "Could not delete App Service plan ${plan_name}." >&2
    cleanup_failed=1
  fi
else
  echo "App Service plan is already absent: ${plan_name}"
fi

if (( cleanup_failed )); then
  false
fi
PATH_B_CLEANUP
then
  echo 'Path B resource cleanup completed.'
else
  path_b_status=$?
  printf 'Path B step failed; your SSH session remains open (status %d).\n' "${path_b_status}" >&2
  echo 'Correct the error and rerun this block before continuing.' >&2
fi
```

Deleting only the web app does not stop App Service plan charges.

### Path B - Sign out

Whether or not you delete the resources, remove the interactive Azure CLI session from the migrated VM:

```bash
if bash /dev/fd/3 3<<'PATH_B_SIGN_OUT'
set -euo pipefail

command -v az >/dev/null
sign_out_failed=0
if ! az logout; then
  echo 'Azure CLI logout reported an error.' >&2
  sign_out_failed=1
fi
if ! az account clear; then
  echo 'Azure CLI account-cache cleanup reported an error.' >&2
  sign_out_failed=1
fi
if (( sign_out_failed )); then
  false
fi
PATH_B_SIGN_OUT
then
  echo 'Path B Azure CLI sign-out completed.'
else
  path_b_status=$?
  printf 'Path B step failed; your SSH session remains open (status %d).\n' "${path_b_status}" >&2
  echo 'Correct the error and rerun this block before continuing.' >&2
fi
```

Interactive sign-in is appropriate for this guided lab. Signing out and clearing the local subscription cache reduce credential exposure on the VM. No publishing credentials were used or exposed.

You successfully completed Challenge 8 and the Hack.
