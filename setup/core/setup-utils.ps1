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

$script:PersonalToolsApprovalSettingsLoaded = $false

function Import-ApprovalSettings {
    if ($script:PersonalToolsApprovalSettingsLoaded) {
        return
    }

    $script:PersonalToolsApprovalSettingsLoaded = $true
    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $localSettingsPath = Join-Path $repoRoot 'setup\security\approval.local.ps1'

    if (Test-Path $localSettingsPath) {
        . $localSettingsPath
    }
}

function Get-ApprovalMode {
    Import-ApprovalSettings

    $mode = [string]$env:PERSONAL_TOOLS_APPROVAL_MODE
    if ([string]::IsNullOrWhiteSpace($mode)) {
        return 'off'
    }

    return $mode.Trim().ToLowerInvariant()
}

function Get-ApprovalTimeoutSeconds {
    Import-ApprovalSettings

    $defaultTimeout = 120
    $raw = [string]$env:PERSONAL_TOOLS_APPROVAL_TIMEOUT_SEC
    $parsed = 0

    if ([int]::TryParse($raw, [ref]$parsed) -and $parsed -ge 30) {
        return $parsed
    }

    return $defaultTimeout
}

function Get-ApprovalPageUrl {
    Import-ApprovalSettings

    $configuredUrl = [string]$env:PERSONAL_TOOLS_APPROVAL_PAGE_URL
    if (-not [string]::IsNullOrWhiteSpace($configuredUrl)) {
        return $configuredUrl.Trim()
    }

    $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $localPagePath = Join-Path $repoRoot 'setup\security\approval-page.html'
    return ([System.Uri]::new($localPagePath)).AbsoluteUri
}

function New-ApprovalSecret {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        $rng.GetBytes($bytes)
    }
    finally {
        if ($null -ne $rng) {
            $rng.Dispose()
        }
    }

    $secret = [Convert]::ToBase64String($bytes).TrimEnd('=')
    return ($secret -replace '\+', '-' -replace '/', '_')
}

function ConvertTo-QueryString {
    param([hashtable]$Parameters)

    if ($null -eq $Parameters -or $Parameters.Count -eq 0) {
        return ''
    }

    return (($Parameters.GetEnumerator() |
        Where-Object { $null -ne $_.Value -and -not [string]::IsNullOrWhiteSpace([string]$_.Value) } |
        ForEach-Object {
            '{0}={1}' -f [System.Uri]::EscapeDataString([string]$_.Key), [System.Uri]::EscapeDataString([string]$_.Value)
        }) -join '&')
}

function Invoke-ApprovalApiRequest {
    param(
        [Parameter(Mandatory = $true)][string]$SupabaseUrl,
        [Parameter(Mandatory = $true)][string]$AnonKey,
        [Parameter(Mandatory = $true)][ValidateSet('Get', 'Post', 'Patch')][string]$Method,
        [string]$RelativePath = '',
        [hashtable]$ExtraHeaders,
        [object]$Body
    )

    $headers = @{
        apikey        = $AnonKey
        Authorization = "Bearer $AnonKey"
        Accept        = 'application/json'
    }

    if ($ExtraHeaders) {
        foreach ($key in $ExtraHeaders.Keys) {
            $headers[$key] = $ExtraHeaders[$key]
        }
    }

    $invokeParams = @{
        Method      = $Method
        Uri         = ($SupabaseUrl.TrimEnd('/') + '/rest/v1/admin_approval_requests' + $RelativePath)
        Headers     = $headers
        ErrorAction = 'Stop'
    }

    if ($null -ne $Body) {
        $invokeParams['ContentType'] = 'application/json'
        $invokeParams['Body'] = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }

    return Invoke-RestMethod @invokeParams
}

