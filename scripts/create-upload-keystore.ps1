param(
    [string]$OutputPath = ".\secrets\upload-key.jks",
    [string]$Alias = "upload",
    [string]$JavaHome = 'C:\Program Files\Android\Android Studio\jbr',
    [string]$CommonName = 'Mossyfin Upload Key',
    [string]$OrgUnit = 'Personal',
    [string]$Organization = 'Personal',
    [string]$City = 'Unknown',
    [string]$State = 'Unknown',
    [string]$CountryCode = 'US',
    [int]$ValidityDays = 9125,
    [switch]$Force
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

$javaExe = Join-Path $JavaHome 'bin\keytool.exe'
if (-not (Test-Path $javaExe)) {
    throw "keytool.exe not found under: $JavaHome"
}

$resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$outputDir = Split-Path -Parent $resolvedOutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

if ((Test-Path $resolvedOutputPath) -and -not $Force) {
    throw "Keystore already exists: $resolvedOutputPath. Use -Force to overwrite it."
}

$storePasswordSecure = Read-Host 'Enter keystore password' -AsSecureString
$confirmStorePasswordSecure = Read-Host 'Confirm keystore password' -AsSecureString
$storePassword = ConvertTo-PlainText $storePasswordSecure
$confirmStorePassword = ConvertTo-PlainText $confirmStorePasswordSecure

if ($storePassword -ne $confirmStorePassword) {
    throw 'Keystore passwords did not match.'
}

$keyPasswordSecure = Read-Host 'Enter key password (press Enter to reuse keystore password)' -AsSecureString
$keyPassword = ConvertTo-PlainText $keyPasswordSecure
if ([string]::IsNullOrWhiteSpace($keyPassword)) {
    $keyPassword = $storePassword
}

$dname = "CN=$CommonName, OU=$OrgUnit, O=$Organization, L=$City, S=$State, C=$CountryCode"

$arguments = @(
    '-genkeypair'
    '-v'
    '-storetype', 'PKCS12'
    '-keystore', $resolvedOutputPath
    '-alias', $Alias
    '-keyalg', 'RSA'
    '-keysize', '4096'
    '-validity', $ValidityDays
    '-storepass', $storePassword
    '-keypass', $keyPassword
    '-dname', $dname
)

try {
    & $javaExe @arguments
}
finally {
    $storePassword = $null
    $confirmStorePassword = $null
    $keyPassword = $null
}

Write-Host "[create-upload-keystore] Keystore created at: $resolvedOutputPath"
Write-Host "[create-upload-keystore] Alias: $Alias"
Write-Host "[create-upload-keystore] Keep this file and both passwords safe"