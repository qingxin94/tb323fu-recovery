# TB323FU AERA 设备树静态复核报告

日期：2026-11-16  
范围：`/home/user/Doubao/chats/38454134509658626/android_device_lenovo_tb323fu-AERA`  
基线：Android 16 / AERA 16.0；boot 内核 `6.12.30-android16-5-g1750f757fabe-ab13938768-4k`；vendor_dlkm/vendor_boot 模块 `6.12.30-android16-5-maybe-dirty-4k`。

## 结论

这轮**只做了静态核查，没有完整 AOSP/AERA 编译，没有生成 recovery.img，没有刷机，也没有真机验证**。  
静态结构现在是干净的：`recovery/root` 下 **0 个 `.ko`** 和 **0 个符号链接**；vendor 模块仍然只写模块名，运行时从真实 `/vendor_dlkm`、`/system_dlkm`、vendor_boot 加载。

但**不能据此声称 recovery 可启动、触摸/GPU/解密/Wi-Fi/音频可用**。下面列出的剩余项里，有几项只有构建或真机才能确认。

## 已发现并修复的实际问题

### 1. stock HAL/守护进程没有可执行权限

`recovery/root/vendor/bin`、`recovery/root/vendor/bin/hw` 下列文件原来是 `0644`：

- `qseecomd`
- `ssgqmigd`
- `ssgqmigd64`
- `android.hardware.boot-service.qti`
- `android.hardware.gatekeeper-rust-service-qti`
- `android.hardware.security.onekeymint-service-qti`
- `vendor.qti.hardware.display.allocator-service`

init 无法执行这些文件，快启动 HAL、gatekeeper/keymint、显示 allocator 都会直接失败。  
已统一改为 `0755`；`tools/extract_stock_blobs.sh` 也补了 `chmod 0755`，避免重新提取时又变回 `0644`。

### 2. DMCTL 配置有两个问题

- `vendorsetup.sh` 导出 `AERA_USE_DMSETUP=1`，而 `BoardConfig.mk` 又 `AERA_USE_DMCTL := true`；AERA 的 `aera_build.mk` 明确禁止两者同时启用，会直接 `$(error ...)`。
- `AERA_USE_DMCTL := true` 也不够：`aera_build.mk` 的判断是 `ifeq ($(OF_USE_DMCTL),1)`，`true` 不等于 `1`，会静默不启用 DMCTL。

已移除 `AERA_USE_DMSETUP`，并把 `AERA_USE_DMCTL` 改为 `1`。

### 3. 有独立 recovery 分区的设备被误配成 virtual A/B

设备 GPT 有 `recovery_a` / `recovery_b`，`AERA_AB_DEVICE_WITH_RECOVERY_PARTITION := 1` 才是正确路径。但产品 make 继承了 `virtual_ab_ota/compression.mk`，`vendorsetup.sh` 又导出 `AERA_VIRTUAL_AB_DEVICE=1`。这会导致：

- AERA 把设备当 virtual A/B；
- `twrp.cpp` 里的 `Fox_Remove_Problematic_File()` 删除 `/system/etc/vintf/manifest/boot-service.qti.xml`，而本树正需要这个 manifest 给 `vendor.boot-qti`。

已移除该继承和导出，保留 `AERA_AB_DEVICE_WITH_RECOVERY_PARTITION := 1`。

### 4. GPU/加密用户态闭包缺 3 个 stock vendor 库

对 `recovery/root/vendor` 下 ELF 做 `readelf -d` 闭包审计后，补入：

| 库 | 使用方 | 影响 |
| --- | --- | --- |
| `libvmmem.so` | `libgralloccore.so`、`vendor.qti.hardware.display.snapalloc-impl.so` | display allocator / gralloc / snapalloc |
| `libqcbor.so` | `libQSEEComAPI.so`、`libminkdescriptor.so`、`hw/libqtigatekeeper.so` | crypto / gatekeeper |
| `libxml2.so` | `libdrmfs.so` | DRM / 加密相关服务 |

