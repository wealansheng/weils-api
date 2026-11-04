[CmdletBinding()]
param(
    [switch]$PrepareOnly,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs = @()
)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$localDirectory = Join-Path $projectDirectory '.local-data'
$temporaryDirectory = Join-Path $projectDirectory 'build\dev-temp'

# 使用项目内的数据目录，避免开发进程继承无法访问的用户目录；保留已有本地副本。
New-Item -ItemType Directory -Force -Path $localDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
$destinationFile = Join-Path $localDirectory 'workspace.json'
if (-not (Test-Path -LiteralPath $destinationFile)) {
    foreach ($suffix in @('.bak', '.tmp')) {
        if (Test-Path -LiteralPath "$destinationFile$suffix") {
            throw "Local workspace has recovery files: $destinationFile$suffix. Restore them before initializing a new workspace."
        }
    }
    $initialDirectory = [Environment]::GetEnvironmentVariable('WEILS_API_DATA_DIR', 'Process')
    if ([string]::IsNullOrWhiteSpace($initialDirectory)) {
        $initialDirectory = Join-Path $env:APPDATA 'WeilsAPI'
    }
    $sourceDirectory = $initialDirectory
    $locationFile = Join-Path $initialDirectory 'settings.json'
    if (Test-Path -LiteralPath $locationFile) {
        $location = Get-Content -LiteralPath $locationFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($location.version -ne 1 -or [string]::IsNullOrWhiteSpace($location.dataDirectory) -or
            -not [IO.Path]::IsPathRooted($location.dataDirectory)) {
            throw "Invalid data-directory configuration: $locationFile"
        }
        $sourceDirectory = $location.dataDirectory
        if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) {
            throw "Existing workspace directory is unavailable: $sourceDirectory. No empty replacement was created."
        }
    }
    $sourceFile = Join-Path $sourceDirectory 'workspace.json'
    if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
        # 先暂存副本再生成主文件，避免下次启动将复制失败的文件误认为已初始化的数据。
        $stagingFile = "$destinationFile.importing"
        if (Test-Path -LiteralPath $stagingFile) {
            throw "An unfinished workspace import exists: $stagingFile. Check it before retrying."
        }
        Copy-Item -LiteralPath $sourceFile -Destination $stagingFile -ErrorAction Stop
        if (Test-Path -LiteralPath "$sourceFile.bak" -PathType Leaf) {
            Copy-Item -LiteralPath "$sourceFile.bak" -Destination "$destinationFile.bak" -ErrorAction Stop
        }
        Move-Item -LiteralPath $stagingFile -Destination $destinationFile -ErrorAction Stop
        Write-Host "Copied workspace from $sourceDirectory. Original files were retained."
    } elseif (Test-Path -LiteralPath "$sourceFile.bak" -PathType Leaf) {
        throw "Only a backup exists at $sourceFile.bak. Restore it before initializing a local workspace."
    }
}

Write-Host "Workspace: $localDirectory"
Write-Host "Temporary files: $temporaryDirectory"
if ($PrepareOnly) { return }

$previousEnvironment = @{}
foreach ($variableName in @('WEILS_API_DATA_DIR', 'TEMP', 'TMP')) {
    $environmentPath = "Env:$variableName"
    $present = Test-Path -LiteralPath $environmentPath
    $previousEnvironment[$variableName] = @{
        Present = $present
        Value = if ($present) { (Get-Item -LiteralPath $environmentPath).Value } else { $null }
    }
}
Push-Location -LiteralPath $projectDirectory
try {
    $env:WEILS_API_DATA_DIR = $localDirectory
    $env:TEMP = $temporaryDirectory
    $env:TMP = $temporaryDirectory
    & flutter run -d windows @FlutterArgs
    $flutterExitCode = $LASTEXITCODE
} finally {
    foreach ($variableName in $previousEnvironment.Keys) {
        $previous = $previousEnvironment[$variableName]
        if ($previous.Present) {
            Set-Item -LiteralPath "Env:$variableName" -Value $previous.Value
        } else {
            Remove-Item -LiteralPath "Env:$variableName" -ErrorAction SilentlyContinue
        }
    }
    Pop-Location
}
if ($flutterExitCode -ne 0) { throw "Flutter run failed with exit code $flutterExitCode." }
