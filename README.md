# Universal MotCamera4 Suite Installer

<p align="center">
  <img src="assets/motcamera4_logo.png" width="128" height="128" alt="MotCamera4 Logo">
  <br>
  <a href="https://deepmind.google"><img src="https://img.shields.io/badge/Pair%20Programmed%20With-Google%20DeepMind%20Antigravity-blueviolet?style=flat-square&logo=google" alt="Pair Programmed With Google DeepMind Antigravity"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=flat-square" alt="License"></a>
</p>

Extracts Motorola Camera 4, companion AI services, vendor hardware abstraction layers (HALs), and multi-camera tuning libraries directly from Motorola stock firmware and packages them into a flashable zip for recovery sideload on custom ROMs.

> [!NOTE]
> **No Proprietary Files Hosted**:  
> This repository contains **no copyrighted binaries, proprietary firmware blobs, or Motorola APKs**. All device-specific camera packages and HAL services are dynamically harvested on your local machine directly from official Motorola stock firmware provided by the user.

> [!IMPORTANT]
> **AI Disclaimer**:  
> This project was developed and vibe coded with the assistance of **Google DeepMind Gemini 3.8 Flash (High / Thinking)**. While extraction and packaging logic include automated safety checks, flashing modifications to custom ROMs carries inherent risks. Always ensure you have a current recovery backup of your device before installing.

> [!TIP]
> **License**:  
> This project is free, open-source software released under the [Apache License 2.0](LICENSE).

---

## Compatibility

- **Custom ROMs:** LineageOS, crDroid, PixelOS, Evolution X, or any AOSP-based custom ROM.
- **Android Versions:** Android 13+ (Android 13, 14, 15+).
- **Firmware Requirement:** Official Motorola stock firmware for your device matching your Android version (no specific build required, as long as it is official stock Android 13+).
- **Recovery:** Any custom recovery supporting sideload or zip flashing (Lineage Recovery, TWRP, OrangeFox).
- **OTA Survival:** Includes an `addon.d` survival script so camera components persist across custom ROM updates without needing to re-flash.
- **Installation Timing:** Can be installed at any time—no data wipe or first-boot installation required.

---

## Devices

### Tested Devices
Verified to compile, sideload, and run with full multi-camera functionality:
- **Moto G Stylus 5G (2023)** (`genevn`)

### Untested (Expected Compatible)
Any Motorola device running official stock Android 13+ with the Moto Camera 4 suite should be compatible, including:

- **Moto G Series:**
  - Moto G Stylus 5G (2022, 2024 `manaus`)
  - Moto G 5G, Moto G Power 5G
  - Moto G84 5G, Moto G73 5G, Moto G54 5G, Moto G53 5G, Moto G34 5G
  - Moto G200, Moto G100
- **Motorola Edge Series:**
  - Edge 50 Ultra / Pro / Fusion
  - Edge 40 / 40 Pro (`rtwo`) / 40 Neo
  - Edge 30 / 30 Pro / 30 Ultra / 30 Fusion / 30 Neo
  - Edge+ (2022 / 2023)
- **Motorola Razr Series:**
  - Razr 50 / 50 Ultra (Razr+ 2024)
  - Razr 40 / 40 Ultra (Razr+ 2023)
  - Razr (2022)
- **ThinkPhone & Other Series:**
  - Lenovo ThinkPhone by Motorola (`bronco`)
  - Motorola Defy 2

---

## Installation

### 1. Prerequisites
- Official stock firmware for your Motorola device (downloaded via Motorola Rescue and Smart Assistant (RSA), mirrors.lolinet.com, or firmware dumps). The compiler accepts:
  - A folder containing `super.img_sparsechunk.*`
  - A stock firmware `.zip` archive
  - Extracted partition images (`product.img`, `system_ext.img`, etc.)
  - A pre-extracted folder structure (`product/`, `system_ext/`, etc.)
- A computer running Linux or Windows.

#### Linux System Dependencies
Ensure dynamic partition and filesystem extraction tools are installed:

| Distribution | Command |
| :--- | :--- |
| **Fedora / RHEL** | `sudo dnf install android-tools erofs-utils zip curl python3` |
| **Ubuntu / Debian** | `sudo apt install android-sdk-libsparse-utils erofs-utils zip curl python3` |
| **Arch Linux** | `sudo pacman -S android-tools erofs-utils zip curl python` |

---

### 2. Build the Recovery Package

#### Linux
```bash
chmod +x compile_recovery_package_linux.sh

# Interactive mode (prompts for firmware path):
./compile_recovery_package_linux.sh

# Non-interactive CLI mode:
./compile_recovery_package_linux.sh "/path/to/stock_firmware"
```

#### Windows
- **Option A:** Double-click `compile_recovery_package_windows.bat` and enter your firmware directory when prompted.
- **Option B (PowerShell):**
  ```powershell
  .\compile_recovery_package_windows.ps1 -FirmwarePath "C:\path\to\stock_firmware"
  ```

The generated flashable zip will be placed in the `output/` directory:
```text
output/MotoCamera4_<device>_Recovery_Installer.zip
```

---

### 3. Flash via Recovery Sideload
1. Reboot your phone into **Recovery Mode** (Lineage Recovery, TWRP, or OrangeFox).
2. Select **Apply Update** $\rightarrow$ **Apply from ADB** (or **Advanced** $\rightarrow$ **ADB Sideload** in TWRP/OrangeFox).
3. Connect the phone to your computer via USB and run:
   ```bash
   adb sideload output/MotoCamera4_<device>_Recovery_Installer.zip
   ```
4. If recovery warns that signature verification failed, select **Install anyway** (expected for custom packages).
5. Once installation finishes, select **Reboot system now**.

---

## Credits & Acknowledgments

- **Lead Developer:** [vrwindsor1](https://github.com/vrwindsor1)
- **AI Pair Programming & Architecture:** Built in collaboration with Google DeepMind's **Antigravity** (powered by Gemini 3.8 Flash High).
