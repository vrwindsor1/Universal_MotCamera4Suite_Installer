#!/usr/bin/env bash
# ==============================================================================
# Motorola Camera 4 Suite Universal Recovery Package Compiler (Linux)
# Compatible Devices: Any Motorola device utilizing the Moto Camera 4 Suite
# Supported Base ROMs: Official Motorola Stock ROMs (Android 12, 13, 14, 15+)
# Target Systems: LineageOS, AOSP, and custom ROMs (Android 13 - 17+)
#
# 100% Vibe Coded with Google DeepMind Gemini 3.8 Flash (Thinking / High)
#
# Automatically detects:
#   * Device Codename, Marketing Model, Hardware Platform / SoC
#   * Android OS Version, API SDK Level, Stock Firmware Build ID
#   * Moto Camera 4 Suite components (UI, AI provider, ImagerTuning, Desktop)
#   * Device-specific camera HALs, HIDL/AIDL daemons, and VINTF manifests
#   * Multi-camera sensor configuration and auxiliary camera system properties
#
# Generates:
#   MotoCamera4_<Codename>_Recovery_Installer.zip (Lineage Recovery / TWRP sideload)
#   with LineageOS addon.d OTA backup survival script
#
# Usage:
#   Interactive:  ./compile_recovery_package_linux.sh
#   CLI:          ./compile_recovery_package_linux.sh "/path/to/stock_firmware" [output_dir]
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_TEMPLATES_DIR="${SCRIPT_DIR}/templates/recovery"
DEFAULT_OUTPUT_DIR="${SCRIPT_DIR}/output"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/vrwindsor1/motocamera-genevn/main"

# Global state for trap cleanup
WORK_DIR=""
MOUNTED_DIRS=()

# Styling
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_CYAN="\033[36m"
C_YELLOW="\033[33m"
C_RED="\033[31m"
C_PURPLE="\033[35m"
C_BLUE="\033[34m"

log_info()    { echo -e "${C_CYAN}[INFO]${C_RESET} $1"; }
log_ok()      { echo -e "${C_GREEN}[OK]${C_RESET} $1"; }
log_warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
log_err()     { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }
log_profile() { echo -e "${C_PURPLE}[PROFILE]${C_RESET} $1"; }

banner() {
  echo -e "${C_BOLD}${C_CYAN}"
  echo "================================================================================"
  echo "      Motorola Camera 4 Suite Universal Recovery Package Compiler               "
  echo "         Dynamic Multi-Device Hal & Framework Extraction Suite                  "
  echo "================================================================================"
  echo -e "${C_PURPLE}   ⚡ 100% Vibe Coded with Google DeepMind Gemini 3.8 Flash (Thinking / High)  ${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}================================================================================${C_RESET}"
  echo ""
}

# ------------------------------------------------------------------------------
# 0. Environment Setup (Ensure tools in PATH even under sudo)
# ------------------------------------------------------------------------------
setup_environment() {
  if [ -n "$SUDO_USER" ]; then
    local real_home
    real_home=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)
    if [ -n "$real_home" ] && [ -d "$real_home" ]; then
      export PATH="${real_home}/.local/bin:${PATH}"
      export LD_LIBRARY_PATH="${real_home}/.local/lib:${LD_LIBRARY_PATH}"
    fi
  fi

  export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:${PATH}"
  export LD_LIBRARY_PATH="${HOME}/.local/lib:${LD_LIBRARY_PATH}"
}

# ------------------------------------------------------------------------------
# 1. Dependency Verification
# ------------------------------------------------------------------------------
check_dependencies() {
  log_info "Verifying host build tools..."
  local missing=()

  for tool in zip simg2img lpunpack; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done

  # Verify EROFS extraction capability:
  # 1. erofs-extract or fsck.erofs
  # 2. OR root permissions with native kernel erofs support
  local erofs_capable=0
  if command -v erofs-extract &>/dev/null; then
    erofs_capable=1
  elif command -v fsck.erofs &>/dev/null; then
    erofs_capable=1
  elif [ "$(id -u)" -eq 0 ] && modinfo erofs &>/dev/null; then
    erofs_capable=1
  fi

  if [ "$erofs_capable" -eq 0 ]; then
    missing+=("erofs-utils (fsck.erofs / erofs-extract)")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    log_err "Missing required build tools: ${missing[*]}"
    echo ""
    echo "Please install dependencies for your distribution:"
    echo "  Fedora / RHEL:   sudo dnf install android-tools erofs-utils zip curl python3"
    echo "  Ubuntu / Debian: sudo apt install android-sdk-libsparse-utils erofs-utils zip curl python3"
    echo "  Arch Linux:      sudo pacman -S android-tools erofs-utils zip curl python"
    echo ""
    exit 1
  fi

  log_ok "All required host build tools are available."
}

