param(
    [string]$Action = 'all'
)

$ErrorActionPreference = 'Stop'

function Format-Size {
    param([double]$Bytes)

    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}

function Write-Section {
    param([string]$Title)

    Write-Output $Title
    Write-Output ('-' * $Title.Length)
}

function Get-CurrentDrive {
    $path = (Get-Location).Path
    if ($path -match '^[A-Za-z]:') {
        return $matches[0]
    }

    if ($env:SystemDrive) {
        return $env:SystemDrive
    }

    return 'C:'
}

function Show-DiskInfo {
    Write-Section 'Disk Space'

    $drive = Get-CurrentDrive
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'"

    if (-not $disk) {
        Write-Output "Could not read drive information for $drive."
        return
    }

    $size = [double]$disk.Size
    $free = [double]$disk.FreeSpace
    $used = $size - $free
    $usedPercent = if ($size -gt 0) { [math]::Round(($used / $size) * 100, 1) } else { 0 }

    Write-Output ("Current path : {0}" -f (Get-Location).Path)
    Write-Output ("Drive        : {0}" -f $drive)
    Write-Output ("Free         : {0}" -f (Format-Size $free))
    Write-Output ("Used         : {0} ({1}%)" -f (Format-Size $used), $usedPercent)
    Write-Output ("Total        : {0}" -f (Format-Size $size))
}

function Show-NetworkInfo {
    Write-Section 'Network'

    $printed = $false
    $netConfigCmd = Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue

    if ($netConfigCmd) {
        $configs = Get-NetIPConfiguration | Where-Object {
            $_.IPv4Address -and $_.NetAdapter -and $_.NetAdapter.Status -eq 'Up'
        }

        foreach ($cfg in $configs) {
            $printed = $true
            $ips = @($cfg.IPv4Address | ForEach-Object { $_.IPAddress }) -join ', '
            $mac = if ($cfg.NetAdapter.MacAddress) { $cfg.NetAdapter.MacAddress } else { 'n/a' }
            Write-Output ("Adapter      : {0}" -f $cfg.InterfaceAlias)
            Write-Output ("IPv4         : {0}" -f $ips)
            Write-Output ("MAC          : {0}" -f $mac)
            Write-Output ''
        }
    }

    if (-not $printed) {
        $configs = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {
            $_.IPEnabled -and $_.IPAddress -and $_.MACAddress
        }

        foreach ($cfg in $configs) {
            $ipv4 = @($cfg.IPAddress | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' })
            if (-not $ipv4) {
                continue
            }

            $printed = $true
            Write-Output ("Adapter      : {0}" -f $cfg.Description)
            Write-Output ("IPv4         : {0}" -f ($ipv4 -join ', '))
            Write-Output ("MAC          : {0}" -f $cfg.MACAddress)
            Write-Output ''
        }
    }

    if (-not $printed) {
        Write-Output 'No active network adapters with IPv4 were found.'
    }
}

function Show-RamInfo {
    Write-Section 'RAM Usage'

    $os = Get-CimInstance Win32_OperatingSystem
    $total = [double]$os.TotalVisibleMemorySize * 1KB
    $free = [double]$os.FreePhysicalMemory * 1KB
    $used = $total - $free
    $usedPercent = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }

    Write-Output ("Used         : {0} ({1}%)" -f (Format-Size $used), $usedPercent)
    Write-Output ("Free         : {0}" -f (Format-Size $free))
    Write-Output ("Total        : {0}" -f (Format-Size $total))
    Write-Output ''
    Write-Output 'Top 5 offenders'
    Write-Output '---------------'

    $topProcesses = Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 5 @{Name='Name';Expression={$_.ProcessName}}, @{Name='PID';Expression={$_.Id}}, @{Name='RAM';Expression={Format-Size $_.WorkingSet64}}

    if ($topProcesses) {
        ($topProcesses | Format-Table -AutoSize | Out-String -Width 140).TrimEnd()
    }
    else {
        Write-Output 'Could not read process memory usage.'
    }
}

function Open-TaskManager {
    Start-Process taskmgr.exe | Out-Null
    Write-Output 'Opened Task Manager.'
}

function Show-Help {
    Write-Output 'Quick diagnostics helper'
    Write-Output ''
    Write-Output 'Usage:'
    Write-Output '  diag'
    Write-Output '  diag all'
    Write-Output '  diag disk'
    Write-Output '  diag net'
    Write-Output '  diag ram'
    Write-Output '  diag taskmgr'
    Write-Output ''
    Write-Output 'What it does:'
    Write-Output '  - shows free space for the current drive'
    Write-Output '  - prints the local IPv4 and MAC address'
    Write-Output '  - shows current RAM usage and the top 5 memory offenders'
    Write-Output '  - opens Windows Task Manager quickly'
}

switch ($Action.ToLowerInvariant()) {
    'all' {
        Show-DiskInfo
        Write-Output ''
        Show-NetworkInfo
        Show-RamInfo
    }
    'status' {
        Show-DiskInfo
        Write-Output ''
        Show-NetworkInfo
        Show-RamInfo
    }
    'disk' { Show-DiskInfo }
    'space' { Show-DiskInfo }
    'drive' { Show-DiskInfo }
    'net' { Show-NetworkInfo }
    'network' { Show-NetworkInfo }
    'ip' { Show-NetworkInfo }
    'mac' { Show-NetworkInfo }
    'ram' { Show-RamInfo }
    'memory' { Show-RamInfo }
    'taskmgr' { Open-TaskManager }
    'taskman' { Open-TaskManager }
    'tasks' { Open-TaskManager }
    'processes' { Open-TaskManager }
    'help' { Show-Help }
    '/?' { Show-Help }
    '-h' { Show-Help }
    '--help' { Show-Help }
    default {
        Write-Output ("Unknown action: {0}" -f $Action)
        Write-Output ''
        Show-Help
        exit 1
    }
}
