# AERA Recovery — Lenovo Legion Y700 (tb323fu / TB323FU)

GitHub Actions 自动编译 AERA Recovery 设备树仓库。

## 设备信息

| 项目 | 值 |
|---|---|
| 设备代号 | tb323fu |
| 机型 | Lenovo Legion Y700 2025 (TB323FU) |
| SoC | Qualcomm SM8850 (Snapdragon 8 Elite Gen 5, platform: canoe) |
| Android | 16 |
| 内核 | 6.12.30-android16-5 |
| 面板 | Novatek NT36523 触控 + CSOT 3K DSC 屏（横版） |
| Build 指纹 | `Lenovo/TB323FU/TB323FU:16/BQ2A.250831.001-BP2A.250605.031.A3/10.026.260205C:user/release-keys` |

## 使用方法

1. 把这个仓库推送到你的 GitHub 账号下
2. Actions 页面会自动开始编译
3. 编译完成后，在 Actions 运行记录里下载 `tb323fu-recovery-img` artifact
4. 得到 `recovery.img`，用 fastboot 刷入

```bash
fastboot flash recovery_a recovery.img
fastboot flash recovery_b recovery.img
fastboot reboot recovery
```

## 手动触发

如果 push 后没有自动编译，去 Actions 页面手动点 "Run workflow"。

## 已知问题与状态

| 项目 | 状态 | 说明 |
|---|---|---|
| 编译内存 | ✅ 已配置 | Actions runner 15.6GB 内存，已加 16GB swap + 降并行度 -j2 |
| 电池电量显示 | ✅ 已配置 | 按 SM8850 标准 Qualcomm power_supply 路径配置 |
| 屏幕分辨率 | ⚠️ 待实测 | 横版平板，面板时序候选含 2160x5120 / 5120x2160，实际物理分辨率待刷机确认 |
| 触摸屏 | ⚠️ 待实测 | Novatek NT36523 驱动随内核加载，需刷入后确认；无触摸可用音量键+电源键操作 |
| 预编译 kernel | ⚠️ 待补充 | 需从原厂 boot/vendor_boot 提取 Image + dtb 并上传到 Release |

## 无触摸时的操作方式

如果 recovery 触摸不可用，可用实体键操作：
- **音量上/下**：移动光标
- **电源键**：确认/选择
