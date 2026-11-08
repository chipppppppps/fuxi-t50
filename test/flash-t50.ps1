#requires -Version 5.1
# Put the t50 display-probe image into slot b and make slot b active.
# This image carries the display/legacy-framebuffer driver chain that the
# boot_v4 image does not have. It still boots from RAM only: the payload
# volume rides inside the boot image and nothing writes to /data.
# Reversible: run back-to-a.ps1 (or `fastboot --set-active=a`) to boot Android again.
# ASCII only on purpose: Windows PowerShell 5.1 reads .ps1 as ANSI.

param(
    [string] $Image  = 'C:\Users\34804\Documents\deepseek-harness\default-workspace\unixnu-fuxi\test-2026-11-08\boot-t50-probe.img',
    [string] $Sha256 = '3d811f836994815722a8c8db21b4875c5d7f4b87d5f03e7a0facdbff51ff54b5'
)

$ErrorActionPreference = 'Stop'

$fastboot = 'C:\Users\34804\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\fastboot.exe'

function Say($text) { Write-Host $text }

function Invoke-Fastboot {
    param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Arguments)
    # fastboot prints getvar to stderr; with ErrorActionPreference Stop that
    # becomes a terminating error, so relax it around each native call.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $text = & $fastboot @Arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previous
    return [pscustomobject]@{ Text = $text; Code = $code }
}

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
    $lines = (Invoke-Fastboot devices).Text -split "`n"
    foreach ($line in $lines) {
        $parts = ($line -split "\s+") | Where-Object { $_ -ne '' }
        if ($parts.Count -ge 2 -and $parts[1] -eq 'fastboot') { $serial = $parts[0]; break }
    }
    if ($serial) { break }
    Start-Sleep -Seconds 2
}
if (-not $serial) { throw "no fastboot device appeared within 120 s" }
Say ("device     : " + $serial)

$product = (Invoke-Fastboot -s $serial getvar product).Text
Say ("product    : " + ($product -replace "\s+", " ").Trim())
if ($product -notmatch 'fuxi') { throw "this is not a fuxi; refusing to continue" }

$slot = (Invoke-Fastboot -s $serial getvar current-slot).Text
$unlock = (Invoke-Fastboot -s $serial getvar unlocked).Text
Say ("slot       : " + ($slot -replace "\s+", " ").Trim())
Say ("unlocked   : " + ($unlock -replace "\s+", " ").Trim())
if ($unlock -notmatch 'yes') { throw "bootloader is not unlocked; refusing to write boot_b" }

$psize = (Invoke-Fastboot -s $serial getvar partition-size:boot_b).Text
Say ("boot_b size: " + ($psize -replace "\s+", " ").Trim())
$m = [regex]::Match($psize, '0x([0-9a-fA-F]+)')
if (-not $m.Success) { throw "could not read partition-size:boot_b" }
$capacity = [Convert]::ToInt64($m.Groups[1].Value, 16)
Say ("boot_b cap : " + $capacity + " bytes")
if ($capacity -lt $size) { throw ("image needs " + $size + " bytes but boot_b holds only " + $capacity) }

Say ""
Say "Trying to keep a copy of the current boot_b (not all bootloaders support this)..."
$backup = Join-Path (Split-Path $Image) ("boot_b.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".img")
(Invoke-Fastboot -s $serial fetch boot_b $backup).Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { Say $_ }
if (Test-Path $backup) { Say ("backup     : " + $backup + "  (" + (Get-Item $backup).Length + " bytes)") }
else { Say "backup     : not supported by this bootloader (slot a is untouched, so Android still boots)" }

Say ""
Say "Writing boot_b..."
$flash = Invoke-Fastboot -s $serial flash boot_b $Image
(($flash.Text -split "`n") | Where-Object { $_.Trim() } | ForEach-Object { Say $_.Trim() })
if ($flash.Code -ne 0) {
    Say "flash failed - nothing changed. Do NOT set the slot."
    exit 1
}

Say "Making slot b active..."
$active = Invoke-Fastboot -s $serial --set-active=b
if ($active.Code -ne 0) {
    Say "set-active failed; slot a is still active, Android is safe."
    exit 1
}

Say ""
Say "Rebooting into slot b..."
(Invoke-Fastboot -s $serial reboot) | Out-Null
Start-Sleep -Seconds 3

Say ""
Say "The phone is booting the t50 display probe from slot b."
Say "Expected: the UniXNU menu appears for about 3 seconds, then the loader hands off."
Say "Watch for: a green bar, then a blue bar, then either a framebuffer console with"
Say "the XNU boot log or a panic screen with text. Photograph whatever it shows."
Say "To go back to Android: run 2-back-to-android.cmd, or 'fastboot --set-active=a'."
