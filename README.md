# Universal MotCamera4 Suite Installer

<p align="center">
  <img src="assets/motcamera4_logo.png" width="128" height="128" alt="MotCamera4 Logo">
  <br>
  <a href="https://deepmind.google"><img src="https://img.shields.io/badge/Pair%20Programmed%20With-Google%20DeepMind%20Antigravity-blueviolet?style=flat-square&logo=google" alt="Pair Programmed With Google DeepMind Antigravity"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=flat-square" alt="License"></a>
</p>

Extracts Motorola Camera components for devices using the MotCamera4 suite (`com.motorola.camera3` v9+), companion AI services, vendor hardware abstraction layers (HALs), and multi-camera tuning libraries directly from Motorola stock firmware and packages them into a flashable zip for recovery sideload on custom ROMs (Android 13+).

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

- **Target Camera Suite:** **Moto Camera 4** (`com.motorola.camera3` version 9.x+).
- **Device Lifecycle Requirement:** The target device likely needs to have officially supported stock **Android 13 or Android 14** somewhere in its official lifecycle (either released with it or received as an official update) to contain the modern MotCamera4 suite and compatible camera HAL stack.
  > [!NOTE]
  > This has not been verified across every Motorola generation. Users with devices running earlier or later stock versions are welcome to test and submit compatibility reports!
- **Custom ROMs:** LineageOS, crDroid, PixelOS, Evolution X, or any AOSP-based custom ROM.
- **Custom ROM Android Versions:** Android 13+ (Android 13, 14, 15, 16+).
- **Firmware Requirement:** Official Motorola stock firmware for your device matching your target Android version (no specific build required, as long as it contains the MotCamera4 suite).
- **Recovery:** Any custom recovery supporting sideload or zip flashing (Lineage Recovery, TWRP, OrangeFox).
- **OTA Survival:** Includes an `addon.d` survival script so camera components persist across custom ROM updates without needing to re-flash.
- **Installation Timing:** Can be installed at any time—no data wipe or first-boot installation required.

> [!TIP]
> 📋 **Device Compatibility Matrix & Testing Guide**:  
> We maintain a dedicated compatibility matrix and detailed testing walkthrough in [**COMPATIBILITY.md**](COMPATIBILITY.md).  
> 👉 **[View the Device Compatibility List & Guide](COMPATIBILITY.md)**

---

## Compatibility Reports

Tested this installer on your Motorola device? Help the community by reporting your test outcome!

You can submit your findings directly using our [GitHub Compatibility Report Form](https://github.com/vrwindsor1/Universal_MotCamera4Suite_Installer/issues/new?template=compatibility_report.yml).

### Report Fields Checklist
When filling out the report, you will provide:
1. **Compiler Method:**
   - `.sh` (Linux Shell Script)
   - `.ps1` (Windows PowerShell Script)
   - `.bat` (Windows Batch Launcher)
2. **Device Information:**
   - **Device Name:** Official marketing name (e.g., `Moto G Stylus 5G (2023)`)
   - **Codename:** Hardware board codename (e.g., `genevn`)
   - **Model Number:** Specific SKU / hardware model (e.g., `XT2315-1`)
3. **Test Result:**
   - `Works Perfectly`: All camera sensors (main, ultrawide, macro, selfie) and video recording function without issues.
   - `Mostly Working`: The app opens, but only specific lenses or camera modes work.
   - `App Crashes`: The app crashes, force-closes, or hangs on launch.
   - `App Missing`: The ROM boots normally, but Moto Camera 4 is not installed or visible.
   - `Won't Boot`: Device enters a bootloop, softbricks, or dumps into recovery.
4. **Environment:** Custom ROM name/version (e.g., LineageOS 21) and stock firmware build extracted from.

👉 **[Submit a Device Compatibility Report](https://github.com/vrwindsor1/Universal_MotCamera4Suite_Installer/issues/new?template=compatibility_report.yml)**  
📖 **[View the Full Compatibility Matrix & Walkthrough in COMPATIBILITY.md](COMPATIBILITY.md)**

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
