[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InputArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Help {
    @"
Screenshot helper

Usage:
  screenshot
  screenshot snip
  screenshot openfolder
  screenshot help

What it does:
  - opens the built-in Windows snipping UI for a quick screenshot
  - lets Windows handle saving or copying the image
"@ | Write-Host
}

function Get-ScreenshotFolder {
    $pictures = [Environment]::GetFolderPath('MyPictures')
    if ([string]::IsNullOrWhiteSpace($pictures)) {
        $pictures = Join-Path $env:USERPROFILE 'Pictures'
    }

    $folder = Join-Path $pictures 'Screenshots'
    if (-not (Test-Path $folder)) {
        $null = New-Item -ItemType Directory -Path $folder -Force
    }

    return $folder
}

function Open-ScreenshotFolder {
    $folder = Get-ScreenshotFolder
    Start-Process explorer.exe $folder | Out-Null
    Write-Host "Opened $folder"
    exit 0
}

function Start-SnipCapture {
    $snippingTool = Join-Path $env:WINDIR 'System32\SnippingTool.exe'

    if (Test-Path $snippingTool) {
        Start-Process -FilePath $snippingTool | Out-Null
        Write-Host 'Opened Windows Snipping Tool.'
        exit 0
    }

    Start-Process 'ms-screenclip:' | Out-Null
    Write-Host 'Opened Windows screen clip UI.'
    exit 0
}

$rawInput = if ($InputArgs) { ($InputArgs -join ' ').Trim() } else { '' }

if ([string]::IsNullOrWhiteSpace($rawInput)) {
    Start-SnipCapture
}

if ($rawInput -match '^(?i)(help|/h|-h|--help|\?)$') {
    Show-Help
    exit 0
}

if ($rawInput -match '^(?i)(openfolder|folder|open-dir|dir)$') {
    Open-ScreenshotFolder
}

if ($rawInput -match '^(?i)(snip|shot|capture|new)$') {
    Start-SnipCapture
}

Write-Host 'This helper opens the Windows screenshot tool.'
Write-Host 'Use: screenshot   or   screenshot openfolder'
exit 0
