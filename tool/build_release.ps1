[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$pubspec = Get-Content -LiteralPath (Join-Path $projectDirectory 'pubspec.yaml') -Raw -Encoding UTF8
$versionMatch = [regex]::Match($pubspec, '(?m)^version:[ \t]*([^\r\n#]+)')
$version = $versionMatch.Groups[1].Value.Trim().Trim([char[]]@([char]39, [char]34))
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+\d+)?$') {
    throw 'Expected a version such as 1.0.0+1 in pubspec.yaml.'
}

$releaseDirectory = Join-Path $projectDirectory 'build\windows\x64\runner\Release'
$outputDirectory = [IO.Path]::GetFullPath((Join-Path $projectDirectory 'build\releases'))
$bundleName = "weils_api-$version-windows-x64"
$bundleDirectory = Join-Path $outputDirectory $bundleName
$archivePath = "$bundleDirectory.zip"
$executableName = "weils_api-$version.exe"

if (-not $Force -and ((Test-Path -LiteralPath $bundleDirectory) -or (Test-Path -LiteralPath $archivePath))) {
    throw "Release $version already exists. Update pubspec.yaml or pass -Force to replace it."
}

Push-Location -LiteralPath $projectDirectory
try {
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

foreach ($requiredPath in @('weils_api.exe', 'flutter_windows.dll', 'data\icudtl.dat', 'data\app.so', 'data\flutter_assets')) {
    if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory $requiredPath))) {
        throw "Release build is missing $requiredPath."
    }
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$stagingDirectory = Join-Path $outputDirectory ('.staging-' + [guid]::NewGuid().ToString('N'))
$stagingArchive = "$stagingDirectory.zip"

<#
.SYNOPSIS
仅删除 build/releases 下的直接子项，包括旧发布包与临时打包文件。
.DESCRIPTION
删除前解析绝对路径并校验父目录，避免递归删除超出发布输出目录。
#>
function Remove-ReleaseOutput([string]$Path) {
    $absolutePath = [IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetDirectoryName($absolutePath) -ne $outputDirectory) {
        throw "Refusing to remove a path outside $outputDirectory."
    }
    if (Test-Path -LiteralPath $absolutePath) {
        Remove-Item -LiteralPath $absolutePath -Recurse -Force
    }
}

try {
    # 复制到暂存目录打包，保留 Flutter 原始构建产物供后续构建和运行使用。
    Copy-Item -LiteralPath $releaseDirectory -Destination $stagingDirectory -Recurse
    Rename-Item -LiteralPath (Join-Path $stagingDirectory 'weils_api.exe') -NewName $executableName

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($stagingDirectory, $stagingArchive)

    # 仅在构建与打包都成功后替换已有版本。
    if ($Force) {
        Remove-ReleaseOutput $bundleDirectory
        Remove-ReleaseOutput $archivePath
    }
    Move-Item -LiteralPath $stagingDirectory -Destination $bundleDirectory
    Move-Item -LiteralPath $stagingArchive -Destination $archivePath
} finally {
    Remove-ReleaseOutput $stagingDirectory
    Remove-ReleaseOutput $stagingArchive
}

Write-Host "Version: $version"
Write-Host "EXE: $(Join-Path $bundleDirectory $executableName)"
Write-Host "ZIP: $archivePath"