# ------------------------------------------------------------------------------
# 2. Template Resolution (Local or Standalone Remote Fetch)
# ------------------------------------------------------------------------------
ensure_templates() {
  local target_work_dir="$1"

  # Case A: templates exist relative to script directory
  if [ -d "$LOCAL_TEMPLATES_DIR" ] && [ -f "${LOCAL_TEMPLATES_DIR}/META-INF/com/google/android/update-binary" ]; then
    TEMPLATES_DIR="$LOCAL_TEMPLATES_DIR"
    log_ok "Using local recovery templates."
    return 0
  fi

  # Case B: templates exist in current working directory
  if [ -d "./templates/recovery" ] && [ -f "./templates/recovery/META-INF/com/google/android/update-binary" ]; then
    TEMPLATES_DIR="$(pwd)/templates/recovery"
    log_ok "Using local recovery templates."
    return 0
  fi

  log_info "Local templates not found. Fetching open-source recovery templates..."
  TEMPLATES_DIR="${target_work_dir}/downloaded_templates"
  mkdir -p "${TEMPLATES_DIR}/META-INF/com/google/android" "${TEMPLATES_DIR}/addon.d"

  local files=(
    "templates/recovery/build.prop"
    "templates/recovery/toybox"
    "templates/recovery/addon.d/addond_head"
    "templates/recovery/addon.d/addond_tail"
    "templates/recovery/META-INF/com/google/android/update-binary"
    "templates/recovery/META-INF/com/google/android/updater-script"
  )

  for file in "${files[@]}"; do
    local rel_dest="${file#templates/recovery/}"
    local dest="${TEMPLATES_DIR}/${rel_dest}"
    mkdir -p "$(dirname "$dest")"
    if command -v curl &>/dev/null; then
      curl -sSL "${GITHUB_RAW_BASE}/${file}" -o "$dest"
    elif command -v wget &>/dev/null; then
      wget -q "${GITHUB_RAW_BASE}/${file}" -O "$dest"
    else
      log_err "curl or wget is required to download recovery templates."
      exit 1
    fi
  done

  chmod +x "${TEMPLATES_DIR}/toybox" "${TEMPLATES_DIR}/META-INF/com/google/android/update-binary"
  log_ok "Recovery scaffolding templates downloaded successfully."
}

