[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

$script:KnownProfiles = @(
    [pscustomobject]@{
        MenuKey      = '1'
        Label        = 'Portuguese (Brazil)'
        Tag          = 'pt-BR'
        PreferredTip = '0416:00000416'
        Aliases      = @('1', 'pt', 'pt-br', 'portuguese', 'portugues', 'português', 'brazilian portuguese', 'portuguese brazil', 'portuguese brazilian')
    },
    [pscustomobject]@{
        MenuKey      = '2'
        Label        = 'English International (US-International)'
        Tag          = 'en-US'
        PreferredTip = '0409:00020409'
        Aliases      = @('2', 'en', 'en-us', 'english', 'english international', 'international english', 'us international', 'us-international', 'intl english', 'international')
    }
)

function ConvertTo-NormalizedText {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $decomposed = $Value.ToLowerInvariant().Normalize([System.Text.NormalizationForm]::FormD)
    $chars = foreach ($char in $decomposed.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            $char
        }
    }

    return (($chars -join '') -replace '[^a-z0-9]+', ' ').Trim()
}

function Get-InstalledLanguageList {
    $languageItems = New-Object System.Collections.Generic.List[object]

    foreach ($languageItem in (Get-WinUserLanguageList)) {
        [void]$languageItems.Add($languageItem)
    }

    return $languageItems.ToArray()
}

function Test-IsAdministrator {
    try {
        return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Request-ElevatedInstall {
    param([Parameter(Mandatory = $true)]$Candidate)

    if (Test-IsAdministrator) {
        return
    }

    Write-Host ''
    Write-Host 'Windows may need Administrator access to download this language pack.' -ForegroundColor Yellow
    $choice = Read-Host 'Open an elevated PowerShell window to finish the install now? [Y/N]'

    if ($choice -notmatch '^(y|yes)$') {
        return
    }

    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory (Get-Location).Path -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath,
        'set', $Candidate.Tag
    ) | Out-Null

    exit 0
}

function Get-InstalledLanguageCandidates {
    $installed = Get-InstalledLanguageList

    foreach ($item in $installed) {
        $profileChoice = $script:KnownProfiles | Where-Object Tag -eq $item.LanguageTag | Select-Object -First 1

        [pscustomobject]@{
            Tag           = $item.LanguageTag
            Label         = if ($profileChoice) { $profileChoice.Label } else { $item.Autonym }
            DisplayName   = $item.Autonym
            EnglishName   = $item.EnglishName
            Installed     = $true
            PreferredTip  = if ($profileChoice) { $profileChoice.PreferredTip } elseif ($item.InputMethodTips.Count -gt 0) { $item.InputMethodTips[0] } else { $null }
            InputTips     = @($item.InputMethodTips)
            Aliases       = if ($profileChoice) { @($profileChoice.Aliases) } else { @() }
        }
    }
}

function Get-CultureCatalogCandidates {
    if ($script:CultureCatalog) {
        return $script:CultureCatalog
    }

    $catalog = New-Object System.Collections.Generic.List[object]

    foreach ($culture in ([Globalization.CultureInfo]::GetCultures([Globalization.CultureTypes]::SpecificCultures) | Sort-Object Name -Unique)) {
        $profileChoice = $script:KnownProfiles | Where-Object Tag -eq $culture.Name | Select-Object -First 1

        $catalog.Add([pscustomobject]@{
                Tag           = $culture.Name
                Label         = if ($profileChoice) { $profileChoice.Label } else { $culture.EnglishName }
                DisplayName   = $culture.NativeName
                EnglishName   = $culture.EnglishName
                Installed     = $false
                PreferredTip  = if ($profileChoice) { $profileChoice.PreferredTip } else { $null }
                InputTips     = @()
                Aliases       = if ($profileChoice) { @($profileChoice.Aliases) } else { @() }
            })
    }

    foreach ($profileChoice in $script:KnownProfiles) {
        if (-not ($catalog | Where-Object Tag -eq $profileChoice.Tag)) {
            $catalog.Add([pscustomobject]@{
                    Tag           = $profileChoice.Tag
                    Label         = $profileChoice.Label
                    DisplayName   = $profileChoice.Label
                    EnglishName   = $profileChoice.Label
                    Installed     = $false
                    PreferredTip  = $profileChoice.PreferredTip
                    InputTips     = @()
                    Aliases       = @($profileChoice.Aliases)
                })
        }
    }

    $script:CultureCatalog = $catalog
    return $script:CultureCatalog
}

function Get-AllCandidates {
    $byTag = @{}

    foreach ($candidate in Get-CultureCatalogCandidates) {
        $byTag[$candidate.Tag] = $candidate
    }

    foreach ($candidate in Get-InstalledLanguageCandidates) {
        $byTag[$candidate.Tag] = $candidate
    }

    return @($byTag.GetEnumerator() | ForEach-Object { $_.Value })
}

function Get-CandidateByTag {
    param([string]$Tag)

    foreach ($candidate in Get-AllCandidates) {
        if ($candidate.Tag -eq $Tag) {
            return $candidate
        }
    }

    return $null
}

function Get-MatchScore {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)][string]$NormalizedQuery
    )

    if ([string]::IsNullOrWhiteSpace($NormalizedQuery)) {
        return 0
    }

    $score = 0
    $fields = @(
        $Candidate.Tag,
        $Candidate.Label,
        $Candidate.DisplayName,
        $Candidate.EnglishName
    ) + @($Candidate.Aliases)

    foreach ($field in $fields) {
        $normalizedField = ConvertTo-NormalizedText $field
        if (-not $normalizedField) {
            continue
        }

        if ($normalizedField -eq $NormalizedQuery) {
            $score = [Math]::Max($score, 120)
            continue
        }

        if ($normalizedField.StartsWith($NormalizedQuery)) {
            $score = [Math]::Max($score, 100)
            continue
        }

        if ($normalizedField.Contains($NormalizedQuery)) {
            $score = [Math]::Max($score, 90)
            continue
        }

        $matchedTokens = 0
        foreach ($token in ($NormalizedQuery -split ' ' | Where-Object { $_ })) {
            if ($normalizedField.Contains($token)) {
                $matchedTokens++
            }
        }

        if ($matchedTokens -gt 0) {
            $score = [Math]::Max($score, 55 + ($matchedTokens * 10))
        }
    }

    if ($Candidate.Installed) {
        $score += 15
    }

    return $score
}

