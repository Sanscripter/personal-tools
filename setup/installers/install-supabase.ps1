param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

function Get-SupabaseInstallDir {
    return (Join-Path $env:LOCALAPPDATA 'Programs\Supabase\bin')
}

function Get-SupabaseExePath {
    return (Join-Path (Get-SupabaseInstallDir) 'supabase.exe')
}

function Add-UserPathIfMissing {
    param([Parameter(Mandatory = $true)][string]$Candidate)

    if (-not (Test-Path $Candidate)) {
        return
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
        $parts = $userPath -split ';'
    }

    if ($parts -contains $Candidate) {
        Add-PathIfExists $Candidate
        return
    }

    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        $Candidate
    }
    else {
        $userPath.TrimEnd(';') + ';' + $Candidate
    }

    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    Add-PathIfExists $Candidate
}

function Update-SupabasePath {
    Add-UserPathIfMissing (Get-SupabaseInstallDir)
}

function Get-SupabaseAssetName {
    try {
        $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    }
    catch {
        $arch = ([Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')).ToLowerInvariant()
    }

    if ($arch -match 'arm64') {
        return 'supabase_windows_arm64.tar.gz'
    }

    return 'supabase_windows_amd64.tar.gz'
}

function Show-SupabaseInfo {
    Update-SupabasePath

    $supabaseCommand = Get-Command supabase -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $supabaseCommand) {
        $exePath = Get-SupabaseExePath
        if (Test-Path $exePath) {
            $supabaseCommand = Get-Item $exePath
        }
    }

    if ($supabaseCommand) {
        Write-Host ''
        Write-Host 'Supabase CLI: ready' -ForegroundColor Green
        Write-Host ('Path: ' + $supabaseCommand.Source)
        try {
            & $supabaseCommand.Source --version
        }
        catch {
            Write-Host 'The CLI is installed but its version could not be queried in this shell yet.' -ForegroundColor Yellow
        }
    }
    else {
        Write-Host ''
        Write-Host 'Supabase CLI is not on PATH yet.' -ForegroundColor Yellow
    }
}

function Install-SupabaseCli {
    $installDir = Get-SupabaseInstallDir
    $exePath = Get-SupabaseExePath

    if (Test-Path $exePath) {
        Update-SupabasePath
        return
    }

    $assetName = Get-SupabaseAssetName
    $downloadUrl = 'https://github.com/supabase/cli/releases/latest/download/' + $assetName
    $tempRoot = Join-Path $env:TEMP ('supabase-cli-' + [guid]::NewGuid().ToString('N'))
    $archivePath = Join-Path $tempRoot $assetName
    $extractDir = Join-Path $tempRoot 'extract'

    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null

    Write-Host 'Downloading Supabase CLI...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing

    Write-Host 'Extracting archive...' -ForegroundColor Cyan
    & tar -xzf $archivePath -C $extractDir
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to extract the Supabase CLI archive.'
    }

    $downloadedExe = Get-ChildItem -Path $extractDir -Filter 'supabase.exe' -Recurse -File | Select-Object -First 1
    if (-not $downloadedExe) {
        throw 'The extracted archive did not contain supabase.exe.'
    }

    Copy-Item -LiteralPath $downloadedExe.FullName -Destination $exePath -Force
    Update-SupabasePath

    try {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
    }
}

Write-Host 'Supabase CLI setup' -ForegroundColor Cyan
Update-SupabasePath

if ($Status) {
    Show-SupabaseInfo
    exit 0
}

Install-SupabaseCli
Show-SupabaseInfo

Write-Host ''
Write-Host 'Supabase CLI setup finished. Try: supabase --help' -ForegroundColor Green
