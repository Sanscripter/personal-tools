[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InputArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Help {
    @"
WhatsApp helper

Usage:
  whatsapp open
  whatsapp search <chat name>
  whatsapp chat <chat name>
  whatsapp chat <chat name> -- <message>
  whatsapp draft -- <message>
  whatsapp send -- <message>
  whatsapp draft <chat name> -- <message>
  whatsapp send <chat name> -- <message>
  whatsapp phone <number>
  whatsapp phone <number> -- <message>
  whatsapp help

Examples:
  whatsapp open
  whatsapp search family
  whatsapp chat Alice
  whatsapp chat Alice -- Here is the link
  whatsapp draft -- Quick note for the current chat
  whatsapp send -- I am on my way
  whatsapp draft Project Team -- Meeting moved to 3pm
  whatsapp send Alice -- I am on my way
  whatsapp phone +5511999999999 -- Hello from Windows

What it does:
  - opens the local WhatsApp desktop app when available
  - automates chat search using the keyboard
  - can type a draft or send a message into the first matching chat
  - can also open a number directly through the WhatsApp send URL
"@ | Write-Host
}

function Get-RawInput {
    if ($InputArgs -and $InputArgs.Count -gt 0) {
        return ($InputArgs -join ' ').Trim()
    }

    $raw = [Environment]::GetEnvironmentVariable('WHATSAPP_RAW_ARGS', 'Process')
    if ($null -eq $raw) {
        return ''
    }

    return $raw.Trim()
}

function Convert-ToSendKeysLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Text
    )

    $map = @{
        '+' = '{+}'
        '^' = '{^}'
        '%' = '{%}'
        '~' = '{~}'
        '(' = '{(}'
        ')' = '{)}'
        '[' = '{[}'
        ']' = '{]}'
        '{' = '{{}'
        '}' = '{}}'
    }

    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Text.ToCharArray()) {
        $key = [string] $char
        if ($map.ContainsKey($key)) {
            [void] $builder.Append($map[$key])
        }
        elseif ($key -eq "`r") {
        }
        elseif ($key -eq "`n") {
            [void] $builder.Append('+{ENTER}')
        }
        else {
            [void] $builder.Append($key)
        }
    }

    return $builder.ToString()
}

function Start-WhatsApp {
    $targets = @(
        @{ Kind = 'uri'; Value = 'whatsapp:' },
        @{ Kind = 'app'; Value = 'shell:AppsFolder\5319275A.WhatsAppDesktop_cv1g1gvanyjgm!App' },
        @{ Kind = 'web'; Value = 'https://web.whatsapp.com/' }
    )

    foreach ($target in $targets) {
        try {
            if ($target.Kind -eq 'app') {
                Start-Process -FilePath 'explorer.exe' -ArgumentList $target.Value | Out-Null
            }
            else {
                Start-Process $target.Value | Out-Null
            }

            return
        }
        catch {
        }
    }

    throw 'Unable to launch WhatsApp.'
}

function Set-WhatsAppWindowFocus {
    $shell = New-Object -ComObject WScript.Shell

    for ($i = 0; $i -lt 30; $i++) {
        foreach ($title in @('WhatsApp', 'whatsapp')) {
            try {
                if ($shell.AppActivate($title)) {
                    Start-Sleep -Milliseconds 250
                    return $shell
                }
            }
            catch {
            }
        }

        Start-Sleep -Milliseconds 300
    }

    throw 'WhatsApp opened, but its window could not be focused.'
}

function Send-TextByClipboard {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Shell,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Text
    )

    $hadClipboard = $false
    $previousText = $null

    try {
        $previousText = Get-Clipboard -Raw -ErrorAction Stop
        $hadClipboard = $true
    }
    catch {
    }

    try {
        Set-Clipboard -Value $Text -ErrorAction Stop
        Start-Sleep -Milliseconds 120
        $Shell.SendKeys('^v')
    }
    catch {
        $Shell.SendKeys((Convert-ToSendKeysLiteral -Text $Text))
    }
    finally {
        try {
            if ($hadClipboard) {
                Set-Clipboard -Value $previousText -ErrorAction SilentlyContinue
            }
        }
        catch {
        }
    }
}

