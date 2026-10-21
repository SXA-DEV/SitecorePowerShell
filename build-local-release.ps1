[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repositoryRoot = $PSScriptRoot
$solutionPath = Join-Path $repositoryRoot "Spe.sln"
$cliDirectory = Join-Path $repositoryRoot "cli"
$generateScript = Join-Path $cliDirectory "generate.bat"
$vswherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

foreach ($path in @($solutionPath, $generateScript, $vswherePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required build file was not found: $path"
    }
}

$visualStudioPath = & $vswherePath -latest -products "*" -requires Microsoft.Component.MSBuild -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $visualStudioPath) {
    throw "Visual Studio with MSBuild was not found."
}

$visualStudioPath = $visualStudioPath | Select-Object -First 1
$msbuildPath = Join-Path $visualStudioPath "MSBuild\Current\Bin\MSBuild.exe"
$visualStudioVersion = (& $vswherePath -latest -products "*" -requires Microsoft.Component.MSBuild -property installationVersion).Split(".")[0]
$webTargetsPath = Join-Path $visualStudioPath "MSBuild\Microsoft\VisualStudio\v$visualStudioVersion.0\WebApplications\Microsoft.WebApplication.targets"

if (-not (Test-Path -LiteralPath $msbuildPath)) {
    throw "MSBuild was not found at: $msbuildPath"
}
if (-not (Test-Path -LiteralPath $webTargetsPath)) {
    throw "The Visual Studio WebApplication targets are missing: $webTargetsPath"
}

Write-Host "Building Release locally with Visual Studio MSBuild."
$noOpPostBuildScript = Join-Path ([System.IO.Path]::GetTempPath()) "spe-no-post-build-$([guid]::NewGuid().ToString('N')).ps1"
New-Item -ItemType File -Path $noOpPostBuildScript -ErrorAction Stop | Out-Null

$buildArguments = @(
    $solutionPath
    "/t:Build"
    "/p:Configuration=Release"
    "/p:LangVersion=13.0"
    "/p:ScriptLocation=$noOpPostBuildScript"
    "/m"
)
try {
    & $msbuildPath @buildArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Release build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Remove-Item -LiteralPath $noOpPostBuildScript -Force -ErrorAction SilentlyContinue
}

Write-Host "Generating serialized item resource files locally."
Push-Location $cliDirectory
try {
    & $generateScript
    if ($LASTEXITCODE -ne 0) {
        throw "Sitecore CLI item-resource generation failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$resourceDirectory = Join-Path $cliDirectory "_out"
$stagingItemsDirectory = Join-Path $repositoryRoot "src\_Deploy\Spe\sitecore modules\items"
foreach ($database in @("core", "master", "web")) {
    $resourceName = "items.$database.spe.dat"
    $sourcePath = Join-Path $resourceDirectory $resourceName
    $destinationDirectory = Join-Path $stagingItemsDirectory $database
    $destinationPath = Join-Path $destinationDirectory $resourceName

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Generated item resource was not found: $sourcePath"
    }
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        throw "Build staging directory was not found: $destinationDirectory"
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    $placeholderPath = "$destinationPath.tmp"
    if (Test-Path -LiteralPath $placeholderPath) {
        Remove-Item -LiteralPath $placeholderPath -Force
    }

    Write-Host "Staged $destinationPath"
}

Write-Host "Local Release outputs are in src\_Deploy\Spe. No Sitecore instance was contacted."
Write-Host "This script does not create the installable ZIP or Web Deploy package."