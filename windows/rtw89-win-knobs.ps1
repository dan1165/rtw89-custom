# rtw89-win-knobs.ps1 - relax the Realtek Windows driver for the RTL8851BU
# (TP-Link Archer TX10UB Nano), or dump what it exposes.
#
#   ... -File .\rtw89-win-knobs.ps1            # dump only
#   ... -File .\rtw89-win-knobs.ps1 -Apply     # back up, set, re-apply at logon
#   ... -File .\rtw89-win-knobs.ps1 -Revert    # restore the backup, drop the task
#
# Windows does not use the Linux .ko, so there is no source to patch here: the
# only knobs are the registry values the driver reads at start. -Apply touches
# only keywords the driver already exposes, so a wrong guess is a no-op.
#
# Run elevated.

[CmdletBinding()]
param(
	[switch]$Apply,
	[switch]$Revert,
	[switch]$Quiet,
	[switch]$NoTask,
	[switch]$RemoveDriver
)

$ErrorActionPreference = 'Stop'
$classGuid = '{4d36e972-e325-11ce-bfc1-08002be10318}'
$classKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classGuid"
$taskName = 'rtw89-win-knobs'
$stateDir = Join-Path $env:ProgramData 'rtw89-win-knobs'
$backup = Join-Path $stateDir 'backup.json'
$self = $MyInvocation.MyCommand.Path

# keyword -> value. Anything not present on the adapter is skipped.
$want = [ordered]@{
	'CountryRegion' = 'US'
	'RegDomain'     = '0'
	'TxPower'       = '30'
	'bDFSEnable'    = '1'
}

function Say($msg, $color = 'Gray') {
	if (-not $Quiet) { Write-Host $msg -ForegroundColor $color }
}

function Get-AdapterKey($adapter) {
	Get-ChildItem $classKey -ErrorAction SilentlyContinue | Where-Object {
		$p = Get-ItemProperty $_.PSPath -Name NetCfgInstanceId -ErrorAction SilentlyContinue
		$p -and $p.NetCfgInstanceId -eq $adapter.InterfaceGuid.ToString()
	} | Select-Object -First 1
}

if ($RemoveDriver) {
	# remove every staged copy of the vendor INF from the driver store
	$cur = $null
	$targets = @()
	foreach ($line in (& pnputil.exe /enum-drivers)) {
		if ($line -match 'Published Name\s*:\s*(\S+)') { $cur = $Matches[1] }
		elseif ($line -match 'Original Name\s*:\s*(\S+)' -and $Matches[1] -eq 'netrtwlanu6.inf' -and $cur) {
			$targets += $cur
		}
	}
	if (-not $targets) { Say 'no staged netrtwlanu6.inf found' Yellow; exit 0 }
	foreach ($t in $targets) {
		& pnputil.exe /delete-driver $t /uninstall /force | Out-Null
		Say "removed $t"
	}
	exit 0
}

$adapters = @(Get-NetAdapter -Physical | Where-Object {
		$_.InterfaceDescription -match 'Realtek|802\.11ax' -or
		$_.PnpDeviceID -match 'VID_3625|VID_0BDA'
	})

if ($adapters.Count -eq 0) {
	Say 'No Realtek 802.11ax adapter found. Plug the stick in and re-run.' Yellow
	if ($Apply -and -not $NoTask) {
		# still schedule it: the task will do the work once the stick appears
		& schtasks.exe /create /tn $taskName /tr "powershell -NoProfile -ExecutionPolicy Bypass -File `"$self`" -Apply -Quiet" /sc onlogon /rl highest /f | Out-Null
		Say 'Scheduled to run at logon instead.' Gray
	}
	exit 0
}

if ($Revert) {
	foreach ($a in $adapters) {
		$key = Get-AdapterKey $a
		if (-not $key) { continue }
		if (Test-Path $backup) {
			$saved = Get-Content $backup -Raw | ConvertFrom-Json
			foreach ($p in $saved.PSObject.Properties) {
				if ($null -eq $p.Value) {
					Remove-ItemProperty -Path $key.PSPath -Name $p.Name -ErrorAction SilentlyContinue
				} else {
					Set-ItemProperty -Path $key.PSPath -Name $p.Name -Value $p.Value
				}
			}
			Say "restored $($p.Name) on $($a.Name)"
		}
		Restart-NetAdapter -Name $a.Name -ErrorAction SilentlyContinue
	}
	& schtasks.exe /delete /tn $taskName /f 2>$null | Out-Null
	Say 'reverted' Green
	exit 0
}

foreach ($a in $adapters) {
	Say "=== $($a.Name)  [$($a.InterfaceDescription)]" Cyan
	$key = Get-AdapterKey $a
	if (-not $key) { Say 'driver registry key not found' Yellow; continue }

	$props = @(Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue)

	if (-not $Apply) {
		# dump mode
		Say "key: $($key.PSPath)"
		Say "`n-- advanced properties --"
		foreach ($p in $props) {
			$valid = if ($p.ValidRegistryValues) { $p.ValidRegistryValues -join '|' } else { '' }
			Say ("  {0,-28} = {1,-10} {2}" -f $p.RegistryKeyword, $p.RegistryValue, $valid)
		}
		Say "`n-- regulatory-ish values in the driver key --"
		(Get-ItemProperty $key.PSPath).PSObject.Properties |
			Where-Object { $_.Name -match 'Country|RegDomain|Channel|TxPower|DFS|Band' } |
			ForEach-Object { Say ("  {0} = {1}" -f $_.Name, $_.Value) }
		$inf = (Get-ItemProperty $key.PSPath -Name InfPath -ErrorAction SilentlyContinue).InfPath
		if ($inf -and (Test-Path "C:\Windows\INF\$inf")) {
			Say "`n-- matching INF lines --"
			Select-String -Path "C:\Windows\INF\$inf" -Pattern 'CountryRegion|RegDomain|ChannelPlan|TxPower|bDFSEnable' |
				Select-Object -First 25 | ForEach-Object { Say ("  {0}: {1}" -f $_.LineNumber, $_.Line.Trim()) }
		}
		continue
	}

	# apply mode: back up first, once
	if (-not (Test-Path $backup)) {
		New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
		$orig = [ordered]@{}
		foreach ($k in $want.Keys) {
			$cur = (Get-ItemProperty $key.PSPath -Name $k -ErrorAction SilentlyContinue).$k
			$orig[$k] = $cur
		}
		$orig | ConvertTo-Json | Set-Content -Path $backup -Encoding UTF8
	}

	$names = $props | ForEach-Object { $_.RegistryKeyword }
	foreach ($k in $want.Keys) {
		if ($names -notcontains $k) { Say "  skip $k (not exposed)"; continue }
		try {
			Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $k -RegistryValue $want[$k] -NoRestart
			Say "  set  $k = $($want[$k])" Green
		} catch {
			Say "  fail $k : $($_.Exception.Message)" Yellow
		}
	}
	Restart-NetAdapter -Name $a.Name -ErrorAction SilentlyContinue
	Say '  adapter restarted'
}

if ($Apply -and -not $NoTask) {
	& schtasks.exe /create /tn $taskName /tr "powershell -NoProfile -ExecutionPolicy Bypass -File `"$self`" -Apply -Quiet" /sc onlogon /rl highest /f | Out-Null
	Say 're-applies at logon (survives driver updates)' Gray
}
