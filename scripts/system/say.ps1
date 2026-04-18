param(
    [switch]$ListVoices,
    [switch]$ListLanguages,
    [string]$ProbeLanguage
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:LanguageCatalog = $null
$script:VoiceCatalog = $null
$script:WinRtReady = $false
$script:AsTaskMethod = $null

function Get-IntSetting {
    param(
        [string]$Value,
        [int]$Default,
        [int]$Minimum,
        [int]$Maximum
    )

    $parsed = 0
    if (-not [int]::TryParse($Value, [ref]$parsed)) {
        return $Default
    }

    if ($parsed -lt $Minimum) { return $Minimum }
    if ($parsed -gt $Maximum) { return $Maximum }
    return $parsed
}

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

    return (($chars -join '') -replace '[^\p{L}\p{Nd}]+', ' ').Trim()
}

function Get-SsmlRateSetting {
    param([int]$Rate)

    if ($Rate -eq 0) {
        return '0%'
    }

    $percent = $Rate * 10
    if ($percent -gt 0) {
        return ('+' + $percent + '%')
    }

    return ($percent + '%')
}

function Get-SsmlVolumeSetting {
    param([int]$Volume)

    if ($Volume -le 0) { return 'silent' }
    if ($Volume -le 20) { return 'x-soft' }
    if ($Volume -le 40) { return 'soft' }
    if ($Volume -le 70) { return 'medium' }
    if ($Volume -le 90) { return 'loud' }
    return 'x-loud'
}

function Initialize-WinRtSpeech {
    if ($script:WinRtReady) {
        return $true
    }

    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.Speech, ContentType=WindowsRuntime]

        if (-not $script:AsTaskMethod) {
            $script:AsTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
                Where-Object {
                    $_.Name -eq 'AsTask' -and
                    $_.IsGenericMethod -and
                    $_.GetParameters().Count -eq 1
                } |
                Select-Object -First 1
        }

        $script:WinRtReady = ($null -ne $script:AsTaskMethod)
        return $script:WinRtReady
    }
    catch {
        return $false
    }
}

function Invoke-WinRtTask {
    param(
        [Parameter(Mandatory = $true)]
        [object]$AsyncOperation,

        [Parameter(Mandatory = $true)]
        [type]$ResultType
    )

    if (-not (Initialize-WinRtSpeech)) {
        throw 'Windows Runtime speech is not available.'
    }

    $task = $script:AsTaskMethod.MakeGenericMethod($ResultType).Invoke($null, @($AsyncOperation))
    $task.Wait()
    return $task.Result
}

function Get-LanguageCatalog {
    if ($script:LanguageCatalog) {
        return $script:LanguageCatalog
    }

    $cultureTypes = [Globalization.CultureTypes]::SpecificCultures -bor [Globalization.CultureTypes]::NeutralCultures
    $script:LanguageCatalog = @(
        [Globalization.CultureInfo]::GetCultures($cultureTypes) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } |
        Sort-Object Name -Unique |
        ForEach-Object {
            [pscustomobject]@{
                Tag         = $_.Name
                EnglishName = $_.EnglishName
                NativeName  = $_.NativeName
                DisplayName = $_.DisplayName
                TwoLetter   = $_.TwoLetterISOLanguageName
                ThreeLetter = $_.ThreeLetterISOLanguageName
                IsNeutral   = $_.IsNeutralCulture
            }
        }
    )

    return $script:LanguageCatalog
}

function Get-LanguageMatchScore {
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
        $Candidate.EnglishName,
        $Candidate.NativeName,
        $Candidate.DisplayName,
        $Candidate.TwoLetter,
        $Candidate.ThreeLetter
    )

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

    if (-not $Candidate.IsNeutral) {
        $score += 5
    }

    return $score
}

