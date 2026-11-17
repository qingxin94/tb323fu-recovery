# AERA Recovery device tree — Lenovo Legion Tab 8.8" Gen 5 (TB323FU)

联想拯救者 Y700 五代 / Lenovo Legion Tab 8.8" Gen 5  
型号 `TB323FU`，平台 Qualcomm Canoe / SM8850，GPU Adreno 840，Android 16 (SDK 36)

AERA 分支：`aera-16.0`  
设备树路径：`device/lenovo/tb323fu`

---

## 1. 这套设备树解决了什么

### 1.1 官方 recovery 没有内核，vermagic 也不是整串比较

先看官方镜像的真实布局（从 boot header 读出来的）：

| 镜像 | kernel_size | ramdisk_size |
|---|---|---|
| `boot.img` | 39,954,944 | 0 |
| `recovery.img` | **0** | 16,658,324 |

官方 recovery 是 **纯 ramdisk**；recovery 模式 = boot 分区的内核 +
recovery 分区的 ramdisk。往 `recovery.img` 里塞内核没有意义，
bootloader 不会用它。本设备树按这个布局做：

- `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true`
  → `recovery.img` 只有 ramdisk，`kernel_size = 0`，和官方一致；
- `prebuilt/kernel` 仍然保留（从 `vmlinux` 还原的 39,956,480 字节
  ARM64 Image），但只作为可选参考/调试，不参与 recovery 构建；
- **不预置任何 vendor `.ko`**。AERA 启动时挂载真实的 `/vendor`、
  `/vendor_dlkm`，从分区里的 `/lib/modules` 加载设备当前固件自带的那一份。

固件里两份 6.12.30 内核：

| 来源 | vermagic |
|---|---|
| `boot.img` 里的 kernel | `6.12.30-android16-5-g1750f757fabe-ab13938768-4k` |
| `vmlinux`（359 MB，带调试信息） | `6.12.30-android16-5-maybe-dirty-4k` |

`vendor_dlkm` / `vendor_boot` 模块的 vermagic 是 `maybe-dirty`，
但这 **不是** 加载障碍。关键在 `kernel/module/version.c` 的
`same_magic()`：

```c
int same_magic(const char *amagic, const char *bmagic, bool has_crcs)
{
    if (has_crcs) {
        amagic += strcspn(amagic, " ");
        bmagic += strcspn(bmagic, " ");
    }
    return strcmp(amagic, bmagic) == 0;
}
```

`check_modinfo()` 传入的 `has_crcs` 就是模块有没有 `__versions` 段。
只要 `CONFIG_MODVERSIONS=y` 且模块带 `__versions`，两边指针都会推到
第一个空格之后，只比较：

```
 SMP preempt mod_unload modversions aarch64
```

前面的 `6.12.30-android16-5-<localversion>-4k` 整段被跳过；ABI 兼容性由
`__versions` 里的符号 CRC 负责，不是版本号字符串。

设备侧实证：

- `nvt_36xxx.ko` 确实带 `__versions` 段（section size `0x1c40`）；
- 尾部 flags 与 boot 内核完全一致；
- CRC 来自同一份 canoe 6.12.30 内核的 ABI；
- `finit_module(fd, params, 0)` 的 flags=0，不依赖
  `MODULE_INIT_IGNORE_VERMAGIC`，实测返回 0。

反过来，6.12.94 的 TWRP 模块被拒，不是因为 6.12.30 → 6.12.94 的版本号，
而是它的 `__versions` CRC 按 6.12.94 内核计算，`module_layout` 等符号
CRC 对不上，内核报 `disagrees about version of symbol module_layout`，
用户态看到 `Exec format error`。

所以：

- **不需要换 boot 内核**；设备 boot 分区现有的 `g1750` 内核就能加载
  `maybe-dirty` 的 `vendor_dlkm` 模块；
