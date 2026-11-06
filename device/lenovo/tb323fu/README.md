# AERA Recovery Device Tree - Lenovo TB323FU

## Device Info

| Item | Value |
|---|---|
| Device | Lenovo Legion Y700 5th Gen (2026) |
| Codename | TB323FU |
| SoC | Qualcomm Snapdragon 8 Elite Gen 5 |
| Screen | 8.8" 3040×1904, 165Hz |
| Architecture | arm64 |
| Android | 16 |
| Partition | A/B + GKI |

## Build Instructions

### Prerequisites

- Ubuntu 20.04 / 22.04 (64-bit)
- At least 250GB free disk space
- At least 16GB RAM
- Git, repo, and build tools installed

### Setup Build Environment

```bash
# Install dependencies
sudo apt-get install git-core git-lfs python3 python3-pip python3-dev build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig

# Install repo
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH=~/bin:$PATH
```

### Sync AERA Source

```bash
mkdir -p ~/android/AERA_16.0
cd ~/android/AERA_16.0

repo init -u https://github.com/AERA-Recovery/android_manifest.git -b aera-16.0
repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc)
```

### Clone Device Tree

```bash
cd ~/android/AERA_16.0
git clone <your-device-tree-repo> device/lenovo/TB323FU
```

### Build

```bash
cd ~/android/AERA_16.0
source build/envsetup.sh
lunch twrp_TB323FU-bp2a-eng
mka adbd recoveryimage
```

Output: `out/target/product/TB323FU/recovery.img`

## TODO List

Before first successful build, need to verify/extract:

- [ ] Confirm SoC platform codename (SM8xxx)
- [ ] Extract and place prebuilt kernel from boot.img
- [ ] Extract recovery.fstab from stock recovery ramdisk
- [ ] Get super partition size
- [ ] Get build fingerprint from stock ROM
- [ ] Confirm kernel KMI version for Root Manager modules
- [ ] Test touch screen after first boot
- [ ] Test /data decryption
- [ ] Test backup/restore

## Flashing

```bash
# Boot to bootloader
adb reboot bootloader

# Flash recovery
fastboot flash recovery recovery.img

# Boot to recovery
fastboot reboot recovery
```
