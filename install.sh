#!/bin/bash
set -e

# Must be root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

echo ""
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║                                                   ║"
echo "  ║      xxxjihad VPN Manager - Installer             ║"
echo "  ║      Telegram: https://t.me/XxXjihad              ║"
echo "  ║                                                   ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo ""
echo "  Installing xxxjihad VPN Manager..."
echo ""

# URLs
MENU_URL="https://raw.githubusercontent.com/xxxjihad-vpn/xxxjihad-vpn/main/menu.sh"

# Download menu script
echo "  [1/3] Downloading menu script..."
wget -4 -q -O /usr/local/bin/menu "$MENU_URL"
chmod +x /usr/local/bin/menu
echo "  [✓] Menu script installed."

# Run initial setup
echo "  [2/3] Running initial setup..."
bash /usr/local/bin/menu --install-setup

echo "  [3/3] Installation complete!"
echo ""
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║   Installation Complete!                          ║"
echo "  ║   Type 'menu' to start the VPN Manager.          ║"
echo "  ║   Telegram: https://t.me/XxXjihad                ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo ""