function Get-SearchMatches {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [int]$MaxResults = 8
    )

    $normalizedQuery = ConvertTo-NormalizedText $Query
    if (-not $normalizedQuery) {
        return @()
    }

    $results = foreach ($candidate in Get-AllCandidates) {
        $score = Get-MatchScore -Candidate $candidate -NormalizedQuery $normalizedQuery
        if ($score -gt 0) {
            [pscustomobject]@{
                Score     = $score
                Candidate = $candidate
            }
        }
    }

    return @(
        $results |
        Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = { $_.Candidate.Installed }; Descending = $true }, @{ Expression = { $_.Candidate.Tag } } |
        Select-Object -First $MaxResults
    )
}

function Resolve-LanguageCandidate {
    param([string]$Query)

    $cleanQuery = $Query.Trim()
    if ($cleanQuery -eq '1') {
        return Get-CandidateByTag -Tag 'pt-BR'
    }

    if ($cleanQuery -eq '2') {
        return Get-CandidateByTag -Tag 'en-US'
    }

    $resultEntries = Get-SearchMatches -Query $cleanQuery -MaxResults 1
    if ($resultEntries.Count -gt 0) {
        return $resultEntries[0].Candidate
    }

    return $null
}

function Get-InstalledLanguageItem {
    param([string]$Tag)

    foreach ($languageItem in (Get-InstalledLanguageList)) {
        if ($languageItem.LanguageTag -eq $Tag) {
            return $languageItem
        }
    }

    return $null
}

