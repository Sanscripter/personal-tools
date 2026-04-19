[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InputArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Help {
    @"
Steam helper

Usage:
  steam open
  steam status
  steam list
  steam browse
  steam search <game name>
  steam play <game name|number|appid>
  steam run <appid>
  steam store <query>
  steam help

Examples:
  steam open
  steam list
  steam browse
  steam search portal
  steam play Hades
  steam play 14
  steam play warband
  steam play "Mount & Blade: Warband"
  steam run 620
  steam store balatro

What it does:
  - opens the local Steam client when available
  - reads your installed Steam library manifests
  - lists your installed games directly in the terminal
  - searches by name and can launch a game by name or app id
"@ | Write-Host
}

function Get-RawInput {
    if ($InputArgs -and $InputArgs.Count -gt 0) {
        return ($InputArgs -join ' ').Trim()
    }

    $raw = [Environment]::GetEnvironmentVariable('STEAM_RAW_ARGS', 'Process')
    if ($null -eq $raw) {
        return ''
    }

    return $raw.Trim()
}

function ConvertTo-NormalPathString {
    param(
        [AllowEmptyString()]
        [string] $PathText
    )

    if ([string]::IsNullOrWhiteSpace($PathText)) {
        return ''
    }

    $value = [Environment]::ExpandEnvironmentVariables($PathText)
    $value = $value -replace '/', '\'
    $value = $value -replace '\\\\', '\'
    return $value.Trim()
}

function Get-SteamInstallation {
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($regPath in @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )) {
        try {
            $item = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($prop in @('SteamExe', 'SteamPath', 'InstallPath')) {
                if ($item.PSObject.Properties.Name -contains $prop) {
                    $raw = [string] $item.$prop
                    if (-not [string]::IsNullOrWhiteSpace($raw)) {
                        if ($prop -eq 'SteamPath' -or $prop -eq 'InstallPath') {
                            $candidates.Add((Join-Path (ConvertTo-NormalPathString -PathText $raw) 'steam.exe'))
                        }
                        else {
                            $candidates.Add((ConvertTo-NormalPathString -PathText $raw))
                        }
                    }
                }
            }
        }
        catch {
        }
    }

    foreach ($path in @(
        'C:\Program Files (x86)\Steam\steam.exe',
        'C:\Program Files\Steam\steam.exe'
    )) {
        $candidates.Add($path)
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            $resolved = (Resolve-Path -LiteralPath $candidate).Path
            return [pscustomobject]@{
                Available = $true
                Exe       = $resolved
                Root      = Split-Path -Path $resolved -Parent
            }
        }
    }

    return [pscustomobject]@{
        Available = $false
        Exe       = ''
        Root      = ''
    }
}

function Get-SteamLibraryRoots {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Install
    )

    $roots = New-Object System.Collections.Generic.List[string]

    if ($Install.Root) {
        $roots.Add($Install.Root)
    }

    if (-not $Install.Root) {
        return @($roots | Select-Object -Unique)
    }

    $libraryFile = Join-Path $Install.Root 'steamapps\libraryfolders.vdf'
    if (-not (Test-Path -LiteralPath $libraryFile)) {
        return @($roots | Select-Object -Unique)
    }

    try {
        $text = Get-Content -LiteralPath $libraryFile -Raw -ErrorAction Stop

        foreach ($match in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
            $path = ConvertTo-NormalPathString -PathText $match.Groups[1].Value
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $roots.Add($path)
            }
        }

        foreach ($match in [regex]::Matches($text, '"\d+"\s+"([A-Za-z]:\\\\[^"]+|\\\\\\\\[^"]+)"')) {
            $path = ConvertTo-NormalPathString -PathText $match.Groups[1].Value
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $roots.Add($path)
            }
        }
    }
    catch {
    }

    return @($roots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Get-InstalledGames {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Install
    )

    $games = New-Object System.Collections.Generic.List[object]
    $seen = @{}

    foreach ($root in Get-SteamLibraryRoots -Install $Install) {
        $steamApps = Join-Path $root 'steamapps'
        if (-not (Test-Path -LiteralPath $steamApps)) {
            continue
        }

        foreach ($manifest in Get-ChildItem -LiteralPath $steamApps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue) {
            try {
                $text = Get-Content -LiteralPath $manifest.FullName -Raw -ErrorAction Stop
                $appId = [regex]::Match($text, '"appid"\s+"(\d+)"').Groups[1].Value
                $name = [regex]::Match($text, '"name"\s+"([^"]+)"').Groups[1].Value
                $installDir = [regex]::Match($text, '"installdir"\s+"([^"]+)"').Groups[1].Value

                if ([string]::IsNullOrWhiteSpace($appId) -or $seen.ContainsKey($appId)) {
                    continue
                }

                if ([string]::IsNullOrWhiteSpace($name)) {
                    $name = $manifest.BaseName
                }

                $games.Add([pscustomobject]@{
                    AppId      = $appId
                    Name       = $name
                    InstallDir = if ($installDir) { Join-Path $steamApps (Join-Path 'common' $installDir) } else { '' }
                    Library    = $root
                })

                $seen[$appId] = $true
            }
            catch {
            }
        }
    }

    return @($games | Sort-Object Name)
}