- 也不要改模块 vermagic 字符串；改了反而会让 CRC/签名路径更乱；
- 风险边界是“内核 ABI 与模块 CRC 同源”。如果以后 OTA 仍是 6.12.30
  但改了内核 config/导出符号，CRC 会变，旧 `vendor_dlkm` 模块会被拒；
  那时只能换匹配那一版固件的 `vendor_dlkm`，改 vermagic 没有用。

### 1.2 模块加载策略

`AERA_LOAD_VENDOR_MODULES` 只写模块名，启动期加载：

- SPU / weaver：`spss_utils` 依赖闭包 9 个 + `spcom`
- 触摸：`panel_event_notifier` → `nvt_36xxx`（NT36523，Novatek）
- 显示：`drm_display_helper` → `msm_drm`，`msm_kgsl`
- USB / 触觉 / 电池 / TEE：dwc3、PHY、haptics、charger、qce50 等

Wi-Fi 不在启动期加载。`AERA_POST_DECRYPT_MODULES` 在 userdata 解密后从
`system_dlkm` / `vendor_dlkm` 暂存，等用户打开 WLAN 时才真正拉起射频
（`init.recovery.wifi.rc`）。

> `recovery/root` 里不保留 `lib/modules` 占位目录，也不放任何 `.ko` 或
> `modules.*` 索引；否则空目录会遮住 vendor_boot 的真实 `/lib/modules`。
> AERA 的 loader 在运行期只会把真实分区里的模块目录临时复制到 `/tmp` 再
> bind mount，目的是生成 `modules.load.twrp` 而不往只读分区写文件；模块
> 来源仍是设备的 `vendor_boot` / `vendor_dlkm`，不是 `recovery.img` 自带，
> 卸载后临时副本即消失。镜像内始终零 `.ko`。

### 1.3 本机事实

- 屏幕 8.8" 3040×1904，165 Hz；面板 `baldur_nt36523_csot_3k_dsc_vid`
  （NT36523 + CSOT，DSC video mode）
- 触摸 Novatek NVT-ts-spi，`novatek-mp-criteria-609F`，模块 `nvt_36xxx.ko`
- 触摸固件必须放 `recovery/root/system/etc/firmware/novatek_ts_{fw,mp}.bin`，
  与 `system_a.img` 同名文件逐字节一致（SHA-256 前 16 位分别是
  `a374ce0856f9e61b`、`1b83ad26961e9e44`）；不要放 `/vendor/firmware`
  下的 CSOT 变体。
- 亮度 `/sys/class/backlight/panel0-backlight/brightness`，面板
  `qcom,mdss-dsi-bl-max-level = <0xfff>` → `AERA_MAX_BRIGHTNESS := 4095`
- A/B + 独立 `recovery_a/recovery_b`（各 100 MiB，LUN4）
- super 20,480 MiB；LP group `qti_dynamic_partitions` 上限 21,470,642,176
- 逻辑分区全部 ext4：system/system_ext/product/vendor/vendor_dlkm/odm/system_dlkm
- userdata f2fs + `aes-256-xts:aes-256-cts:v2`，metadata f2fs
- eSE ST54L（OMAPI 暂未启用：vendor 镜像里缺 secure_element HAL/库）

---

## 2. 目录结构

```
device/lenovo/tb323fu/
├── BoardConfig.mk
├── device.mk
├── aera_tb323fu.mk          # AERA UI / 行为
├── twrp_tb323fu.mk          # 产品定义
├── AndroidProducts.mk
├── Android.mk
├── vendorsetup.sh
├── system.prop
├── audio/
│   ├── Android.bp
│   ├── aera_audio_host.c    # 只注册 AGM/PAL，不复制 stock HAL
│   └── aera_audio_bridge.cpp# AERA browser PCM socket
├── prebuilt/
│   └── kernel               # 可选；从 vmlinux 还原（39,956,480 B），不参与 recovery
├── recovery/root/
│   ├── init.recovery.qcom.rc
│   ├── init.recovery.audio.rc
│   ├── init.recovery.wifi.rc
│   ├── system/bin/aera-audio-bootstrap
│   ├── system/etc/{recovery.fstab,twrp.flags,ueventd.rc,cgroups.json,...}
│   ├── system/etc/vintf/manifest/*.xml
│   └── vendor/              # 仅 GPU/HAL/固件等用户态 blob，没有 .ko
└── tools/
    ├── extract_stock_blobs.sh
    ├── make_kernel_image.py
    ├── pack_boot.sh
    ├── check_audio_closure.py
    ├── check_module_graph.py
    └── verify_tree.py
```

