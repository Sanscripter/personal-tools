[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InputArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Help {
    @"
Screen recorder

Usage:
  screen audio
  screen silent
  screen noaudio
  screen audio my-demo.mp4
  screen silent demo.mp4 -seconds 15
  screen openfolder
  screen setup
  screen help

What it does:
  - records the current desktop to an mp4 file
  - audio mode tries to include the default Windows audio device
  - silent mode records video only
  - press q in the ffmpeg window or Ctrl+C to stop a live recording
"@ | Write-Host
}

function Get-RecorderFolder {
    $videos = [Environment]::GetFolderPath('MyVideos')
    if ([string]::IsNullOrWhiteSpace($videos)) {
        $videos = Join-Path $env:USERPROFILE 'Videos'
    }

    $folder = Join-Path $videos 'ScreenRecordings'
    if (-not (Test-Path $folder)) {
        $null = New-Item -ItemType Directory -Path $folder -Force
    }

    return $folder
}

function Open-RecorderFolder {
    $folder = Get-RecorderFolder
    Start-Process explorer.exe $folder | Out-Null
    Write-Host "Opened $folder"
    exit 0
}

function Get-FfmpegPath {
    $command = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\ffmpeg.exe'),
        (Join-Path $env:ProgramFiles 'ffmpeg\bin\ffmpeg.exe'),
        (Join-Path $env:ProgramFiles 'FFmpeg\bin\ffmpeg.exe'),
        (Join-Path $env:ChocolateyInstall 'bin\ffmpeg.exe'),
        'C:\ffmpeg\bin\ffmpeg.exe'
    ) | Where-Object { $_ -and (-not [string]::IsNullOrWhiteSpace($_)) }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
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

function Invoke-Setup {
    $wingetPath = Get-WingetPath
    if (-not $wingetPath) {
        Write-Host 'FFmpeg was not found and winget is not available for automatic install in this shell.'
        Write-Host 'Run addPath or reopen Cmder after App Installer is available, then try: screen setup'
        exit 1
    }

    Write-Host 'Installing FFmpeg with winget...'
    & $wingetPath install --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
    exit $LASTEXITCODE
}

function Resolve-OutputPath {
    param(
        [string] $OutputName
    )

    if ([string]::IsNullOrWhiteSpace($OutputName)) {
        $OutputName = 'screen-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.mp4'
    }
    elseif (-not [System.IO.Path]::HasExtension($OutputName)) {
        $OutputName = "$OutputName.mp4"
    }

    if (-not [System.IO.Path]::IsPathRooted($OutputName)) {
        $OutputName = Join-Path (Get-RecorderFolder) $OutputName
    }

    $parent = Split-Path -Parent $OutputName
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    return [System.IO.Path]::GetFullPath($OutputName)
}

function Get-DShowDeviceName {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FfmpegPath
    )

    try {
        $deviceText = & $FfmpegPath -hide_banner -list_devices true -f dshow -i dummy 2>&1 | Out-String
        $patterns = @('virtual-audio-capturer', 'Stereo Mix', 'What U Hear', 'Wave Out')

        foreach ($pattern in $patterns) {
            $match = [regex]::Match($deviceText, '"([^"]*' + [regex]::Escape($pattern) + '[^"]*)"', 'IgnoreCase')
            if ($match.Success) {
                return $match.Groups[1].Value
            }
        }
    }
    catch {
    }

    return $null
}

function Get-AudioInputArgs {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FfmpegPath
    )

    $dshowName = Get-DShowDeviceName -FfmpegPath $FfmpegPath
    if (-not [string]::IsNullOrWhiteSpace($dshowName)) {
        return @('-f', 'dshow', '-i', "audio=$dshowName")
    }

    return @('-f', 'wasapi', '-i', 'default')
}

function Start-Recording {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FfmpegPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('audio', 'silent')]
        [string] $Mode,

        [Parameter(Mandatory = $true)]
        [string] $OutputPath,

        [int] $FramesPerSecond = 30,
        [int] $DurationSeconds = 0
    )

    $videoArgs = @(
        '-y',
        '-hide_banner',
        '-loglevel', 'warning',
        '-stats',
        '-f', 'gdigrab',
        '-framerate', "$FramesPerSecond",
        '-i', 'desktop'
    )

    $encodeArgs = @(
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart'
    )

    if ($DurationSeconds -gt 0) {
        $encodeArgs += @('-t', "$DurationSeconds")
    }

    if ($Mode -eq 'audio') {
        $audioArgs = Get-AudioInputArgs -FfmpegPath $FfmpegPath
        $allArgs = $videoArgs + $audioArgs + $encodeArgs + @('-c:a', 'aac', '-b:a', '160k', $OutputPath)

        try {
            & $FfmpegPath @allArgs
            return $LASTEXITCODE
        }
        catch {
            Write-Warning 'Audio capture was not available. Falling back to silent recording.'
        }
    }

    $silentArgs = $videoArgs + $encodeArgs + @($OutputPath)
    & $FfmpegPath @silentArgs
    return $LASTEXITCODE
}

$mode = 'audio'
$outputParts = New-Object System.Collections.Generic.List[string]
$seconds = 0
$fps = 30

if (-not $InputArgs -or $InputArgs.Count -eq 0) {
    Show-Help
    exit 0
}

for ($i = 0; $i -lt $InputArgs.Count; $i++) {
    $token = [string]$InputArgs[$i]
    switch -Regex ($token) {
        '^(?i)(help|/h|-h|--help|\?)$' {
            Show-Help
            exit 0
        }
        '^(?i)(openfolder|folder|open-dir|dir)$' {
            Open-RecorderFolder
        }
        '^(?i)(setup|install)$' {
            Invoke-Setup
        }
        '^(?i)(silent|mute|noaudio|video)$' {
            $mode = 'silent'
            continue
        }
        '^(?i)(audio|sound|record)$' {
            $mode = 'audio'
            continue
        }
        '^(?i)(-seconds|--seconds|-duration|--duration)$' {
            if ($i + 1 -ge $InputArgs.Count) {
                throw 'A number is required after -seconds.'
            }

            $i++
            $seconds = [int]$InputArgs[$i]
            continue
        }
        '^(?i)(-fps|--fps)$' {
            if ($i + 1 -ge $InputArgs.Count) {
                throw 'A number is required after -fps.'
            }

            $i++
            $fps = [int]$InputArgs[$i]
            continue
        }
        default {
            $outputParts.Add($token)
        }
    }
}

$ffmpegPath = Get-FfmpegPath
if (-not $ffmpegPath) {
    Write-Host 'FFmpeg was not found.'
    Write-Host 'Run: screen setup'
    Write-Host 'Or install FFmpeg manually, then try again.'
    exit 1
}

$outputName = ($outputParts -join ' ').Trim()
$outputPath = Resolve-OutputPath -OutputName $outputName

Write-Host "Starting $mode screen recording..."
Write-Host "Saving to: $outputPath"
if ($seconds -gt 0) {
    Write-Host "Duration: $seconds second(s)"
}
else {
    Write-Host 'Press q or Ctrl+C to stop.'
}

$exitCode = Start-Recording -FfmpegPath $ffmpegPath -Mode $mode -OutputPath $outputPath -FramesPerSecond $fps -DurationSeconds $seconds
if ($exitCode -eq 0) {
    Write-Host 'Recording finished.'
}

exit $exitCode
