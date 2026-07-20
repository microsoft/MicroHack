param(
    [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [string]$Jwt
)

begin {
    function Convert-FromBase64Url {
        param([string]$Value)
        $Value = $Value.Replace('-','+').Replace('_','/')
        switch ($Value.Length % 4) {
            2 { $Value += '==' }
            3 { $Value += '=' }
            0 { }
            default { throw "Invalid Base64URL length." }
        }
        [Convert]::FromBase64String($Value)
    }
}

process {
    $Jwt = $Jwt.Trim()
    $parts = $Jwt -split '\.'
    if ($parts.Length -ne 3) {
        throw "Not a valid JWT (expected 3 dot-separated parts)."
    }

    $headerJson = [Text.Encoding]::UTF8.GetString((Convert-FromBase64Url $parts[0]))
    $payloadJson = [Text.Encoding]::UTF8.GetString((Convert-FromBase64Url $parts[1]))
    $signatureBytes = Convert-FromBase64Url $parts[2]

    $headerObj = $headerJson | ConvertFrom-Json
    $payloadObj = $payloadJson | ConvertFrom-Json

    Write-Host "`n=== JWT HEADER ===" -ForegroundColor Cyan
    $headerObj | Format-List

    Write-Host "=== JWT PAYLOAD ===" -ForegroundColor Cyan
    $payloadObj | Format-List

    Write-Host "=== TOKEN TIMING ===" -ForegroundColor Cyan
    if ($payloadObj.iat) {
        $issuedAt = [DateTimeOffset]::FromUnixTimeSeconds($payloadObj.iat).LocalDateTime
        Write-Host "Issued At (iat):  $issuedAt"
    }
    if ($payloadObj.nbf) {
        $notBefore = [DateTimeOffset]::FromUnixTimeSeconds($payloadObj.nbf).LocalDateTime
        Write-Host "Not Before (nbf): $notBefore"
    }
    if ($payloadObj.exp) {
        $expires = [DateTimeOffset]::FromUnixTimeSeconds($payloadObj.exp).LocalDateTime
        $remaining = $expires - [DateTime]::Now
        Write-Host "Expires (exp):    $expires"
        if ($remaining.TotalSeconds -gt 0) {
            Write-Host "Time Remaining:   $($remaining.ToString('hh\:mm\:ss'))" -ForegroundColor Green
        } else {
            Write-Host "Status:           EXPIRED" -ForegroundColor Red
        }
    }

    Write-Host "`n=== SIGNATURE (SHA256) ===" -ForegroundColor Cyan
    $sigHash = ([System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($signatureBytes))).Replace('-','')
    Write-Host $sigHash

    Write-Host ""
}