`recovery/root/vendor` 约 42 MB，是 Adreno 840 的 EGL/GLES/LLVM、gralloc/mapper、
display allocator、gatekeeper/keymint、GPU 固件和 Wi-Fi 配置；内核模块不在其中。

---

## 3. 构建

```bash
repo init -u https://github.com/AERA-Recovery/android_manifest -b aera-16.0
repo sync -j8

# 把本设备树放到 device/lenovo/tb323fu
cp -a android_device_lenovo_tb323fu-AERA device/lenovo/tb323fu

source build/envsetup.sh
lunch twrp_tb323fu-bp2a-eng
mka adbd recoveryimage
```

产物：`out/target/product/tb323fu/recovery.img`

- recovery 分区 100 MiB；`recovery.img` 的 `kernel_size = 0`，只装 lz4 ramdisk，和官方布局一致。40 MB 内核不占 recovery 空间。
- `vendorsetup.sh` 已设置 `AERA_DELETE_MAGISK_ADDON=1`，避免 ramdisk 超限。
- 如果构建时提示 ramdisk 过大，优先删 `recovery/root/vendor/lib64/libllvm-qgl.so`
  或减少 `tensorflowlite` 类非必需库；不要删 GPU 固件。

内核可以重新生成（可选）：

```bash
python3 tools/make_kernel_image.py \
    /path/to/TB323_ZUXOS_2.0.12.088_Tool/image/vmlinux \
    prebuilt/kernel
```

校验输出：

```bash
python3 - <<'PY'
d=open('prebuilt/kernel','rb').read()
print(len(d), hex(len(d)), d[0x38:0x3c])
PY
# 期望 39956480 0x261b000 b'ARM\x64'
```

功能覆盖与缺口见 [`FUNCTIONAL_COVERAGE.md`](FUNCTIONAL_COVERAGE.md)；音频件清单见 [`AUDIO_INVENTORY.md`](AUDIO_INVENTORY.md)。

### 3.0 音频闭包检查

```bash
python3 tools/check_audio_closure.py \
    --vendor /path/to/vendor_a.img \
    --vendor-dlkm /path/to/vendor_dlkm_a.img
```

检查 44 个音频模块、15 个 stock 运行件、ACDB/audio 配置是否在原厂镜像中，
并确认 `recovery/root` 下没有 `.ko`。它还会核对音频源码、init 服务、产品包和
`AERA_POST_DECRYPT_MODULES` 的接线。这只检查“件在不在、名字对不对”，不启动
音频服务。

recovery 侧音频不是把 HAL 搬进来：`aera-audio-service` 只 `dlopen` stock
`libagmipcservice.so` / `libpalipcservice.so` 的 `registerService()`，
`aera-audio-bridge` 只把 AERA 浏览器 PCM 写进 FIFO 后交给 stock `agmplay`。
两者都从已安装的 vendor 分区取件；内核模块仍只按名字从真实 `vendor_dlkm`
加载。

### 3.1 跨分区 / 跨文件夹依赖

模块依赖不能只看文件名，也不能靠手写顺序蒙。AERA 的启动期 loader 会把
vendor_boot / vendor_dlkm 的整个目录复制到 tmpfs，并用 `modules.dep` 解析依赖；
但 `AERA_POST_DECRYPT_MODULES` 的 post-decrypt loader 只把**列出的模块**扁平
暂存到 `/tmp/post_decrypt_modules`，然后按列表顺序 `finit_module`，不会从
vendor_boot 补依赖。因此规则是：

