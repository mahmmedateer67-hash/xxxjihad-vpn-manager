#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# xxxjihad VPN Manager - Professional Installer v3.0
# ═══════════════════════════════════════════════════════════════════════════════

# Colors
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_RESET='\033[0m'

# Must be root
if [[ $EUID -ne 0 ]]; then
    echo -e "${C_RED}Error: This script must be run as root.${C_RESET}"
    exit 1
fi

clear
echo -e "${C_CYAN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║                                                   ║"
echo "  ║      xxxjihad VPN Manager - Installer             ║"
echo "  ║      Telegram: https://t.me/XxXjihad              ║"
echo "  ║                                                   ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${C_RESET}"

echo -e "  ${C_BLUE}Starting installation...${C_RESET}"
echo ""

# 1. Install basic dependencies first
echo -e "  ${C_YELLOW}[1/3] Installing basic dependencies (curl, wget, git)...${C_RESET}"
apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq curl wget git > /dev/null 2>&1
echo -e "  ${C_GREEN}[✓] Dependencies installed.${C_RESET}"

# 2. Download the main script and save it as 'xxxjihad'
echo -e "  ${C_YELLOW}[2/3] Downloading main script to /usr/local/bin/xxxjihad...${C_RESET}"
REPO_URL="https://raw.githubusercontent.com/mahmmedateer67-hash/xxxjihad-vpn-manager/master/menu.sh"
TARGET_PATH="/usr/local/bin/xxxjihad"

# Remove old versions if they exist
rm -f "$TARGET_PATH"
rm -f "/usr/local/bin/menu"

# Download using wget
wget -4 -q -O "$TARGET_PATH" "$REPO_URL"

# Verify download
if [[ ! -f "$TARGET_PATH" ]] || [[ ! -s "$TARGET_PATH" ]]; then
    echo -e "  ${C_RED}[✗] Failed to download with wget. Trying curl...${C_RESET}"
    curl -fsSL -4 -o "$TARGET_PATH" "$REPO_URL"
fi

if [[ ! -f "$TARGET_PATH" ]] || [[ ! -s "$TARGET_PATH" ]]; then
    echo -e "  ${C_RED}[✗] Critical Error: Could not download the script.${C_RESET}"
    exit 1
fi

# Set permissions
chmod +x "$TARGET_PATH"
echo -e "  ${C_GREEN}[✓] Script installed successfully as 'xxxjihad'.${C_RESET}"

# 3. Run initial setup
echo -e "  ${C_YELLOW}[3/3] Running system environment setup...${C_RESET}"
# Run the script with the setup flag
bash "$TARGET_PATH" --install-setup

echo ""
echo -e "  ${C_GREEN}${C_BOLD}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}║                                                           ║${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}║   INSTALLATION COMPLETE!                                  ║${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}║                                                           ║${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}║   You can now start the manager by typing:                ║${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}║   👉  xxxjihad                                            ║${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}║                                                           ║${C_RESET}"
echo -e "  ${C_GREEN}${C_BOLD}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
echo ""
