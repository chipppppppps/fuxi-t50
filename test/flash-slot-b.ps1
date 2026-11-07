#requires -Version 5.1
# Put a UniXNU probe image into slot b and make slot b active.
# Reversible: run back-to-a.ps1 (or `fastboot --set-active=a`) to boot Android again.
# ASCII only on purpose: Windows PowerShell 5.1 reads .ps1 as ANSI.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File flash-slot-b.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File flash-slot-b.ps1 -Image ..\t50-boot.img -Sha256 <hash>

param(
    [string] $Image  = 'C:\Users\34804\Documents\deepseek-harness\default-workspace\unixnu-fuxi\boot_v4.img',
    [string] $Sha256 = '9cdfb91f6330b7afdc8eb483a9db7c24b61daa6826aeb617b8474c58d09c783d'
)

$ErrorActionPreference = 'Stop'

$fastboot = 'C:\Users\34804\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\fastboot.exe'

function Say($text) { Write-Host $text }

if (-not (Test-Path $fastboot)) { throw "fastboot not found: $fastboot" }
if (-not (Test-Path $Image))    { throw "image not found: $Image" }

$size = (Get-Item $Image).Length
$hash = (Get-FileHash $Image -Algorithm SHA256).Hash.ToLower()
Say ("image      : " + $Image)
Say ("bytes      : " + $size)
Say ("sha256     : " + $hash)
if ($Sha256 -and ($hash -ne $Sha256.ToLower())) {
    throw ("sha256 mismatch, refusing to flash (expected " + $Sha256 + ")")
}

Say ""
Say "Waiting for a device in fastboot (power off, hold volume-down + power, plug the cable)..."
$serial = $null
for ($i = 0; $i -lt 60; $i++) {
    $lines = & $fastboot devices 2>$null
    foreach ($line in $lines) {
        $parts = ($line -split "\s+") | Where-Object { $_ -ne '' }
        if ($parts.Count -ge 2 -and $parts[1] -eq 'fastboot') { $serial = $parts[0]; break }
    }
    if ($serial) { break }
    Start-Sleep -Seconds 2
}
if (-not $serial) { throw "no fastboot device appeared within 120 s" }
Say ("device     : " + $serial)

$product = (& $fastboot -s $serial getvar product 2>&1 | Out-String)
Say ("product    : " + ($product -replace "\s+", " ").Trim())
if ($product -notmatch 'fuxi') { throw "this is not a fuxi; refusing to continue" }

$slot   = (& $fastboot -s $serial getvar current-slot 2>&1 | Out-String)
$unlock = (& $fastboot -s $serial getvar unlocked 2>&1 | Out-String)
Say ("slot       : " + ($slot -replace "\s+", " ").Trim())
Say ("unlocked   : " + ($unlock -replace "\s+", " ").Trim())
if ($unlock -notmatch 'yes') { throw "bootloader is not unlocked; refusing to write boot_b" }

$psize = (& $fastboot -s $serial getvar partition-size:boot_b 2>&1 | Out-String)
Say ("boot_b size: " + ($psize -replace "\s+", " ").Trim())
$m = [regex]::Match($psize, '0x([0-9a-fA-F]+)')
if (-not $m.Success) { throw "could not read partition-size:boot_b" }
$capacity = [Convert]::ToInt64($m.Groups[1].Value, 16)
Say ("boot_b cap : " + $capacity + " bytes")
if ($capacity -lt $size) { throw ("image needs " + $size + " bytes but boot_b holds only " + $capacity) }

Say ""
Say "Trying to keep a copy of the current boot_b (not all bootloaders support this)..."
$backup = Join-Path (Split-Path $Image) ("boot_b.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".img")
& $fastboot -s $serial fetch boot_b $backup 2>&1 | Out-String | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { Say $_ }
if (Test-Path $backup) { Say ("backup     : " + $backup + "  (" + (Get-Item $backup).Length + " bytes)") }
else { Say "backup     : not supported by this bootloader (slot a is untouched, so Android still boots)" }

Say ""
Say "Writing boot_b..."
& $fastboot -s $serial flash boot_b $Image
if ($LASTEXITCODE -ne 0) {
    Say "flash failed - nothing changed. Do NOT set the slot."
    exit 1
}

Say "Making slot b active..."
& $fastboot -s $serial --set-active=b
if ($LASTEXITCODE -ne 0) {
    Say "set-active failed; slot a is still active, Android is safe."
    exit 1
}

Say ""
Say "Rebooting into slot b..."
& $fastboot -s $serial reboot
Start-Sleep -Seconds 3

Say ""
Say "The phone is booting the probe image from slot b."
Say "Watch the screen: bands, then text or a progress line, then it either stays there or panics."
Say "Tap the screen once to make the touch probe print its diagnostic rows."
Say "To go back to Android: run back-to-a.ps1, or 'fastboot --set-active=a' plus a reboot."
