[CmdletBinding()]
param(
    [ValidateSet('status', 'init', 'sites', 'resolve-site', 'computers', 'computer', 'tabs', 'focus-tab')]
    [string] $Action = 'status',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InputArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contextPath = Join-Path $repoRoot 'setup\security\morgan-context.local.json'
$examplePath = Join-Path $repoRoot 'setup\security\morgan-context.local.example.json'

function New-DefaultContext {
    [ordered]@{
        sites = [ordered]@{
            github = 'https://github.com/'
            gmail = 'https://mail.google.com/'
            calendar = 'https://calendar.google.com/'
            work = @(
                'https://github.com/'
                'https://mail.google.com/'
                'https://calendar.google.com/'
            )
        }
        computers = [ordered]@{
            'this-pc' = [ordered]@{
                host  = $env:COMPUTERNAME
                notes = 'Current Windows machine'
                tags  = @('local')
            }
        }
    }
}

function Save-Context {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [object] $Data
    )

    $json = $Data | ConvertTo-Json -Depth 10
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

function Initialize-ContextFile {
    if (Test-Path $contextPath) {
        return $false
    }

    if (Test-Path $examplePath) {
        Copy-Item -Path $examplePath -Destination $contextPath -Force
    }
    else {
        Save-Context -Path $contextPath -Data (New-DefaultContext)
    }

    return $true
}

function Get-ContextData {
    param(
        [switch] $CreateIfMissing
    )

    if ($CreateIfMissing) {
        [void](Initialize-ContextFile)
    }

    if (-not (Test-Path $contextPath)) {
        return $null
    }

    $raw = Get-Content -Path $contextPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return (New-DefaultContext | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
    }

    return ($raw | ConvertFrom-Json)
}

function Get-NamedPropertyValue {
    param(
        [object] $Object,
        [string] $Name
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    $property = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-SiteUrls {
    param(
        [object] $SiteEntry
    )

    if ($null -eq $SiteEntry) {
        return @()
    }

    if ($SiteEntry -is [string]) {
        return @($SiteEntry)
    }

    if ($SiteEntry -is [System.Array]) {
        return @($SiteEntry | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) })
    }

    $url = Get-NamedPropertyValue -Object $SiteEntry -Name 'url'
    if ($url -is [string] -and -not [string]::IsNullOrWhiteSpace($url)) {
        return @($url)
    }

    $urls = Get-NamedPropertyValue -Object $SiteEntry -Name 'urls'
    if ($urls -is [System.Array]) {
        return @($urls | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) })
    }

    return @()
}

function Get-BrowserWindows {
    @(Get-Process chrome, msedge -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and -not [string]::IsNullOrWhiteSpace($_.MainWindowTitle) } |
        Sort-Object ProcessName, Id |
        Select-Object @{ Name = 'App'; Expression = { $_.ProcessName } }, Id, MainWindowTitle)
}