三份都来自本机 stock `vendor_a.img`，不是从别的机型搬的。`tools/extract_stock_blobs.sh` 已同步加入。

补完后，`recovery/root/vendor` 仍有 18 个 ELF `NEEDED` 库不在树内，它们都是 AERA recovery 系统库（`libc`、`liblog`、`libbase`、`libbinder_ndk`、`libutils`、`libcutils`、`libhidlbase`、`libhardware`、`libnativewindow`、`libsync`、`libunwindstack`、`libvndksupport`、`libcrypto`、`libz`、`libc++`、`libdl`、`libm`、`android.hardware.gatekeeper-V1-ndk.so`）。这些没有在真实构建产物中逐个确认，属于剩余风险。

### 5. GPU allocator 启动时机过早

`aera-graphics-allocator` 原来在 `class core` 下直接启动，可能在 `msm_kgsl.ko` / `msm_drm.ko` 加载前就运行。已改为 `disabled`，在 `twrp.modules.loaded=true` 后启动；此时启动期模块已经加载完。

### 6. `/dataext` 的 twrp.flags 缺 slotselect

`recovery.fstab` 里 `/dataext` 有 `slotselect`，但 `twrp.flags` 的 `/dataext` 行没有。设备是 A/B，`dataext_a/b` 是实际分区，已补 `slotselect`，避免 TWRP 挂错槽。

### 7. 无实现的 VINTF 声明

原来有两份 manifest 没有对应可执行文件：

- `android.hardware.health-service.qti.xml`：声明 AIDL health v4，但本树没有 `android.hardware.health-service.qti`；AERA 自带的是 health@2.x，电池/充电当前走 `/sys/class/power_supply` 和 SOCCP 读取。
- `android.hardware.fastboot-service.example.xml`：示例 manifest，本树没有对应 fastboot HAL 服务。

已移除这两份，保留 `boot-service.qti.xml`，它和 `vendor.boot-qti` 服务对应。

另外移除了 `recovery/root/vendor/etc/init/android.hardware.boot-service.qti.rc`：该 rc 会再定义一次 `vendor.boot-qti`，而本树已经在 `init.recovery.qcom.rc` 里定义同一服务；避免 init 自动导入 vendor rc 时出现重复服务定义。

### 8. 音频 bootstrap 的 ADSP 与 pd-mapper 顺序

原顺序是 `pd-mapper` → `start_adsp` → `audioadsprpcd`。`pd-mapper` 需要 DSP 侧服务定位器，ADSP 未上电时容易失败。已改为：

1. `start_adsp`
2. `aera-audio-pd-mapper`
3. `aera-audio-adsprpcd`
4. `aera-agm-service`

## 现在通过的静态检查

### `tools/verify_tree.py`

结果：**21 PASS / 0 FAIL**。新增检查覆盖：

- recovery kernel-less 配置；
- `recovery/root` 无 `.ko`；
- 启动列表包含 `spss_utils`、`spcom`、`nvt_36xxx`；
- fstab 含 `vendor_dlkm` / `system_dlkm`；
- 49 个启动模块在 vendor_dlkm/vendor_boot 中存在；
- `nvt_36xxx.ko` 的 `__versions`（7232 bytes）和 vermagic；
- boot kernel vermagic 尾部一致；
- `AERA_USE_DMCTL := 1`、没有 `AERA_USE_DMSETUP`；
- 没有 virtual A/B 误配；
- 无 health/fastboot 孤立 VINTF；
- vendor/bin 原生文件都有可执行位；
- `/dataext` 有 `slotselect`；
- `libvmmem.so`、`libqcbor.so`、`libxml2.so` 存在。

### `tools/check_audio_closure.py`

结果：**0 FAIL**。44 个音频模块在 vendor_dlkm；15 个运行件、8 个配置在 stock vendor；源码、init 服务、产品包、模块列表已接线；`recovery/root` 无 `.ko`。

