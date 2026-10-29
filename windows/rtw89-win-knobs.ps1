# rtw89-win-knobs.ps1 - inspect and relax the Realtek Windows driver for the
# RTL8851BU (TP-Link Archer TX10UB Nano).
#
# Windows does not use the Linux .ko, so the Linux unlock has no equivalent
# here: the Windows driver is a separate binary and the only knobs are the
# registry values it reads at start. This script dumps them and, with -Apply,
# sets the permissive ones that actually exist.
#
#   powershell -ExecutionPolicy Bypass -File .\rtw89-win-knobs.ps1          # dump
#   powershell -ExecutionPolicy Bypass -File .\rtw89-win-knobs.ps1 -Apply   # set
#
# Run elevated. -Apply only touches keywords the driver already exposes, so it
# cannot invent a knob that gets ignored.

[CmdletBinding()]
param([switch]$Apply)

$ErrorActionPreference = 'Stop'
$classGuid = '{4d36e972-e325-11ce-bfc1-08002be10318}'
$classKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classGuid"

# keyword -> value. Anything not present on the adapter is skipped with a note.
$want = [ordered]@{
	'CountryRegion' = 'US'   # 2-letter in most Realtek INFs, numeric in some
	'RegDomain'     = '0'    # 0 = world/FCC-style table where the knob exists
	'TxPower'       = '30'   # dBm cap, if exposed
	'bDFSEnable'    = '1'
}

$adapters = @(Get-NetAdapter -Physical | Where-Object {
		$_.InterfaceDescription -match 'Realtek|802\.11ax' -or
		$_.PnpDeviceID -match 'VID_3625|VID_0BDA'
	})
if ($adapters.Count -eq 0) { throw 'No Realtek 802.11ax adapter found.' }

foreach ($a in $adapters) {
	Write-Host ''
	Write-Host "=== $($a.Name)  [$($a.InterfaceDescription)]" -ForegroundColor Cyan
	Write-Host "PnP: $($a.PnpDeviceID)"

	# driver key, matched by instance GUID
	$key = Get-ChildItem $classKey -ErrorAction SilentlyContinue | Where-Object {
		$p = Get-ItemProperty $_.PSPath -Name NetCfgInstanceId -ErrorAction SilentlyContinue
		$p -and $p.NetCfgInstanceId -eq $a.InterfaceGuid.ToString()
	} | Select-Object -First 1
	if (-not $key) { Write-Warning 'driver registry key not found'; continue }

	$inf = (Get-ItemProperty $key.PSPath -Name InfPath -ErrorAction SilentlyContinue).InfPath
	Write-Host "key: $($key.PSPath)"
	if ($inf) { Write-Host "inf: $inf" }

	Write-Host "`n-- advanced properties the driver exposes --"
	$props = @(Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue)
	foreach ($p in $props) {
		$valid = if ($p.ValidRegistryValues) { $p.ValidRegistryValues -join '|' } else { '' }
		Write-Host ("  {0,-28} = {1,-10} {2}" -f $p.RegistryKeyword, $p.RegistryValue, $valid)
	}

	Write-Host "`n-- regulatory-ish values in the driver key --"
	$all = Get-ItemProperty $key.PSPath
	$all.PSObject.Properties |
		Where-Object { $_.Name -match 'Country|RegDomain|Channel|TxPower|DFS|Band' } |
		ForEach-Object { Write-Host ("  {0} = {1}" -f $_.Name, $_.Value) }

	if ($inf -and (Test-Path "C:\Windows\INF\$inf")) {
		Write-Host "`n-- matching lines in the INF --"
		Select-String -Path "C:\Windows\INF\$inf" -Pattern 'CountryRegion|RegDomain|ChannelPlan|TxPower|bDFSEnable' |
			Select-Object -First 25 |
			ForEach-Object { Write-Host ("  {0}: {1}" -f $_.LineNumber, $_.Line.Trim()) }
	}

	if (-not $Apply) { continue }

	Write-Host "`n-- applying --"
	$names = $props | ForEach-Object { $_.RegistryKeyword }
	foreach ($k in $want.Keys) {
		if ($names -notcontains $k) {
			Write-Host ("  skip {0} (not exposed)" -f $k) -ForegroundColor DarkGray
			continue
		}
		try {
			Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $k -RegistryValue $want[$k] -NoRestart
			Write-Host ("  set  {0} = {1}" -f $k, $want[$k]) -ForegroundColor Green
		} catch {
			Write-Host ("  fail {0}: {1}" -f $k, $_.Exception.Message) -ForegroundColor Yellow
		}
	}
	Restart-NetAdapter -Name $a.Name
	Write-Host '  adapter restarted'
}

Write-Host "`nDone. Re-run without -Apply to see the result." -ForegroundColor Cyan