switch ($Action) {
    'init' {
        $created = Initialize-ContextFile
        if ($created) {
            Write-Host "Created Morgan context file: $contextPath"
        }
        else {
            Write-Host "Morgan context file already exists: $contextPath"
        }
        exit 0
    }

    'status' {
        $context = Get-ContextData -CreateIfMissing
        $siteCount = @($context.sites.PSObject.Properties).Count
        $computerCount = @($context.computers.PSObject.Properties).Count

        Write-Host 'Morgan context'
        Write-Host '--------------'
        Write-Host ("File: {0}" -f $contextPath)
        Write-Host ("Sites: {0}" -f $siteCount)
        Write-Host ("Computers: {0}" -f $computerCount)
        Write-Host 'Tip: edit the JSON file to add your own frequent sites, tab groups, and machines.'
        exit 0
    }

    'sites' {
        $context = Get-ContextData -CreateIfMissing
        Write-Host 'Saved sites'
        Write-Host '-----------'

        foreach ($property in $context.sites.PSObject.Properties) {
            $urls = @(Get-SiteUrls -SiteEntry $property.Value)
            if ($urls.Count -le 1) {
                Write-Host ("{0} -> {1}" -f $property.Name, ($urls | Select-Object -First 1))
            }
            else {
                Write-Host ("{0} -> {1} tabs" -f $property.Name, $urls.Count)
            }
        }

        exit 0
    }

    'resolve-site' {
        $context = Get-ContextData
        if ($null -eq $context) {
            exit 1
        }

        $name = ($InputArgs -join ' ').Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            exit 1
        }

        $entry = Get-NamedPropertyValue -Object $context.sites -Name $name
        $urls = @(Get-SiteUrls -SiteEntry $entry)

        if ($urls.Count -eq 0) {
            exit 1
        }

        $urls | Write-Output
        exit 0
    }

    'computers' {
        $context = Get-ContextData -CreateIfMissing
        Write-Host 'Saved computers'
        Write-Host '---------------'

        foreach ($property in $context.computers.PSObject.Properties) {
            $entry = $property.Value
            $machineHost = Get-NamedPropertyValue -Object $entry -Name 'host'
            $notes = Get-NamedPropertyValue -Object $entry -Name 'notes'
            if ([string]::IsNullOrWhiteSpace($notes)) {
                Write-Host ("{0} -> {1}" -f $property.Name, $machineHost)
            }
            else {
                Write-Host ("{0} -> {1} ({2})" -f $property.Name, $machineHost, $notes)
            }
        }

        exit 0
    }

    'computer' {
        $context = Get-ContextData -CreateIfMissing
        $name = if ($InputArgs.Count -gt 0) { $InputArgs[0] } else { '' }
        $mode = if ($InputArgs.Count -gt 1) { $InputArgs[1] } else { 'info' }

        if ([string]::IsNullOrWhiteSpace($name)) {
            Write-Host 'Use: morgan computer <name> [open]'
            exit 1
        }

        $entry = Get-NamedPropertyValue -Object $context.computers -Name $name
        if ($null -eq $entry) {
            Write-Host ("No saved computer named '{0}' was found." -f $name)
            exit 1
        }

        $machineHost = Get-NamedPropertyValue -Object $entry -Name 'host'
        $notes = Get-NamedPropertyValue -Object $entry -Name 'notes'
        $rdp = Get-NamedPropertyValue -Object $entry -Name 'rdp'
        $ssh = Get-NamedPropertyValue -Object $entry -Name 'ssh'

        Write-Host ("Computer: {0}" -f $name)
        if ($machineHost) { Write-Host ("Host: {0}" -f $machineHost) }
        if ($notes) { Write-Host ("Notes: {0}" -f $notes) }
        if ($rdp) { Write-Host ("RDP: {0}" -f $rdp) }
        if ($ssh) { Write-Host ("SSH: {0}" -f $ssh) }

        if ($mode -match '^(?i)(open|switch|connect)$') {
            if ($rdp) {
                Start-Process -FilePath 'mstsc.exe' -ArgumentList "/v:$rdp" | Out-Null
                Write-Host 'Opening Remote Desktop...'
                exit 0
            }

            if ($ssh) {
                Start-Process -FilePath 'cmd.exe' -ArgumentList @('/k', "ssh $ssh") | Out-Null
                Write-Host 'Opening SSH session...'
                exit 0
            }

            Write-Host 'This computer has no launch action yet. Add an rdp or ssh field in the context file.'
            exit 1
        }

        exit 0
    }

    'tabs' {
        $windows = @(Get-BrowserWindows)
        if ($windows.Count -eq 0) {
            Write-Host 'No visible Chrome or Edge windows were found.'
            exit 0
        }

        Write-Host 'Open browser tabs/windows'
        Write-Host '------------------------'
        foreach ($window in $windows) {
            Write-Host ("[{0}] {1}" -f $window.App, $window.MainWindowTitle)
        }

        exit 0
    }

    'focus-tab' {
        $query = ($InputArgs -join ' ').Trim()
        if ([string]::IsNullOrWhiteSpace($query)) {
            Write-Host 'Use: morgan tab <part of the tab title>'
            exit 1
        }

        $windows = @(Get-BrowserWindows)
        $match = $windows | Where-Object {
            $_.MainWindowTitle -like "*$query*" -or $_.App -like "*$query*"
        } | Select-Object -First 1

        if ($null -eq $match) {
            Write-Host ("No open browser tab matched '{0}'." -f $query)
            exit 1
        }

        $shell = New-Object -ComObject WScript.Shell
        [void]$shell.AppActivate([int]$match.Id)
        Write-Host ("Focused: {0}" -f $match.MainWindowTitle)
        exit 0
    }
}
