# fuxi-t50

Xiaomi 13 (fuxi, SM8550) 上跑 t50 那条 iOS/XNU 移植线的构建工作区。

上游：`ljhhkx529/unixnu-fuxi@old`（设备仓库）、`ljhhkx529/uefi-fuxi@old`（UEFI 固件）、`UniXNU/UniXNU@main`（构建驱动）。

## 这个仓库是干什么的

上游那条线**无法从干净树自举**：设备仓库里若干归档脚本（`build-sheng-platform-power.py`、`build-native-legacy-display.py`、`build-native-aes-bindings.py`、`build-native-hid-input.py`）都要一份 `build/native-prelink/native-owner-ufs-cpu-desktop-*-candidate.macho`，那是作者机器上的历史产物，仓库里没有、也没有任何 recipe 能产出它。

这里放两个 workflow，在 GitHub 的 macOS runner 上把这条路绕过并跑通：

| workflow | id | 作用 |
| --- | --- | --- |
| `t50-stage-a.yml` | — | Stage A：先链一个没有 storage/display 的内核，用桩补 undefined 符号；它的 prelink 产物就是后面要的 generation-0 candidate |
| `t50-kernel.yml` | 410274358 | 完整内核：喂入 candidate、补显示驱动生成头、摘掉与树里 XNU 头版本不符的 Adreno kit、自愈补桩，产出 `out/fuxi/kernel/kernel.macho`（约 52.5 MB） |
| `t50-pack.yml` | 410396642 | 打包：拉内核 artifact → payload（带 Apple 原始 static+system 信任缓存）→ UEFI 固件 → `bootimage.py` 打 v3 头 → `boot.img`（约 12.4 MB） |

`t50-kernel.yml` 的 `workflow_dispatch` 有 `display` 输入：`real` 走真实显示驱动，`stub` 用桩跳过它。
`t50-pack.yml` 的 `kernel_artifact` 输入填上一步 kernel artifact 的 id。

## 一键复现

```bash
gh workflow run t50-kernel.yml -R <you>/fuxi-t50 -f display=real
# 等它绿，取 kernel artifact id
gh workflow run t50-pack.yml -R <you>/fuxi-t50 -f kernel_artifact=<id>
gh run download <run-id> -R <you>/fuxi-t50 -n fuxi-t50-boot-1
```

## 2026-11-08 的产物

- `boot.img` 12,382,208 B，sha256 `3d811f836994815722a8c8db21b4875c5d7f4b87d5f03e7a0facdbff51ff54b5`
- 内核 52,518,912 B，sha256 `bd43c63656c6cce679496300274e46bc7071d355602334f9efe46e116c299708`
- payload 184,549,376 B（FAT32 卷标 `FUXIESP`），gzip 进 boot image 的 kernel 段，尾部接 815,093 B dtb
- 详见 [docs/RESULTS-2026-11-08.md](docs/RESULTS-2026-11-08.md)，Release 里带镜像本体

## 上机

见 [test/README.md](test/README.md)。只有写 `boot_b` 槽位或 `fastboot boot`，不碰 `/data`、不碰 slot a。
