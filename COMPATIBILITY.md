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

Every tested device outcome is classified into one of the following categories:

| Status Badge | Result Category | Definition |
| :---: | :--- | :--- |
| 🟢 | **`Works Perfectly`** | Full success. Moto Camera 4 launches cleanly; all rear physical sensors (Main, Ultrawide, Macro, Telephoto), front selfie, and video recording function without issues. |
| 🟡 | **`Mostly Working`** | Partial success. The app launches and photos can be taken, but specific auxiliary sensors or advanced modes (e.g., slow motion, ultrawide switching) do not work. |
| 🔴 | **`App Crashes`** | Sideload finishes and the app is installed, but the app immediately crashes, freezes, or force-closes upon launch. |
| ⚪ | **`App Missing`** | Sideload completes, but after booting the ROM, Moto Camera 4 is completely absent from the app drawer and system partition. |
| ⛔ | **`Won't Boot`** | The flashed package caused the device to bootloop, dump into recovery, or hang on the boot animation (softbrick). |
| ❔ | **`Untested`** | No community-verified test reports submitted yet, but this device is expected by the developer to be working based on its stock MotCamera4 architecture. |

---

## Device Compatibility Matrix

Click any device or report link in the table below to view its dedicated test history, custom ROMs, and sensor breakdowns in the [`reports/`](reports/) directory:

<!-- SUMMARY_TABLE_START -->
| Device Name | Codename | Model # | Status | Reports |
| :--- | :--- | :--- | :---: | :---: |
| [**Moto G Stylus 5G (2023)**](reports/genevn.md) | `genevn` | `XT2315-1` | 🟢 Works Perfectly | [1 Report ➔](reports/genevn.md) |
| [**Lenovo ThinkPhone by Motorola**](reports/bronco.md) | `bronco` | `XT2309` | ❔ Untested | [0 Reports ➔](reports/bronco.md) |
| [**Moto G (2023)**](reports/penangp.md) | `penangp` | `XT2313` | ❔ Untested | [0 Reports ➔](reports/penangp.md) |
| [**Moto G Power 5G (2023)**](reports/cebu.md) | `cebu` | `XT2311` | ❔ Untested | [0 Reports ➔](reports/cebu.md) |
| [**Moto G Stylus 5G (2022)**](reports/milanf.md) | `milanf` | `XT2215` | ❔ Untested | [0 Reports ➔](reports/milanf.md) |
| [**Moto G Stylus 5G (2024)**](reports/manaus.md) | `manaus` | `XT2419` | ❔ Untested | [0 Reports ➔](reports/manaus.md) |
| [**Moto G34 5G**](reports/fog.md) | `fog` | `XT2363` | ❔ Untested | [0 Reports ➔](reports/fog.md) |
| [**Moto G53 5G**](reports/penang.md) | `penang` | `XT2335` | ❔ Untested | [0 Reports ➔](reports/penang.md) |
| [**Moto G54 5G**](reports/cancunf.md) | `cancunf` | `XT2343` | ❔ Untested | [0 Reports ➔](reports/cancunf.md) |
| [**Moto G73 5G**](reports/devon.md) | `devon` | `XT2237` | ❔ Untested | [0 Reports ➔](reports/devon.md) |
| [**Moto G84 5G**](reports/bangkk.md) | `bangkk` | `XT2347` | ❔ Untested | [0 Reports ➔](reports/bangkk.md) |
| [**Motorola Edge (2022) / Edge 30**](reports/dubai.md) | `dubai` | `XT2203`, `XT2205` | ❔ Untested | [0 Reports ➔](reports/dubai.md) |
| [**Motorola Edge 30 Fusion**](reports/tundra.md) | `tundra` | `XT2243` | ❔ Untested | [0 Reports ➔](reports/tundra.md) |
| [**Motorola Edge 30 Pro / Edge+ (2022)**](reports/hiphic.md) | `hiphic` | `XT2201` | ❔ Untested | [0 Reports ➔](reports/hiphic.md) |
| [**Motorola Edge 30 Ultra / Moto X30 Pro**](reports/eqs.md) | `eqs` | `XT2241` | ❔ Untested | [0 Reports ➔](reports/eqs.md) |
| [**Motorola Edge 40**](reports/corfur.md) | `corfur` | `XT2303` | ❔ Untested | [0 Reports ➔](reports/corfur.md) |
| [**Motorola Edge 40 Neo**](reports/manao.md) | `manao` | `XT2307` | ❔ Untested | [0 Reports ➔](reports/manao.md) |
| [**Motorola Edge 40 Pro / Edge+ (2023)**](reports/rtwo.md) | `rtwo` | `XT2301` | ❔ Untested | [0 Reports ➔](reports/rtwo.md) |
| [**Motorola Razr 40 / Razr (2023)**](reports/segas.md) | `segas` | `XT2323` | ❔ Untested | [0 Reports ➔](reports/segas.md) |
| [**Motorola Razr 40 Ultra / Razr+ (2023)**](reports/zeekr.md) | `zeekr` | `XT2321` | ❔ Untested | [0 Reports ➔](reports/zeekr.md) |
<!-- SUMMARY_TABLE_END -->

---

## Submitting a Device Compatibility Report

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
