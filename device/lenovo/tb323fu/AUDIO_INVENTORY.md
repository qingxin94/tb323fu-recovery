# TB323FU 音频件清单（只做定位，不含任何 .ko）

这份清单记录 TB323FU 原厂固件里实际存在的音频运行件。所有内核模块仍然只在
`AERA_LOAD_VENDOR_MODULES` / `AERA_POST_DECRYPT_MODULES` 里写名字，运行时从设备
真实的 `/vendor_dlkm` 加载；`recovery/root` 下不出现 `.ko`。

## 1. vendor_dlkm 内核模块（44 个）

来源：`vendor_dlkm_a.img:/lib/modules/`

依赖件（同样只写名字、从真实分区加载）：`gpr_dlkm.ko`、`audpkt_ion_dlkm.ko`、
`sdca_registers_dlkm.ko`、`mbhc_dlkm.ko`、`fsa4480_i2c.ko`、
`fsa4480_sub_i2c.ko`、`slimbus.ko`、`hqsysfs.ko`。`qcom_aoss`、`qcom-scm`、
`mem_buf_dev`、`mdt_loader`、`qcom_pil_info`、`qcom_ramdump`、`socinfo`、
`pinctrl-msm`、`qti-regmap-debugfs`、`qcom_ipc_logging` 在 vendor_boot 里，已加入
启动列表，不塞进 recovery。

- ADSP / Q6 / 框架：`adsp_loader_dlkm.ko`、`adsp_sleepmon.ko`、`q6_dlkm.ko`、
  `q6_notifier_dlkm.ko`、`q6_pdr_dlkm.ko`、`audio_pkt_dlkm.ko`、`pinctrl_lpi_dlkm.ko`、
  `audio_prm_dlkm.ko`、`spf_core_dlkm.ko`、`frpc-adsprpc.ko`、
  `qcom_q6v5.ko`、`qcom_q6v5_pas.ko`
- LPASS / codec：`lpass_cdc_dlkm.ko`、`lpass_cdc_rx_macro_dlkm.ko`、
  `lpass_cdc_tx_macro_dlkm.ko`、`lpass_cdc_va_macro_dlkm.ko`、
  `lpass_cdc_wsa_macro_dlkm.ko`、`lpass_cdc_wsa2_macro_dlkm.ko`、
  `lpass_bt_swr_dlkm.ko`、`snd_event_dlkm.ko`
- WCD / WSA：`wcd_core_dlkm.ko`、`wcd9xxx_dlkm.ko`、`wcd939x_dlkm.ko`、
  `wcd939x_slave_dlkm.ko`、`wcd938x_dlkm.ko`、`wcd938x_slave_dlkm.ko`、
  `wcd9378_dlkm.ko`、`wcd9378_slave_dlkm.ko`、`wsa883x_dlkm.ko`、
  `wsa884x_dlkm.ko`、`wsa885x_i2c_dlkm.ko`
- 机器驱动 / 功放：`machine_dlkm.ko`、`simple_amp_dlkm.ko`、
  `aw882xx_dlkm.ko`、`spk_id_dlkm.ko`、`swr_dlkm.ko`、`swr_ctrl_dlkm.ko`、
  `swr_dmic_dlkm.ko`、`swr_haptics_dlkm.ko`、`snd-usb-audio-qmi.ko`
- 蓝牙音频：`btfmcodec.ko`、`btfm_slim_codec.ko`、`bt_fm_swr.ko`、`btpower.ko`

这些模块全部在 `vendor_dlkm_a.img` 中实测存在。它们不是 recovery ramdisk 的一
部分；AERA 只保存模块名，启动或解密后从分区加载。

## 2. stock vendor 用户态运行件

来源：`vendor_a.img`

| 路径 | 作用 |
| --- | --- |
| `/bin/agmplay` | AGM/PAL 简单播放器 |
| `/bin/agmcap` | AGM/PAL 采集器 |
| `/bin/audioadsprpcd` | AudioPD / adsprpc 守护进程 |
| `/bin/pd-mapper` | PDR / ADSP 服务定位 |
| `/bin/hw/audiohalservice.qti` | Qualcomm 音频 HAL（AIDL） |
| `/lib64/libagmipcservice.so` | AGM IPC 服务注册 |
| `/lib64/libpalipcservice.so` | PAL IPC 服务注册 |
| `/lib64/libar-pal.so` | AudioReach PAL |
| `/lib64/libagmclient.so` | AGM 客户端 |
| `/lib64/libagmmixer.so` | AGM mixer |
| `/lib64/libtinyalsa.so` | tinyalsa |
| `/lib64/libadsprpc.so` | adsprpc |
| `/lib64/libadsp_default_listener.so` | ADSP listener |
| `/lib64/libstream_contextproxy.so` | stream context proxy |
| `/lib64/libstream_common.so` | stream common |

