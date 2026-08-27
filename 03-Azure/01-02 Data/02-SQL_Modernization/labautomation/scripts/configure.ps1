$ErrorActionPreference = 'Stop'

function Ensure-AzdValue {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $Prompt,

        [switch] $Secret
    )

    $currentValue = azd env get-value $Name 2>$null

    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($currentValue)) {
        return
    }

    $value = & $Prompt

    if ($Secret) {
        #azd env set-secret $Name $value | Out-Null
        azd env set $Name $value | Out-Null
    }
    else {
        azd env set $Name $value | Out-Null
    }
}

Ensure-AzdValue `
    -Name 'VM_ADMIN_USERNAME' `
    -Prompt {
        Read-Host 'VM administrator username'
    }

Ensure-AzdValue `
    -Name 'VM_ADMIN_PASSWORD' `
    -Secret `
    -Prompt {
        # Beispiel im configure.ps1 Skript
        $password = Read-Host -AsSecureString "VM administrator password"
        # Konvertierung des SecureString in Klartext für azd (falls erforderlich)
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
        $plainPassword
    }

Ensure-AzdValue `
    -Name 'SQL_MI_ADMIN_USERNAME' `
    -Prompt {
        Read-Host 'SQL MI administrator username'
    }

Ensure-AzdValue `
    -Name 'SQL_MI_ADMIN_PASSWORD' `
    -Secret `
    -Prompt {
        # Beispiel im configure.ps1 Skript
        $password = Read-Host -AsSecureString "SQL MI administrator password"
        # Konvertierung des SecureString in Klartext für azd (falls erforderlich)
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
        $plainPassword
    }

Ensure-AzdValue `
    -Name 'TEAM_VM_COUNT' `
    -Prompt {
        do {
            $value = Read-Host 'Number of team VMs, from 3 through 20'
            $numericValue = $value -as [int]
        }
        until (
            $numericValue -ge 3 -and
            $numericValue -le 20
        )

        $numericValue
    }