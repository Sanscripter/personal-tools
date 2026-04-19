function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-PathIfExists {
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return
    }

    if (Test-Path $Candidate) {
        $parts = $env:Path -split ';'
        if ($parts -notcontains $Candidate) {
            $env:Path = "$Candidate;$env:Path"
        }
    }
}

function Refresh-WindowsToolingPath {
    Add-PathIfExists (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps')
    Add-PathIfExists (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links')
}

function Get-WingetPath {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\winget.exe')
    ) | Where-Object { $_ -and (-not [string]::IsNullOrWhiteSpace($_)) }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Refresh-NodeToolingPath {
    Refresh-WindowsToolingPath
    Add-PathIfExists $env:NVM_HOME
    Add-PathIfExists $env:NVM_SYMLINK
    Add-PathIfExists (Join-Path $env:ProgramFiles 'nvm')
    Add-PathIfExists (Join-Path $env:ProgramFiles 'nodejs')
    Add-PathIfExists (Join-Path $env:AppData 'npm')
    Add-PathIfExists (Join-Path $env:ProgramData 'chocolatey\bin')
}

function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-OptionalAudioWarning {
    param([string]$PromptMessage = 'Play an audible warning before requesting Administrator mode? [y/N]')

    $audioChoice = Read-Host $PromptMessage
    if ($audioChoice -notmatch '^(y|yes)$') {
        return
    }

    try {
        [console]::Beep(1200, 150)
        Start-Sleep -Milliseconds 100
        [console]::Beep(900, 250)
    }
    catch {
        Write-Host 'Audio warning is not available in this host.' -ForegroundColor DarkYellow
    }
}

function Ensure-ElevatedSession {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$ScriptArguments = @(),
        [string]$Reason = 'Administrator privileges are recommended for this setup step.'
    )

    if (Test-IsAdmin) {
        return $true
    }

    Write-Host ''
    Write-Host '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Yellow
    Write-Host '!! ADMINISTRATOR ACCESS IS ABOUT TO BE REQUESTED       !!' -ForegroundColor Yellow
    Write-Host '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Yellow
    Write-Host $Reason -ForegroundColor Red
    Write-Host "Working directory: $((Get-Location).Path)" -ForegroundColor Cyan

    Invoke-OptionalAudioWarning

    $confirm = Read-Host 'Open a new elevated PowerShell window now? [y/N]'
    if ($confirm -notmatch '^(y|yes)$') {
        Write-Host 'Cancelled. No elevated window was opened.' -ForegroundColor Yellow
        return $false
    }

    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory (Get-Location).Path -ArgumentList (@('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $ScriptArguments) | Out-Null
    return $false
}

function Ensure-PackageManager {
    Refresh-WindowsToolingPath

    $wingetPath = Get-WingetPath
    if ($wingetPath) {
        Add-PathIfExists (Split-Path -Parent $wingetPath)
        if (Test-Command 'winget') {
            return 'winget'
        }
    }

    if (Test-Command 'choco') {
        return 'choco'
    }

    Write-Host 'No package manager was found. Bootstrapping Chocolatey...' -ForegroundColor Yellow
    if (-not (Test-IsAdmin)) {
        throw 'Chocolatey bootstrapping requires an elevated shell. Re-run this installer as Administrator.'
    }

    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    Add-PathIfExists (Join-Path $env:ProgramData 'chocolatey\bin')
    if (Test-Command 'choco') {
        return 'choco'
    }

    throw 'Unable to initialize winget or Chocolatey.'
}

function Install-WindowsPackage {
    param(
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [string]$WingetId,
        [string]$ChocoId,
        [string]$AltChocoId
    )

    $pm = Ensure-PackageManager
    Write-Section "Installing $DisplayName"

    if ($pm -eq 'winget' -and $WingetId) {
        & winget install -e --id $WingetId --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            return
        }

        Write-Host 'winget did not complete cleanly. Falling back where possible...' -ForegroundColor Yellow
        Add-PathIfExists (Join-Path $env:ProgramData 'chocolatey\bin')
    }

    if ($ChocoId -and (Test-Command 'choco')) {
        & choco install $ChocoId -y
        if ($LASTEXITCODE -eq 0) {
            return
        }
    }

    if ($AltChocoId -and (Test-Command 'choco')) {
        & choco install $AltChocoId -y
        if ($LASTEXITCODE -eq 0) {
            return
        }
    }

    throw "Failed to install $DisplayName."
}

function Show-VersionIfAvailable {
    param(
        [string]$CommandName,
        [string[]]$CommandArgs = @('--version')
    )

    if (Test-Command $CommandName) {
        Write-Host ""
        Write-Host "$CommandName version:" -ForegroundColor Green
        & $CommandName @CommandArgs
    }
    else {
        Write-Host ""
        Write-Host "$CommandName is not on PATH yet. Open a new terminal after installation if needed." -ForegroundColor Yellow
    }
}