function Open-ChatDialog {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Query,

        [switch] $OpenChat
    )

    Start-WhatsApp
    $shell = Set-WhatsAppWindowFocus

    $shell.SendKeys('^n')
    Start-Sleep -Milliseconds 500
    Send-TextByClipboard -Shell $shell -Text $Query

    if ($OpenChat) {
        Start-Sleep -Milliseconds 700
        $shell.SendKeys('{ENTER}')
        Start-Sleep -Milliseconds 450
    }

    return $shell
}

function Get-ReadyWhatsAppShell {
    Start-WhatsApp
    return Set-WhatsAppWindowFocus
}

function Normalize-OutgoingMessage {
    param(
        [AllowEmptyString()]
        [string] $Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    return [regex]::Replace(
        $Text,
        'https?://www\.google\.[^\s]+[?&]q=([^&\s]+)',
        {
            param($m)
            try {
                return [System.Uri]::UnescapeDataString($m.Groups[1].Value)
            }
            catch {
                return $m.Value
            }
        }
    )
}

function Open-PhoneTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Phone,

        [string] $Message = ''
    )

    $digits = [regex]::Replace($Phone, '[^0-9]', '')
    if ([string]::IsNullOrWhiteSpace($digits)) {
        throw 'Please provide a phone number with digits.'
    }

    $encoded = [System.Uri]::EscapeDataString($Message)
    $targets = @()

    if ([string]::IsNullOrWhiteSpace($Message)) {
        $targets += "whatsapp://send?phone=$digits"
        $targets += "https://wa.me/$digits"
    }
    else {
        $targets += "whatsapp://send?phone=$digits&text=$encoded"
        $targets += "https://wa.me/$digits?text=$encoded"
    }

    foreach ($target in $targets) {
        try {
            Start-Process $target | Out-Null
            return
        }
        catch {
        }
    }

    throw 'Unable to open the WhatsApp phone target.'
}

$rawInput = Get-RawInput

if ([string]::IsNullOrWhiteSpace($rawInput)) {
    Show-Help
    exit 0
}

if ($rawInput -match '^(?i)(help|/h|-h|--help|\?)$') {
    Show-Help
    exit 0
}

if ($rawInput -match '^(?i)(open|launch)$') {
    Start-WhatsApp
    exit 0
}

if ($rawInput -match '^(?i)(search|find)\s+(.+)$') {
    Open-ChatDialog -Query $Matches[2].Trim() | Out-Null
    exit 0
}

if ($rawInput -match '^(?i)(chat|openchat)\s+(.+)$') {
    $rest = $Matches[2].Trim()
    $parts = $rest -split '\s+--\s+', 2

    if ($parts.Count -ge 2) {
        $target = $parts[0].Trim()
        $message = Normalize-OutgoingMessage -Text $parts[1]
        $shell = Open-ChatDialog -Query $target -OpenChat
        Send-TextByClipboard -Shell $shell -Text $message
        exit 0
    }

    Open-ChatDialog -Query $rest -OpenChat | Out-Null
    exit 0
}

if ($rawInput -match '^(?i)(draft|message|send)\s+(.+)$') {
    $mode = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2].Trim()

    if ($rest -match '^--\s*(.+)$') {
        $message = Normalize-OutgoingMessage -Text $Matches[1]
        $shell = Get-ReadyWhatsAppShell
        Send-TextByClipboard -Shell $shell -Text $message

        if ($mode -eq 'send') {
            Start-Sleep -Milliseconds 150
            $shell.SendKeys('{ENTER}')
        }

        exit 0
    }

    $parts = $rest -split '\s+--\s+', 2

    if ($parts.Count -lt 2) {
        Write-Error 'Use: whatsapp send -- <message> or whatsapp send <chat name> -- <message>'
        exit 1
    }

    $target = $parts[0].Trim()
    $message = Normalize-OutgoingMessage -Text $parts[1]
    $shell = Open-ChatDialog -Query $target -OpenChat
    Send-TextByClipboard -Shell $shell -Text $message

    if ($mode -eq 'send') {
        Start-Sleep -Milliseconds 150
        $shell.SendKeys('{ENTER}')
    }

    exit 0
}

if ($rawInput -match '^(?i)(phone|number)\s+(.+)$') {
    $rest = $Matches[2]
    $parts = $rest -split '\s+--\s+', 2
    $phone = $parts[0].Trim()
    $message = if ($parts.Count -ge 2) { $parts[1] } else { '' }

    Open-PhoneTarget -Phone $phone -Message $message
    exit 0
}

Open-ChatDialog -Query $rawInput.Trim() | Out-Null
exit 0