function Install-LanguageIfMissing {
    param([Parameter(Mandatory = $true)]$Candidate)

    $installedItem = Get-InstalledLanguageItem -Tag $Candidate.Tag
    if ($installedItem) {
        return $installedItem
    }

    Write-Host ('Downloading and installing ' + $Candidate.Label + '...') -ForegroundColor Cyan

    $installLanguageCommand = Get-Command Install-Language -ErrorAction SilentlyContinue
    if ($installLanguageCommand) {
        try {
            Install-Language -Language $Candidate.Tag -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Host ('Install-Language returned: ' + $_.Exception.Message) -ForegroundColor Yellow
        }
    }

    $list = New-Object System.Collections.Generic.List[object]
    foreach ($existingLanguage in (Get-InstalledLanguageList)) {
        [void]$list.Add($existingLanguage)
    }

    $installedItem = $null
    foreach ($languageItem in $list) {
        if ($languageItem.LanguageTag -eq $Candidate.Tag) {
            $installedItem = $languageItem
            break
        }
    }

    if (-not $installedItem) {
        $newLanguageList = New-WinUserLanguageList -Language $Candidate.Tag
        $installedItem = $newLanguageList[0]

        if ($Candidate.PreferredTip -and $installedItem.InputMethodTips -notcontains $Candidate.PreferredTip) {
            [void]$installedItem.InputMethodTips.Add($Candidate.PreferredTip)
        }

        [void]$list.Add($installedItem)
        Set-WinUserLanguageList -LanguageList $list -Force
    }

    $refreshedItem = Get-InstalledLanguageItem -Tag $Candidate.Tag
    if (-not $refreshedItem) {
        Request-ElevatedInstall -Candidate $Candidate
        throw ('Windows did not expose ' + $Candidate.Tag + ' after installation. Try again from an elevated shell with admin.')
    }

    return $refreshedItem
}

function Get-SelectedInputTip {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)]$InstalledItem
    )

    if ($Candidate.PreferredTip) {
        return $Candidate.PreferredTip
    }

    if ($InstalledItem.InputMethodTips.Count -gt 0) {
        return $InstalledItem.InputMethodTips[0]
    }

    return $null
}

function Switch-ActiveKeyboardLayout {
    param([string]$InputTip)

    if ([string]::IsNullOrWhiteSpace($InputTip) -or $InputTip -notmatch '^[0-9A-Fa-f]{4}:([0-9A-Fa-f]{8})$') {
        return
    }

    $klid = $matches[1]

    try {
        Add-Type -Namespace PersonalTools -Name KeyboardNative -MemberDefinition @'
using System;
using System.Runtime.InteropServices;
public static class KeyboardNative {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags);

    [DllImport("user32.dll")]
    public static extern IntPtr ActivateKeyboardLayout(IntPtr hkl, uint Flags);
}
'@ -ErrorAction SilentlyContinue | Out-Null

        $handle = [PersonalTools.KeyboardNative]::LoadKeyboardLayout($klid, 1)
        if ($handle -ne [IntPtr]::Zero) {
            [void][PersonalTools.KeyboardNative]::ActivateKeyboardLayout($handle, 0)
        }
    }
    catch {
    }
}