# ------------------------------------------------------------------------------
# 3. Firmware Input Resolution
# ------------------------------------------------------------------------------
get_firmware_path() {
  local input="$1"

  if [ -z "$input" ]; then
    echo -e "${C_BOLD}Please specify the path to your downloaded Motorola stock firmware:${C_RESET}"
    echo "  (Accepts: folder with sparsechunks, partition .img files, pre-extracted folders, or .zip archive)"
    echo -e "${C_CYAN}  Tip: Stock firmware can be obtained via Motorola Rescue and Smart Assistant (RSA)${C_RESET}"
    echo -e "       or from official mirrors: ${C_YELLOW}https://mirrors.lolinet.com/firmware/lenomola/${C_RESET}"
    echo ""
    read -e -p "> Path: " input
  fi

  # Trim whitespace
  input="$(echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  # Strip quotes safely
  while [[ "$input" =~ ^[\'\"](.*)[\'\"]$ ]]; do
    input="${BASH_REMATCH[1]}"
    input="$(echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  done

  # Expand tilde
  input="${input/#\~/$HOME}"

  if [ ! -e "$input" ]; then
    log_err "Specified path does not exist: $input"
    exit 1
  fi

  FIRMWARE_INPUT="$input"
  log_ok "Firmware source: $FIRMWARE_INPUT"
}

# ------------------------------------------------------------------------------
# 4. Extraction Engine
# ------------------------------------------------------------------------------
extract_firmware() {
  local src="$1"
  local work_dir="$2"
  local partitions_dir="${work_dir}/partitions"
  local extracted_dir="${work_dir}/extracted"

  mkdir -p "$partitions_dir" "$extracted_dir"

  # Case A: Already extracted directory with product/ and system_ext/
  if [ -d "$src" ] && [ -d "${src}/product" ] && [ -d "${src}/system_ext" ]; then
    log_info "Detected pre-extracted partition filesystem tree."
    FIRMWARE_ROOT="$src"
    return 0
  fi

  # Case B: If input is an archive, extract it first
  if [ -f "$src" ] && [[ "$src" =~ \.(zip|tar\.gz|tgz)$ ]]; then
    log_info "Unpacking firmware archive..."
    local unzipped_dir="${work_dir}/unpacked_zip"
    mkdir -p "$unzipped_dir"
    if [[ "$src" =~ \.zip$ ]]; then
      unzip -q "$src" -d "$unzipped_dir"
    else
      tar -xzf "$src" -C "$unzipped_dir"
    fi
    src="$unzipped_dir"
  fi

  # Case C: Check for sparsechunks safely
  local sparse_files=()
  while IFS= read -r -d $'\0' f; do
    [ -n "$f" ] && sparse_files+=("$f")
  done < <(find "$src" -maxdepth 1 -name "super.img_sparsechunk.*" -print0 2>/dev/null | sort -z -V)

  if [ ${#sparse_files[@]} -gt 0 ]; then
    log_info "Recombining ${#sparse_files[@]} super sparsechunk segments with simg2img..."
    simg2img "${sparse_files[@]}" "${work_dir}/super.raw.img"
    log_ok "Unpacking dynamic partitions from super.raw.img with lpunpack..."
    lpunpack "${work_dir}/super.raw.img" "$partitions_dir"
    rm -f "${work_dir}/super.raw.img"
  elif [ -f "${src}/super.img" ] || [ -f "${src}/super.raw.img" ]; then
    local super_img="${src}/super.img"
    [ ! -f "$super_img" ] && super_img="${src}/super.raw.img"
    log_info "Found super partition image: $super_img"
    lpunpack "$super_img" "$partitions_dir"
  elif [ -f "${src}/product.img" ] || [ -f "${src}/product_a.img" ]; then
    log_info "Found existing partition images in directory."
    partitions_dir="$src"
  else
    # Check one subdirectory deep (common for extracted RSA / LMSA zips)
    local sub_sparse=()
    while IFS= read -r -d $'\0' f; do
      [ -n "$f" ] && sub_sparse+=("$f")
    done < <(find "$src" -mindepth 2 -maxdepth 2 -name "super.img_sparsechunk.*" -print0 2>/dev/null | sort -z -V)

    if [ ${#sub_sparse[@]} -gt 0 ]; then
      log_info "Found ${#sub_sparse[@]} sparsechunks in subdirectory. Recombining..."
      simg2img "${sub_sparse[@]}" "${work_dir}/super.raw.img"
      lpunpack "${work_dir}/super.raw.img" "$partitions_dir"
      rm -f "${work_dir}/super.raw.img"
    else
      log_err "Could not identify recognized stock firmware files in: $src"
      log_err "Expected: super.img_sparsechunk.*, super.img, or partition images (product.img, etc.)"
      exit 1
    fi
  fi

  # Extract partition images (EROFS or EXT4)
  for part in product system_ext system vendor odm; do
    local img=""
    for candidate in "${partitions_dir}/${part}_a.img" "${partitions_dir}/${part}.img" "${partitions_dir}/${part}_b.img"; do
      if [ -f "$candidate" ]; then
        img="$candidate"
        break
      fi
    done

    # odm is optional; others are mandatory
    if [ -z "$img" ]; then
      if [ "$part" = "odm" ]; then
        continue
      fi
      log_err "Missing required partition image: ${part}.img"
      exit 1
    fi

    local target_part_dir="${extracted_dir}/${part}"
    mkdir -p "$target_part_dir"

    log_info "Extracting ${part} partition (${img##*/})..."
    local extracted=0

    # Strategy 1: Loop mount if root
    if [ "$(id -u)" -eq 0 ]; then
      if mount -t erofs -o loop,ro "$img" "$target_part_dir" 2>/dev/null || mount -t ext4 -o loop,ro "$img" "$target_part_dir" 2>/dev/null; then
        MOUNTED_DIRS+=("$target_part_dir")
        extracted=1
        log_ok "Mounted ${part} partition via kernel loop."
      fi
    fi

    # Strategy 2: erofs-extract or fsck.erofs
    if [ "$extracted" -eq 0 ]; then
      if command -v erofs-extract &>/dev/null; then
        erofs-extract --extract="$target_part_dir" --overwrite "$img" 2>/dev/null || true
      elif command -v fsck.erofs &>/dev/null; then
        fsck.erofs --extract="$target_part_dir" --overwrite "$img" 2>/dev/null || true
      fi

      if [ -n "$(ls -A "$target_part_dir" 2>/dev/null)" ]; then
        extracted=1
      fi
    fi

    if [ "$extracted" -eq 0 ]; then
      log_err "Failed to extract ${part} partition (${img##*/})!"
      log_err "Please verify that erofs-utils is installed (sudo dnf install erofs-utils / sudo apt install erofs-utils)."
      exit 1
    fi
  done

  FIRMWARE_ROOT="$extracted_dir"
  log_ok "All partitions successfully extracted to: $FIRMWARE_ROOT"
}

# ------------------------------------------------------------------------------
# 5. Device Auto-Detection & Firmware Profiling
# ------------------------------------------------------------------------------
read_prop() {
  local key="$1"
  shift
  for file in "$@"; do
    if [ -f "$file" ]; then
      local val
      val=$(grep -E "^${key}=" "$file" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '\r')
      if [ -n "$val" ]; then
        echo "$val"
        return 0
      fi
    fi
  done
  return 1
}

profile_device() {
  local src_root="$1"
  log_info "Profiling device hardware and firmware properties..."

  local sys_path="${src_root}/system"
  [ -d "${src_root}/system/system" ] && sys_path="${src_root}/system/system"

  PROP_FILES=(
    "${src_root}/product/etc/build.prop"
    "${src_root}/product/build.prop"
    "${src_root}/vendor/build.prop"
    "${sys_path}/build.prop"
    "${src_root}/system_ext/etc/build.prop"
    "${src_root}/system_ext/build.prop"
    "${src_root}/odm/etc/build.prop"
  )

  # 1. Device Codename
  DEVICE_CODENAME=$(read_prop "ro.product.vendor.device" "${PROP_FILES[@]}" || \
                   read_prop "ro.product.system.device" "${PROP_FILES[@]}" || \
                   read_prop "ro.product.product.device" "${PROP_FILES[@]}" || \
                   read_prop "ro.product.device" "${PROP_FILES[@]}" || \
                   read_prop "ro.product.vendor.name" "${PROP_FILES[@]}" || \
                   read_prop "ro.product.system.name" "${PROP_FILES[@]}" || \
                   read_prop "ro.product.product.name" "${PROP_FILES[@]}" || \
                   read_prop "ro.product.name" "${PROP_FILES[@]}" || echo "")

  # Fallback: scan product/etc/permissions/com.motorola.camera3.*.xml
  if [ -z "$DEVICE_CODENAME" ] || [ "$DEVICE_CODENAME" = "msi" ]; then
    local cam_perm
    cam_perm=$(find "${src_root}/product/etc/permissions" -name "com.motorola.camera3.*.xml" 2>/dev/null | head -n1)
    if [ -n "$cam_perm" ]; then
      local base="${cam_perm##*/}"
      local extracted_code="${base#com.motorola.camera3.}"
      extracted_code="${extracted_code%.xml}"
      if [ "$extracted_code" != "content.ai" ] && [ "$extracted_code" != "lens" ]; then
        DEVICE_CODENAME="$extracted_code"
      fi
    fi
  fi

  [ -z "$DEVICE_CODENAME" ] && DEVICE_CODENAME="generic"

  # 2. Marketing Model Name
  DEVICE_MODEL=$(read_prop "ro.product.product.model" "${PROP_FILES[@]}" || \
                 read_prop "ro.product.system.model" "${PROP_FILES[@]}" || \
                 read_prop "ro.product.vendor.model" "${PROP_FILES[@]}" || \
                 read_prop "ro.product.model" "${PROP_FILES[@]}" || echo "Motorola Smartphone")

  # 3. Android Release Version & SDK Level
  ANDROID_VERSION=$(read_prop "ro.build.version.release" "${PROP_FILES[@]}" || \
                   read_prop "ro.product.build.version.release" "${PROP_FILES[@]}" || \
                   read_prop "ro.system.build.version.release" "${PROP_FILES[@]}" || echo "14")

  SDK_LEVEL=$(read_prop "ro.build.version.sdk" "${PROP_FILES[@]}" || \
              read_prop "ro.product.build.version.sdk" "${PROP_FILES[@]}" || \
              read_prop "ro.system.build.version.sdk" "${PROP_FILES[@]}" || echo "34")

  # 4. Stock Build ID & Fingerprint
  BUILD_ID=$(read_prop "ro.build.id" "${PROP_FILES[@]}" || \
             read_prop "ro.product.build.id" "${PROP_FILES[@]}" || \
             read_prop "ro.system.build.id" "${PROP_FILES[@]}" || echo "UNKNOWN")

  PLATFORM_SOC=$(read_prop "ro.board.platform" "${PROP_FILES[@]}" || \
                 read_prop "ro.hardware" "${PROP_FILES[@]}" || \
                 read_prop "ro.product.board" "${PROP_FILES[@]}" || echo "unknown")

  log_profile "Detected Stock Firmware Profile:"
  echo -e "    ${C_BOLD}Model:${C_RESET}       ${DEVICE_MODEL}"
  echo -e "    ${C_BOLD}Codename:${C_RESET}    ${DEVICE_CODENAME}"
  echo -e "    ${C_BOLD}Platform:${C_RESET}    ${PLATFORM_SOC}"
  echo -e "    ${C_BOLD}Android:${C_RESET}     ${ANDROID_VERSION} (API SDK ${SDK_LEVEL})"
  echo -e "    ${C_BOLD}Build ID:${C_RESET}    ${BUILD_ID}"
}

# ------------------------------------------------------------------------------
# 6. Moto Camera 4 Suite Discovery & Validation
# ------------------------------------------------------------------------------
validate_camera_suite() {
  local src_root="$1"
  log_info "Detecting and validating Motorola Camera 4 Suite..."

  # Locate MotCamera4.apk across partitions
  MOTCAMERA4_APK=$(find "$src_root" -type f -name "MotCamera4.apk" 2>/dev/null | head -n1)

  if [ -z "$MOTCAMERA4_APK" ]; then
    log_err "MotCamera4.apk was not found in the firmware partitions!"
    echo ""
    echo "This compiler is specifically designed for Motorola devices that utilize the Moto Camera 4 Suite."
    echo "Possible reasons:"
    echo "  1. The firmware belongs to an older Moto device running Moto Camera 2 or 3 (v7.x/v8.x)."
    echo "  2. The firmware does not have product/ or system_ext/ partitions extracted properly."
    echo ""
    exit 1
  fi

  log_ok "Located Moto Camera 4 application: $MOTCAMERA4_APK"

  # Extract camera version string
  MOTCAMERA4_VER=""
  if command -v python3 &>/dev/null; then
    MOTCAMERA4_VER=$(python3 -c "
import zipfile, re, sys
try:
    with zipfile.ZipFile('$MOTCAMERA4_APK', 'r') as z:
        for name in ['classes.dex', 'classes2.dex']:
            if name in z.namelist():
                m = re.findall(b'9\.[0-9]+\.[0-9]+\.[0-9]+', z.read(name))
                if m:
                    print(m[0].decode())
                    sys.exit(0)
except Exception:
    pass
" 2>/dev/null || true)
  fi

  if [ -z "$MOTCAMERA4_VER" ]; then
    MOTCAMERA4_VER=$(strings "$MOTCAMERA4_APK" 2>/dev/null | grep -E '^9\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "v9.x+")
  fi

  log_ok "Moto Camera 4 Version: ${MOTCAMERA4_VER}"

  # Check companion applications
  local ai_apk
  ai_apk=$(find "$src_root" -type f -name "MotCamera3AI.apk" 2>/dev/null | head -n1)
  if [ -n "$ai_apk" ]; then
    log_ok "Found AI Scene Engine: MotCamera3AI.apk"
  else
    log_warn "MotCamera3AI.apk not found; AI scene heuristics will be omitted."
  fi

  local tuning_apk
  tuning_apk=$(find "$src_root" -type f -name "ImagerTuning*.apk" 2>/dev/null | head -n1)
  if [ -n "$tuning_apk" ]; then
    local tuning_name="${tuning_apk##*/}"
    log_ok "Found Image Tuning Provider: ${tuning_name}"
  else
    log_warn "ImagerTuning APK not found in system_ext/priv-app."
  fi

  local desktop_apk
  desktop_apk=$(find "$src_root" -type f -name "MotCameraDesktop.apk" 2>/dev/null | head -n1)
  if [ -n "$desktop_apk" ]; then
    log_ok "Found Desktop Companion: MotCameraDesktop.apk"
  fi
}

# ------------------------------------------------------------------------------
# 7. Dynamic Camera Properties Harvester
# ------------------------------------------------------------------------------
harvest_camera_properties() {
  local src_root="$1"
  local output_prop="$2"

  log_info "Harvesting device-specific multi-camera system properties..."
  rm -f "$output_prop"
  touch "$output_prop"

  cat <<EOF >> "$output_prop"
# ==============================================================================
# Auto-harvested Motorola Camera 4 Suite Properties
# Device: ${DEVICE_MODEL} (${DEVICE_CODENAME})
# Firmware: ${BUILD_ID} (Android ${ANDROID_VERSION}, SDK ${SDK_LEVEL})
# ==============================================================================
ro.motocamera.device=${DEVICE_CODENAME}
ro.motocamera.model=${DEVICE_MODEL}
ro.motocamera.android=${ANDROID_VERSION}
ro.motocamera.sdk=${SDK_LEVEL}
ro.motocamera.build_id=${BUILD_ID}
ro.motocamera.version=${MOTCAMERA4_VER}

EOF

  local harvested_keys=()

  # Collect properties from vendor, system_ext, and system build.prop
  for prop_file in "${PROP_FILES[@]}"; do
    if [ -f "$prop_file" ]; then
      while IFS='=' read -r key val || [ -n "$key" ]; do
        case "$key" in
          persist.vendor.camera.*|\
          vendor.camera.aux.*|\
          ro.vendor.camera.aux.*|\
          ro.camera.cfa.*|\
          camera.disable_zsl_mode|\
          ro.camera.enableCamera1MaxZsl)
            clean_key=$(echo "$key" | tr -d ' \r\t')
            clean_val=$(echo "$val" | tr -d '\r')
            if [ -n "$clean_key" ] && [[ ! " ${harvested_keys[*]} " =~ " ${clean_key} " ]]; then
              echo "${clean_key}=${clean_val}" >> "$output_prop"
              harvested_keys+=("$clean_key")
            fi
            ;;
        esac
      done < "$prop_file"
    fi
  done

  # Guarantee baseline aux camera unlock if not found
  if [[ ! " ${harvested_keys[*]} " =~ " persist.vendor.camera.expose.aux " ]]; then
    echo "persist.vendor.camera.expose.aux=1" >> "$output_prop"
  fi

  log_ok "Harvested ${#harvested_keys[@]} device camera properties."
}

# ------------------------------------------------------------------------------
# 8. Proprietary Component Harvester
# ------------------------------------------------------------------------------
harvest_blobs() {
  local src_root="$1"
  local staging_dir="$2"

  log_info "Harvesting Moto Camera 4 binaries, libraries, and frameworks..."
  rm -rf "$staging_dir"
  mkdir -p "${staging_dir}/system"

  local sys_path="${src_root}/system"
  [ -d "${src_root}/system/system" ] && sys_path="${src_root}/system/system"

  # ----------------------------------------------------------------------------
  # 1. Product Partition Components
  # ----------------------------------------------------------------------------
  log_info "  - Harvesting Product applications & permissions..."
  mkdir -p "${staging_dir}/system/product/priv-app"
  mkdir -p "${staging_dir}/system/product/app"
  mkdir -p "${staging_dir}/system/product/etc/permissions"
  mkdir -p "${staging_dir}/system/product/etc/sysconfig"
  mkdir -p "${staging_dir}/system/product/etc/init"
  mkdir -p "${staging_dir}/system/product/etc/MotoDesktopAppConfig"

  # MotCamera4 app directory
  local cam4_src_dir
  cam4_src_dir=$(find "${src_root}/product" -type d -name "MotCamera4" 2>/dev/null | head -n1)
  if [ -n "$cam4_src_dir" ]; then
    cp -rf "$cam4_src_dir" "${staging_dir}/system/product/priv-app/"
  else
    # Fallback copy single apk
    mkdir -p "${staging_dir}/system/product/priv-app/MotCamera4"
    cp -f "$MOTCAMERA4_APK" "${staging_dir}/system/product/priv-app/MotCamera4/"
  fi

  # MotCamera3AI app directory
  local ai_src_dir
  ai_src_dir=$(find "${src_root}/product" -type d -name "MotCamera3AI" 2>/dev/null | head -n1)
  if [ -n "$ai_src_dir" ]; then
    cp -rf "$ai_src_dir" "${staging_dir}/system/product/app/"
  fi

  # Camera permissions and sysconfigs (matches device-specific com.motorola.camera3.<codename>.xml too)
  cp -f "${src_root}/product/etc/permissions/"*com.motorola.camera3* "${staging_dir}/system/product/etc/permissions/" 2>/dev/null || true
  cp -f "${src_root}/product/etc/sysconfig/"*com.motorola.camera3* "${staging_dir}/system/product/etc/sysconfig/" 2>/dev/null || true
  cp -f "${src_root}/product/etc/init/"*motcamera* "${staging_dir}/system/product/etc/init/" 2>/dev/null || true
  [ -d "${src_root}/product/etc/MotoDesktopAppConfig" ] && cp -rf "${src_root}/product/etc/MotoDesktopAppConfig/"* "${staging_dir}/system/product/etc/MotoDesktopAppConfig/" 2>/dev/null || true

  # Shutter/focus sounds if present
  if [ -d "${src_root}/product/media/audio/ui" ]; then
    mkdir -p "${staging_dir}/system/product/media/audio/ui"
    cp -f "${src_root}/product/media/audio/ui/"camera_* "${staging_dir}/system/product/media/audio/ui/" 2>/dev/null || true
  fi

  # ----------------------------------------------------------------------------
  # 2. System_ext Partition Components
  # ----------------------------------------------------------------------------
  log_info "  - Harvesting System_ext ImagerTuning, Desktop, frameworks, and libs..."
  mkdir -p "${staging_dir}/system/system_ext/priv-app"
  mkdir -p "${staging_dir}/system/system_ext/framework"
  mkdir -p "${staging_dir}/system/system_ext/lib64"
  mkdir -p "${staging_dir}/system/system_ext/etc/permissions"
  mkdir -p "${staging_dir}/system/system_ext/etc/enable-disable-packages"
  mkdir -p "${staging_dir}/system/system_ext/etc/sysconfig"

  # Dynamic ImagerTuning app directory (ImagerTuning-U, ImagerTuning-T, ImagerTuning, etc.)
  while IFS= read -r -d $'\0' d; do
    [ -n "$d" ] && cp -rf "$d" "${staging_dir}/system/system_ext/priv-app/"
  done < <(find "${src_root}/system_ext/priv-app" -maxdepth 1 -type d -name "ImagerTuning*" -print0 2>/dev/null)

  # MotCameraDesktop app directory
  if [ -d "${src_root}/system_ext/priv-app/MotCameraDesktop" ]; then
    cp -rf "${src_root}/system_ext/priv-app/MotCameraDesktop" "${staging_dir}/system/system_ext/priv-app/"
  fi

  # Frameworks and permissions
  cp -f "${src_root}/system_ext/framework/"*com.motorola.* "${staging_dir}/system/system_ext/framework/" 2>/dev/null || true
  cp -f "${src_root}/system_ext/etc/permissions/"*motorola* "${staging_dir}/system/system_ext/etc/permissions/" 2>/dev/null || true
  cp -f "${src_root}/system_ext/etc/permissions/"*imager* "${staging_dir}/system/system_ext/etc/permissions/" 2>/dev/null || true
  cp -f "${src_root}/system_ext/etc/permissions/"*camera* "${staging_dir}/system/system_ext/etc/permissions/" 2>/dev/null || true
  cp -f "${src_root}/system_ext/etc/public.libraries-"* "${staging_dir}/system/system_ext/etc/" 2>/dev/null || true
  cp -f "${src_root}/system_ext/etc/enable-disable-packages/"*camera* "${staging_dir}/system/system_ext/etc/enable-disable-packages/" 2>/dev/null || true
  cp -f "${src_root}/system_ext/etc/enable-disable-packages/"*desktop* "${staging_dir}/system/system_ext/etc/enable-disable-packages/" 2>/dev/null || true
  cp -f "${src_root}/system_ext/etc/sysconfig/"* "${staging_dir}/system/system_ext/etc/sysconfig/" 2>/dev/null || true

  # System_ext native libraries (both 64-bit and 32-bit if present)
  for lib_arch in lib64 lib; do
    local src_lib_dir="${src_root}/system_ext/${lib_arch}"
    if [ -d "$src_lib_dir" ]; then
      local dst_lib_dir="${staging_dir}/system/system_ext/${lib_arch}"
      mkdir -p "$dst_lib_dir"
      # Dynamic library harvesting: ArcSoft, Camera JNI, ImgTuner, Desktop, OpenCV, HIDL
      for pattern in "libarcsoft*" "libcamera*" "libimgTuner*" "libjni_helper*" "libopencv*" "motorola.hardware.camera*"; do
        while IFS= read -r -d $'\0' lib_file; do
          [ -n "$lib_file" ] && cp -f "$lib_file" "$dst_lib_dir/"
        done < <(find "$src_lib_dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
      done
    fi
  done

  # ----------------------------------------------------------------------------
  # 3. System Framework and Libraries
  # ----------------------------------------------------------------------------
  log_info "  - Harvesting System framework signature libraries..."
  mkdir -p "${staging_dir}/system/framework"
  mkdir -p "${staging_dir}/system/etc/permissions"
  mkdir -p "${staging_dir}/system/lib64"

  # Signature framework (mandatory for Moto Camera 4 uses-library verification)
  cp -f "${sys_path}/framework/com.motorola.motosignature.jar" "${staging_dir}/system/framework/" 2>/dev/null || true
  cp -f "${sys_path}/framework/moto-core_services.jar" "${staging_dir}/system/framework/" 2>/dev/null || true
  cp -f "${sys_path}/framework/moto-settings.jar" "${staging_dir}/system/framework/" 2>/dev/null || true
  cp -f "${sys_path}/etc/permissions/com.motorola.motosignature.xml" "${staging_dir}/system/etc/permissions/" 2>/dev/null || true
  cp -f "${sys_path}/etc/permissions/moto-core_services.xml" "${staging_dir}/system/etc/permissions/" 2>/dev/null || true
  cp -f "${sys_path}/etc/permissions/moto-settings.xml" "${staging_dir}/system/etc/permissions/" 2>/dev/null || true

  for lib_arch in lib64 lib; do
    if [ -d "${sys_path}/${lib_arch}" ]; then
      mkdir -p "${staging_dir}/system/${lib_arch}"
      while IFS= read -r -d $'\0' lib_file; do
        [ -n "$lib_file" ] && cp -f "$lib_file" "${staging_dir}/system/${lib_arch}/"
      done < <(find "${sys_path}/${lib_arch}" -maxdepth 1 -type f -name "motorola.hardware.camera*" -print0 2>/dev/null)
    fi
  done

  # ----------------------------------------------------------------------------
  # 4. Vendor Camera HAL & VINTF Manifest
  # ----------------------------------------------------------------------------
  log_info "  - Harvesting Vendor HAL services and VINTF manifests..."
  mkdir -p "${staging_dir}/system/vendor/bin/hw"
  mkdir -p "${staging_dir}/system/vendor/etc/init"
  mkdir -p "${staging_dir}/system/vendor/etc/vintf/manifest"
  mkdir -p "${staging_dir}/system/vendor/lib64/hw"

  # Hardware Daemons
  while IFS= read -r -d $'\0' bin_file; do
    [ -n "$bin_file" ] && cp -f "$bin_file" "${staging_dir}/system/vendor/bin/hw/"
  done < <(find "${src_root}/vendor/bin/hw" -maxdepth 1 -type f -name "motorola.hardware.camera.*" -print0 2>/dev/null)

  # Init rc files
  while IFS= read -r -d $'\0' rc_file; do
    [ -n "$rc_file" ] && cp -f "$rc_file" "${staging_dir}/system/vendor/etc/init/"
  done < <(find "${src_root}/vendor/etc/init" -maxdepth 1 -type f -name "motorola.hardware.camera.*" -print0 2>/dev/null)

  # Vendor HAL libraries
  for lib_arch in lib64 lib; do
    if [ -d "${src_root}/vendor/${lib_arch}" ]; then
      mkdir -p "${staging_dir}/system/vendor/${lib_arch}/hw"
      # Impl libs
      while IFS= read -r -d $'\0' lib_file; do
        [ -n "$lib_file" ] && cp -f "$lib_file" "${staging_dir}/system/vendor/${lib_arch}/hw/"
      done < <(find "${src_root}/vendor/${lib_arch}/hw" -maxdepth 1 -type f -name "motorola.hardware.camera.*" -print0 2>/dev/null)

      # Shared vendor libs
      while IFS= read -r -d $'\0' lib_file; do
        [ -n "$lib_file" ] && cp -f "$lib_file" "${staging_dir}/system/vendor/${lib_arch}/"
      done < <(find "${src_root}/vendor/${lib_arch}" -maxdepth 1 -type f \( -name "motorola.hardware.camera.*" -o -name "libmot_chi_desktop_helper*" \) -print0 2>/dev/null)
    fi
  done

  # VINTF Manifest
  local vintf_file="${staging_dir}/system/vendor/etc/vintf/manifest/manifest_imgtuner.xml"
  if [ -f "${src_root}/vendor/etc/vintf/manifest/manifest_imgtuner.xml" ]; then
    cp -f "${src_root}/vendor/etc/vintf/manifest/manifest_imgtuner.xml" "$vintf_file"
  else
    cat <<'EOF' > "$vintf_file"
<manifest version="1.0" type="device">
    <hal format="hidl">
        <name>motorola.hardware.camera.imgtuner</name>
        <transport>hwbinder</transport>
        <version>1.0</version>
        <version>2.0</version>
        <interface>
            <name>IImageTuning</name>
            <instance>default</instance>
        </interface>
        <fqname>@1.0::IImageTuning/default</fqname>
        <fqname>@2.0::IImageTuning/default</fqname>
    </hal>
</manifest>
EOF
  fi

  # Final sanity check: core application presence
  local staged_cam4
  staged_cam4=$(find "${staging_dir}/system" -name "MotCamera4.apk" 2>/dev/null | head -n1)
  if [ -z "$staged_cam4" ]; then
    log_err "Failed to stage MotCamera4.apk! Halting package generation."
    exit 1
  fi

  log_ok "All Moto Camera 4 Suite proprietary blobs harvested successfully."
}

# ------------------------------------------------------------------------------
# 9. Recovery Package Assembly
# ------------------------------------------------------------------------------
build_recovery_package() {
  local staging_dir="$1"
  local output_dir="$2"
  local build_tmp="$3"
  local camera_prop="$4"

  mkdir -p "$output_dir"
  local abs_output_dir="$(cd "$output_dir" && pwd)"

  log_info "Assembling flashable recovery installer for ${DEVICE_MODEL} (${DEVICE_CODENAME})..."
  local rec_build="${build_tmp}/recovery_build"
  rm -rf "$rec_build"
  mkdir -p "$rec_build"

  # Copy recovery scaffolding templates
  cp -rf "${TEMPLATES_DIR}/"* "$rec_build/"

  # Update template build.prop with detected firmware version
  cat <<EOF > "${rec_build}/build.prop"
arch=arm64
version=${SDK_LEVEL}
version_nice=${ANDROID_VERSION}.0.0
ro.product.device=${DEVICE_CODENAME}
ro.product.model=${DEVICE_MODEL}
EOF

  # Ensure addon.d scripts are inside system/addon.d
  mkdir -p "${rec_build}/system/addon.d"
  cp -rf "${TEMPLATES_DIR}/addon.d/"* "${rec_build}/system/addon.d/"
  rm -rf "${rec_build}/addon.d"

  # Copy harvested camera components
  cp -rf "${staging_dir}/system/"* "${rec_build}/system/"

  # Embed device properties file inside package root
  cp -f "$camera_prop" "${rec_build}/motocamera.prop"

  # Package flashable recovery ZIP
  local rec_zip="${abs_output_dir}/MotoCamera4_${DEVICE_CODENAME}_Recovery_Installer.zip"
  rm -f "$rec_zip"
  (cd "$rec_build" && zip -r9q "$rec_zip" .)

  # Write metadata summary text
  local info_file="${abs_output_dir}/MotoCamera4_${DEVICE_CODENAME}_info.txt"
  cat <<EOF > "$info_file"
================================================================================
Motorola Camera 4 Suite Recovery Package Summary
================================================================================
Device Model:       ${DEVICE_MODEL}
Device Codename:    ${DEVICE_CODENAME}
Hardware Platform:  ${PLATFORM_SOC}
Android Version:    ${ANDROID_VERSION} (API SDK ${SDK_LEVEL})
Stock Build ID:     ${BUILD_ID}
Moto Camera Suite:  ${MOTCAMERA4_VER}
Installer ZIP:      ${rec_zip##*/}
Build Timestamp:    $(date -u +"%Y-%m-%d %H:%M:%S UTC")
================================================================================
EOF

  log_ok "Recovery Installer created: $rec_zip ($(du -h "$rec_zip" | cut -f1))"
  log_ok "Build manifest saved: $info_file"
}

# ------------------------------------------------------------------------------
# Cleanup handler
# ------------------------------------------------------------------------------
cleanup() {
  if [ ${#MOUNTED_DIRS[@]} -gt 0 ]; then
    log_info "Unmounting loop mounts..."
    for mnt in "${MOUNTED_DIRS[@]}"; do
      umount -l "$mnt" 2>/dev/null || true
    done
  fi

  if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------
main() {
  banner
  setup_environment
  check_dependencies

  local cli_input="$1"
  local cli_out="$2"

  local out_dir="${cli_out:-$DEFAULT_OUTPUT_DIR}"
  mkdir -p "$out_dir"
  local abs_out_dir="$(cd "$out_dir" && pwd)"

  local base_work_dir="${abs_out_dir}/.build_tmp"
  mkdir -p "$base_work_dir"
  WORK_DIR="$(mktemp -d "${base_work_dir}/motocamera_build_XXXXXX" 2>/dev/null || mktemp -d /tmp/motocamera_build_XXXXXX)"

  log_info "Working directory initialized: $WORK_DIR"
  ensure_templates "$WORK_DIR"

  get_firmware_path "$cli_input"
  extract_firmware "$FIRMWARE_INPUT" "$WORK_DIR"

  profile_device "$FIRMWARE_ROOT"
  validate_camera_suite "$FIRMWARE_ROOT"

  local camera_prop="${WORK_DIR}/motocamera.prop"
  harvest_camera_properties "$FIRMWARE_ROOT" "$camera_prop"

  local staging_dir="${WORK_DIR}/staging"
  harvest_blobs "$FIRMWARE_ROOT" "$staging_dir"

  build_recovery_package "$staging_dir" "$abs_out_dir" "$WORK_DIR" "$camera_prop"

  local rec_zip="${abs_out_dir}/MotoCamera4_${DEVICE_CODENAME}_Recovery_Installer.zip"
  echo ""
  echo -e "${C_BOLD}${C_GREEN}================================================================================"
  echo "          Universal Recovery Package Compiled Successfully!                     "
  echo -e "================================================================================${C_RESET}"
  echo ""
  echo "Target Device:"
  echo "  --> Model:    ${DEVICE_MODEL}"
  echo "  --> Codename: ${DEVICE_CODENAME}"
  echo "  --> Version:  Moto Camera 4 (${MOTCAMERA4_VER})"
  echo ""
  echo "Installer Package:"
  echo "  --> ${rec_zip}"
  echo ""
  echo "How to install via Lineage Recovery / TWRP:"
  echo "  1. Reboot your phone into Recovery mode."
  echo "  2. Select 'Apply Update' -> 'Apply from ADB' (or 'Install' in TWRP)."
  echo "  3. From your PC terminal, run:"
  echo "       adb sideload \"${rec_zip}\""
  echo "  4. If prompted with 'Signature verification failed. Install anyway?', select 'Yes'."
  echo "  5. Reboot system. Moto Camera 4 is ready to use!"
  echo ""
  echo -e "${C_CYAN}[OTA Survival]${C_RESET} The included addon.d script will automatically"
  echo "preserve the camera suite across nightly LineageOS updates."
  echo ""
}

main "$@"