### `tools/check_module_graph.py`

结果：**0 FAIL / 321 WARN**。  
321 条 WARN 主要是预期跨分区依赖（vendor_dlkm 模块依赖 vendor_boot 模块）和同名模块（如 `qcom_smd.ko` 在 vendor_boot/vendor_dlkm 都有）。这不是把 `.ko` 塞进 ramdisk，也不代表依赖缺失；`0 FAIL` 表示启动闭包、post 顺序、vendor_boot-only 误入 post 等硬错误没有出现。

### 其他

- `vendorsetup.sh`、`aera-audio-bootstrap` 均通过 `bash -n`。
- `recovery/root` 统计：109 个文件、69 个 `.so`、0 个 `.ko`、0 个符号链接；`recovery/root/vendor` 约 47 MB。
- `recovery.fstab` 25 条、`twrp.flags` 26 条，字段数和重复 mount point 的简单结构检查通过；但这不等于 AERA/TWRP 解析器验证通过。

## 剩余高风险 / 未验证项

### 构建级

1. **没有执行完整 `mka adbd recoveryimage`**，没有生成 recovery.img，不能确认：
   - `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true` 在 AERA 构建里真的让 recovery.img 的 kernel_size 为 0；
   - `TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel` 仍存在，虽然按 AOSP 变量它只影响 boot 而不是 recovery，但 AERA 构建是否完全遵守尚未验证；
   - `ALLOW_MISSING_DEPENDENCIES := true`、`BUILD_BROKEN_*` 是否掩盖了真实依赖错误。
2. `recovery.fstab` / `twrp.flags` 只做了人工和简单字段检查，没有用 AERA/TWRP 的真实解析器跑过。
3. `android.hardware.boot-service.qti.rc` 已移除，`vendor.boot-qti` 只由本树 `init.recovery.qcom.rc` 定义；构建时仍需确认没有其他 stock rc 再次定义同名服务。

### 音频

1. `audio/aera_audio_host.c` 只做了本地 Android 头 stub 的语法检查，没有在 AERA Soong / bionic 下编译链接；`AServiceManager_checkService`、`AIBinder_decStrong`、`ABinderProcess_*` 的真实签名和 ABI 未确认。
2. `audio/aera_audio_bridge.cpp` 只做了本地 `g++ -fsyntax-only`，没有在 AERA Soong 下编译。
3. stock `libagmipcservice.so` / `libpalipcservice.so` 依赖 `libbinder_ndk`、`libbase`、`libutils`、`libcutils`；当前用 AERA 系统同名库，ABI 兼容性未验证。参考 dodge 曾专门绑定 stock system 的 `libbinder.so` / `libbinder_ndk.so`，本树没有照搬；如果 AGM/PAL 服务启动即退出，这是第一优先排查点。
4. `aera-audio-bootstrap` 的以下行为都未真机验证：
   - `post.decrypt.modules=true` 的触发时机；
   - stock vendor 是否已被 AERA unmount、`/dev/block/mapper/vendor` 是否仍存在；
   - `/mnt/aera-stock/vendor` 为空目录或符号链接分支；
   - `mount -o remount,bind,ro` 在 AERA toybox 上的语义；
   - ADSP remoteproc 名称/状态路径；
   - `audioadsprpcd` 当前以 `root` 启动，而 stock 服务是 `user media group media`，可能影响 `/data/vendor/audio*` 权限。
5. `agmplay` 的 card/device/interface 实际值未确认；当前默认 `100/100`，接口为空；`agmplay` 是否接受 FIFO 形式的 WAV、WAV 头中的超大 data size 是否会被接受，也未验证。
6. stock `audioadsprpcd`/`pd-mapper` 从 `/mnt/aera-stock/vendor/bin` 启动，依赖 `LD_LIBRARY_PATH` 指向 stock vendor；这条路径在 `/vendor` 已挂载/未挂载两种分支下都未实测。

### 显示 / GPU / 触摸