function Set-KeyboardSelection {
    param([Parameter(Mandatory = $true)]$Candidate)

    $installedItem = Install-LanguageIfMissing -Candidate $Candidate
    $selectedTip = Get-SelectedInputTip -Candidate $Candidate -InstalledItem $installedItem

    $list = Get-InstalledLanguageList
    $byTag = @{}
    foreach ($item in $list) {
        if (-not $byTag.ContainsKey($item.LanguageTag)) {
            $byTag[$item.LanguageTag] = $item
        }
    }

    if (-not $byTag.ContainsKey($Candidate.Tag)) {
        $byTag[$Candidate.Tag] = $installedItem
    }

    if ($selectedTip -and $byTag[$Candidate.Tag].InputMethodTips -notcontains $selectedTip) {
        [void]$byTag[$Candidate.Tag].InputMethodTips.Add($selectedTip)
    }

    $orderedTags = New-Object System.Collections.Generic.List[string]
    [void]$orderedTags.Add($Candidate.Tag)

    foreach ($item in $list) {
        if (-not $orderedTags.Contains($item.LanguageTag)) {
            [void]$orderedTags.Add($item.LanguageTag)
        }
    }

    $newList = foreach ($tag in $orderedTags) {
        if ($byTag.ContainsKey($tag)) {
            $byTag[$tag]
        }
    }

    Set-WinUserLanguageList -LanguageList $newList -Force

    if ($selectedTip) {
        Set-WinDefaultInputMethodOverride -InputTip $selectedTip
        Switch-ActiveKeyboardLayout -InputTip $selectedTip
    }

    Write-Host ('Selected: ' + $Candidate.Label + ' [' + $Candidate.Tag + ']') -ForegroundColor Green
    if ($selectedTip) {
        Write-Host ('Keyboard tip: ' + $selectedTip)
    }
    Write-Host 'This setting is stored in your Windows user profile and will persist after restart.' -ForegroundColor Green
}

function Show-InstalledList {
    $defaultInputTip = (Get-WinDefaultInputMethodOverride).InputMethodTip
    $installed = Get-InstalledLanguageList

    Write-Host 'Installed keyboard languages' -ForegroundColor Cyan
    Write-Host ''

    $index = 1
    foreach ($item in $installed) {
        $marker = if ($defaultInputTip -and $item.InputMethodTips -contains $defaultInputTip) { '  <-- current default' } else { '' }
        Write-Host (($index.ToString() + '. ' + $item.Autonym + ' [' + $item.LanguageTag + ']' + $marker)) -ForegroundColor White
        if ($item.InputMethodTips.Count -gt 0) {
            Write-Host ('   Tips: ' + ($item.InputMethodTips -join ', ')) -ForegroundColor DarkGray
        }
        $index++
    }
}

function Show-SearchResults {
    param([Parameter(Mandatory = $true)][string]$Query)

    $resultEntries = Get-SearchMatches -Query $Query -MaxResults 10
    if ($resultEntries.Count -eq 0) {
        Write-Host ('No language matches found for: ' + $Query) -ForegroundColor Yellow
        return
    }

    $installedMatches = @($resultEntries | Where-Object { $_.Candidate.Installed })
    $otherMatches = @($resultEntries | Where-Object { -not $_.Candidate.Installed })

    if ($installedMatches.Count -gt 0) {
        Write-Host ('Installed matches for: ' + $Query) -ForegroundColor Green
        foreach ($entry in $installedMatches) {
            $candidate = $entry.Candidate
            Write-Host (' - ' + $candidate.Label + ' [' + $candidate.Tag + ']')
        }
        Write-Host ''
    }

    if ($otherMatches.Count -gt 0) {
        Write-Host 'Other good matches that Windows can install' -ForegroundColor Yellow
        foreach ($entry in $otherMatches) {
            $candidate = $entry.Candidate
            Write-Host (' - ' + $candidate.Label + ' [' + $candidate.Tag + ']')
        }
    }
}

function Show-Status {
    Write-Host 'Keyboard language helper' -ForegroundColor Cyan
    Write-Host ''
    Show-InstalledList
    Write-Host ''
    Write-Host 'Quick switches' -ForegroundColor Green
    Write-Host '  1. Portuguese (Brazil)'
    Write-Host '  2. English International (US-International)'
}

