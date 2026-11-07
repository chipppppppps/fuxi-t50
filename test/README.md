# 明天的测试包

两件事分两次做，**都只写 `boot_b` 槽位，不碰 `/data`、不碰 slot a**。

| 顺序 | 双击 | 镜像 | 期望看到什么 |
| --- | --- | --- | --- |
| 1（先做） | `1b-flash-t50.cmd` | `boot-t50-probe.img` 12,382,208 B<br>sha256 `3d811f83…51ff54b5` | 菜单 3 秒 → 绿条 → 蓝条 → **画面/日志或 panic 文字**（t50 带显示驱动，第一次上机未知） |
| 2（备用） | `1-flash-slot-b.cmd` | `..\boot_v4.img` 144,691,200 B<br>sha256 `9cdfb91f…09c783d` | 绿条 → 蓝条 → 无文字（也算正常）→ 点屏幕一下出 FTS / SYS 两行 |

回到安卓：`2-back-to-android.cmd`（等价于 `fastboot --set-active=a`）。

---

## 0. 两个镜像是什么

- **`boot-t50-probe.img`**：今晚在 CI 上从头编出来的 t50 线镜像（`chipppppppps/fuxi-t50` run 42403568750）。内核是 52,518,912 B 的 `t50-mine` 系内核，payload 卷 184,549,376 B 原样塞在 boot image 里，启动参数里带 `sheng-backlight=1 fuxi-backlight=dsi sheng-fb-gpu=1 sheng-gpu-metal=1 offline-legacy-*` 这一整套显示/GPU 参数。**它没在真机上跑过**（`hardware_tested: false`），所以要你来看第一眼。
- **`boot_v4.img`**（在外层目录）：我们已经验过的 UniXNU 线镜像，能挂上 APFS 根卷、launchd 作为 PID 1 活着，但没有显示驱动，屏幕只有色条。作为「万一 t50 那张什么都不出」的对照。

两张都是 `fastboot boot`/写槽位出来的**临时镜像**：内部根卷全是内存盘，没有任何东西会写用户数据。

## 1. 进 fastboot

关机 → 按住**音量下 + 电源** → 出现小米 logo 后松手 → 插线。
电脑上 `fastboot devices` 能看到一串设备号就对了。

## 2. 双击 `1b-flash-t50.cmd`

脚本会自己检查：sha256 → 设备在不在 → `product: fuxi` → `unlocked: yes` → `partition-size:boot_b` 装不装得下。
**任何一项不对就停，一个字节都不写。** 正常时你会看到：

```
image      : ...\boot-t50-probe.img
bytes      : 12382208
sha256     : 3d811f836994815722a8c8db21b4875c5d7f4b87d5f03e7a0facdbff51ff54b5
device     : 9165fcf
product    : fuxi
slot       : a
unlocked   : yes
boot_b cap : <脚本打印的实际字节数>
```

然后它自己 `flash boot_b`、自己 `--set-active=b`。

### 可能停下来的两种情况

- **`image needs … but boot_b holds only …`** → 装不下，什么都没写。把两个数字发我。
- **`flash failed`** → 没写进去，槽位没动，安卓照常。

## 3. 手机重启进 slot b

写到 slot b 后，`fastboot reboot` 或长按电源键重启就会进 b 槽（安卓在 a 槽，完全没动）。

看屏幕，按顺序记：

1. **UniXNU 菜单**（logo + 几个选项）——它应该 3 秒后自己消失。如果一直停着不动，说明启动条目失败回退了，屏幕底部会有一行 `'UniXNU' returned: <错误码>`，**把这行拍下来**，这是最有用的信息。
2. **绿条** = DarwinBoot 把控制权交给内核；**蓝条** = 内核开始跑；品红 = 即将开 MMU。
3. 之后三种可能：
   - 出现**黑底白字的日志/进度**（t50 的 framebuffer console）→ 拍照，这是今晚最想看到的结果。
   - 出现 **panic 文字**（`panic(cpu …)` / `initproc failed to start` 之类）→ 拍照。
   - 一直卡在某条色带上不动 → 记下是哪种颜色。

## 4. 拍完照回安卓

双击 `2-back-to-android.cmd`，或手动：

```
fastboot --set-active=a
fastboot reboot
```

## 5. 兜底

如果 `1b` 那张反复 panic、你想先确认槽位切换本身没问题，就跑 `1-flash-slot-b.cmd`（boot_v4）。那张的行为我们已经知道：绿条、蓝条、无文字，点一下屏幕会打出两行 FTS/SYS 诊断。

## 6. 全程没有风险的部分

- `boot_b` 是 A/B 槽位里给 OTA 用的备用槽，写坏了只会让 b 槽起不来；
- slot a 一个字节没动，安卓永远能起；
- 镜像里没有 UFS 写驱动（t50 那张的 root 仍是 `native-ram-block` 内存盘），物理上写不到 `/data`；
- 真的想彻底回滚：`fastboot --set-active=a` 就够了。
