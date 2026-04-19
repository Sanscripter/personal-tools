param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

function Get-CmderRoot {
    $candidates = @(
        $env:CMDER_ROOT,
        (Join-Path $env:ChocolateyInstall 'lib\cmder\tools\cmder'),
        'C:\tools\cmder',
        (Join-Path $env:LOCALAPPDATA 'cmder'),
        (Join-Path $env:USERPROFILE 'cmder'),
        (Join-Path $env:USERPROFILE 'Desktop\cmder')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if ((Test-Path (Join-Path $candidate 'vendor\init.bat')) -or (Test-Path (Join-Path $candidate 'Cmder.exe'))) {
            return $candidate
        }
    }

    return $null
}

function Update-CmderShellState {
    param([string]$CmderRoot)

    Refresh-WindowsToolingPath

    if (-not [string]::IsNullOrWhiteSpace($CmderRoot)) {
        $env:CMDER_ROOT = $CmderRoot
        Add-PathIfExists $CmderRoot
        Add-PathIfExists (Join-Path $CmderRoot 'vendor\bin')
    }

    Add-PathIfExists (Join-Path $env:ProgramData 'chocolatey\bin')
}

function Save-CmderRoot {
    param([string]$CmderRoot)

    if (-not [string]::IsNullOrWhiteSpace($CmderRoot)) {
        [Environment]::SetEnvironmentVariable('CMDER_ROOT', $CmderRoot, 'User')
    }
}

function Get-CmderStartupDirectories {
    $primaryDir = if (Test-Path 'D:\') { 'D:\' } else { [System.IO.Path]::GetPathRoot($env:SystemDrive) }
    if (-not $primaryDir) {
        $primaryDir = 'C:\'
    }

    $secondaryDir = $primaryDir

    try {
        $reposFolder = Get-ChildItem -LiteralPath $primaryDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq 'repos' } |
            Select-Object -First 1

        if ($reposFolder) {
            $secondaryDir = $reposFolder.FullName
        }
    }
    catch {
        $secondaryDir = $primaryDir
    }

    [pscustomobject]@{
        Primary   = $primaryDir
        Secondary = $secondaryDir
    }
}

function Set-ConEmuValue {
    param(
        [Parameter(Mandatory)] [System.Xml.XmlElement]$Parent,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Type,
        [Parameter(Mandatory)] [string]$Data
    )

    $node = $Parent.SelectSingleNode("value[@name='$Name']")
    if (-not $node) {
        $node = $Parent.OwnerDocument.CreateElement('value')
        [void]$node.SetAttribute('name', $Name)
        [void]$Parent.AppendChild($node)
    }

    [void]$node.SetAttribute('type', $Type)
    [void]$node.SetAttribute('data', $Data)
    return $node
}

function Update-CmderStartupLayout {
    param([string]$CmderRoot)

    if ([string]::IsNullOrWhiteSpace($CmderRoot)) {
        return
    }

    $configPath = Join-Path $CmderRoot 'config\user-ConEmu.xml'
    if (-not (Test-Path $configPath)) {
        return
    }

    $startupDirs = Get-CmderStartupDirectories
    $primaryDir = $startupDirs.Primary
    $secondaryDir = $startupDirs.Secondary

    [xml]$config = Get-Content -LiteralPath $configPath -Raw
    $vanillaNode = $config.SelectSingleNode("//key[@name='.Vanilla']")
    if (-not $vanillaNode) {
        return
    }

    $tasksNode = $vanillaNode.SelectSingleNode("key[@name='Tasks']")
    if (-not $tasksNode) {
        return
    }

    $taskNode = $tasksNode.SelectSingleNode("key[value[@name='Name' and @data='{cmd::Cmder}']]")
    if (-not $taskNode) {
        return
    }

    $cmd1 = 'cmd /k ""%ConEmuDir%\..\init.bat" " -cur_console:d:"' + $primaryDir + '"'
    $cmd2 = 'cmd /k ""%ConEmuDir%\..\init.bat" " -cur_console:s50H:d:"' + $secondaryDir + '"'

    [void](Set-ConEmuValue -Parent $vanillaNode -Name 'StartTasksName' -Type 'string' -Data '{cmd::Cmder}')
    [void](Set-ConEmuValue -Parent $taskNode -Name 'Cmd1' -Type 'string' -Data $cmd1)
    [void](Set-ConEmuValue -Parent $taskNode -Name 'Cmd2' -Type 'string' -Data $cmd2)
    [void](Set-ConEmuValue -Parent $taskNode -Name 'Count' -Type 'long' -Data '2')

    $config.Save($configPath)

    Write-Host ('Startup panes: ' + $primaryDir + ' | ' + $secondaryDir) -ForegroundColor Green
}

function Show-CmderInfo {
    param([string]$CmderRoot)

    if ($CmderRoot) {
        $startupDirs = Get-CmderStartupDirectories

        Write-Host ''
        Write-Host 'Cmder root: ready' -ForegroundColor Green
        Write-Host ('Path: ' + $CmderRoot)
        Write-Host ('Default startup panes: ' + $startupDirs.Primary + ' | ' + $startupDirs.Secondary)

        if (Test-Path (Join-Path $CmderRoot 'vendor\init.bat')) {
            Write-Host 'reload helper: ready' -ForegroundColor Green
        }
        else {
            Write-Host 'reload helper files were not found yet.' -ForegroundColor Yellow
        }
    }
    else {
        Write-Host ''
        Write-Host 'Cmder is not configured yet. Run: tools-setup commander' -ForegroundColor Yellow
    }
}

Write-Host 'Cmder setup' -ForegroundColor Cyan
$cmderRoot = Get-CmderRoot
Update-CmderShellState -CmderRoot $cmderRoot

if ($Status) {
    Show-CmderInfo -CmderRoot $cmderRoot
    exit 0
}

if (-not $cmderRoot) {
    $shouldContinue = Ensure-ElevatedSession -ScriptPath $PSCommandPath -Reason 'Cmder installation may write to shared tools folders.'
    if (-not $shouldContinue) {
        exit 0
    }

    Install-WindowsPackage -DisplayName 'Cmder' -WingetId 'cmder.cmder' -ChocoId 'cmder'
    $cmderRoot = Get-CmderRoot
    Update-CmderShellState -CmderRoot $cmderRoot
}

if (-not $cmderRoot) {
    Write-Host ''
    Write-Host 'Cmder may need a new terminal before it becomes visible on PATH.' -ForegroundColor Yellow
    exit 0
}

Save-CmderRoot -CmderRoot $cmderRoot
Update-CmderStartupLayout -CmderRoot $cmderRoot
Show-CmderInfo -CmderRoot $cmderRoot

Write-Host ''
Write-Host 'Cmder setup finished. Use: reload' -ForegroundColor Green