function Find-Games {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Query,

        [Parameter(Mandatory = $true)]
        [object[]] $Games
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return @()
    }

    $trimmed = $Query.Trim()
    $results = $Games | Where-Object {
        $_.AppId -eq $trimmed -or $_.Name -like "*$trimmed*"
    } | Sort-Object @(
        @{ Expression = { if ($_.Name -ieq $trimmed -or $_.AppId -eq $trimmed) { 0 } elseif ($_.Name -like "$trimmed*") { 1 } else { 2 } } },
        @{ Expression = { $_.Name } }
    )

    return @($results)
}

function Show-GameList {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Games
    )

    if (-not $Games -or $Games.Count -eq 0) {
        Write-Output 'No installed Steam games were found.'
        return
    }

    $index = 1
    foreach ($game in $Games) {
        Write-Output ('{0,3}. {1} [{2}]' -f $index, $game.Name, $game.AppId)
        $index++
    }
}

function Start-SteamClient {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Install
    )

    if ($Install.Available -and $Install.Exe) {
        Start-Process -FilePath $Install.Exe | Out-Null
        return
    }

    Start-Process 'steam://open/main' | Out-Null
}

function Start-SteamStoreSearch {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Query,

        [Parameter(Mandatory = $true)]
        [pscustomobject] $Install
    )

    $encoded = [System.Uri]::EscapeDataString($Query)
    $url = "https://store.steampowered.com/search/?term=$encoded"

    try {
        if ($Install.Available) {
            Start-Process "steam://openurl/$url" | Out-Null
        }
        else {
            Start-Process $url | Out-Null
        }
    }
    catch {
        Start-Process $url | Out-Null
    }
}

function Resolve-GameSelection {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Query,

        [Parameter(Mandatory = $true)]
        [object[]] $Games
    )

    $trimmed = $Query.Trim()
    if ($trimmed -match '^\d+$') {
        $byAppId = @($Games | Where-Object { $_.AppId -eq $trimmed })
        if ($byAppId.Count -gt 0) {
            return $byAppId
        }

        $index = [int] $trimmed
        if ($index -ge 1 -and $index -le $Games.Count) {
            return @($Games[$index - 1])
        }
    }

    return @(Find-Games -Query $trimmed -Games $Games)
}

function Request-LaunchSelection {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Games,

        [Parameter(Mandatory = $true)]
        [pscustomobject] $Install,

        [string] $Prompt = 'Enter a game number to launch, or press Enter to cancel'
    )

    if (-not $Games -or $Games.Count -eq 0) {
        return $false
    }

    Write-Output ''
    $choice = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($choice)) {
        Write-Output 'Cancelled.'
        return $false
    }

    $picked = @(Resolve-GameSelection -Query $choice -Games $Games)
    if ($picked.Count -eq 1) {
        $game = $picked[0]
        Start-SteamGame -AppId $game.AppId -Install $Install -Name $game.Name
        return $true
    }

    Write-Output 'That selection was not valid.'
    return $false
}

function Start-SteamGame {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AppId,

        [pscustomobject] $Install,

        [string] $Name = ''
    )

    if ($Install -and $Install.Available -and $Install.Exe) {
        try {
            Start-Process -FilePath $Install.Exe -ArgumentList "-applaunch $AppId" | Out-Null
            if ($Name) {
                Write-Output ("Launching: $Name [$AppId]")
            }
            else {
                Write-Output ("Launching app id $AppId")
            }
            return
        }
        catch {
        }
    }

    Start-Process "steam://rungameid/$AppId" | Out-Null
    if ($Name) {
        Write-Output ("Launching: $Name [$AppId]")
    }
    else {
        Write-Output ("Launching app id $AppId")
    }
}