function Resolve-LanguageTag {
    param([string]$RequestedLanguage)

    if ([string]::IsNullOrWhiteSpace($RequestedLanguage)) {
        return $null
    }

    $normalizedQuery = ConvertTo-NormalizedText $RequestedLanguage
    if (-not $normalizedQuery) {
        return $null
    }

    $match = Get-LanguageCatalog |
        ForEach-Object {
            $score = Get-LanguageMatchScore -Candidate $_ -NormalizedQuery $normalizedQuery
            if ($score -gt 0) {
                [pscustomobject]@{
                    Score     = $score
                    Candidate = $_
                }
            }
        } |
        Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = { -not $_.Candidate.IsNeutral }; Descending = $true }, @{ Expression = { $_.Candidate.Tag } } |
        Select-Object -First 1

    if ($match) {
        return $match.Candidate.Tag
    }

    return $null
}

function Get-LanguageLabel {
    param([string]$LanguageTag)

    if ([string]::IsNullOrWhiteSpace($LanguageTag)) {
        return ''
    }

    $match = Get-LanguageCatalog | Where-Object Tag -eq $LanguageTag | Select-Object -First 1
    if ($match) {
        return $match.EnglishName
    }

    return $LanguageTag
}

function Get-VoiceCatalog {
    if ($script:VoiceCatalog) {
        return $script:VoiceCatalog
    }

    $voiceMap = @{}

    if (Initialize-WinRtSpeech) {
        foreach ($voice in ([Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Sort-Object DisplayName, Language)) {
            $key = ('{0}|{1}|{2}' -f $voice.DisplayName, $voice.Language, $voice.Gender)
            if (-not $voiceMap.ContainsKey($key)) {
                $voiceMap[$key] = [ordered]@{
                    Name    = $voice.DisplayName
                    Language = $voice.Language
                    Gender  = $voice.Gender.ToString()
                    Sources = @()
                    WinRtId = $null
                    SapiName = $null
                }
            }

            $entry = $voiceMap[$key]
            $entry.Sources += 'WinRT'
            if (-not $entry.WinRtId) {
                $entry.WinRtId = $voice.Id
            }
        }
    }

    $desktopSynth = $null
    try {
        Add-Type -AssemblyName System.Speech
        $desktopSynth = New-Object System.Speech.Synthesis.SpeechSynthesizer
        foreach ($voice in ($desktopSynth.GetInstalledVoices() | Where-Object { $_.Enabled })) {
            $info = $voice.VoiceInfo
            $key = ('{0}|{1}|{2}' -f $info.Name, $info.Culture.Name, $info.Gender)
            if (-not $voiceMap.ContainsKey($key)) {
                $voiceMap[$key] = [ordered]@{
                    Name    = $info.Name
                    Language = $info.Culture.Name
                    Gender  = $info.Gender.ToString()
                    Sources = @()
                    WinRtId = $null
                    SapiName = $null
                }
            }

            $entry = $voiceMap[$key]
            $entry.Sources += 'SAPI'
            if (-not $entry.SapiName) {
                $entry.SapiName = $info.Name
            }
        }
    }
    catch {
    }
    finally {
        if ($desktopSynth) {
            $desktopSynth.Dispose()
        }
    }

    $script:VoiceCatalog = @(
        $voiceMap.GetEnumerator() |
        ForEach-Object {
            [pscustomobject]@{
                Name     = $_.Value.Name
                Language = $_.Value.Language
                Gender   = $_.Value.Gender
                Sources  = @($_.Value.Sources | Sort-Object -Unique)
                WinRtId  = $_.Value.WinRtId
                SapiName = $_.Value.SapiName
            }
        } |
        Sort-Object Language, Name
    )

    return $script:VoiceCatalog
}

function Find-BestVoiceInfo {
    param(
        [string]$RequestedVoice,
        [string]$RequestedLanguage
    )

    $voices = Get-VoiceCatalog
    $resolvedLanguage = Resolve-LanguageTag -RequestedLanguage $RequestedLanguage
    $selectedVoice = $null

    if (-not [string]::IsNullOrWhiteSpace($RequestedVoice)) {
        $selectedVoice = $voices | Where-Object { $_.Name -ieq $RequestedVoice } | Select-Object -First 1
        if (-not $selectedVoice) {
            $selectedVoice = $voices | Where-Object {
                $_.Name.IndexOf($RequestedVoice, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            } | Select-Object -First 1
        }
    }

    if (-not $selectedVoice -and $resolvedLanguage) {
        $selectedVoice = $voices | Where-Object { $_.Language -ieq $resolvedLanguage } | Select-Object -First 1
        if (-not $selectedVoice) {
            $prefix = $resolvedLanguage.Split('-')[0].ToLowerInvariant()
            $selectedVoice = $voices | Where-Object {
                $candidateLanguage = $_.Language.ToLowerInvariant()
                $candidateLanguage -eq $prefix -or $candidateLanguage.StartsWith($prefix + '-')
            } | Select-Object -First 1
        }
    }

    [pscustomobject]@{
        Voice             = $selectedVoice
        ResolvedLanguage  = $resolvedLanguage
        ResolvedLabel     = Get-LanguageLabel -LanguageTag $resolvedLanguage
    }
}

function Invoke-WinRtSpeech {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        $VoiceInfo,
        [string]$ResolvedLanguage,
        [int]$Rate,
        [int]$Volume
    )

    if (-not (Initialize-WinRtSpeech)) {
        return $false
    }

    $synth = $null
    $stream = $null
    $netStream = $null
    $player = $null
    $tempPath = Join-Path $env:TEMP ('personal-tools-say-' + [Guid]::NewGuid().ToString('N') + '.wav')

    try {
        $synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
        $chosenVoice = $null

        if ($VoiceInfo -and $VoiceInfo.WinRtId) {
            $chosenVoice = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices |
                Where-Object { $_.Id -eq $VoiceInfo.WinRtId } |
                Select-Object -First 1
        }
        elseif ($ResolvedLanguage) {
            $prefix = $ResolvedLanguage.Split('-')[0].ToLowerInvariant()
            $chosenVoice = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices |
                Where-Object {
                    $candidateLanguage = $_.Language.ToLowerInvariant()
                    $candidateLanguage -eq $ResolvedLanguage.ToLowerInvariant() -or $candidateLanguage.StartsWith($prefix + '-')
                } |
                Select-Object -First 1
        }

        if ($chosenVoice) {
            $synth.Voice = $chosenVoice
        }

        $languageTag = if ($chosenVoice) { $chosenVoice.Language } elseif ($ResolvedLanguage) { $ResolvedLanguage } else { 'en-US' }
        $escapedText = [System.Security.SecurityElement]::Escape($Text)
        $rateSetting = Get-SsmlRateSetting -Rate $Rate
        $volumeSetting = Get-SsmlVolumeSetting -Volume $Volume
        $ssml = "<speak version='1.0' xml:lang='$languageTag'><prosody rate='$rateSetting' volume='$volumeSetting'>$escapedText</prosody></speak>"

        $stream = Invoke-WinRtTask -AsyncOperation ($synth.SynthesizeSsmlToStreamAsync($ssml)) -ResultType ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
        $netStream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)

        $fileStream = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        try {
            $netStream.CopyTo($fileStream)
        }
        finally {
            $fileStream.Dispose()
        }

        $player = New-Object System.Media.SoundPlayer $tempPath
        $player.Load()
        $player.PlaySync()
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($player) { $player.Dispose() }
        if ($netStream) { $netStream.Dispose() }
        if ($stream) { $stream.Dispose() }
        if ($synth) { $synth.Dispose() }
        Remove-Item -LiteralPath $tempPath -ErrorAction SilentlyContinue
    }
}