- vendor_boot 里的依赖（例如 `qcom_aoss`、`qcom-scm`、`smem`、`mem_buf_dev`、
  `pinctrl-msm`、`qti-regmap-debugfs`）必须放进 `AERA_LOAD_VENDOR_MODULES`，
  在解密前就加载；
- vendor_dlkm / system_dlkm 里的依赖可以放进 `AERA_POST_DECRYPT_MODULES`，但
  必须排在依赖它的模块之前；
- 跨文件夹的模块由 `Stage_Post_Decrypt_Modules` 递归查找，但它会扁平复制；
  若两个目录存在同名 `.ko`，不能靠猜，必须先解决歧义。

用下面脚本按真实 `modules.dep` 做闭包检查：

```bash
python3 tools/check_module_graph.py \
    --vendor-dlkm /path/vendor_dlkm_a.img \
    --system-dlkm /path/system_dlkm_a.img \
    --vendor-boot-modules /path/vendor_ramdisk/lib/modules
```

它会检查 post 依赖是否在 startup 闭包中、顺序是否反了、是否有只存在于
vendor_boot 却被放进 post 的模块，以及同名/跨目录歧义。当前 TB323FU 的结果是
**0 FAIL**；跨分区 WARN 主要是 vendor_dlkm 的 `modules.dep` 指向 vendor_boot
依赖，属于预期，不是把 `.ko` 塞进 recovery。

### 3.2 静态审计

不依赖真机，先检查这套树的关键不变量：

```bash
python3 tools/verify_tree.py \
    --vendor-dlkm /path/to/vendor_dlkm_a.img \
    --vendor-boot-modules /path/to/vendor_ramdisk/lib/modules \
    --boot-kernel /path/to/unpacked/boot/kernel
```

期望结果：kernel-less recovery、recovery/root 无 `.ko`、无 `modules.*`、
无 `lib/modules` 占位、启动列表含
`spss_utils.ko`/`spcom.ko`/`nvt_36xxx.ko`、49 个启动模块在
vendor_dlkm / vendor_boot 存在、`nvt_36xxx.ko` 带 `__versions`、模块与 boot
内核 vermagic 尾部一致。

重新提取用户态 blob（可选，刷机包路径按实际改）：

```bash
tools/extract_stock_blobs.sh \
    /path/to/work/lp_full/vendor_a.img \
    .
```

---

## 4. 刷入与验证

前提：bootloader 已解锁；AERA 需要关闭 AVB 校验（按 AERA 官方说明处理
`vbmeta`）。

### 4.1 刷 kernel-less recovery

```bash
fastboot flash recovery_a recovery.img
fastboot flash recovery_b recovery.img
fastboot reboot recovery
```

`recovery.img` 的 header 应该是 `kernel_size = 0`、`ramdisk_size > 0`，
和官方一致。可以在构建后检查：

```bash
python3 - <<'PY'
import struct
d=open('out/target/product/tb323fu/recovery.img','rb').read(64)
print('kernel', struct.unpack('<I',d[8:12])[0],
      'ramdisk', struct.unpack('<I',d[12:16])[0])
PY
```

Recovery 模式用的是 boot 分区内核；**不要为了 vermagic 去刷 boot**。
当前 boot 内核即使是 `g1750` 也能通过 `__versions` CRC 加载
`maybe-dirty` 的 vendor 模块。

### 4.2 验证内核校验路径

```bash
adb shell uname -a
adb shell 'zcat /proc/config.gz 2>/dev/null | grep -E "CONFIG_MODVERSIONS|CONFIG_MODULE_FORCE_LOAD"'
adb shell 'dmesg | grep -iE "disagrees about version|module_layout|version magic"'
```

正常应看到：

- `CONFIG_MODVERSIONS=y`；
- `uname -a` 是 `6.12.30-android16-5-g1750...`（不是问题）；
- 成功加载的模块不会出现 `disagrees about version of symbol ...`；
- `cat /proc/modules | grep nvt_36xxx` 能看到模块。

### 4.3 如果出现 `disagrees about version of symbol module_layout`