$rawInput = Get-RawInput

if ([string]::IsNullOrWhiteSpace($rawInput)) {
    Show-Help
    exit 0
}

$commandText = $rawInput.Trim()
$install = Get-SteamInstallation

if ($commandText -match '^(?i)(help|/h|-h|--help|\?)$') {
    Show-Help
    exit 0
}

if ($commandText -match '^(?i)(status)$') {
    if ($install.Available) {
        $games = @(Get-InstalledGames -Install $install)
        Write-Output 'Steam: available'
        Write-Output ("Path : " + $install.Exe)
        Write-Output ("Games: " + $games.Count)
    }
    else {
        Write-Output 'Steam: not detected'
    }

    exit 0
}

if ($commandText -match '^(?i)(open|launch)$') {
    Start-SteamClient -Install $install
    exit 0
}

if ($commandText -match '^(?i)(list|games)$') {
    if (-not $install.Available) {
        Write-Output 'Steam is not installed or could not be detected.'
        exit 1
    }

    $games = @(Get-InstalledGames -Install $install)
    Show-GameList -Games $games
    exit 0
}

if ($commandText -match '^(?i)(browse)$') {
    if (-not $install.Available) {
        Write-Output 'Steam is not installed or could not be detected.'
        exit 1
    }

    $games = @(Get-InstalledGames -Install $install)
    Show-GameList -Games $games
    [void](Request-LaunchSelection -Games $games -Install $install)
    exit 0
}

if ($commandText -match '^(?i)(search|find)\s+(.+)$') {
    $query = $Matches[2].Trim()

    if (-not $install.Available) {
        Write-Output 'Steam is not installed or could not be detected.'
        Start-SteamStoreSearch -Query $query -Install $install
        exit 0
    }

    $games = @(Get-InstalledGames -Install $install)
    $gameMatches = @(Find-Games -Query $query -Games $games)

    if ($gameMatches.Count -gt 0) {
        Show-GameList -Games $gameMatches
        [void](Request-LaunchSelection -Games $gameMatches -Install $install -Prompt 'Play one of these results? Enter a number, app id, or press Enter to cancel')
    }
    else {
        Write-Output ("No installed Steam games matched: " + $query)
        Start-SteamStoreSearch -Query $query -Install $install
    }

    exit 0
}

if ($commandText -match '^(?i)(store)\s+(.+)$') {
    $query = $Matches[2].Trim()
    Start-SteamStoreSearch -Query $query -Install $install
    exit 0
}

if ($commandText -match '^(?i)(run|appid)\s+(\d+)$') {
    $appId = $Matches[2]
    $games = if ($install.Available) { @(Get-InstalledGames -Install $install) } else { @() }
    $game = $games | Where-Object { $_.AppId -eq $appId } | Select-Object -First 1
    $name = if ($game) { $game.Name } else { '' }
    Start-SteamGame -AppId $appId -Install $install -Name $name
    exit 0
}

if ($commandText -match '^(?i)(play|start|game)\s+(.+)$') {
    $query = $Matches[2].Trim()

    if (-not $install.Available) {
        Write-Output 'Steam is not installed or could not be detected.'
        Start-SteamStoreSearch -Query $query -Install $install
        exit 0
    }

    $games = @(Get-InstalledGames -Install $install)
    $gameMatches = @(Resolve-GameSelection -Query $query -Games $games)

    if ($gameMatches.Count -eq 1) {
        $game = $gameMatches[0]
        Start-SteamGame -AppId $game.AppId -Install $install -Name $game.Name
        exit 0
    }

    if ($gameMatches.Count -gt 1) {
        Write-Output 'Multiple installed matches were found:'
        Show-GameList -Games $gameMatches
        [void](Request-LaunchSelection -Games $gameMatches -Install $install -Prompt 'Choose one to launch, or press Enter to cancel')
        exit 0
    }

    Write-Output ("No installed Steam games matched: " + $query)
    Start-SteamStoreSearch -Query $query -Install $install
    exit 0
}

Write-Output ("Unknown Steam command: " + $commandText)
Write-Output ''
Show-Help
exit 1
