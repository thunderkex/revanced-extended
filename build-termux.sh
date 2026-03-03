#!/usr/bin/env bash
# ============================================
# ReVanced Extended - Termux Build Script
# Enhanced with better UX and error handling
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pr() { echo -e "${GREEN}[+] ${1}${NC}"; }
warn() { echo -e "${YELLOW}[!] ${1}${NC}"; }
epr() { echo -e "${RED}[-] ${1}${NC}"; }
info() { echo -e "${BLUE}[i] ${1}${NC}"; }

ask() {
	local y
	for ((n = 0; n < 3; n++)); do
		pr "$1 [y/n]"
		if read -r y; then
			if [ "$y" = y ]; then
				return 0
			elif [ "$y" = n ]; then
				return 1
			fi
		fi
		pr "Asking again..."
	done
	return 1
}

# Check minimum requirements
check_requirements() {
    pr "Checking system requirements..."
    
    # Check available storage
    local available_mb
    available_mb=$(df -m "$HOME" | tail -1 | awk '{print $4}')
    if [ "$available_mb" -lt 2000 ]; then
        warn "Low storage: ${available_mb}MB available. At least 2GB recommended."
        if ! ask "Continue anyway?"; then
            exit 1
        fi
    fi
    
    # Check RAM
    local total_ram
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 2000 ]; then
        warn "Low RAM: ${total_ram}MB. Building may be slow or fail."
    fi
}

pr "ReVanced Extended - Termux Builder"
info "Version: $(date +%Y.%m.%d)"
echo ""

pr "Ask for storage permission"
until
	yes | termux-setup-storage >/dev/null 2>&1
	ls /sdcard >/dev/null 2>&1
do sleep 1; done

if [ ! -f ~/.rvmm_"$(date '+%Y%m')" ]; then
	pr "Setting up environment..."
	yes "" | pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" && pkg install -y git curl jq openjdk-17 zip
	: >~/.rvmm_"$(date '+%Y%m')"
fi

check_requirements

OUTPUT_DIR="/sdcard/Download/revanced-extended"
mkdir -p "$OUTPUT_DIR"

if [ -d revanced-extended ] || [ -f config.toml ]; then
	if [ -d revanced-extended ]; then cd revanced-extended; fi
	pr "Checking for revanced-extended updates"
	git fetch
	if git status | grep -q 'is behind\|fatal'; then
		pr "revanced-extended is not synced with upstream."
		pr "Cloning revanced-extended. config.toml will be preserved."
		cd ..
		cp -f revanced-extended/config.toml .
		rm -rf revanced-extended
		git clone https://github.com/thunderkex/revanced-extended --recurse --depth 1
		mv -f config.toml revanced-extended/config.toml
		cd revanced-extended
	fi
else
	pr "Cloning revanced-extended."
	git clone https://github.com/thunderkex/revanced-extended --depth 1
	cd revanced-extended
	sed -i '/^enabled.*/d; /^\[.*\]/a enabled = false' config.toml
	grep -q 'revanced-extended' ~/.gitconfig 2>/dev/null ||
		git config --global --add safe.directory ~/revanced-extended
fi

[ -f ~/storage/downloads/revanced-extended/config.toml ] \
	|| cp config.toml ~/storage/downloads/revanced-extended/config.toml

# Menu for build options
show_menu() {
    echo ""
    info "=== Build Options ==="
    echo "1. Open config generator (web)"
    echo "2. Edit config.toml"
    echo "3. Build with default settings"
    echo "4. Build specific architecture"
    echo "5. Build with lite variants"
    echo "6. Resume previous build"
    echo "7. Clean and rebuild"
    echo "0. Exit"
    echo ""
}

build_with_arch() {
    echo ""
    info "Select architecture:"
    echo "1. arm64-v8a (most devices)"
    echo "2. armeabi-v7a (older devices)"
    echo "3. universal (all architectures)"
    echo "4. all (build separately)"
    read -rp "Choice: " arch_choice
    
    case "$arch_choice" in
        1) export TARGET_ARCH="arm64-v8a" ;;
        2) export TARGET_ARCH="armeabi-v7a" ;;
        3) export TARGET_ARCH="universal" ;;
        4) export TARGET_ARCH="all" ;;
        *) export TARGET_ARCH="arm64-v8a" ;;
    esac
    
    pr "Building for $TARGET_ARCH..."
    ./build.sh
}

if ask "Open rvmm-config-gen to generate a config?"; then
	am start -a android.intent.action.VIEW -d https://j-hc.github.io/rvmm-config-gen/
fi

printf "\n"
until
	if ask "Open 'config.toml' to configure builds?\nAll are disabled by default, you will need to enable at first time building"; then
		am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced-extended/config.toml -t text/plain
	fi
	ask "Setup is done. Do you want to start building?"
do :; done
cp -f ~/storage/downloads/revanced-extended/config.toml config.toml

# Execute build
pr "Starting build process..."
BUILD_START=$(date +%s)

./build.sh

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))
pr "Build completed in $((BUILD_DURATION / 60))m $((BUILD_DURATION % 60))s"

# Copy outputs
cd build
PWD=$(pwd)
COUNT=0
for op in *; do
	[ "$op" = "*" ] && {
		epr "No build outputs found"
		exit 1
	}
	mv -f "${PWD}/${op}" ~/storage/downloads/revanced-extended/"${op}"
	((COUNT++))
done

pr "Successfully built $COUNT files"
pr "Outputs are available in /sdcard/Download/revanced-extended folder"

# Open output folder
am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced-extended -t resource/folder
sleep 2
am start -a android.intent.action.VIEW -d file:///sdcard/Download/revanced-extended -t resource/folder
