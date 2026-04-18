[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InputArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Help {
    @"
Google helper

Usage:
  google something to search
  google lucky something to search
  google results something to search
  google url something to search
  google help

What it does:
  - Encodes your query as UTF-8 safely for any language
  - Uses Chrome through the existing chrome helper
  - Tries to open the first result directly in lucky mode
  - Falls back to the normal Google results page if lucky routing is flaky
"@ | Write-Host
}

function Resolve-LuckyTargetUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Url
    )

    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.AllowAutoRedirect = $false
        $request.Method = 'GET'
        $request.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        $response = $request.GetResponse()
        $response.Close()
        return $null
    } catch [System.Net.WebException] {
        $response = $_.Exception.Response
        if ($null -eq $response) {
            return $null
        }

        try {
            $location = [string]$response.Headers['Location']
            if ([string]::IsNullOrWhiteSpace($location)) {
                return $null
            }

            if ($location -match '[?&]q=([^&]+)') {
                return [System.Uri]::UnescapeDataString($Matches[1])
            }

            return $location
        } finally {
            $response.Close()
        }
    }
}

$rawInput = if ($InputArgs -and $InputArgs.Count -gt 0) {
    ($InputArgs -join ' ')
} else {
    [Environment]::GetEnvironmentVariable('GOOGLE_RAW_ARGS', 'Process')
}

$rawInput = [string]::new($rawInput).Trim()

if ([string]::IsNullOrWhiteSpace($rawInput)) {
    Show-Help
    exit 0
}

$mode = 'lucky'
$query = $rawInput

if ($rawInput -match '^(?i)(help|/h|-h|--help|\?)$') {
    Show-Help
    exit 0
}

if ($rawInput -match '^(?i)(results?|search)\s+(.+)$') {
    $mode = 'results'
    $query = $Matches[2]
} elseif ($rawInput -match '^(?i)(lucky|open)\s+(.+)$') {
    $mode = 'lucky'
    $query = $Matches[2]
} elseif ($rawInput -match '^(?i)(url|print)\s+(.+)$') {
    $mode = 'url'
    $query = $Matches[2]
}

$query = $query.Trim()

if ([string]::IsNullOrWhiteSpace($query)) {
    Write-Error 'Please provide a non-empty search query.'
    exit 1
}

$encodedQuery = [System.Uri]::EscapeDataString($query)
$resultsUrl = "https://www.google.com/search?q=$encodedQuery"
$luckyUrl = "https://www.google.com/search?q=$encodedQuery&btnI=1"

switch ($mode) {
    'results' {
        $url = $resultsUrl
    }
    'url' {
        $url = $resultsUrl
    }
    default {
        $url = $luckyUrl
    }
}

if ($mode -eq 'url') {
    $url | Write-Output
    exit 0
}

$launchUrl = $url
if ($mode -eq 'lucky') {
    $resolvedUrl = Resolve-LuckyTargetUrl -Url $luckyUrl
    if ([string]::IsNullOrWhiteSpace($resolvedUrl)) {
        $launchUrl = $resultsUrl
    } elseif ($resolvedUrl -match '^https?://([a-z0-9-]+\.)*google\.[^/]+/?$') {
        $launchUrl = $resultsUrl
    } else {
        $launchUrl = $resolvedUrl
    }
}

$chromeLauncher = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\bin\chrome.bat'))

if (Test-Path $chromeLauncher) {
    $env:CHROME_TARGET = $launchUrl
    try {
        $process = Start-Process -FilePath $chromeLauncher -ArgumentList @('open') -PassThru -Wait
        exit $process.ExitCode
    }
    finally {
        Remove-Item Env:CHROME_TARGET -ErrorAction SilentlyContinue
    }
}

Start-Process $launchUrl | Out-Null
exit 0