`libagmipcservice.so` 直接依赖 `libbinder_ndk`、`libar-gsl`、`libagm` 和
`vendor.qti.hardware.agm-V1-ndk.so`；`libpalipcservice.so` 依赖
`libfmq`、`libar-pal` 和 `vendor.qti.hardware.pal-V1-ndk.so`。这些都应在设备
真实 vendor 分区中，不从 recovery 复制 `.ko`。

## 3. 配置 / 校准 / 固件

| 路径 | 作用 |
| --- | --- |
| `/etc/audio/sku_canoe/audio_module_config_primary.xml` | primary audio 配置 |
| `/etc/audio/sku_canoe/mixer_paths_canoe_mtp.xml` | mixer 路径 |
| `/etc/audio/sku_canoe/resourcemanager_canoe_mtp.xml` | PAL resource manager |
| `/etc/audio/sku_canoe/plugin_manager.xml` | PAL plugin |
| `/etc/acdbdata/canoe_mtp/` | ACDB 校准数据库 |
| `/lib/rfsa/adsp/` | ADSP 库/固件目录 |
| `/firmware/aw882xx_acf.bin` | AW882xx 功放配置 |
| `/firmware/aw22xxx_fw.bin` | AW22xxx 固件 |

音频 ACDB 在 `acdbdata/canoe_mtp`；`audio_policy_configuration.xml` 的
primary 部分在 `audio_module_config_primary.xml`，不是根目录那个总 policy。

## 3.1 已落盘的 recovery 音频组件

| 路径 | 作用 |
| --- | --- |
| `audio/aera_audio_host.c` | recovery 内 root 进程，只 `dlopen` stock `libagmipcservice.so` / `libpalipcservice.so`，调用其 `registerService()` 并校验 `vendor.qti.hardware.agm.IAGM/default`、`vendor.qti.hardware.pal.IPAL/default` |
| `audio/aera_audio_bridge.cpp` | AERA `aera-browser-audio-v1` 抽象 socket 服务；校验 UID 99090/99092，写 WAV 头到 FIFO，调用 stock `agmplay` |
| `recovery/root/init.recovery.audio.rc` | 定义 pd-mapper、audioadsprpcd、AGM host、bootstrap 四个 disabled 服务 |
| `recovery/root/system/bin/aera-audio-bootstrap` | 只读挂载 stock vendor/dsp/modem，绑定 audio/ACDB/ADSP/AW 固件，启动 ADSP 与服务 |

TB323FU stock `agmplay` 的实际用法（`strings agmplay`）：

```text
agmplay file.wav [-D card] [-d device]
            [-num_intf N iface...]
```

它从 WAV 头取采样率/声道/位深，**没有** dodge 树里用的 `-c/-r/-b`
参数，也不能把 `-i` 当作接口参数。bridge 因此只传
`-D <card> -d <device>`，需要接口时传 `-num_intf 1 <iface>`；card/device
默认 100，可用属性 `aera.audio.card`、`aera.audio.device`、
`aera.audio.interface` 覆盖。

## 4. bring-up 顺序（源码已落盘，待真机验证）

1. AERA 启动模块加载完成后，从真实 `vendor_dlkm` 按 `modules.dep` 加载上面
   44 个模块；**不把任何 `.ko` 放进 recovery ramdisk**。
2. 挂载 stock `vendor` 到 `/mnt/aera-stock/vendor`（只读），挂载 `dsp` 和
   `modem` 到 `/vendor/dsp`、`/firmware` / `/vendor/firmware_mnt`。
3. 绑定 stock 的 `/etc/audio/sku_canoe`、`/etc/acdbdata` 到 AERA 可见路径。
4. 启动 `pd-mapper`、`audioadsprpcd`，再启动本树的
   `aera-agm-service`（只调用 stock `libagmipcservice`/`libpalipcservice`
   的 `registerService`，不启动完整 `audiohalservice.qti`）。
5. 启动 AERA 的音频 bridge；播放测试优先用 stock `agmplay` 指向 speaker
   device，确认 PAL/AGM 链路后再接浏览器 PCM。

这一步没有直接照搬参考树的 `aera-palplayer`、`aera_aw_hal`、bootstrap 脚本；
它们只用于确认 stock PAL/AGM 的存在和大致顺序。要落地必须用 TB323FU 自己的
设备参数并真机验证。

## 5. 已知风险

- stock `audiohalservice.qti` 是 Android HAL，可能依赖 audioserver / audio
  policy 的 framework 侧行为；AERA recovery 里不一定完整。
- 更稳的路径是 recovery 专用 AGM/PAL host，只注册 `IAGM` / `IPAL` binder
  服务，不启动完整 audio HAL。
- `pd-mapper` / `audioadsprpcd` 依赖 ADSP remoteproc 和 modem 固件；顺序错了
  会看到 PDR lookup 失败或 ADSP 未起。
- AW882xx 功放由 PAL/ACDB 初始化；不要自己猜 I2C 寄存器，也不要把别的机型的
  `aera-aw-hal` 直接拿来用。