function Invoke-SystemSpeech {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        $VoiceInfo,
        [int]$Rate,
        [int]$Volume
    )

    $synth = $null
    try {
        Add-Type -AssemblyName System.Speech
        $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

        if ($VoiceInfo -and $VoiceInfo.SapiName) {
            $synth.SelectVoice($VoiceInfo.SapiName)
        }
        elseif ($VoiceInfo -and $VoiceInfo.Name) {
            $candidate = $synth.GetInstalledVoices() |
                Where-Object { $_.Enabled -and $_.VoiceInfo.Name -ieq $VoiceInfo.Name } |
                Select-Object -First 1
            if ($candidate) {
                $synth.SelectVoice($candidate.VoiceInfo.Name)
            }
        }

        $synth.Rate = $Rate
        $synth.Volume = $Volume
        [void]$synth.Speak($Text)
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($synth) {
            $synth.Dispose()
        }
    }
}

if ($ListVoices) {
    $voices = Get-VoiceCatalog
    if (-not $voices) {
        Write-Output 'No installed Windows speech voices were found.'
        exit 1
    }

    Write-Output 'Installed voices:'
    foreach ($voiceInfo in $voices) {
        Write-Output ('- {0} | {1} | {2} | {3}' -f $voiceInfo.Name, $voiceInfo.Language, $voiceInfo.Gender, ($voiceInfo.Sources -join '+'))
    }

    exit 0
}

