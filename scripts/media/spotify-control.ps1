param(
    [ValidateSet('status','track','play','pause','toggle','next','previous','shuffle-status','shuffle-on','shuffle-off','shuffle-toggle')]
    [string]$Action = 'status'
)

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

function Get-SpotifySession {
    $manager = Invoke-Await -Operation ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) -ResultType ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
    return $manager.GetSessions() | Where-Object { $_.SourceAppUserModelId -match 'Spotify' } | Select-Object -First 1
}

function Send-MediaKey {
    param(
        [Parameter(Mandatory = $true)]
        [int]$KeyCode
    )

    $signature = @'
[DllImport("user32.dll")]
public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);
'@

    $type = Add-Type -MemberDefinition $signature -Name MediaKeys -Namespace Win32 -PassThru
    $keyUp = 2

    $type::keybd_event($KeyCode, 0, 0, 0)
    $type::keybd_event($KeyCode, 0, $keyUp, 0)
}

function Send-ShuffleHotkey {
    try {
        $shell = New-Object -ComObject WScript.Shell
        [void]$shell.AppActivate('Spotify')
        $shell.SendKeys('^s')
    } catch {
    }
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
    } catch {
    }

    if ($Fallback) {
        & $Fallback
        return $true
    }

    return $false
}

function Get-TrackTitle {
    param(
        [object]$Session
    )

    if (-not $Session) {
        return ''
    }

    try {
        $props = Invoke-Await -Operation ($Session.TryGetMediaPropertiesAsync()) -ResultType ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
        return $props.Title
    } catch {
        return ''
    }
}

$session = Get-SpotifySession
$playbackInfo = if ($session) { $session.GetPlaybackInfo() } else { $null }
$status = if ($playbackInfo) { $playbackInfo.PlaybackStatus.ToString() } else { 'Unknown' }
$title = Get-TrackTitle -Session $session
$shuffleActive = if ($playbackInfo) { [bool]$playbackInfo.IsShuffleActive } else { $false }

switch ($Action) {
    'status' {
        Write-Output $status
    }
    'track' {
        Write-Output $title
    }
    'play' {
        if ($status -eq 'Playing') {
            exit 0
        }

        if ($session) {
            [void](Invoke-SessionBool -Operation { $session.TryPlayAsync() } -Fallback { Send-MediaKey -KeyCode 179 })
        } else {
            Start-Process 'spotify:play'
        }

        exit 0
    }
    'pause' {
        if ($status -eq 'Playing') {
            if ($session) {
                [void](Invoke-SessionBool -Operation { $session.TryPauseAsync() } -Fallback { Send-MediaKey -KeyCode 179 })
            } else {
                Send-MediaKey -KeyCode 179
            }
        }

        exit 0
    }
    'toggle' {
        if ($session) {
            [void](Invoke-SessionBool -Operation { $session.TryTogglePlayPauseAsync() } -Fallback { Send-MediaKey -KeyCode 179 })
        } else {
            Send-MediaKey -KeyCode 179
        }

        exit 0
    }
    'next' {
        if ($session) {
            [void](Invoke-SessionBool -Operation { $session.TrySkipNextAsync() } -Fallback { Send-MediaKey -KeyCode 176 })
        } else {
            Send-MediaKey -KeyCode 176
        }

        exit 0
    }
    'previous' {
        if ($session) {
            $positionSeconds = 0

            try {
                $positionSeconds = $session.GetTimelineProperties().Position.TotalSeconds
            } catch {
                $positionSeconds = 0
            }

            [void](Invoke-SessionBool -Operation { $session.TrySkipPreviousAsync() } -Fallback { Send-MediaKey -KeyCode 177 })

            if ($positionSeconds -gt 3) {
                [void](Invoke-SessionBool -Operation { $session.TrySkipPreviousAsync() } -Fallback { Send-MediaKey -KeyCode 177 })
            }
        } else {
            Send-MediaKey -KeyCode 177
        }

        exit 0
    }
    'shuffle-status' {
        if ($shuffleActive) {
            Write-Output 'On'
        } else {
            Write-Output 'Off'
        }
    }
    'shuffle-on' {
        if ($session) {
            if (-not $shuffleActive) {
                [void](Invoke-SessionBool -Operation { $session.TryChangeShuffleActiveAsync($true) } -Fallback { Send-ShuffleHotkey })
            }
        } else {
            Send-ShuffleHotkey
        }

        exit 0
    }
    'shuffle-off' {
        if ($session) {
            if ($shuffleActive) {
                [void](Invoke-SessionBool -Operation { $session.TryChangeShuffleActiveAsync($false) } -Fallback { Send-ShuffleHotkey })
            }
        } else {
            Send-ShuffleHotkey
        }

        exit 0
    }
    'shuffle-toggle' {
        if ($session) {
            $desiredState = -not $shuffleActive
            [void](Invoke-SessionBool -Operation { $session.TryChangeShuffleActiveAsync($desiredState) } -Fallback { Send-ShuffleHotkey })
        } else {
            Send-ShuffleHotkey
        }

        exit 0
    }
}
