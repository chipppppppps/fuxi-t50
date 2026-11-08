#requires -Version 5.1
# Make slot a active again so the phone boots Android.
# ASCII only on purpose: Windows PowerShell 5.1 reads .ps1 as ANSI.

$ErrorActionPreference = 'Stop'

$fastboot = 'C:\Users\34804\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\fastboot.exe'
if (-not (Test-Path $fastboot)) { throw "fastboot not found: $fastboot" }

# fastboot writes some of its chatter to stderr; with ErrorActionPreference=Stop
# PowerShell 5.1 turns that into a terminating NativeCommandError. Relax it here.
function Invoke-Fastboot {
    param([Parameter(ValueFromRemainingArguments = $true)] $Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = & $fastboot @Arguments 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    [pscustomobject]@{ Text = ($text -join "`n"); Code = $code }
}

Write-Host "Waiting for a device in fastboot..."
$serial = $null
for ($i = 0; $i -lt 60; $i++) {
    $found = (Invoke-Fastboot devices).Text
    foreach ($line in ($found -split "`n")) {
        $parts = ($line -split "\s+") | Where-Object { $_ -ne '' }
        if ($parts.Count -ge 2 -and $parts[1] -eq 'fastboot') { $serial = $parts[0]; break }
    }
    if ($serial) { break }
    Start-Sleep -Seconds 2
}
if (-not $serial) { throw "no fastboot device appeared within 120 s (hold volume-down + power, then plug the cable)" }
Write-Host ("device  : " + $serial)

$result = Invoke-Fastboot -s $serial --set-active=a
Write-Host $result.Text
if ($result.Code -ne 0) { throw "set-active=a failed" }

Write-Host "Slot a is active. Rebooting..."
Write-Host (Invoke-Fastboot -s $serial reboot).Text
Write-Host "Android should come up with all of its data."
