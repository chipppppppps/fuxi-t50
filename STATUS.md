# STATUS — t50 line stopped on 2026-11-08

Verdict: the t50 kernel this repository can build **does not survive the kernel entry** on the phone.

## What was proven

* The boot image is structurally sound. `boot.img` for the t50 pack run 42431428899:
  * 12,386,304 bytes, sha256 `9bb0797dab99e44e3cb5aa3b9aebab3bfbac3be5bd4ef004a68c5e0020818a02`
  * the gzip kernel blob inflates to 187,695,296 bytes = shim 192 + firmware 3,145,728 + payload 184,549,376
  * the payload's sha256 is `504b0d886b09a261ab7907969856feb143c4fed54d80b340dc3da03102235a87`, exactly the hash the pack run recorded
  * `payload_kernel_sha256 == kernel_sha256` (`bd43c63656c6cce679496300274e46bc7071d355602334f9efe46e116c299708`), so the kernel was not modified by the pack step
* Three images were started with `fastboot boot` (nothing written to the phone):
  | image | entry probe | result on the phone |
  | --- | --- | --- |
  | `boot-t50-probe.img` | blue/magenta bars + panic screen | menu → green bar → black → reboot after ~2 s |
  | `boot-t50-timed.img` | stage 3 resets 8 s after the MMU is on | menu → green bar → black → reboot after ~2 s |
  | `boot-t50-timed32.img` | stage 3 resets 32 s after the MMU is on | menu → green bar → black → reboot after ~2 s |
  | `boot-t50-raw.img` | **no probe at all**, kernel bytes untouched | menu → green bar → black → reboot after ~2 s |
* The reset moment does not depend on the probe, the delay value or the panic screen, and the unpatched kernel behaves the same. The green bar is the last thing the UEFI side draws, so the kernel never reached the blue bar, which the probe paints at its entry.

## Why it cannot be fixed from this repository alone

`scripts/build-native-legacy-display.py`, `build-sheng-platform-power.py`, `build-native-aes-bindings.py` and `build-native-hid-input.py` all require a reference Mach-O under `build/native-prelink/` (`native-owner-ufs-rootauth3-candidate.macho`, `native-owner-mobile-graphics-candidate.macho`, `native-defaults-candidate.macho`, …). Those files are build products of a **previous, working kernel** and are not published anywhere (`old`, `main` and `V2` branches, no releases, no artifacts big enough to be an image). `native_prelink.exports()` needs an `LC_SYMTAB`, so the Apple kernelcache cannot stand in for them.

The link was completed here by stubbing the symbols those archives would have provided (`stage-a/`), and by dropping the Adreno driver/kit recipes so the tree's XNU headers stay consistent. The result links and packs, but the machine resets inside the first two seconds — consistent with a prelinked kernel whose bindings were never qualified.

The question is filed upstream: https://github.com/UniXNU/UniXNU/issues/197

## What still works

The OddlyLabs UniXNU line in `chipppppppps/unixnu-fuxi` reaches user space on this phone: `fastboot boot boot_v4.img` ends with launchd as PID 1 (`SYS root apfs /dev/disk1s1 1:launchd 3:restored_externa 4:mount_tmpfs n3`). It has no display driver, so the screen only shows the boot bars and the touch-probe panic rows.

## Reproducing the t50 build (for whoever has the candidates)

1. Put a qualified `native-owner-ufs-cpu-desktop-*-candidate.macho` (plus its `.json` plan) at `fuxi/build/xnu-prelink/`.
2. Run `t50-kernel.yml` with `display: real` and no stub list.
3. Feed the kernel artifact id to `t50-pack.yml`.

Everything else (submodule repointing, the three stale archive paths in `build-xnu-4k-baseline.sh`, the EDK2 library drops, the nop-filled entry padding, `llvm-nm`/`ld.lld`) is already handled by those two workflows.
