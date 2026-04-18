param()

$ErrorActionPreference = 'SilentlyContinue'

function Get-HookPayload {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    try {
        return $raw | ConvertFrom-Json -Depth 100
    }
    catch {
        return $null
    }
}

function Get-MessageText($message) {
    if ($null -eq $message) { return $null }

    if ($message.PSObject.Properties['text']) {
        return [string]$message.text
    }

    if ($message.PSObject.Properties['prompt']) {
        return [string]$message.prompt
    }

    if ($message.PSObject.Properties['content']) {
        $content = $message.content
        if ($content -is [string]) {
            return $content
        }

        $parts = @()
        foreach ($item in @($content)) {
            if ($item -is [string]) {
                $parts += $item
            }
            elseif ($item.PSObject.Properties['text']) {
                $parts += [string]$item.text
            }
            elseif ($item.PSObject.Properties['value']) {
                $parts += [string]$item.value
            }
        }

        if ($parts.Count -gt 0) {
            return ($parts -join ' ')
        }
    }

    return $null
}

function Find-LastUserPrompt {
    param([string]$TranscriptPath)

    if ([string]::IsNullOrWhiteSpace($TranscriptPath) -or -not (Test-Path $TranscriptPath)) {
        return $null
    }

    try {
        $raw = Get-Content -Raw -LiteralPath $TranscriptPath
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }

        $pattern = '"role"\s*:\s*"user"[\s\S]{0,4000}?"(?:text|prompt|content|value)"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
        $matches = [regex]::Matches($raw, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($matches.Count -gt 0) {
            $text = $matches[$matches.Count - 1].Groups[1].Value
            return [Regex]::Unescape($text)
        }
    }
    catch {
    }

    return $null
}

function Get-ConciseSummary {
    param([string]$Prompt)

    if ([string]::IsNullOrWhiteSpace($Prompt)) {
        return 'Finished your request.'
    }

    $p = $Prompt.ToLowerInvariant()

    if ($p -match 'readme') { return 'Finished the README update.' }
    if ($p -match 'spotify') { return 'Finished the Spotify update.' }
    if ($p -match 'chrome') { return 'Finished the Chrome update.' }
    if ($p -match 'google') { return 'Finished the Google helper update.' }
    if ($p -match 'hook|notification|say done|speech') { return 'Updated the done notification.' }
    if ($p -match 'fix|bug|debug|error') { return 'Finished the fix.' }
    if ($p -match 'add|create') { return 'Added the requested change.' }
    if ($p -match 'update|change|modify') { return 'Finished the update.' }
    if ($p -match 'how do i|how to|explain|what') { return 'Answered your question.' }

    return 'Finished your request.'
}

$payload = Get-HookPayload
$spokenText = 'Done.'

if ($payload) {
    $prompt = $null

    if ($payload.PSObject.Properties['transcript_path']) {
        $prompt = Find-LastUserPrompt -TranscriptPath ([string]$payload.transcript_path)
    }

    $spokenText = Get-ConciseSummary -Prompt $prompt

    $repoRoot = if ($payload.PSObject.Properties['cwd'] -and $payload.cwd) { [string]$payload.cwd } else { (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
}
else {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

$logPath = Join-Path $PSScriptRoot 'say-done.log'
try {
    Add-Content -LiteralPath $logPath -Value ((Get-Date -Format s) + ' | ' + $spokenText)
}
catch {
}

$spotifyControl = Join-Path $repoRoot 'scripts\media\spotify-control.ps1'
if (-not (Test-Path $spotifyControl)) {
    $spotifyControl = Join-Path $repoRoot 'compat\spotify-control.ps1'
}
$shouldResumeSpotify = $false

try {
    if (Test-Path $spotifyControl) {
        $spotifyStatus = & powershell -NoProfile -ExecutionPolicy Bypass -File $spotifyControl -Action status 2>$null
        $shouldResumeSpotify = ($spotifyStatus -match 'Playing')
        & powershell -NoProfile -ExecutionPolicy Bypass -File $spotifyControl -Action pause | Out-Null
    }
}
catch {
}

try {
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try {
        [void]$synth.Speak($spokenText)
    }
    finally {
        $synth.Dispose()
    }
}
catch {
}

try {
    if ($shouldResumeSpotify -and (Test-Path $spotifyControl)) {
        [System.Threading.Thread]::Sleep(500)
        & powershell -NoProfile -ExecutionPolicy Bypass -File $spotifyControl -Action play | Out-Null
    }
}
catch {
}

@{ continue = $true } | ConvertTo-Json -Compress