这不是 vermagic 字符串的问题，而是模块 `__versions` 的 CRC 与当前
boot 内核的导出符号 CRC 不同源。处理方式只有：

- 换回与当前 boot 内核同源的 `vendor_dlkm`；或
- 刷入与当前 `vendor_dlkm` 同源的那一版 boot 内核（如果你确实有），

**不要**改模块里的 vermagic 字符串；改字符串不会改 CRC，也绕不过
`check_version()`。当前 ZUXOS 2.0.12.088 这一套应是同源构建，正常不会
触发这条。

### 4.4 `prebuilt/kernel` 是可选件

`prebuilt/kernel` 不参与 `recovery.img` 构建，正常刷机不需要它。
只有在你想主动做“换内核启动”实验时，才用 `tools/pack_boot.sh` 打包；
这不是本适配的必需步骤。`fastboot boot` 支持与否因 bootloader 而异，
失败不会改分区。

## 5. 验证模块是否来自分区

进入 AERA 后：

```bash
adb shell
cat /proc/modules | grep -E 'nvt_36xxx|spss_utils|spcom|msm_drm|msm_kgsl'
ls -l /vendor_dlkm/lib/modules/nvt_36xxx.ko
```

AERA 日志里应能看到：

```
Checking mounted /vendor
Checking mounted /vendor_dlkm
Checking directory: /vendor/lib/modules
Checking directory: /vendor_dlkm/lib/modules
Loading module .../nvt_36xxx.ko
```

如果看到 `version magic ... should be ...`，那不是 localversion 差异
（`__versions` 存在时前缀会被跳过），而是模块缺少 `__versions`、尾部
flags 或架构不一致；不要靠刷 boot 解决，先查模块的 `__versions` 和
`modinfo vermagic`。

---

## 6. 已知风险 / 待实测

1. **recovery 没有内核，靠 boot 分区内核**：这是官方布局，不是缺陷。
   `g1750` 内核可以通过 `__versions` CRC 加载 `maybe-dirty` 模块，
   不要为了版本号去刷 boot；只有 `dmesg` 报 `disagrees about version
   of symbol ...` 才是 CRC 不同源，按 §4.3 处理。
2. **100 MiB 上限**：recovery 不含内核，只有 vendor blob 42 MB + AERA
   ramdisk；构建后仍请检查 `recovery.img` 实际大小，超限先裁非必需用户态库。
3. **解密**：`AERA_INCLUDE_CRYPTO/FBE` 已开，`qseecomd`、gatekeeper、
   keymint、`libQSEEComAPI` 等已放入 ramdisk；仍建议先在未加密 data 上
   验证触摸/显示/刷机，再测试 FBE。
4. **WLAN**：`qca_cld3_peach_v2` 链在解密后暂存，`fs_ready` 节点为
   `b0000000.qcom,cnss-peach`；WLAN 固件本体在 modem 分区，若
   `wlan0` 不出现，先确认 `/vendor/firmware_mnt` 已挂载。
5. **屏幕方向**：当前 `AERA_THEME := landscape_hdpi`、`AERA_SCREEN_H := 1904`；
   若 UI 旋转 90°，改成 `portrait_hdpi` / `3040`。
6. **亮度**：面板 `bl-max-level=0xfff`，默认 2047；若实际
   `/sys/class/backlight/panel0-backlight/max_brightness` 不是 4095，
   按实际值改 `AERA_MAX_BRIGHTNESS`。
7. **指纹/人脸**：本版未启用 `AERA_SUPPORT_FINGERPRINT`，后续可加。

---

## 7. 参考

- AERA manifest: https://github.com/AERA-Recovery/android_manifest
- AERA recovery: https://github.com/AERA-Recovery/android_bootable_recovery
- 参考设备树: OnePlus 13 `dodge`、OnePlus 15 `infiniti`
- 固件: `TB323_ZUXOS_2.0.12.088_Tool`（ZUXOS 2.0.12.088 / Android 16）
- 4PDA 上有现成 TB323FU 设备树/TWRP（需登录），本树未使用其二进制；
  仅作为可行性参考。