1. `libvmmem` 已补，但 Adreno 840 用户态闭包、display allocator、gralloc/mapper 没有真机验证；GPU 固件 `gen80000_*` 是否被 recovery 内核正确加载未确认。
2. `AERA_SCREEN_H := 2280`、`AERA_STATUS_H := 114`、`AERA_THEME := portrait_hdpi`、`AERA_FRAMERATE := 60` 只按设备事实配置，没有实际 UI 渲染验证。
3. `nvt_36xxx` 的 `__versions`/vermagic 静态检查通过，但 `event6`/`event7`、`/proc/gesture_mode`、`/dev/lenovo_penraw` 没有在 recovery 下验证。

### 分区 / 解密 / Wi-Fi

1. `init.recovery.qcom.rc` 的 `on fs` 用 `ro.boot.bootdevice` 创建 `/dev/block/bootdevice` 符号链接；如果 AERA 没有触发 `on fs` 或属性为空，fstab 里大量 `by-name` 路径会不可用。这是 stock recovery 同样依赖的路径，但本树未实测。
2. `init.recovery.wifi.rc` 的 `b0000000.qcom,cnss-peach/fs_ready`、`chmod 222`、`write 1` 路径未确认；失败不一定阻断启动，但 Wi-Fi 不会起来。
3. `qseecomd` / gatekeeper / onekeymint 的启动条件、`libqcbor`/`libxml2` 已补，但没有真机解密/解锁验证；`AERA_INCLUDE_CRYPTO` 只是构建配置。
4. `/firmware` 的 `mounttodecrypt`、`/persist` 的 `fsflags=ro` 等 twrp.flags 标志没有实测。

### 模块加载

1. `AERA_POST_DECRYPT_MODULES` 的扁平暂存/按列表顺序 `finit_module` 行为按源码推断，没有用真机 `/proc/modules`、dmesg 验证跨分区依赖实际加载成功。
2. `AERA_LOAD_VENDOR_MODULES` 当前 49 项、`AERA_POST_DECRYPT_MODULES` 当前 76 项；启动/后解密列表本身没有重复项，`recovery/root` 没有 `.ko`。
3. 321 条 WARN 不是失败，但同名模块（`qcom_smd.ko`、`qcom_glink.ko`、`qcom_q6v5.ko` 等）在 vendor_boot/vendor_dlkm 都存在；AERA 递归查找时的选择顺序仍需真机确认。

## 建议的下一步（按风险排序）

1. 在 AERA 源码树里执行一次完整构建，先只看 `recovery.img` 的 header：`kernel_size` 必须是 0；同时确认没有因 `AERA_USE_DMSETUP`/DMCTL、virtual A/B 继承产生构建错误。
2. 构建后检查 `recovery/root/vendor/bin` 的可执行位是否在 `out` 产物中保留。
3. 真机先验证最小闭环：显示 + 触摸 + ADB + 分区挂载；再验证解密和 fastbootd。
4. 音频单独做 bring-up：先确认 `libagmipcservice`/`libpalipcservice` 能注册，再确认 `agmplay` 的 card/device，再验证 FIFO WAV；不要一上来就调浏览器音频。
5. 不要在未验证前把 `libbinder` 等 stock system 库直接覆盖到 `/system`；如果 AGM/PAL 失败，再按 AERA/dodge 的窄绑定方式只暴露 ABI 匹配的库。

## 边界说明

- 本报告没有把 Skyward/TWRP 手册里的 59 MB 底包、init 服务顺序、`"SYST"` binder 头、weaver 轮询、TWRP `restorecon` 配方搬进设备树。
- 没有把 Android 17 参考树的音频实现、模块预置方式、A17 TEE 替换文件复制过来；只核对了设备事实。
- 没有 clone、push 或改动 `https://github.com/qingxin94/tb323fu-recovery`。
- 所有新增/修改文件都在本地设备树目录；旧 zip 已过期，以当前本地目录为准。