function Show-Help {
    Write-Host 'Keyboard language helper' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Quick choices:' -ForegroundColor Green
    Write-Host '  keyboard 1                         Switch to Portuguese (Brazil)'
    Write-Host '  keyboard 2                         Switch to English International'
    Write-Host ''
    Write-Host 'Search and select:' -ForegroundColor Green
    Write-Host '  keyboard portuguese'
    Write-Host '  keyboard english international'
    Write-Host '  keyboard pt-BR'
    Write-Host '  keyboard search canadian french'
    Write-Host '  keyboard status'
    Write-Host ''
    Write-Host 'If the best match is not installed, Windows will download and install it, then select it.'
}

function Start-Menu {
    Show-Status
    Write-Host ''
    Write-Host 'Menu' -ForegroundColor Green
    Write-Host '  1. Portuguese (Brazil)'
    Write-Host '  2. English International (US-International)'
    Write-Host '  3. Show installed languages'
    Write-Host '  4. Search or install another language'
    Write-Host '  5. Exit'
    Write-Host ''

    $choice = Read-Host 'Choose 1-5'

    switch ($choice) {
        '1' {
            Set-KeyboardSelection -Candidate (Get-CandidateByTag -Tag 'pt-BR')
            return
        }
        '2' {
            Set-KeyboardSelection -Candidate (Get-CandidateByTag -Tag 'en-US')
            return
        }
        '3' {
            Show-InstalledList
            return
        }
        '4' {
            $query = Read-Host 'Enter a language name or code'
            if (-not [string]::IsNullOrWhiteSpace($query)) {
                $candidate = Resolve-LanguageCandidate -Query $query
                if ($candidate) {
                    Set-KeyboardSelection -Candidate $candidate
                }
                else {
                    Write-Host ('No usable match found for: ' + $query) -ForegroundColor Yellow
                }
            }
            return
        }
        default {
            return
        }
    }
}

$command = 'menu'
$remainingArguments = @()

if ($Arguments.Count -gt 0) {
    $first = $Arguments[0]
    switch -Regex ($first.ToLowerInvariant()) {
        '^(help|/\?|--help|-h)$' {
            $command = 'help'
            $remainingArguments = @($Arguments | Select-Object -Skip 1)
            break
        }
        '^(status|list)$' {
            $command = $first.ToLowerInvariant()
            $remainingArguments = @($Arguments | Select-Object -Skip 1)
            break
        }
        '^(search|find|lookup)$' {
            $command = 'search'
            $remainingArguments = @($Arguments | Select-Object -Skip 1)
            break
        }
        '^(set|select|use|switch|install)$' {
            $command = $first.ToLowerInvariant()
            $remainingArguments = @($Arguments | Select-Object -Skip 1)
            break
        }
        '^(1|2)$' {
            $command = 'set'
            $remainingArguments = @($first)
            break
        }
        default {
            $command = 'set'
            $remainingArguments = @($Arguments)
            break
        }
    }
}

$queryText = ($remainingArguments -join ' ').Trim()

switch ($command) {
    'help' {
        Show-Help
    }
    'status' {
        Show-Status
    }
    'list' {
        Show-InstalledList
    }
    'search' {
        if ([string]::IsNullOrWhiteSpace($queryText)) {
            Show-InstalledList
        }
        else {
            Show-SearchResults -Query $queryText
        }
    }
    'install' {
        if ([string]::IsNullOrWhiteSpace($queryText)) {
            Start-Menu
        }
        else {
            $candidate = Resolve-LanguageCandidate -Query $queryText
            if (-not $candidate) {
                throw ('No language match found for: ' + $queryText)
            }

            Set-KeyboardSelection -Candidate $candidate
        }
    }
    'set' {
        if ([string]::IsNullOrWhiteSpace($queryText)) {
            Start-Menu
        }
        else {
            $candidate = Resolve-LanguageCandidate -Query $queryText
            if (-not $candidate) {
                throw ('No language match found for: ' + $queryText)
            }

            Set-KeyboardSelection -Candidate $candidate
        }
    }
    default {
        Start-Menu
    }
}
