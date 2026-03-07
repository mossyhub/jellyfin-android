param(
    [string]$KeystorePath = ".\secrets\upload-key.jks",
    [string]$Alias = "upload",
    [string]$ApplicationId = 'com.blazelink.mossyfin',
    [string]$AaosApplicationId = 'com.blazelink.mossyfin.aaos',
    [string]$AppLabel = 'Mossyfin',
    [string]$AaosAppLabel = 'Mossyfin'
)

$ErrorActionPreference = 'Stop'

function ConvertTo-PlainText([Security.SecureString]$SecureString) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$resolvedKeystorePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KeystorePath)
if (-not (Test-Path $resolvedKeystorePath)) {
    throw "Keystore not found: $resolvedKeystorePath"
}

$storePasswordSecure = Read-Host 'Enter keystore password' -AsSecureString
$samePassword = Read-Host 'Use the same password for the key? (Y/n)'

$storePassword = ConvertTo-PlainText $storePasswordSecure
if ([string]::IsNullOrWhiteSpace($samePassword) -or $samePassword -match '^[Yy]') {
    $keyPassword = $storePassword
}
else {
    $keyPasswordSecure = Read-Host 'Enter key password' -AsSecureString
    $keyPassword = ConvertTo-PlainText $keyPasswordSecure
}

try {
    & "$repoRoot\scripts\build-aaos.ps1" `
        -Task bundleAaosProprietaryRelease `
        -ApplicationId $ApplicationId `
        -AaosApplicationId $AaosApplicationId `
        -AppLabel $AppLabel `
        -AaosAppLabel $AaosAppLabel `
        -StoreFile $resolvedKeystorePath `
        -StorePassword $storePassword `
        -KeyAlias $Alias `
        -KeyPassword $keyPassword
}
finally {
    $storePassword = $null
    $keyPassword = $null
}