if ($ListLanguages) {
    Write-Output 'Supported language identifiers:'
    foreach ($language in (Get-LanguageCatalog | Sort-Object EnglishName, Tag)) {
        Write-Output ('- {0} | {1} | {2}' -f $language.Tag, $language.EnglishName, $language.NativeName)
    }

    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($ProbeLanguage)) {
    $selection = Find-BestVoiceInfo -RequestedVoice $null -RequestedLanguage $ProbeLanguage
    Write-Output ('Requested language: ' + $ProbeLanguage)
    if ($selection.ResolvedLanguage) {
        Write-Output ('Resolved language: ' + $selection.ResolvedLanguage + ' (' + $selection.ResolvedLabel + ')')
    }
    else {
        Write-Output 'Resolved language: no match found'
    }

    if ($selection.Voice) {
        Write-Output ('Best installed voice: ' + $selection.Voice.Name + ' [' + $selection.Voice.Language + '] via ' + ($selection.Voice.Sources -join '+'))
    }
    else {
        Write-Output 'Best installed voice: none currently installed for that language'
    }

    exit 0
}

$text = $env:SAY_TEXT
if ([string]::IsNullOrWhiteSpace($text)) {
    exit 1
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$spotifyControl = Join-Path $repoRoot 'scripts\media\spotify-control.ps1'
$shouldResumeSpotify = $false
$requestedVoice = $env:SAY_VOICE
$requestedLanguage = $env:SAY_LANG
$rate = Get-IntSetting -Value $env:SAY_RATE -Default 0 -Minimum -10 -Maximum 10
$volume = Get-IntSetting -Value $env:SAY_VOLUME -Default 100 -Minimum 0 -Maximum 100
$selection = Find-BestVoiceInfo -RequestedVoice $requestedVoice -RequestedLanguage $requestedLanguage

try {
    if (Test-Path $spotifyControl) {
        $spotifyStatus = & powershell -NoProfile -ExecutionPolicy Bypass -File $spotifyControl -Action status 2>$null
        $shouldResumeSpotify = ($spotifyStatus -match 'Playing')

        if ($shouldResumeSpotify) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $spotifyControl -Action pause | Out-Null
        }
    }
}
catch {
}

$spoken = $false
try {
    $preferWinRt = ($selection.Voice -and $selection.Voice.WinRtId) -or (-not [string]::IsNullOrWhiteSpace($selection.ResolvedLanguage))

    if ($preferWinRt) {
        $spoken = Invoke-WinRtSpeech -Text $text -VoiceInfo $selection.Voice -ResolvedLanguage $selection.ResolvedLanguage -Rate $rate -Volume $volume
    }

    if (-not $spoken) {
        $spoken = Invoke-SystemSpeech -Text $text -VoiceInfo $selection.Voice -Rate $rate -Volume $volume
    }

    if (-not $spoken) {
        exit 1
    }
}
finally {
    try {
        if ($shouldResumeSpotify -and (Test-Path $spotifyControl)) {
            [System.Threading.Thread]::Sleep(1)
            & powershell -NoProfile -ExecutionPolicy Bypass -File $spotifyControl -Action play | Out-Null
        }
    }
    catch {
    }
}
