param(
    [Parameter(Mandatory)][string]$Binary,
    [Parameter(Mandatory)][string]$Archive
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$binaryPath = (Resolve-Path -LiteralPath $Binary).Path
$archivePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Archive)
$version = '2026.10.26'
$assets = @{
    'yt-dlp.exe'    = 'f5389d3698ecde4ef06f4e6b1ce0294fe9ac1396228c8990b8d3416d6d177a7d'
    'yt-dlp.tar.gz' = '21f942d258d25cc4e60b4982a25c423460f0bebb835f38e6dfd1fcb140087f95'
}

$stage = [IO.Directory]::CreateTempSubdirectory('drift-package-').FullName
try {
    Copy-Item -LiteralPath $binaryPath -Destination (Join-Path $stage 'drift.exe')
    Copy-Item -LiteralPath (Join-Path $repo 'LICENSE'), (Join-Path $repo 'README.md') -Destination $stage
    Copy-Item -LiteralPath (Join-Path $repo 'docs/windows.md') -Destination (Join-Path $stage 'WINDOWS.md')

    $source = Join-Path $stage 'source'
    $files = git -C $repo -c core.quotePath=false ls-files --cached --others --exclude-standard
    if ($LASTEXITCODE -ne 0) { throw 'Could not list Drift source files' }
    foreach ($file in $files | Select-Object -Unique) {
        $original = Join-Path $repo $file
        if (!(Test-Path -LiteralPath $original -PathType Leaf)) { continue }
        $target = Join-Path (Join-Path $source 'drift') $file
        [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
        Copy-Item -LiteralPath $original -Destination $target
    }

    foreach ($asset in $assets.Keys) {
        $directory = if ($asset -eq 'yt-dlp.exe') { $stage } else { $source }
        $destination = Join-Path $directory $asset
        Invoke-WebRequest "https://github.com/yt-dlp/yt-dlp/releases/download/$version/$asset" -OutFile $destination -TimeoutSec 90
        $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $assets[$asset]) { throw "SHA-256 mismatch for $asset" }
    }

    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $archivePath)
    $zipHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$zipHash  $([IO.Path]::GetFileName($archivePath))" |
        Set-Content -LiteralPath "$archivePath.sha256" -Encoding ascii
} finally {
    $resolvedStage = (Resolve-Path -LiteralPath $stage).Path
    $temp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
    if ((Split-Path -Parent $resolvedStage) -eq $temp -and
        (Split-Path -Leaf $resolvedStage) -like 'drift-package-*') {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
