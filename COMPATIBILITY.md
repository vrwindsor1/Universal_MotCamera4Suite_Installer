# Universal MotCamera4 Suite — Device Compatibility List & Guide

<p align="center">
  <img src="assets/motcamera4_logo.png" width="96" height="96" alt="MotCamera4 Logo">
  <br>
  <a href="README.md"><img src="https://img.shields.io/badge/Installer-Documentation-blue?style=flat-square" alt="README"></a>
  <a href="reports/"><img src="https://img.shields.io/badge/Device-Reports%20Folder-purple?style=flat-square" alt="Device Reports"></a>
  <a href="https://github.com/vrwindsor1/Universal_MotCamera4Suite_Installer/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Submit-Compatibility%20Report-success?style=flat-square&logo=github" alt="Submit Report"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=flat-square" alt="License"></a>
</p>

This document tracks community-verified Motorola devices, tested custom ROMs, compiler methods, and hardware sensor functionality for the [Universal MotCamera4 Suite Installer](README.md).

> [!NOTE]
> Every entry in this matrix is populated strictly from confirmed user reports. No speculative, untested, or unverified hardware entries are listed.

---

## Quick Links

- 🏠 **[Installer Documentation & Source (README)](README.md)**
- 📂 **[Individual Device Reports Directory (reports/)](reports/)**
- 📝 **[Submit a Compatibility Report (GitHub Form)](https://github.com/vrwindsor1/Universal_MotCamera4Suite_Installer/issues/new?template=compatibility_report.yml)**
- 🐛 **[Report a Tool Bug / Script Issue](https://github.com/vrwindsor1/Universal_MotCamera4Suite_Installer/issues/new?template=bug_report.yml)**

---

## Result Classifications

Every tested device outcome is classified into one of five categories:

| Status Badge | Result Category | Definition |
| :---: | :--- | :--- |
| 🟢 | **`Works Perfectly`** | Full success. Moto Camera 4 launches cleanly; all rear physical sensors (Main, Ultrawide, Macro, Telephoto), front selfie, and video recording function without issues. |
| 🟡 | **`Mostly Working`** | Partial success. The app launches and photos can be taken, but specific auxiliary sensors or advanced modes (e.g., slow motion, ultrawide switching) do not work. |
| 🔴 | **`App Crashes`** | Sideload finishes and the app is installed, but the app immediately crashes, freezes, or force-closes upon launch. |
| ⚪ | **`App Missing`** | Sideload completes, but after booting the ROM, Moto Camera 4 is completely absent from the app drawer and system partition. |
| ⛔ | **`Won't Boot`** | The flashed package caused the device to bootloop, dump into recovery, or hang on the boot animation (softbrick). |

---

## Device Compatibility Matrix

Click any device or report link in the table below to view its dedicated test history, custom ROMs, and sensor breakdowns in the [`reports/`](reports/) directory:

<!-- SUMMARY_TABLE_START -->
| Device Name | Codename | Model # | Status | Reports |
| :--- | :--- | :--- | :---: | :---: |
| [**Moto G Stylus 5G (2023)**](reports/genevn.md) | `genevn` | `XT2315-1` | 🟢 Works Perfectly | [1 Report ➔](reports/genevn.md) |
<!-- SUMMARY_TABLE_END -->

---

## Step-by-Step Guide to Testing & Reporting

Follow this walkthrough to safely test the camera suite on your custom ROM and submit a standardized report.

### Step 1: Pre-Testing Safety Checklist
> [!CAUTION]
> Always create a backup before flashing!
> 1. Reboot to your custom recovery (Lineage Recovery, TWRP, OrangeFox).
> 2. Perform a backup or verify you have the bootable ROM zip handy in case you need to restore.
> 3. Verify your device is on an AOSP-based custom ROM running **Android 13 or newer**.
> 4. **Device Stock Lifecycle:** The device likely needed official stock **Android 13 or 14** somewhere in its official lifecycle to have the `com.motorola.camera3` v9+ suite. Other device generations are welcome to be tested, but are unverified.
> 5. **Version Independence:** Your stock firmware version **does not need to match** your custom ROM's Android version. You can extract from stock Android 13 or 14 and flash onto newer custom ROMs (e.g. LineageOS Android 15, 16, 17+).

### Step 2: Acquire Stock Firmware
1. Download the official stock firmware for your exact device model from:
   - Motorola Rescue and Smart Assistant (RSA) tool (`C:\ProgramData\RSA\Download\RomFiles\`)
   - Trusted Motorola firmware repositories (e.g., mirrors.lolinet.com)
2. Locate the folder with `super.img_sparsechunk.*`, partition images (`product.img`, `system_ext.img`), or stock archive.

### Step 3: Run the Compiler
Select the script matching your environment:

- **Linux (`.sh`):**
  ```bash
  chmod +x compile_recovery_package_linux.sh
  ./compile_recovery_package_linux.sh "/path/to/firmware"
  ```
- **Windows PowerShell (`.ps1`):**
  ```powershell
  .\compile_recovery_package_windows.ps1 -FirmwarePath "C:\path\to\firmware"
  ```
- **Windows Batch Launcher (`.bat`):**
  Double-click `compile_recovery_package_windows.bat` and enter the firmware directory path.

Verify that the compiler finishes with:
```text
[SUCCESS] Flashable recovery zip created at: output/MotoCamera4_<device>_Recovery_Installer.zip
```

### Step 4: Sideload in Recovery
1. Reboot your phone into **Recovery Mode**.
2. Select **Apply Update** $\rightarrow$ **Apply from ADB** (or **ADB Sideload** in TWRP/OrangeFox).
3. Connect USB and run:
   ```bash
   adb sideload output/MotoCamera4_<device>_Recovery_Installer.zip
   ```
4. If recovery flags a signature prompt, select **Install anyway**.
5. Reboot to system.

### Step 5: Post-Boot Verification Procedure
Check each of the following points:

1. **App Installed?**
   - Check if **Moto Camera 4** (and companion photo services) appear in your launcher/app drawer.
   - If missing $\rightarrow$ Result is **`App Missing`**.
2. **App Launches?**
   - Tap the camera icon. Does the camera viewfinder load, or does it instantly crash / freeze?
   - If it crashes on open $\rightarrow$ Result is **`App Crashes`**.
3. **Sensor Switching:**
   - **Main Sensor (1x):** Can you capture full-resolution photos?
   - **Ultrawide (0.5x):** Does switching to wide angle work?
   - **Macro:** Can you switch to macro mode?
   - **Front Camera:** Does the selfie camera work?
   - If some switch but others crash/black-screen $\rightarrow$ Result is **`Mostly Working`**.
   - If every sensor and mode works $\rightarrow$ Result is **`Works Perfectly`**.
4. **Phone Boot:**
   - If the device got stuck on the bootloader/logo $\rightarrow$ Result is **`Won't Boot`**.

### Step 6: Capturing Logs (For Crashes or Missing App)
If the app crashed (`App Crashes`) or your phone had issues, capture logs via ADB:
```bash
# Capture Camera and Runtime crash logs:
adb logcat -d -s AndroidRuntime:E CameraService:E libc:E > camera_crash.log

# Or pull the recovery log if sideload had errors:
adb pull /tmp/recovery.log recovery.log
```

---

## How to Submit Your Report

### Use the GitHub Issue Form
Click the link below to open a pre-formatted web form:

👉 **[Open Compatibility Report Form](https://github.com/vrwindsor1/Universal_MotCamera4Suite_Installer/issues/new?template=compatibility_report.yml)**

Fill in the required fields:
- **Compiler Method:** `.sh`, `.ps1`, or `.bat`
- **Device Marketing Name:** (e.g., `Moto G Stylus 5G (2023)`)
- **Device Codename:** (e.g., `genevn`)
- **Device Model #:** (e.g., `XT2315-1`)
- **Test Result:**
  - `Works Perfectly`
  - `Mostly Working`
  - `App Crashes`
  - `App Missing`
  - `Won't Boot`
- **Custom ROM & Android Version:** (e.g., `LineageOS 21 (Android 14)`)
- **Sensor Breakdown & Logs:** Any relevant details or crash logs.
