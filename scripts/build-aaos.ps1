param(
    [string]$Task = 'bundleAaosProprietaryRelease',
    [string]$JavaHome = 'C:\Program Files\Android\Android Studio\jbr',
    [string]$AndroidSdkRoot = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$ApplicationId = 'com.blazelink.mossyfin',
    [string]$AaosApplicationId = 'com.blazelink.mossyfin.aaos',
    [string]$AppLabel = 'Mossyfin',
    [string]$AaosAppLabel = 'Mossyfin',
    [string]$StoreFile,
    [string]$StorePassword,
    [string]$KeyAlias,
    [string]$KeyPassword
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Test-Path $JavaHome)) {
    throw "JAVA_HOME path does not exist: $JavaHome"
}

$javaExe = Join-Path $JavaHome 'bin\java.exe'
if (-not (Test-Path $javaExe)) {
    throw "java.exe not found under: $JavaHome"
}

if (-not (Test-Path $AndroidSdkRoot)) {
    throw "Android SDK path does not exist: $AndroidSdkRoot"
}

$escapedSdk = $AndroidSdkRoot.Replace('\', '\\').Replace(':', '\:')
Set-Content -Path (Join-Path $repoRoot 'local.properties') -Value "sdk.dir=$escapedSdk" -Encoding ASCII

$env:JAVA_HOME = $JavaHome

$gradleArgs = @(
    '-Dorg.gradle.appname=gradlew'
    '-classpath'
    '.\gradle\wrapper\gradle-wrapper.jar'
    'org.gradle.wrapper.GradleWrapperMain'
    $Task
    '--stacktrace'
)

if ($ApplicationId) {
    $gradleArgs += "-Papp.applicationId=$ApplicationId"
}

if ($AppLabel) {
    $gradleArgs += "-Papp.appLabel=$AppLabel"
}

if ($AaosApplicationId) {
    $gradleArgs += "-Papp.aaosApplicationId=$AaosApplicationId"
}

if ($AaosAppLabel) {
    $gradleArgs += "-Papp.aaosAppLabel=$AaosAppLabel"
}

$hasSigningValues = $StoreFile -or $StorePassword -or $KeyAlias -or $KeyPassword
if ($hasSigningValues) {
    $missing = @()
    if (-not $StoreFile) { $missing += 'StoreFile' }
    if (-not $StorePassword) { $missing += 'StorePassword' }
    if (-not $KeyAlias) { $missing += 'KeyAlias' }
    if (-not $KeyPassword) { $missing += 'KeyPassword' }
    if ($missing.Count -gt 0) {
        throw "Signing requires parameters: $($missing -join ', ')"
    }

    $gradleArgs += @(
        "-Psigning.storeFile=$StoreFile"
        "-Psigning.storePassword=$StorePassword"
        "-Psigning.keyAlias=$KeyAlias"
        "-Psigning.keyPassword=$KeyPassword"
        "-Pandroid.injected.signing.store.file=$StoreFile"
        "-Pandroid.injected.signing.store.password=$StorePassword"
        "-Pandroid.injected.signing.key.alias=$KeyAlias"
        "-Pandroid.injected.signing.key.password=$KeyPassword"
    )
}

Write-Host "[build-aaos] Repo root: $repoRoot"
Write-Host "[build-aaos] Task: $Task"
Write-Host "[build-aaos] Java: $javaExe"
Write-Host "[build-aaos] Android SDK: $AndroidSdkRoot"
Write-Host "[build-aaos] App ID: $ApplicationId"
Write-Host "[build-aaos] AAOS App ID: $AaosApplicationId"

& $javaExe @gradleArgs