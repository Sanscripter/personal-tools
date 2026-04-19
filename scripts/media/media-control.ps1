param(
    [ValidateSet('status','play','pause','toggle','next','previous')]
    [string]$Action = 'status'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType=WindowsRuntime]

$script:AsTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object {
        $_.Name -eq 'AsTask' -and
        $_.IsGenericMethod -and
        $_.GetParameters().Count -eq 1
    } |
    Select-Object -First 1

function Invoke-Await {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Operation,

        [Parameter(Mandatory = $true)]
        [type]$ResultType
    )

    $task = $script:AsTaskMethod.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.Wait()
    return $task.Result
}

function Get-MediaManager {
    try {
        return Invoke-Await -Operation ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) -ResultType ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    }
    catch {
        return $null
    }
}

function Ensure-MediaKeyType {
    if (-not ('Win32.MediaKeys' -as [type])) {
        $signature = @'
[DllImport("user32.dll")]
public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);
'@

        Add-Type -MemberDefinition $signature -Name MediaKeys -Namespace Win32 | Out-Null
    }
}

function Send-MediaKey {
    param(
        [Parameter(Mandatory = $true)]
        [int]$KeyCode
    )

    Ensure-MediaKeyType
    $keyUp = 2

    [Win32.MediaKeys]::keybd_event($KeyCode, 0, 0, 0)
    [Win32.MediaKeys]::keybd_event($KeyCode, 0, $keyUp, 0)
}

function Get-CurrentMediaSession {
    $manager = Get-MediaManager
    if (-not $manager) {
        return $null
    }

    try {
        $current = $manager.GetCurrentSession()
        if ($current) {
            return $current
        }
    }
    catch {
    }

    $sessions = @($manager.GetSessions())
    foreach ($candidate in $sessions) {
        try {
            if ($candidate.GetPlaybackInfo().PlaybackStatus.ToString() -eq 'Playing') {
                return $candidate
            }
        }
        catch {
        }
    }

    return $sessions | Select-Object -First 1
}

function Invoke-SessionBool {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,

        [scriptblock]$Fallback
    )

    try {
        $asyncOp = & $Operation
        if ($null -ne $asyncOp) {
            $result = Invoke-Await -Operation $asyncOp -ResultType ([bool])
            if ($result) {
                return $true
            }
        }
    }
    catch {
    }

    if ($Fallback) {
        & $Fallback
        return $true
    }

    return $false
}

function Get-MediaSummary {
    param(
        [object]$Session
    )

    if (-not $Session) {
        return 'No active media session'
    }

    $status = 'Unknown'
    $app = 'Unknown'
    $title = ''

    try {
        $status = $Session.GetPlaybackInfo().PlaybackStatus.ToString()
    }
    catch {
    }

    try {
        $appId = [string]$Session.SourceAppUserModelId
        if (-not [string]::IsNullOrWhiteSpace($appId)) {
            $app = $appId
        }
    }
    catch {
    }

    try {
        $props = Invoke-Await -Operation ($Session.TryGetMediaPropertiesAsync()) -ResultType ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
        if ($props -and -not [string]::IsNullOrWhiteSpace($props.Title)) {
            $title = $props.Title
        }
    }
    catch {
    }

    if ([string]::IsNullOrWhiteSpace($title)) {
        return "$status | $app"
    }

    return "$status | $app | $title"
}

$session = Get-CurrentMediaSession

switch ($Action) {
    'status' {
        Write-Output (Get-MediaSummary -Session $session)
        exit 0
    }
    'play' {
        if ($session) {
            [void](Invoke-SessionBool -Operation { $session.TryPlayAsync() } -Fallback { Send-MediaKey -KeyCode 179 })
        }
        else {
            Send-MediaKey -KeyCode 179
        }

        exit 0
    }
    'pause' {
        if ($session) {
            [void](Invoke-SessionBool -Operation { $session.TryPauseAsync() } -Fallback { Send-MediaKey -KeyCode 179 })
        }
        else {
            Send-MediaKey -KeyCode 179
        }

        exit 0
    }
    'toggle' {
        if ($session) {
            [void](Invoke-SessionBool -Operation { $session.TryTogglePlayPauseAsync() } -Fallback { Send-MediaKey -KeyCode 179 })
        }
        else {
            Send-MediaKey -KeyCode 179
        }

        exit 0
    }
    'next' {
        if ($session) {
            [void](Invoke-SessionBool -Operation { $session.TrySkipNextAsync() } -Fallback { Send-MediaKey -KeyCode 176 })
        }
        else {
            Send-MediaKey -KeyCode 176
        }

        exit 0
    }
    'previous' {
        if ($session) {
            [void](Invoke-SessionBool -Operation { $session.TrySkipPreviousAsync() } -Fallback { Send-MediaKey -KeyCode 177 })
        }
        else {
            Send-MediaKey -KeyCode 177
        }

        exit 0
    }
}