function Request-PrivilegedApproval {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [string]$Reason = 'Administrator privileges are being requested from the personal-tools repo.',
        [int]$TimeoutSec = 0
    )

    $mode = Get-ApprovalMode
    if ($mode -in @('off', 'disabled', 'false', '0', 'no')) {
        return $true
    }

    Import-ApprovalSettings

    $supabaseUrl = [string]$env:PERSONAL_TOOLS_SUPABASE_URL
    $anonKey = [string]$env:PERSONAL_TOOLS_SUPABASE_ANON_KEY
    $approverEmail = [string]$env:PERSONAL_TOOLS_APPROVER_EMAIL

    if ($TimeoutSec -le 0) {
        $TimeoutSec = Get-ApprovalTimeoutSeconds
    }

    if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or
        [string]::IsNullOrWhiteSpace($anonKey) -or
        [string]::IsNullOrWhiteSpace($approverEmail)) {
        $message = 'Approval is enabled but the Supabase settings are incomplete. Update setup\security\approval.local.ps1 first.'
        if ($mode -eq 'required') {
            Write-Host $message -ForegroundColor Red
            return $false
        }

        Write-Host $message -ForegroundColor Yellow
        return $true
    }

    $requestId = [guid]::NewGuid().Guid
    $requestSecret = New-ApprovalSecret
    $expiresAt = [DateTime]::UtcNow.AddSeconds([Math]::Max($TimeoutSec, 30)).ToString('o')
    $normalizedApprover = $approverEmail.Trim().ToLowerInvariant()

    $body = [ordered]@{
        request_id       = $requestId
        request_secret   = $requestSecret
        action           = $Action
        reason           = $Reason
        requester_host   = $env:COMPUTERNAME
        requester_user   = [Environment]::UserName
        allowed_email    = $normalizedApprover
        expires_at       = $expiresAt
    }

    try {
        $null = Invoke-ApprovalApiRequest -SupabaseUrl $supabaseUrl -AnonKey $anonKey -Method Post -ExtraHeaders @{
            Prefer             = 'return=representation'
            'X-Approval-Secret' = $requestSecret
        } -Body $body
    }
    catch {
        Write-Host ('Could not create the approval request: ' + $_.Exception.Message) -ForegroundColor Red
        return $false
    }

    $approvalPageUrl = Get-ApprovalPageUrl
    $queryString = ConvertTo-QueryString @{
        request     = $requestId
        secret      = $requestSecret
        supabaseUrl = $supabaseUrl
        anonKey     = $anonKey
    }
    $launchUrl = $approvalPageUrl + $(if ($approvalPageUrl.Contains('?')) { '&' } else { '?' }) + $queryString

    Write-Host ''
    Write-Host 'Approval request created.' -ForegroundColor Green
    Write-Host ("Action: {0}" -f $Action) -ForegroundColor Cyan
    Write-Host ("Approver: {0}" -f $normalizedApprover) -ForegroundColor Cyan
    Write-Host 'Check your phone and approve the request in the browser page.' -ForegroundColor Yellow

    try {
        Start-Process -FilePath $launchUrl | Out-Null
    }
    catch {
        Write-Host 'The approval page could not be opened automatically. Open your configured approval URL manually.' -ForegroundColor Yellow
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Seconds 2

        try {
            $requestIdFilter = [System.Uri]::EscapeDataString("eq.$requestId")
            $selectFields = [System.Uri]::EscapeDataString('request_id,status,approved_by_email,expires_at')
            $response = Invoke-ApprovalApiRequest -SupabaseUrl $supabaseUrl -AnonKey $anonKey -Method Get -RelativePath "?request_id=$requestIdFilter&select=$selectFields&limit=1" -ExtraHeaders @{
                'X-Approval-Secret' = $requestSecret
            }

            $requestState = @($response) | Select-Object -First 1
            if ($null -eq $requestState) {
                continue
            }

            switch ([string]$requestState.status) {
                'approved' {
                    Write-Host 'Approval granted.' -ForegroundColor Green
                    return $true
                }
                'denied' {
                    Write-Host 'Approval was denied.' -ForegroundColor Yellow
                    return $false
                }
                'expired' {
                    Write-Host 'Approval request expired.' -ForegroundColor Yellow
                    return $false
                }
            }
        }
        catch {
            continue
        }
    }

    Write-Host 'Approval timed out.' -ForegroundColor Yellow
    return $false
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

    if (-not (Request-PrivilegedApproval -Action 'administrator session' -Reason $Reason)) {
        Write-Host 'Approval was not granted, so the elevated window was not opened.' -ForegroundColor Yellow
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
