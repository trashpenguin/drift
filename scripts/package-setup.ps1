param(
    [Parameter(Mandatory)][string]$Package,
    [Parameter(Mandatory)][string]$Installer,
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [string]$MpvArchive,
    [string]$CompilerInstaller
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$packagePath = (Resolve-Path -LiteralPath $Package).Path
$setupPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Installer)
$stage = [IO.Directory]::CreateTempSubdirectory('drift-setup-').FullName

function Get-VerifiedArchive($Path, $Url, $Name, $ExpectedHash) {
    if ($Path) {
        $Path = (Resolve-Path -LiteralPath $Path).Path
    } else {
        $Path = Join-Path $stage $Name
        curl.exe --fail --location --silent --show-error --retry 2 --max-time 180 -o $Path $Url
        if ($LASTEXITCODE -ne 0) { throw "Could not download $Name" }
    }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($hash -ne $ExpectedHash) { throw "SHA-256 mismatch for $Name" }
    return $Path
}

try {
    $inno = Get-VerifiedArchive $CompilerInstaller `
        'https://github.com/jrsoftware/issrc/releases/download/is-7_1_1/innosetup-7.1.1-x64.exe' 'inno.exe' `
        '8A5A6711C3766A6E5FB74F280BA0E3551E719CE94538D901FDBD1F8F9920B3F0'
    $mpv = Get-VerifiedArchive $MpvArchive `
        'https://pilotfiber.dl.sourceforge.net/project/mpv-player-windows/release/mpv-0.41.0-x86_64.7z' 'mpv.7z' `
        'EF86FDE0959D789D77A3AD7C3C2DCA51C6999695363F493A6154F2C518634C0F'

    $payload = Join-Path $stage 'payload'
    [IO.Directory]::CreateDirectory($payload) | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($packagePath)
    try {
        foreach ($name in 'drift.exe', 'yt-dlp.exe', 'LICENSE') {
            $entry = $zip.GetEntry($name)
            if (!$entry) { throw "Missing $name in the portable Drift package" }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $payload $name))
        }
    } finally {
        $zip.Dispose()
    }
    tar.exe -xf $mpv -C $payload mpv.exe d3dcompiler_43.dll
    if ($LASTEXITCODE -ne 0) { throw 'Could not extract the mpv runtime' }
    $copyright = Get-VerifiedArchive $null `
        'https://raw.githubusercontent.com/mpv-player/mpv/v0.41.0/Copyright' 'mpv-Copyright.txt' `
        'BFE9EE4CCEABCB8ECBFADF208D04156F73D801E6A57369A5606BB8341E204A23'
    $license = Get-VerifiedArchive $null `
        'https://raw.githubusercontent.com/mpv-player/mpv/v0.41.0/LICENSE.GPL' 'mpv-LICENSE.GPL.txt' `
        'EDAEF632CBB643E4E7A221717A6C441A4C1A7C918E6E4D56DEBC3D8739B233F6'
    Copy-Item -LiteralPath $copyright, $license -Destination $payload
    Copy-Item -LiteralPath (Join-Path $repo 'docs/windows.md') -Destination (Join-Path $payload 'WINDOWS.md')

    $compilerDir = Join-Path $stage 'compiler'
    $install = Start-Process -FilePath $inno -WindowStyle Hidden -PassThru -Wait -ArgumentList `
        "/PORTABLE=1 /CURRENTUSER /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOICONS /DIR=`"$compilerDir`""
    if ($install.ExitCode -ne 0) { throw 'Could not stage the Inno Setup compiler' }

    $compiler = Join-Path $compilerDir 'ISCC.exe'
    $outputDir = Split-Path -Parent $setupPath
    $basename = [IO.Path]::GetFileNameWithoutExtension($setupPath)
    & $compiler '/Qp' "/O$outputDir" "/F$basename" "/DVersion=$Version" "/DPayload=$payload" (Join-Path $PSScriptRoot 'drift-setup.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Inno Setup failed to build Drift Setup' }

    $hash = (Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($setupPath))" |
        Set-Content -LiteralPath "$setupPath.sha256" -Encoding ascii
} finally {
    $resolvedStage = (Resolve-Path -LiteralPath $stage).Path
    $temp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
    if ((Split-Path -Parent $resolvedStage) -eq $temp -and
        (Split-Path -Leaf $resolvedStage) -like 'drift-setup-*') {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
