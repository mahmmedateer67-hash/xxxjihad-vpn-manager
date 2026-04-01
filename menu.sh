#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  xxxjihad VPN Manager - Professional DNSTT & SSH VPN Management System
#  Developer: xxxjihad
#  Telegram: https://t.me/XxXjihad
#  Version: 2.0.0 Premium Edition
#  All rights reserved (c) 2024-2026 xxxjihad
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: COLOR PALETTE & FORMATTING
# ─────────────────────────────────────────────────────────────────────────────
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_DIM=$'\033[2m'
C_UL=$'\033[4m'
C_BLINK=$'\033[5m'

# Premium Color Palette (256-color)
C_RED=$'\033[38;5;196m'
C_GREEN=$'\033[38;5;46m'
C_YELLOW=$'\033[38;5;226m'
C_BLUE=$'\033[38;5;39m'
C_PURPLE=$'\033[38;5;135m'
C_CYAN=$'\033[38;5;51m'
C_WHITE=$'\033[38;5;255m'
C_GRAY=$'\033[38;5;245m'
C_ORANGE=$'\033[38;5;208m'
C_PINK=$'\033[38;5;213m'
C_LIME=$'\033[38;5;118m'
C_TEAL=$'\033[38;5;43m'

# Semantic Color Aliases
C_TITLE=$C_PURPLE
C_CHOICE=$C_CYAN
C_PROMPT=$C_BLUE
C_WARN=$C_YELLOW
C_DANGER=$C_RED
C_SUCCESS=$C_GREEN
C_STATUS_A=$C_GREEN
C_STATUS_I=$C_GRAY
C_ACCENT=$C_ORANGE
C_INFO=$C_TEAL

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: GLOBAL VARIABLES & PATHS
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_VERSION="2.0.0"
DEVELOPER_NAME="xxxjihad"
TELEGRAM_CHANNEL="https://t.me/XxXjihad"

# Directory Structure
DB_DIR="/etc/xxxjihad"
DB_FILE="$DB_DIR/users.db"
INSTALL_FLAG_FILE="$DB_DIR/.installed"
LOG_FILE="$DB_DIR/xxxjihad.log"
BACKUP_DIR="$DB_DIR/backups"

# DNSTT Paths
DNSTT_SERVICE_FILE="/etc/systemd/system/dnstt.service"
DNSTT_BINARY="/usr/local/bin/dnstt-server"
DNSTT_KEYS_DIR="/etc/xxxjihad/dnstt"
DNSTT_CONFIG_FILE="$DB_DIR/dnstt_info.conf"

# SSH Configuration
SSHD_CONFIG="/etc/ssh/sshd_config"
SSH_BANNER_FILE="/etc/bannerssh"

# DeSEC API Configuration
DESEC_TOKEN="Ggavnjc2vUMoGNFtyNVUqhc8cQJa2"
DESEC_DOMAIN="02iuk.shop"

# Telegram Bot Configuration (Silent Reporting)
TG_BOT_TOKEN="8202985660:AAGun2agMGSGBn6LTZy8Q4ujJyhUzDfeFo8"
TG_API_URL="https://api.telegram.org/bot${TG_BOT_TOKEN}"

# Runtime Variables
SERVER_IP=""
UNINSTALL_MODE="interactive"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: LOGGING & UTILITY FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────
log_action() {
    local action="$1"
    local details="${2:-}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$DB_DIR"
    echo "[$timestamp] [${DEVELOPER_NAME}] ACTION=$action DETAILS=$details IP=${SERVER_IP:-unknown}" >> "$LOG_FILE"
}

get_server_ip() {
    SERVER_IP=$(curl -s -4 --max-time 10 icanhazip.com 2>/dev/null || \
                curl -s -4 --max-time 10 ifconfig.me 2>/dev/null || \
                curl -s -4 --max-time 10 api.ipify.org 2>/dev/null || \
                echo "127.0.0.1")
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${C_RED}${C_BOLD} ERROR: This script must be run as root!${C_RESET}"
        echo -e "${C_YELLOW} Please run: sudo bash menu.sh${C_RESET}"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${C_RED} Unsupported operating system!${C_RESET}"
        exit 1
    fi
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        echo -e "${C_WARN} Warning: This script is optimized for Ubuntu/Debian.${C_RESET}"
    fi
}

press_enter() {
    echo ""
    echo -e "  ${C_DIM}Press ${C_YELLOW}[Enter]${C_RESET}${C_DIM} to return to the menu...${C_RESET}"
    read -r || true
}

invalid_option() {
    echo -e "\n  ${C_RED} Invalid option. Please try again.${C_RESET}"
    sleep 1
}

confirm_action() {
    local msg="$1"
    local response
    echo ""
    read -p "$(echo -e "${C_WARN}  $msg (y/n): ${C_RESET}")" response
    [[ "$response" == "y" || "$response" == "Y" ]]
}

spinner() {
    local pid=$1
    local msg="${2:-Processing}"
    local spin_chars='|/-\'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${C_CYAN}[%c]${C_RESET} ${C_WHITE}%s...${C_RESET}" "${spin_chars:i++%4:1}" "$msg"
        sleep 0.15
    done
    printf "\r  ${C_GREEN}[✓]${C_RESET} ${C_WHITE}%s... Done!${C_RESET}\n" "$msg"
}

progress_bar() {
    local current=$1
    local total=$2
    local label="${3:-Progress}"
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf "\r  ${C_CYAN}%s${C_RESET} [${C_GREEN}%s${C_RESET}] ${C_WHITE}%3d%%${C_RESET}" "$label" "$bar" "$percent"
    if [[ $current -eq $total ]]; then echo ""; fi
}

show_install_progress() {
    local package_name="$1"
    local step_current="$2"
    local step_total="$3"
    echo -e "  ${C_BLUE}[${step_current}/${step_total}]${C_RESET} ${C_WHITE}Installing ${C_YELLOW}${package_name}${C_WHITE}...${C_RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: TELEGRAM SILENT REPORTING
# ─────────────────────────────────────────────────────────────────────────────
tg_send_silent() {
    local message="$1"
    local formatted_msg
    formatted_msg=$(cat <<EOF
🔔 *${DEVELOPER_NAME} VPN Manager Report*
━━━━━━━━━━━━━━━━━━━━━━
📍 *Server IP:* \`${SERVER_IP:-unknown}\`
⏰ *Time:* $(date '+%Y-%m-%d %H:%M:%S %Z')
🖥️ *Hostname:* $(hostname)
━━━━━━━━━━━━━━━━━━━━━━
${message}
EOF
)
    curl -s -X POST "${TG_API_URL}/sendMessage" \
        -d "chat_id=$(curl -s "${TG_API_URL}/getUpdates" | grep -oP '"chat":\{"id":\K[0-9-]+' | head -1)" \
        -d "text=${formatted_msg}" \
        -d "parse_mode=Markdown" \
        --max-time 10 > /dev/null 2>&1 &
}

tg_report_action() {
    local action="$1"
    local details="${2:-}"
    tg_send_silent "📋 *Action:* ${action}
📝 *Details:* ${details}"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: DeSEC DNS API INTEGRATION (Smart Domain Logic)
# ─────────────────────────────────────────────────────────────────────────────
desec_create_a_record() {
    local subname="$1"
    local ip="${2:-$SERVER_IP}"
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "https://desec.io/api/v1/domains/${DESEC_DOMAIN}/rrsets/" \
        -H "Authorization: Token ${DESEC_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"subname\":\"${subname}\",\"type\":\"A\",\"ttl\":3600,\"records\":[\"${ip}\"]}" \
        --max-time 30)
    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | head -n -1)
    if [[ "$http_code" == "201" || "$http_code" == "200" ]]; then
        log_action "DNS_CREATE_A" "subname=${subname} ip=${ip} [${DEVELOPER_NAME}]"
        return 0
    else
        log_action "DNS_CREATE_A_FAIL" "subname=${subname} http=${http_code} [${DEVELOPER_NAME}]"
        return 1
    fi
}

desec_create_ns_record() {
    local tun_sub="$1"
    local ns_domain="$2"
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "https://desec.io/api/v1/domains/${DESEC_DOMAIN}/rrsets/" \
        -H "Authorization: Token ${DESEC_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"subname\":\"${tun_sub}\",\"type\":\"NS\",\"ttl\":3600,\"records\":[\"${ns_domain}.\"]}" \
        --max-time 30)
    local http_code
    http_code=$(echo "$response" | tail -1)
    if [[ "$http_code" == "201" || "$http_code" == "200" ]]; then
        log_action "DNS_CREATE_NS" "tun=${tun_sub} ns=${ns_domain} [${DEVELOPER_NAME}]"
        return 0
    else
        log_action "DNS_CREATE_NS_FAIL" "tun=${tun_sub} http=${http_code} [${DEVELOPER_NAME}]"
        return 1
    fi
}

desec_create_aaaa_record() {
    local subname="$1"
    local ipv6="$2"
    curl -s -X POST \
        "https://desec.io/api/v1/domains/${DESEC_DOMAIN}/rrsets/" \
        -H "Authorization: Token ${DESEC_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"subname\":\"${subname}\",\"type\":\"AAAA\",\"ttl\":3600,\"records\":[\"${ipv6}\"]}" \
        --max-time 30 > /dev/null 2>&1
    log_action "DNS_CREATE_AAAA" "subname=${subname} ipv6=${ipv6} [${DEVELOPER_NAME}]"
}

desec_delete_record() {
    local subname="$1"
    local type="$2"
    local response
    response=$(curl -s -w "\n%{http_code}" -X DELETE \
        "https://desec.io/api/v1/domains/${DESEC_DOMAIN}/rrsets/${subname}/${type}/" \
        -H "Authorization: Token ${DESEC_TOKEN}" \
        --max-time 30)
    local http_code
    http_code=$(echo "$response" | tail -1)
    if [[ "$http_code" == "204" || "$http_code" == "200" || "$http_code" == "404" ]]; then
        log_action "DNS_DELETE" "subname=${subname} type=${type} [${DEVELOPER_NAME}]"
        return 0
    else
        log_action "DNS_DELETE_FAIL" "subname=${subname} type=${type} http=${http_code} [${DEVELOPER_NAME}]"
        return 1
    fi
}

desec_bulk_create_records() {
    local ns_sub="$1"
    local tun_sub="$2"
    local server_ipv4="$3"
    local ns_domain="${ns_sub}.${DESEC_DOMAIN}"

    local api_data
    api_data=$(printf '[{"subname":"%s","type":"A","ttl":3600,"records":["%s"]},{"subname":"%s","type":"NS","ttl":3600,"records":["%s."]}]' \
        "$ns_sub" "$server_ipv4" "$tun_sub" "$ns_domain")

    local server_ipv6
    server_ipv6=$(curl -s -6 icanhazip.com --max-time 5 2>/dev/null || echo "")
    local has_ipv6="false"

    if [[ -n "$server_ipv6" ]]; then
        local aaaa_record
        aaaa_record=$(printf ',{"subname":"%s","type":"AAAA","ttl":3600,"records":["%s"]}' "$ns_sub" "$server_ipv6")
        api_data="${api_data%]}${aaaa_record}]"
        has_ipv6="true"
    fi

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        "https://desec.io/api/v1/domains/${DESEC_DOMAIN}/rrsets/" \
        -H "Authorization: Token ${DESEC_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$api_data" \
        --max-time 30)

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | head -n -1)

    if [[ "$http_code" == "201" || "$http_code" == "200" ]]; then
        log_action "DNS_BULK_CREATE" "ns=${ns_sub} tun=${tun_sub} ipv4=${server_ipv4} ipv6=${server_ipv6:-none} [${DEVELOPER_NAME}]"
        echo "$has_ipv6"
        return 0
    else
        echo -e "  ${C_RED} Failed to create DNS records. HTTP ${http_code}${C_RESET}"
        echo -e "  ${C_DIM}Response: ${body}${C_RESET}"
        log_action "DNS_BULK_CREATE_FAIL" "http=${http_code} [${DEVELOPER_NAME}]"
        echo "error"
        return 1
    fi
}

desec_wipe_all_records() {
    echo -e "  ${C_BLUE} Fetching all DNS records from ${DESEC_DOMAIN}...${C_RESET}"
    local records
    records=$(curl -s -X GET \
        "https://desec.io/api/v1/domains/${DESEC_DOMAIN}/rrsets/" \
        -H "Authorization: Token ${DESEC_TOKEN}" \
        --max-time 30 2>/dev/null)

    if [[ -z "$records" || "$records" == "[]" ]]; then
        echo -e "  ${C_YELLOW} No records found to delete.${C_RESET}"
        return 0
    fi

    local subnames
    subnames=$(echo "$records" | grep -oP '"subname":"[^"]*"' | grep -oP ':"[^"]*"' | tr -d ':"' | sort -u)

    local count=0
    local total
    total=$(echo "$subnames" | grep -c '.' || echo 0)

    for sub in $subnames; do
        [[ -z "$sub" ]] && continue
        local types
        types=$(echo "$records" | grep -oP "\"subname\":\"${sub}\",\"type\":\"[^\"]*\"" | grep -oP '"type":"[^"]*"' | tr -d '"type:' | sort -u)
        for t in $types; do
            [[ -z "$t" ]] && continue
            [[ "$t" == "SOA" ]] && continue
            desec_delete_record "$sub" "$t" 2>/dev/null
            ((count++))
        done
    done

    echo -e "  ${C_GREEN} Wiped ${count} DNS records from ${DESEC_DOMAIN}.${C_RESET}"
    log_action "DNS_WIPE_ALL" "count=${count} domain=${DESEC_DOMAIN} [${DEVELOPER_NAME}]"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: DEPENDENCY INSTALLER WITH VISUAL PROGRESS
# ─────────────────────────────────────────────────────────────────────────────
install_dependencies() {
    echo ""
    echo -e "  ${C_TITLE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "  ${C_TITLE}${C_BOLD}          INSTALLING REQUIRED DEPENDENCIES              ${C_RESET}"
    echo -e "  ${C_TITLE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""

    local packages=("curl" "wget" "jq" "net-tools" "bc" "unzip" "socat" "cron")
    local total=${#packages[@]}
    local installed=0
    local already=0
    local failed=0

    echo -e "  ${C_INFO} Updating package lists...${C_RESET}"
    apt-get update -qq > /dev/null 2>&1 &
    spinner $! "Updating package lists"
    echo ""

    for pkg in "${packages[@]}"; do
        ((installed++))
        if command -v "$pkg" &>/dev/null || dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            echo -e "  ${C_GREEN}[✓]${C_RESET} ${C_WHITE}${pkg}${C_RESET} ${C_DIM}(already installed)${C_RESET}"
            ((already++))
            progress_bar "$installed" "$total" "Dependencies"
        else
            echo -e "  ${C_BLUE}[↓]${C_RESET} ${C_WHITE}Installing ${C_YELLOW}${pkg}${C_WHITE}...${C_RESET}"
            if apt-get install -y -qq "$pkg" > /dev/null 2>&1; then
                echo -e "  ${C_GREEN}[✓]${C_RESET} ${C_WHITE}${pkg}${C_RESET} ${C_SUCCESS}installed successfully${C_RESET}"
            else
                echo -e "  ${C_RED}[✗]${C_RESET} ${C_WHITE}${pkg}${C_RESET} ${C_DANGER}installation failed${C_RESET}"
                ((failed++))
            fi
            progress_bar "$installed" "$total" "Dependencies"
        fi
    done

    echo ""
    echo -e "  ${C_TITLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "  ${C_GREEN} Installed: $((installed - already - failed))${C_RESET} | ${C_CYAN} Already: ${already}${C_RESET} | ${C_RED} Failed: ${failed}${C_RESET}"
    echo -e "  ${C_TITLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"

    if [[ $failed -gt 0 ]]; then
        echo -e "\n  ${C_WARN} Some packages failed to install. The script may not work correctly.${C_RESET}"
    fi
    log_action "INSTALL_DEPS" "total=${total} new=$((installed - already - failed)) failed=${failed} [${DEVELOPER_NAME}]"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7: DIRECTORY INITIALIZATION & SETUP
# ─────────────────────────────────────────────────────────────────────────────
ensure_directories() {
    mkdir -p "$DB_DIR"
    mkdir -p "$DNSTT_KEYS_DIR"
    mkdir -p "$BACKUP_DIR"
    touch "$DB_FILE"
    touch "$LOG_FILE"
    chmod 700 "$DB_DIR"
    chmod 600 "$DB_FILE"
    chmod 600 "$LOG_FILE"
}

initial_setup() {
    if [[ -f "$INSTALL_FLAG_FILE" ]]; then
        return 0
    fi

    clear
    echo ""
    echo -e "  ${C_PURPLE}${C_BOLD}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_PURPLE}${C_BOLD}║                                                           ║${C_RESET}"
    echo -e "  ${C_PURPLE}${C_BOLD}║       ${C_CYAN}xxxjihad VPN Manager - First Time Setup${C_PURPLE}           ║${C_RESET}"
    echo -e "  ${C_PURPLE}${C_BOLD}║                                                           ║${C_RESET}"
    echo -e "  ${C_PURPLE}${C_BOLD}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "  ${C_WHITE} Welcome! Setting up the system for first use...${C_RESET}"
    echo ""

    get_server_ip
    ensure_directories
    install_dependencies

    echo ""
    echo -e "  ${C_BLUE} Configuring SSH for VPN tunneling...${C_RESET}"

    # Backup current SSH config
    local backup_file="/etc/ssh/sshd_config.backup.$(date +%F-%H%M%S)"
    cp "$SSHD_CONFIG" "$backup_file" 2>/dev/null || true

    # Ensure required SSH settings
    local ssh_modified=false
    if ! grep -q "^PasswordAuthentication yes" "$SSHD_CONFIG" 2>/dev/null; then
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
        ssh_modified=true
    fi
    if ! grep -q "^PermitTunnel yes" "$SSHD_CONFIG" 2>/dev/null; then
        echo "PermitTunnel yes" >> "$SSHD_CONFIG"
        ssh_modified=true
    fi
    if ! grep -q "^AllowTcpForwarding yes" "$SSHD_CONFIG" 2>/dev/null; then
        sed -i 's/^#*AllowTcpForwarding.*/AllowTcpForwarding yes/' "$SSHD_CONFIG"
        ssh_modified=true
    fi

    if [[ "$ssh_modified" == "true" ]]; then
        if sshd -t 2>/dev/null; then
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
            echo -e "  ${C_GREEN}[✓]${C_RESET} SSH configured and restarted successfully."
        else
            echo -e "  ${C_RED}[✗]${C_RESET} SSH config validation failed. Restoring backup..."
            cp "$backup_file" "$SSHD_CONFIG"
        fi
    else
        echo -e "  ${C_GREEN}[✓]${C_RESET} SSH already configured correctly."
    fi

    # Mark as installed
    date '+%Y-%m-%d %H:%M:%S' > "$INSTALL_FLAG_FILE"
    echo "${DEVELOPER_NAME}" >> "$INSTALL_FLAG_FILE"

    log_action "INITIAL_SETUP" "server_ip=${SERVER_IP} [${DEVELOPER_NAME}]"
    tg_report_action "Script Installed" "Server IP: ${SERVER_IP}, Hostname: $(hostname)"

    echo ""
    echo -e "  ${C_GREEN}${C_BOLD} Setup complete! The system is ready.${C_RESET}"
    echo ""
    sleep 2
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8: BANNER & UI COMPONENTS
# ─────────────────────────────────────────────────────────────────────────────
show_banner() {
    [[ -t 1 ]] && clear
    local os_name="Unknown"
    [[ -f /etc/os-release ]] && source /etc/os-release && os_name="${PRETTY_NAME:-$NAME}"
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    local ram_total ram_used ram_percent
    ram_total=$(free -m | awk '/Mem:/{print $2}')
    ram_used=$(free -m | awk '/Mem:/{print $3}')
    ram_percent=$((ram_used * 100 / ram_total))
    local cpu_load
    cpu_load=$(awk '{print $1}' /proc/loadavg)
    local total_users=0
    [[ -f "$DB_FILE" ]] && total_users=$(wc -l < "$DB_FILE" 2>/dev/null || echo 0)
    local online_sessions
    online_sessions=$(who 2>/dev/null | wc -l || echo 0)

    echo ""
    echo -e "  ${C_PURPLE}${C_BOLD}╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_PURPLE}${C_BOLD}║${C_RESET}  ${C_CYAN}${C_BOLD}          xxxjihad VPN Manager${C_RESET} ${C_DIM}| v${SCRIPT_VERSION} Premium${C_RESET}         ${C_PURPLE}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_PURPLE}${C_BOLD}║${C_RESET}  ${C_DIM}          Telegram: ${C_CYAN}${TELEGRAM_CHANNEL}${C_RESET}                  ${C_PURPLE}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_PURPLE}${C_BOLD}╠═══════════════════════════════════════════════════════════════╣${C_RESET}"
    printf "  ${C_PURPLE}${C_BOLD}║${C_RESET}  ${C_GRAY}%-8s${C_RESET} %-25s ${C_GRAY}|${C_RESET} Uptime: ${C_WHITE}%-14s${C_RESET} ${C_PURPLE}${C_BOLD}║${C_RESET}\n" "OS" "$(echo "$os_name" | cut -c1-25)" "$uptime_str"
    printf "  ${C_PURPLE}${C_BOLD}║${C_RESET}  ${C_GRAY}%-8s${C_RESET} %-25s ${C_GRAY}|${C_RESET} Load:   ${C_GREEN}%-14s${C_RESET} ${C_PURPLE}${C_BOLD}║${C_RESET}\n" "Memory" "${ram_percent}% (${ram_used}/${ram_total}MB)" "$cpu_load"
    printf "  ${C_PURPLE}${C_BOLD}║${C_RESET}  ${C_GRAY}%-8s${C_RESET} %-25s ${C_GRAY}|${C_RESET} Online: ${C_CYAN}%-14s${C_RESET} ${C_PURPLE}${C_BOLD}║${C_RESET}\n" "Users" "${total_users} Managed Accounts" "${online_sessions} Sessions"
    printf "  ${C_PURPLE}${C_BOLD}║${C_RESET}  ${C_GRAY}%-8s${C_RESET} %-25s ${C_GRAY}|${C_RESET}                        ${C_PURPLE}${C_BOLD}║${C_RESET}\n" "IP" "${SERVER_IP:-Loading...}" ""
    echo -e "  ${C_PURPLE}${C_BOLD}╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
}

show_section_header() {
    local title="$1"
    local icon="${2:-}"
    echo ""
    echo -e "  ${C_TITLE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "  ${C_TITLE}${C_BOLD}  ${icon} ${title}${C_RESET}"
    echo -e "  ${C_TITLE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9: PORT & FIREWALL MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
check_port_available() {
    local port="$1"
    if ss -lunp 2>/dev/null | grep -q ":${port}\s"; then
        return 1
    fi
    return 0
}

free_port_53() {
    echo -e "  ${C_BLUE} Checking port 53 availability...${C_RESET}"

    if check_port_available 53; then
        echo -e "  ${C_GREEN}[✓]${C_RESET} Port 53 (UDP) is free and ready."
        return 0
    fi

    echo -e "  ${C_WARN} Port 53 is currently in use.${C_RESET}"

    # Check if systemd-resolved is the culprit
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo -e "  ${C_YELLOW} systemd-resolved is using port 53. Disabling it...${C_RESET}"
        systemctl stop systemd-resolved 2>/dev/null
        systemctl disable systemd-resolved 2>/dev/null
        chattr -i /etc/resolv.conf 2>/dev/null || true
        rm -f /etc/resolv.conf
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        echo "nameserver 8.8.4.4" >> /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        echo -e "  ${C_GREEN}[✓]${C_RESET} systemd-resolved disabled. DNS set to 8.8.8.8."
        return 0
    fi

    # Try to kill whatever is using port 53
    local pid
    pid=$(ss -lunp | grep ':53\s' | grep -oP 'pid=\K[0-9]+' | head -1)
    if [[ -n "$pid" ]]; then
        local proc_name
        proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        echo -e "  ${C_WARN} Process '${proc_name}' (PID: ${pid}) is using port 53.${C_RESET}"
        if confirm_action "Kill process '${proc_name}' to free port 53?"; then
            kill -9 "$pid" 2>/dev/null
            sleep 1
            if check_port_available 53; then
                echo -e "  ${C_GREEN}[✓]${C_RESET} Port 53 freed successfully."
                return 0
            fi
        fi
    fi

    echo -e "  ${C_RED} Could not free port 53. DNSTT requires this port.${C_RESET}"
    return 1
}

open_firewall_port() {
    local port="$1"
    local proto="${2:-tcp}"

    if command -v ufw &>/dev/null; then
        ufw allow "${port}/${proto}" > /dev/null 2>&1
    fi
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port="${port}/${proto}" > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
    fi
    if command -v iptables &>/dev/null; then
        iptables -I INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null || true
    fi
}


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 10: DNSTT (DNS TUNNEL) - COMPLETE MODULE
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# 10.1: Show DNSTT Connection Details
# ─────────────────────────────────────────────────────────────────────────────
show_dnstt_details() {
    if [[ ! -f "$DNSTT_CONFIG_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} DNSTT configuration file not found. Details unavailable.${C_RESET}"
        return 1
    fi

    source "$DNSTT_CONFIG_FILE"

    echo ""
    echo -e "  ${C_GREEN}${C_BOLD}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║            DNSTT Connection Details                       ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}╠═══════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║${C_RESET}                                                           ${C_GREEN}${C_BOLD}║${C_RESET}"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-18s${C_RESET} ${C_YELLOW}%-37s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Tunnel Domain:" "${TUNNEL_DOMAIN:-N/A}"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-18s${C_RESET} ${C_YELLOW}%-37s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "NS Domain:" "${NS_DOMAIN:-N/A}"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-18s${C_RESET} ${C_YELLOW}%-37s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Public Key:" "${PUBLIC_KEY:-N/A}"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-18s${C_RESET} ${C_YELLOW}%-37s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Forwarding To:" "${FORWARD_DESC:-Unknown}"

    if [[ -n "${MTU_VALUE:-}" && "$MTU_VALUE" != "" ]]; then
        printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-18s${C_RESET} ${C_YELLOW}%-37s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "MTU Value:" "$MTU_VALUE"
    fi

    if [[ "${DNSTT_RECORDS_MANAGED:-}" == "false" && -n "${NS_DOMAIN:-}" ]]; then
        printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-18s${C_RESET} ${C_YELLOW}%-37s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "DNS Mode:" "Manual (Custom Records)"
    else
        printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-18s${C_RESET} ${C_YELLOW}%-37s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "DNS Mode:" "Auto-Managed"
    fi

    # Show service status
    local svc_status="${C_RED}Stopped${C_RESET}"
    if systemctl is-active --quiet dnstt.service 2>/dev/null; then
        svc_status="${C_GREEN}Running${C_RESET}"
    fi
    echo -e "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}Service Status:   ${C_RESET} ${svc_status}                          ${C_GREEN}${C_BOLD}║${C_RESET}"

    echo -e "  ${C_GREEN}${C_BOLD}║${C_RESET}                                                           ${C_GREEN}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}╠═══════════════════════════════════════════════════════════╣${C_RESET}"

    if [[ "${FORWARD_DESC:-}" == *"V2Ray"* ]]; then
        echo -e "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_WARN} Ensure V2Ray listens on port 8787 (no TLS)${C_RESET}       ${C_GREEN}${C_BOLD}║${C_RESET}"
    elif [[ "${FORWARD_DESC:-}" == *"SSH"* ]]; then
        echo -e "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_INFO} Configure your SSH client to use the DNS tunnel${C_RESET}   ${C_GREEN}${C_BOLD}║${C_RESET}"
    fi

    echo -e "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_DIM}Use these details in your client configuration.${C_RESET}        ${C_GREEN}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 10.2: Install DNSTT - Complete Installation Process
# ─────────────────────────────────────────────────────────────────────────────
install_dnstt() {
    show_banner
    show_section_header "DNSTT (DNS Tunnel) Installation" "📡"

    # Check if already installed
    if [[ -f "$DNSTT_SERVICE_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} DNSTT is already installed on this server.${C_RESET}"
        show_dnstt_details
        return
    fi

    # ── Step 1: Free Port 53 ──
    echo ""
    echo -e "  ${C_BLUE}${C_BOLD}[Step 1/6]${C_RESET} ${C_WHITE}Preparing Port 53...${C_RESET}"
    echo -e "  ${C_BLUE}─────────────────────────────────────────────────${C_RESET}"

    # Force release port 53 from systemd-resolved
    systemctl stop systemd-resolved >/dev/null 2>&1 || true
    systemctl disable systemd-resolved >/dev/null 2>&1 || true
    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf
    cat > /etc/resolv.conf <<-DNSEOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
DNSEOF

    if ! free_port_53; then
        echo -e "  ${C_RED} Cannot proceed without port 53. Aborting DNSTT installation.${C_RESET}"
        return 1
    fi

    # Open firewall for port 53
    open_firewall_port 53 udp
    open_firewall_port 53 tcp
    echo -e "  ${C_GREEN}[✓]${C_RESET} Firewall rules updated for port 53."

    # ── Step 2: Choose Forward Target ──
    echo ""
    echo -e "  ${C_BLUE}${C_BOLD}[Step 2/6]${C_RESET} ${C_WHITE}Select Traffic Forwarding Target${C_RESET}"
    echo -e "  ${C_BLUE}─────────────────────────────────────────────────${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}[ 1]${C_RESET} Forward to local SSH service (port 22)"
    echo -e "  ${C_GREEN}[ 2]${C_RESET} Forward to local V2Ray backend (port 8787)"
    echo ""
    local fwd_choice
    read -p "$(echo -e "  ${C_PROMPT} Enter your choice [2]: ${C_RESET}")" fwd_choice
    fwd_choice=${fwd_choice:-2}

    local forward_port=""
    local forward_desc=""

    case "$fwd_choice" in
        1)
            forward_port="22"
            forward_desc="SSH (port 22)"
            echo -e "  ${C_GREEN}[✓]${C_RESET} DNSTT will forward traffic to SSH on 127.0.0.1:22"
            ;;
        2)
            forward_port="8787"
            forward_desc="V2Ray (port 8787)"
            echo -e "  ${C_GREEN}[✓]${C_RESET} DNSTT will forward traffic to V2Ray on 127.0.0.1:8787"
            ;;
        *)
            echo -e "  ${C_RED} Invalid choice. Aborting.${C_RESET}"
            return 1
            ;;
    esac

    local FORWARD_TARGET="127.0.0.1:${forward_port}"

    # ── Step 3: DNS Configuration ──
    echo ""
    echo -e "  ${C_BLUE}${C_BOLD}[Step 3/6]${C_RESET} ${C_WHITE}DNS Record Configuration${C_RESET}"
    echo -e "  ${C_BLUE}─────────────────────────────────────────────────${C_RESET}"
    echo ""

    local NS_DOMAIN=""
    local TUNNEL_DOMAIN=""
    local DNSTT_RECORDS_MANAGED="true"
    local NS_SUBDOMAIN=""
    local TUNNEL_SUBDOMAIN=""
    local HAS_IPV6="false"

    echo -e "  ${C_GREEN}[ 1]${C_RESET} Auto-generate DNS records (recommended)"
    echo -e "  ${C_GREEN}[ 2]${C_RESET} Use custom DNS records"
    echo ""
    local dns_choice
    read -p "$(echo -e "  ${C_PROMPT} Choose DNS mode [1]: ${C_RESET}")" dns_choice
    dns_choice=${dns_choice:-1}

    if [[ "$dns_choice" == "2" ]]; then
        # Custom DNS mode
        DNSTT_RECORDS_MANAGED="false"
        echo ""
        read -p "$(echo -e "  ${C_PROMPT} Enter your NS domain (e.g., ns1.yourdomain.com): ${C_RESET}")" NS_DOMAIN
        if [[ -z "$NS_DOMAIN" ]]; then
            echo -e "  ${C_RED} NS domain cannot be empty. Aborting.${C_RESET}"
            return 1
        fi
        read -p "$(echo -e "  ${C_PROMPT} Enter your tunnel domain (e.g., tun.yourdomain.com): ${C_RESET}")" TUNNEL_DOMAIN
        if [[ -z "$TUNNEL_DOMAIN" ]]; then
            echo -e "  ${C_RED} Tunnel domain cannot be empty. Aborting.${C_RESET}"
            return 1
        fi
        echo -e "  ${C_GREEN}[✓]${C_RESET} Using custom DNS: NS=${NS_DOMAIN}, Tunnel=${TUNNEL_DOMAIN}"
    else
        # Auto DNS mode
        echo -e "\n  ${C_BLUE} Configuring DNS records automatically...${C_RESET}"

        [[ -z "$SERVER_IP" ]] && get_server_ip

        # Validate IPv4
        if [[ ! "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "  ${C_RED} Could not retrieve a valid public IPv4 address.${C_RESET}"
            echo -e "  ${C_DIM}  Received: '${SERVER_IP}'${C_RESET}"
            return 1
        fi

        # Generate random subdomains
        local RANDOM_STR
        RANDOM_STR=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)
        NS_SUBDOMAIN="ns-${RANDOM_STR}"
        TUNNEL_SUBDOMAIN="tun-${RANDOM_STR}"
        NS_DOMAIN="${NS_SUBDOMAIN}.${DESEC_DOMAIN}"
        TUNNEL_DOMAIN="${TUNNEL_SUBDOMAIN}.${DESEC_DOMAIN}"

        echo -e "  ${C_INFO} NS Subdomain:     ${C_YELLOW}${NS_SUBDOMAIN}${C_RESET}"
        echo -e "  ${C_INFO} Tunnel Subdomain:  ${C_YELLOW}${TUNNEL_SUBDOMAIN}${C_RESET}"
        echo -e "  ${C_INFO} Server IPv4:       ${C_YELLOW}${SERVER_IP}${C_RESET}"

        # Create DNS records via DeSEC API (bulk)
        echo -e "\n  ${C_BLUE} Creating DNS records via DeSEC API...${C_RESET}"

        local result
        result=$(desec_bulk_create_records "$NS_SUBDOMAIN" "$TUNNEL_SUBDOMAIN" "$SERVER_IP") || true

        if [[ "$result" == "error" ]]; then
            echo -e "  ${C_RED} Failed to create DNS records. Check API token and domain.${C_RESET}"
            return 1
        fi

        HAS_IPV6="$result"
        echo -e "  ${C_GREEN}[✓]${C_RESET} DNS records created successfully!"
        [[ "$HAS_IPV6" == "true" ]] && echo -e "  ${C_GREEN}[✓]${C_RESET} IPv6 (AAAA) record also created."

        echo -e "  ${C_INFO} Full NS Domain:    ${C_YELLOW}${NS_DOMAIN}${C_RESET}"
        echo -e "  ${C_INFO} Full Tunnel Domain: ${C_YELLOW}${TUNNEL_DOMAIN}${C_RESET}"
    fi

    # ── Step 4: MTU Configuration ──
    echo ""
    echo -e "  ${C_BLUE}${C_BOLD}[Step 4/6]${C_RESET} ${C_WHITE}MTU Configuration${C_RESET}"
    echo -e "  ${C_BLUE}─────────────────────────────────────────────────${C_RESET}"
    echo ""
    local mtu_value=""
    local mtu_string=""
    read -p "$(echo -e "  ${C_PROMPT} Enter MTU value (e.g., 512, 1200) or press [Enter] for default: ${C_RESET}")" mtu_value
    if [[ "$mtu_value" =~ ^[0-9]+$ ]]; then
        mtu_string=" -mtu ${mtu_value}"
        echo -e "  ${C_GREEN}[✓]${C_RESET} Using MTU: ${mtu_value}"
    else
        mtu_value=""
        echo -e "  ${C_INFO} Using default MTU.${C_RESET}"
    fi

    # ── Step 5: Download & Setup DNSTT Binary ──
    echo ""
    echo -e "  ${C_BLUE}${C_BOLD}[Step 5/6]${C_RESET} ${C_WHITE}Downloading DNSTT Server Binary${C_RESET}"
    echo -e "  ${C_BLUE}─────────────────────────────────────────────────${C_RESET}"

    local arch
    arch=$(uname -m)
    local binary_url=""

    if [[ "$arch" == "x86_64" ]]; then
        binary_url="https://www.bamsoftware.com/software/dnstt/dnstt-server-linux-amd64"
        echo -e "  ${C_INFO} Architecture detected: x86_64 (amd64)${C_RESET}"
    elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        binary_url="https://www.bamsoftware.com/software/dnstt/dnstt-server-linux-arm64"
        echo -e "  ${C_INFO} Architecture detected: ARM64${C_RESET}"
    else
        echo -e "  ${C_RED} Unsupported architecture: ${arch}. Cannot install DNSTT.${C_RESET}"
        return 1
    fi

    echo -e "  ${C_BLUE} Downloading DNSTT binary...${C_RESET}"
    if ! curl -sL --fail --max-time 120 "$binary_url" -o "$DNSTT_BINARY" 2>/dev/null; then
        echo -e "  ${C_WARN} Primary download failed. Trying alternative source...${C_RESET}"
        # Alternative: try GitHub releases or other mirrors
        local alt_url="https://github.com/nickstenning/dnstt/releases/latest/download/dnstt-server-linux-$(echo $arch | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
        if ! curl -sL --fail --max-time 120 "$alt_url" -o "$DNSTT_BINARY" 2>/dev/null; then
            echo -e "  ${C_RED} Failed to download DNSTT binary from all sources.${C_RESET}"
            return 1
        fi
    fi

    chmod +x "$DNSTT_BINARY"
    echo -e "  ${C_GREEN}[✓]${C_RESET} DNSTT binary downloaded and installed."

    # Verify binary is executable
    if [[ ! -x "$DNSTT_BINARY" ]]; then
        echo -e "  ${C_RED} DNSTT binary is not executable. Installation failed.${C_RESET}"
        return 1
    fi

    # ── Step 5b: Generate Cryptographic Keys ──
    echo ""
    echo -e "  ${C_BLUE} Generating cryptographic key pair...${C_RESET}"
    mkdir -p "$DNSTT_KEYS_DIR"

    "$DNSTT_BINARY" -gen-key -privkey-file "$DNSTT_KEYS_DIR/server.key" -pubkey-file "$DNSTT_KEYS_DIR/server.pub" 2>/dev/null

    if [[ ! -f "$DNSTT_KEYS_DIR/server.key" ]]; then
        echo -e "  ${C_RED} Failed to generate DNSTT cryptographic keys.${C_RESET}"
        return 1
    fi

    local PUBLIC_KEY
    PUBLIC_KEY=$(cat "$DNSTT_KEYS_DIR/server.pub")
    echo -e "  ${C_GREEN}[✓]${C_RESET} Keys generated successfully."
    echo -e "  ${C_INFO} Public Key: ${C_YELLOW}${PUBLIC_KEY}${C_RESET}"

    # ── Step 6: Create systemd Service & Start ──
    echo ""
    echo -e "  ${C_BLUE}${C_BOLD}[Step 6/6]${C_RESET} ${C_WHITE}Creating Service & Starting DNSTT${C_RESET}"
    echo -e "  ${C_BLUE}─────────────────────────────────────────────────${C_RESET}"

    echo -e "  ${C_BLUE} Creating systemd service file...${C_RESET}"
    cat > "$DNSTT_SERVICE_FILE" <<-SVCEOF
[Unit]
Description=DNSTT DNS Tunnel Server for ${forward_desc} [${DEVELOPER_NAME}]
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=${DNSTT_BINARY} -udp :53${mtu_string} -privkey-file ${DNSTT_KEYS_DIR}/server.key ${TUNNEL_DOMAIN} ${FORWARD_TARGET}
Restart=always
RestartSec=3
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

    echo -e "  ${C_GREEN}[✓]${C_RESET} Service file created."

    # Save DNSTT configuration
    echo -e "  ${C_BLUE} Saving DNSTT configuration...${C_RESET}"
    cat > "$DNSTT_CONFIG_FILE" <<-CONFEOF
# DNSTT Configuration - Generated by ${DEVELOPER_NAME} VPN Manager
# Date: $(date '+%Y-%m-%d %H:%M:%S')
NS_SUBDOMAIN="${NS_SUBDOMAIN}"
TUNNEL_SUBDOMAIN="${TUNNEL_SUBDOMAIN}"
NS_DOMAIN="${NS_DOMAIN}"
TUNNEL_DOMAIN="${TUNNEL_DOMAIN}"
PUBLIC_KEY="${PUBLIC_KEY}"
FORWARD_DESC="${forward_desc}"
FORWARD_TARGET="${FORWARD_TARGET}"
DNSTT_RECORDS_MANAGED="${DNSTT_RECORDS_MANAGED}"
HAS_IPV6="${HAS_IPV6}"
MTU_VALUE="${mtu_value}"
SERVER_IP="${SERVER_IP}"
CONFEOF

    echo -e "  ${C_GREEN}[✓]${C_RESET} Configuration saved."

    # Enable and start the service
    echo -e "  ${C_BLUE} Starting DNSTT service...${C_RESET}"
    systemctl daemon-reload
    systemctl enable dnstt.service > /dev/null 2>&1
    systemctl start dnstt.service

    sleep 2

    if systemctl is-active --quiet dnstt.service; then
        echo ""
        echo -e "  ${C_GREEN}${C_BOLD}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "  ${C_GREEN}${C_BOLD}║     SUCCESS: DNSTT Installed & Running!                   ║${C_RESET}"
        echo -e "  ${C_GREEN}${C_BOLD}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
        show_dnstt_details
        log_action "DNSTT_INSTALL" "domain=${TUNNEL_DOMAIN} forward=${FORWARD_TARGET} [${DEVELOPER_NAME}]"
        tg_report_action "DNSTT Installed" "Domain: ${TUNNEL_DOMAIN}, Forward: ${FORWARD_TARGET}, IP: ${SERVER_IP}"
    else
        echo -e "\n  ${C_RED} ERROR: DNSTT service failed to start!${C_RESET}"
        echo -e "  ${C_DIM} Checking service logs:${C_RESET}"
        journalctl -u dnstt.service -n 20 --no-pager 2>/dev/null
        log_action "DNSTT_INSTALL_FAIL" "service_start_failed [${DEVELOPER_NAME}]"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 10.3: Uninstall DNSTT - Complete Removal with Smart DNS Cleanup
# ─────────────────────────────────────────────────────────────────────────────
uninstall_dnstt() {
    show_section_header "Uninstalling DNSTT" "🗑️"

    if [[ ! -f "$DNSTT_SERVICE_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} DNSTT is not installed on this server.${C_RESET}"
        return 0
    fi

    # Confirmation (skip in silent mode)
    if [[ "$UNINSTALL_MODE" != "silent" ]]; then
        if ! confirm_action "Are you sure you want to uninstall DNSTT? This will delete auto-generated DNS records."; then
            echo -e "\n  ${C_YELLOW} Uninstallation cancelled.${C_RESET}"
            return 0
        fi
    fi

    # Stop and disable service
    echo -e "\n  ${C_BLUE} Stopping DNSTT service...${C_RESET}"
    systemctl stop dnstt.service > /dev/null 2>&1 || true
    systemctl disable dnstt.service > /dev/null 2>&1 || true
    echo -e "  ${C_GREEN}[✓]${C_RESET} Service stopped and disabled."

    # Smart DNS Cleanup - Delete auto-generated records
    if [[ -f "$DNSTT_CONFIG_FILE" ]]; then
        source "$DNSTT_CONFIG_FILE"

        if [[ "${DNSTT_RECORDS_MANAGED:-}" == "true" ]]; then
            echo -e "\n  ${C_BLUE} Removing auto-generated DNS records...${C_RESET}"

            # Delete NS record for tunnel subdomain
            if [[ -n "${TUNNEL_SUBDOMAIN:-}" ]]; then
                echo -e "  ${C_DIM}  Deleting NS record: ${TUNNEL_SUBDOMAIN}${C_RESET}"
                desec_delete_record "$TUNNEL_SUBDOMAIN" "NS" 2>/dev/null || true
            fi

            # Delete A record for NS subdomain
            if [[ -n "${NS_SUBDOMAIN:-}" ]]; then
                echo -e "  ${C_DIM}  Deleting A record: ${NS_SUBDOMAIN}${C_RESET}"
                desec_delete_record "$NS_SUBDOMAIN" "A" 2>/dev/null || true
            fi

            # Delete AAAA record if IPv6 was configured
            if [[ "${HAS_IPV6:-}" == "true" && -n "${NS_SUBDOMAIN:-}" ]]; then
                echo -e "  ${C_DIM}  Deleting AAAA record: ${NS_SUBDOMAIN}${C_RESET}"
                desec_delete_record "$NS_SUBDOMAIN" "AAAA" 2>/dev/null || true
            fi

            echo -e "  ${C_GREEN}[✓]${C_RESET} DNS records removed from ${DESEC_DOMAIN}."
            log_action "DNSTT_DNS_CLEANUP" "ns=${NS_SUBDOMAIN:-} tun=${TUNNEL_SUBDOMAIN:-} [${DEVELOPER_NAME}]"
        else
            echo -e "\n  ${C_WARN} DNS records were manually configured. Please delete them from your DNS provider.${C_RESET}"
        fi
    fi

    # Remove all DNSTT files
    echo -e "\n  ${C_BLUE} Removing DNSTT files and binaries...${C_RESET}"
    rm -f "$DNSTT_SERVICE_FILE"
    echo -e "  ${C_DIM}  Removed: ${DNSTT_SERVICE_FILE}${C_RESET}"
    rm -f "$DNSTT_BINARY"
    echo -e "  ${C_DIM}  Removed: ${DNSTT_BINARY}${C_RESET}"
    rm -rf "$DNSTT_KEYS_DIR"
    echo -e "  ${C_DIM}  Removed: ${DNSTT_KEYS_DIR}/  (keys directory)${C_RESET}"
    rm -f "$DNSTT_CONFIG_FILE"
    echo -e "  ${C_DIM}  Removed: ${DNSTT_CONFIG_FILE}${C_RESET}"

    # Reload systemd
    systemctl daemon-reload

    # Restore resolv.conf to writable
    chattr -i /etc/resolv.conf 2>/dev/null || true

    echo ""
    echo -e "  ${C_GREEN}${C_BOLD} DNSTT has been completely uninstalled.${C_RESET}"
    log_action "DNSTT_UNINSTALL" "complete [${DEVELOPER_NAME}]"
    tg_report_action "DNSTT Uninstalled" "Server IP: ${SERVER_IP}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 10.4: DNSTT Service Control (Start/Stop/Restart)
# ─────────────────────────────────────────────────────────────────────────────
dnstt_service_control() {
    if [[ ! -f "$DNSTT_SERVICE_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} DNSTT is not installed.${C_RESET}"
        return 1
    fi

    show_section_header "DNSTT Service Control" "🔧"

    local current_status="${C_RED}Stopped${C_RESET}"
    if systemctl is-active --quiet dnstt.service 2>/dev/null; then
        current_status="${C_GREEN}Running${C_RESET}"
    fi
    echo -e "\n  ${C_WHITE}Current Status: ${current_status}${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}[ 1]${C_RESET} Start DNSTT"
    echo -e "  ${C_GREEN}[ 2]${C_RESET} Stop DNSTT"
    echo -e "  ${C_GREEN}[ 3]${C_RESET} Restart DNSTT"
    echo -e "  ${C_GREEN}[ 4]${C_RESET} View Service Logs"
    echo -e "  ${C_RED}[ 0]${C_RESET} Back"
    echo ""

    local choice
    read -p "$(echo -e "  ${C_PROMPT} Select action: ${C_RESET}")" choice

    case "$choice" in
        1)
            systemctl start dnstt.service
            echo -e "  ${C_GREEN}[✓]${C_RESET} DNSTT service started."
            ;;
        2)
            systemctl stop dnstt.service
            echo -e "  ${C_GREEN}[✓]${C_RESET} DNSTT service stopped."
            ;;
        3)
            systemctl restart dnstt.service
            echo -e "  ${C_GREEN}[✓]${C_RESET} DNSTT service restarted."
            ;;
        4)
            echo -e "\n  ${C_BLUE} Last 30 log entries:${C_RESET}"
            echo -e "  ${C_DIM}─────────────────────────────────────────────────${C_RESET}"
            journalctl -u dnstt.service -n 30 --no-pager 2>/dev/null
            ;;
        0) return ;;
        *) invalid_option ;;
    esac
}


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 11: SSH VPN USER MANAGEMENT - COMPLETE MODULE
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# 11.1: Create SSH VPN User
# ─────────────────────────────────────────────────────────────────────────────
create_ssh_user() {
    show_banner
    show_section_header "Create New SSH VPN User" "✨"

    # Get username
    echo ""
    local username
    read -p "$(echo -e "  ${C_PROMPT} Enter username (or '0' to cancel): ${C_RESET}")" username

    if [[ "$username" == "0" ]]; then
        echo -e "\n  ${C_YELLOW} User creation cancelled.${C_RESET}"
        return
    fi

    if [[ -z "$username" ]]; then
        echo -e "\n  ${C_RED} Error: Username cannot be empty.${C_RESET}"
        return
    fi

    # Check for special characters
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "\n  ${C_RED} Error: Username can only contain letters, numbers, hyphens and underscores.${C_RESET}"
        return
    fi

    # Check if user already exists in our DB
    if grep -q "^${username}:" "$DB_FILE" 2>/dev/null; then
        echo -e "\n  ${C_RED} Error: User '${username}' already exists in the database.${C_RESET}"
        return
    fi

    # Check if system user exists
    local adopt_existing=false
    if id "$username" &>/dev/null; then
        echo -e "\n  ${C_WARN} System user '${username}' already exists but is not in our database.${C_RESET}"
        if confirm_action "Do you want to adopt this existing user and manage it?"; then
            adopt_existing=true
        else
            echo -e "\n  ${C_YELLOW} User creation cancelled.${C_RESET}"
            return
        fi
    fi

    # Get password
    local password=""
    echo ""
    read -p "$(echo -e "  ${C_PROMPT} Enter password (or press Enter for auto-generated): ${C_RESET}")" password
    if [[ -z "$password" ]]; then
        password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10)
        echo -e "  ${C_GREEN} Auto-generated password: ${C_YELLOW}${password}${C_RESET}"
    fi

    # Get account duration
    local days
    read -p "$(echo -e "  ${C_PROMPT} Account duration in days [30]: ${C_RESET}")" days
    days=${days:-30}
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n  ${C_RED} Invalid number of days.${C_RESET}"
        return
    fi

    # Get connection limit
    local limit
    read -p "$(echo -e "  ${C_PROMPT} Simultaneous connection limit [2]: ${C_RESET}")" limit
    limit=${limit:-2}
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        echo -e "\n  ${C_RED} Invalid connection limit.${C_RESET}"
        return
    fi

    # Get bandwidth limit
    local bandwidth_gb
    read -p "$(echo -e "  ${C_PROMPT} Bandwidth limit in GB (0 = unlimited) [0]: ${C_RESET}")" bandwidth_gb
    bandwidth_gb=${bandwidth_gb:-0}
    if ! [[ "$bandwidth_gb" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo -e "\n  ${C_RED} Invalid bandwidth value.${C_RESET}"
        return
    fi

    # Calculate expiry date
    local expire_date
    expire_date=$(date -d "+${days} days" +%Y-%m-%d)

    # Create or adopt system user
    echo ""
    echo -e "  ${C_BLUE} Creating user account...${C_RESET}"

    if [[ "$adopt_existing" == "true" ]]; then
        usermod -s /usr/sbin/nologin "$username" 2>/dev/null || true
        echo -e "  ${C_GREEN}[✓]${C_RESET} Adopted existing system user."
    else
        useradd -m -s /usr/sbin/nologin "$username" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo -e "  ${C_RED} Failed to create system user.${C_RESET}"
            return
        fi
        echo -e "  ${C_GREEN}[✓]${C_RESET} System user created."
    fi

    # Set password and expiry
    echo "${username}:${password}" | chpasswd
    chage -E "$expire_date" "$username"

    # Add to database
    echo "${username}:${password}:${expire_date}:${limit}:${bandwidth_gb}" >> "$DB_FILE"

    # Display result
    local bw_display="Unlimited"
    [[ "$bandwidth_gb" != "0" ]] && bw_display="${bandwidth_gb} GB"

    echo ""
    echo -e "  ${C_GREEN}${C_BOLD}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║          User Created Successfully!                       ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}╠═══════════════════════════════════════════════════════════╣${C_RESET}"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Username:" "$username"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Password:" "$password"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Expires:" "$expire_date"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Connection Limit:" "$limit"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Bandwidth:" "$bw_display"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Server IP:" "${SERVER_IP:-N/A}"
    echo -e "  ${C_GREEN}${C_BOLD}╚═══════════════════════════════════════════════════════════╝${C_RESET}"

    log_action "USER_CREATE" "user=${username} days=${days} limit=${limit} bw=${bandwidth_gb} [${DEVELOPER_NAME}]"
    tg_report_action "SSH User Created" "User: ${username}, Days: ${days}, Limit: ${limit}, IP: ${SERVER_IP}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 11.2: Delete SSH VPN User(s)
# ─────────────────────────────────────────────────────────────────────────────
delete_ssh_user() {
    show_banner
    show_section_header "Delete SSH VPN User" "🗑️"

    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} No users found in the database.${C_RESET}"
        return
    fi

    # Display users with numbers
    echo ""
    echo -e "  ${C_WHITE}${C_BOLD}Available Users:${C_RESET}"
    echo -e "  ${C_DIM}─────────────────────────────────────────────────${C_RESET}"

    local -a users=()
    local i=1
    while IFS=: read -r user pass expiry limit bw; do
        users+=("$user")
        local status="${C_GREEN}Active${C_RESET}"
        local expiry_ts
        expiry_ts=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
        local now_ts
        now_ts=$(date +%s)
        if [[ "$expiry_ts" -lt "$now_ts" && "$expiry_ts" -gt 0 ]]; then
            status="${C_RED}Expired${C_RESET}"
        fi
        printf "  ${C_CHOICE}[%2d]${C_RESET} %-20s ${C_DIM}Expires: %-12s${C_RESET} %s\n" "$i" "$user" "$expiry" "$status"
        ((i++))
    done < "$DB_FILE"

    echo ""
    echo -e "  ${C_WARN}[ 0]${C_RESET} Cancel"
    echo ""

    local selection
    read -p "$(echo -e "  ${C_PROMPT} Enter user number(s) to delete (comma-separated, e.g., 1,3,5): ${C_RESET}")" selection

    if [[ "$selection" == "0" || -z "$selection" ]]; then
        echo -e "\n  ${C_YELLOW} Deletion cancelled.${C_RESET}"
        return
    fi

    # Parse selection
    local -a selected_users=()
    IFS=',' read -ra nums <<< "$selection"
    for num in "${nums[@]}"; do
        num=$(echo "$num" | tr -d ' ')
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#users[@]}" ]]; then
            selected_users+=("${users[$((num-1))]}")
        fi
    done

    if [[ ${#selected_users[@]} -eq 0 ]]; then
        echo -e "\n  ${C_RED} No valid users selected.${C_RESET}"
        return
    fi

    echo -e "\n  ${C_RED} You selected ${#selected_users[@]} user(s) to delete: ${C_YELLOW}${selected_users[*]}${C_RESET}"
    if ! confirm_action "Are you sure you want to PERMANENTLY delete these users?"; then
        echo -e "\n  ${C_YELLOW} Deletion cancelled.${C_RESET}"
        return
    fi

    echo -e "\n  ${C_BLUE} Deleting selected users...${C_RESET}"
    for user in "${selected_users[@]}"; do
        # Kill active sessions
        killall -u "$user" -9 2>/dev/null || true

        # Remove system user
        userdel -r "$user" 2>/dev/null || userdel "$user" 2>/dev/null || true

        # Remove from database
        sed -i "/^${user}:/d" "$DB_FILE"

        echo -e "  ${C_GREEN}[✓]${C_RESET} User '${C_YELLOW}${user}${C_RESET}' deleted."
        log_action "USER_DELETE" "user=${user} [${DEVELOPER_NAME}]"
    done

    tg_report_action "SSH Users Deleted" "Users: ${selected_users[*]}, IP: ${SERVER_IP}"
    echo -e "\n  ${C_GREEN} ${#selected_users[@]} user(s) deleted successfully.${C_RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 11.3: List All SSH VPN Users
# ─────────────────────────────────────────────────────────────────────────────
list_ssh_users() {
    show_banner
    show_section_header "Managed SSH VPN Users" "📋"

    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} No users are currently being managed.${C_RESET}"
        return
    fi

    echo ""
    echo -e "  ${C_CYAN}═══════════════════════════════════════════════════════════════════════════════════════${C_RESET}"
    printf "  ${C_BOLD}${C_WHITE}%-16s │ %-10s │ %-12s │ %-8s │ %-12s │ %-14s${C_RESET}\n" \
        "USERNAME" "PASSWORD" "EXPIRES" "CONNS" "BANDWIDTH" "STATUS"
    echo -e "  ${C_CYAN}───────────────────────────────────────────────────────────────────────────────────────${C_RESET}"

    local current_ts
    current_ts=$(date +%s)
    local total_active=0
    local total_expired=0
    local total_locked=0

    while IFS=: read -r user pass expiry limit bandwidth_gb; do
        [[ -z "$user" ]] && continue
        [[ -z "$bandwidth_gb" ]] && bandwidth_gb="0"

        # Determine status
        local status="${C_GREEN}Active${C_RESET}"
        local status_plain="Active"
        local line_color="$C_WHITE"

        # Check if system user exists
        if ! id "$user" &>/dev/null; then
            status="${C_RED}Not Found${C_RESET}"
            status_plain="NotFound"
            line_color="$C_DIM"
        else
            # Check expiry
            local expiry_ts
            expiry_ts=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
            if [[ "$expiry_ts" -gt 0 && "$expiry_ts" -lt "$current_ts" ]]; then
                status="${C_RED}Expired${C_RESET}"
                status_plain="Expired"
                line_color="$C_RED"
                ((total_expired++))
            else
                ((total_active++))
            fi

            # Check if locked
            local passwd_status
            passwd_status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
            if [[ "$passwd_status" == "L" ]]; then
                status="${C_YELLOW}Locked${C_RESET}"
                status_plain="Locked"
                line_color="$C_YELLOW"
                ((total_locked++))
            fi
        fi

        # Online sessions count
        local online_count=0
        online_count=$(who 2>/dev/null | grep -c "^${user}\s" || echo 0)
        local conn_str="${online_count}/${limit}"

        # Bandwidth display
        local bw_display="Unlimited"
        if [[ "$bandwidth_gb" != "0" ]]; then
            bw_display="${bandwidth_gb}GB"
        fi

        printf "  ${line_color}%-16s${C_RESET} │ ${C_YELLOW}%-10s${C_RESET} │ ${C_ORANGE}%-12s${C_RESET} │ ${C_CYAN}%-8s${C_RESET} │ ${C_TEAL}%-12s${C_RESET} │ %-14s\n" \
            "$user" "$pass" "$expiry" "$conn_str" "$bw_display" "$status"
    done < <(sort "$DB_FILE")

    echo -e "  ${C_CYAN}═══════════════════════════════════════════════════════════════════════════════════════${C_RESET}"
    local total_users
    total_users=$(wc -l < "$DB_FILE" 2>/dev/null || echo 0)
    echo -e "  ${C_WHITE}Total: ${C_CYAN}${total_users}${C_RESET} | ${C_GREEN}Active: ${total_active}${C_RESET} | ${C_RED}Expired: ${total_expired}${C_RESET} | ${C_YELLOW}Locked: ${total_locked}${C_RESET}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# 11.4: Renew SSH VPN User Account
# ─────────────────────────────────────────────────────────────────────────────
renew_ssh_user() {
    show_banner
    show_section_header "Renew User Account" "🔄"

    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} No users found in the database.${C_RESET}"
        return
    fi

    # Display users
    echo ""
    local -a users=()
    local i=1
    while IFS=: read -r user pass expiry limit bw; do
        users+=("$user")
        printf "  ${C_CHOICE}[%2d]${C_RESET} %-20s ${C_DIM}Current expiry: ${C_YELLOW}%-12s${C_RESET}\n" "$i" "$user" "$expiry"
        ((i++))
    done < "$DB_FILE"

    echo -e "\n  ${C_WARN}[ 0]${C_RESET} Cancel"
    echo ""

    local selection
    read -p "$(echo -e "  ${C_PROMPT} Enter user number(s) to renew (comma-separated): ${C_RESET}")" selection

    if [[ "$selection" == "0" || -z "$selection" ]]; then
        echo -e "\n  ${C_YELLOW} Renewal cancelled.${C_RESET}"
        return
    fi

    local days
    read -p "$(echo -e "  ${C_PROMPT} Enter number of days to extend: ${C_RESET}")" days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo -e "\n  ${C_RED} Invalid number of days.${C_RESET}"
        return
    fi

    local new_expire_date
    new_expire_date=$(date -d "+${days} days" +%Y-%m-%d)

    # Parse selection and renew
    IFS=',' read -ra nums <<< "$selection"
    for num in "${nums[@]}"; do
        num=$(echo "$num" | tr -d ' ')
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#users[@]}" ]]; then
            local user="${users[$((num-1))]}"
            chage -E "$new_expire_date" "$user" 2>/dev/null

            # Update database
            local line
            line=$(grep "^${user}:" "$DB_FILE")
            local pass
            pass=$(echo "$line" | cut -d: -f2)
            local cur_limit
            cur_limit=$(echo "$line" | cut -d: -f4)
            local cur_bw
            cur_bw=$(echo "$line" | cut -d: -f5)
            [[ -z "$cur_bw" ]] && cur_bw="0"
            sed -i "s/^${user}:.*/${user}:${pass}:${new_expire_date}:${cur_limit}:${cur_bw}/" "$DB_FILE"

            # Unlock if was locked due to expiry
            usermod -U "$user" 2>/dev/null || true

            echo -e "  ${C_GREEN}[✓]${C_RESET} User '${C_YELLOW}${user}${C_RESET}' renewed until ${C_CYAN}${new_expire_date}${C_RESET}"
            log_action "USER_RENEW" "user=${user} new_expiry=${new_expire_date} [${DEVELOPER_NAME}]"
        fi
    done

    tg_report_action "SSH Users Renewed" "Days: ${days}, New Expiry: ${new_expire_date}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 11.5: Lock/Unlock SSH VPN User
# ─────────────────────────────────────────────────────────────────────────────
lock_ssh_user() {
    show_banner
    show_section_header "Lock User Account" "🔒"

    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} No users found.${C_RESET}"
        return
    fi

    echo ""
    local -a users=()
    local i=1
    while IFS=: read -r user pass expiry limit bw; do
        users+=("$user")
        local lock_status="${C_GREEN}Unlocked${C_RESET}"
        local ps
        ps=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
        [[ "$ps" == "L" ]] && lock_status="${C_RED}Locked${C_RESET}"
        printf "  ${C_CHOICE}[%2d]${C_RESET} %-20s %s\n" "$i" "$user" "$lock_status"
        ((i++))
    done < "$DB_FILE"

    echo -e "\n  ${C_WARN}[ 0]${C_RESET} Cancel"
    echo ""

    local selection
    read -p "$(echo -e "  ${C_PROMPT} Enter user number(s) to lock (comma-separated): ${C_RESET}")" selection

    if [[ "$selection" == "0" || -z "$selection" ]]; then return; fi

    IFS=',' read -ra nums <<< "$selection"
    for num in "${nums[@]}"; do
        num=$(echo "$num" | tr -d ' ')
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#users[@]}" ]]; then
            local user="${users[$((num-1))]}"
            usermod -L "$user" 2>/dev/null
            killall -u "$user" -9 2>/dev/null || true
            echo -e "  ${C_GREEN}[✓]${C_RESET} User '${C_YELLOW}${user}${C_RESET}' locked and sessions killed."
            log_action "USER_LOCK" "user=${user} [${DEVELOPER_NAME}]"
        fi
    done
}

unlock_ssh_user() {
    show_banner
    show_section_header "Unlock User Account" "🔓"

    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} No users found.${C_RESET}"
        return
    fi

    echo ""
    local -a users=()
    local i=1
    while IFS=: read -r user pass expiry limit bw; do
        users+=("$user")
        local lock_status="${C_GREEN}Unlocked${C_RESET}"
        local ps
        ps=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
        [[ "$ps" == "L" ]] && lock_status="${C_RED}Locked${C_RESET}"
        printf "  ${C_CHOICE}[%2d]${C_RESET} %-20s %s\n" "$i" "$user" "$lock_status"
        ((i++))
    done < "$DB_FILE"

    echo -e "\n  ${C_WARN}[ 0]${C_RESET} Cancel"
    echo ""

    local selection
    read -p "$(echo -e "  ${C_PROMPT} Enter user number(s) to unlock (comma-separated): ${C_RESET}")" selection

    if [[ "$selection" == "0" || -z "$selection" ]]; then return; fi

    IFS=',' read -ra nums <<< "$selection"
    for num in "${nums[@]}"; do
        num=$(echo "$num" | tr -d ' ')
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#users[@]}" ]]; then
            local user="${users[$((num-1))]}"
            usermod -U "$user" 2>/dev/null
            echo -e "  ${C_GREEN}[✓]${C_RESET} User '${C_YELLOW}${user}${C_RESET}' unlocked."
            log_action "USER_UNLOCK" "user=${user} [${DEVELOPER_NAME}]"
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# 11.6: Edit SSH VPN User Details
# ─────────────────────────────────────────────────────────────────────────────
edit_ssh_user() {
    show_banner
    show_section_header "Edit User Details" "✏️"

    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} No users found.${C_RESET}"
        return
    fi

    echo ""
    local -a users=()
    local i=1
    while IFS=: read -r user pass expiry limit bw; do
        users+=("$user")
        printf "  ${C_CHOICE}[%2d]${C_RESET} %-20s\n" "$i" "$user"
        ((i++))
    done < "$DB_FILE"

    echo -e "\n  ${C_WARN}[ 0]${C_RESET} Cancel"
    echo ""

    local selection
    read -p "$(echo -e "  ${C_PROMPT} Select user to edit: ${C_RESET}")" selection

    if [[ "$selection" == "0" || -z "$selection" ]]; then return; fi
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#users[@]}" ]]; then
        echo -e "\n  ${C_RED} Invalid selection.${C_RESET}"
        return
    fi

    local username="${users[$((selection-1))]}"
    local line
    line=$(grep "^${username}:" "$DB_FILE")
    local cur_pass cur_expiry cur_limit cur_bw
    cur_pass=$(echo "$line" | cut -d: -f2)
    cur_expiry=$(echo "$line" | cut -d: -f3)
    cur_limit=$(echo "$line" | cut -d: -f4)
    cur_bw=$(echo "$line" | cut -d: -f5)
    [[ -z "$cur_bw" ]] && cur_bw="0"

    while true; do
        show_banner
        show_section_header "Editing User: ${username}" "✏️"

        local bw_display="Unlimited"
        [[ "$cur_bw" != "0" ]] && bw_display="${cur_bw} GB"

        echo ""
        echo -e "  ${C_DIM}Current Details:${C_RESET}"
        echo -e "  ${C_CYAN}  Password:${C_RESET}         ${C_YELLOW}${cur_pass}${C_RESET}"
        echo -e "  ${C_CYAN}  Expires:${C_RESET}          ${C_YELLOW}${cur_expiry}${C_RESET}"
        echo -e "  ${C_CYAN}  Connection Limit:${C_RESET} ${C_YELLOW}${cur_limit}${C_RESET}"
        echo -e "  ${C_CYAN}  Bandwidth:${C_RESET}        ${C_YELLOW}${bw_display}${C_RESET}"
        echo ""
        echo -e "  ${C_GREEN}[ 1]${C_RESET} Change Password"
        echo -e "  ${C_GREEN}[ 2]${C_RESET} Change Expiration Date"
        echo -e "  ${C_GREEN}[ 3]${C_RESET} Change Connection Limit"
        echo -e "  ${C_GREEN}[ 4]${C_RESET} Change Bandwidth Limit"
        echo -e "  ${C_RED}[ 0]${C_RESET} Finish Editing"
        echo ""

        local edit_choice
        read -p "$(echo -e "  ${C_PROMPT} Select option: ${C_RESET}")" edit_choice

        case "$edit_choice" in
            1)
                local new_pass
                read -p "$(echo -e "  ${C_PROMPT} New password (Enter for auto): ${C_RESET}")" new_pass
                if [[ -z "$new_pass" ]]; then
                    new_pass=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 10)
                    echo -e "  ${C_GREEN} Auto-generated: ${C_YELLOW}${new_pass}${C_RESET}"
                fi
                echo "${username}:${new_pass}" | chpasswd
                cur_pass="$new_pass"
                sed -i "s/^${username}:.*/${username}:${cur_pass}:${cur_expiry}:${cur_limit}:${cur_bw}/" "$DB_FILE"
                echo -e "  ${C_GREEN}[✓]${C_RESET} Password changed."
                log_action "USER_EDIT_PASS" "user=${username} [${DEVELOPER_NAME}]"
                ;;
            2)
                local new_days
                read -p "$(echo -e "  ${C_PROMPT} New duration in days from today: ${C_RESET}")" new_days
                if [[ "$new_days" =~ ^[0-9]+$ ]]; then
                    cur_expiry=$(date -d "+${new_days} days" +%Y-%m-%d)
                    chage -E "$cur_expiry" "$username"
                    sed -i "s/^${username}:.*/${username}:${cur_pass}:${cur_expiry}:${cur_limit}:${cur_bw}/" "$DB_FILE"
                    echo -e "  ${C_GREEN}[✓]${C_RESET} Expiry set to ${C_YELLOW}${cur_expiry}${C_RESET}."
                    log_action "USER_EDIT_EXPIRY" "user=${username} new_expiry=${cur_expiry} [${DEVELOPER_NAME}]"
                else
                    echo -e "  ${C_RED} Invalid number.${C_RESET}"
                fi
                ;;
            3)
                local new_limit
                read -p "$(echo -e "  ${C_PROMPT} New connection limit: ${C_RESET}")" new_limit
                if [[ "$new_limit" =~ ^[0-9]+$ ]]; then
                    cur_limit="$new_limit"
                    sed -i "s/^${username}:.*/${username}:${cur_pass}:${cur_expiry}:${cur_limit}:${cur_bw}/" "$DB_FILE"
                    echo -e "  ${C_GREEN}[✓]${C_RESET} Connection limit set to ${C_YELLOW}${cur_limit}${C_RESET}."
                    log_action "USER_EDIT_LIMIT" "user=${username} new_limit=${cur_limit} [${DEVELOPER_NAME}]"
                else
                    echo -e "  ${C_RED} Invalid number.${C_RESET}"
                fi
                ;;
            4)
                local new_bw
                read -p "$(echo -e "  ${C_PROMPT} New bandwidth limit in GB (0 = unlimited): ${C_RESET}")" new_bw
                if [[ "$new_bw" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                    cur_bw="$new_bw"
                    sed -i "s/^${username}:.*/${username}:${cur_pass}:${cur_expiry}:${cur_limit}:${cur_bw}/" "$DB_FILE"
                    local msg="Unlimited"
                    [[ "$cur_bw" != "0" ]] && msg="${cur_bw} GB"
                    echo -e "  ${C_GREEN}[✓]${C_RESET} Bandwidth set to ${C_YELLOW}${msg}${C_RESET}."
                    log_action "USER_EDIT_BW" "user=${username} new_bw=${cur_bw} [${DEVELOPER_NAME}]"
                else
                    echo -e "  ${C_RED} Invalid value.${C_RESET}"
                fi
                ;;
            0)
                return
                ;;
            *)
                invalid_option
                ;;
        esac
        echo ""
        echo -e "  ${C_DIM}Press [Enter] to continue editing...${C_RESET}"
        read -r || return
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# 11.7: Create Trial Account (Time-Limited)
# ─────────────────────────────────────────────────────────────────────────────
create_trial_account() {
    show_banner
    show_section_header "Create Trial Account" "⏱️"

    # Ensure 'at' daemon is available
    if ! command -v at &>/dev/null; then
        echo -e "  ${C_BLUE} Installing 'at' scheduler...${C_RESET}"
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq at > /dev/null 2>&1
        systemctl enable atd &>/dev/null || true
        systemctl start atd &>/dev/null || true
    fi

    echo ""
    echo -e "  ${C_CYAN}Select trial duration:${C_RESET}"
    echo ""
    echo -e "  ${C_GREEN}[ 1]${C_RESET} 1 Hour"
    echo -e "  ${C_GREEN}[ 2]${C_RESET} 2 Hours"
    echo -e "  ${C_GREEN}[ 3]${C_RESET} 3 Hours"
    echo -e "  ${C_GREEN}[ 4]${C_RESET} 6 Hours"
    echo -e "  ${C_GREEN}[ 5]${C_RESET} 12 Hours"
    echo -e "  ${C_GREEN}[ 6]${C_RESET} 1 Day"
    echo -e "  ${C_GREEN}[ 7]${C_RESET} 3 Days"
    echo -e "  ${C_GREEN}[ 8]${C_RESET} Custom (enter hours)"
    echo -e "  ${C_RED}[ 0]${C_RESET} Cancel"
    echo ""

    local dur_choice
    read -p "$(echo -e "  ${C_PROMPT} Select duration: ${C_RESET}")" dur_choice

    local duration_hours=0
    local duration_label=""
    case "$dur_choice" in
        1) duration_hours=1;   duration_label="1 Hour" ;;
        2) duration_hours=2;   duration_label="2 Hours" ;;
        3) duration_hours=3;   duration_label="3 Hours" ;;
        4) duration_hours=6;   duration_label="6 Hours" ;;
        5) duration_hours=12;  duration_label="12 Hours" ;;
        6) duration_hours=24;  duration_label="1 Day" ;;
        7) duration_hours=72;  duration_label="3 Days" ;;
        8)
            read -p "$(echo -e "  ${C_PROMPT} Enter hours: ${C_RESET}")" duration_hours
            if ! [[ "$duration_hours" =~ ^[0-9]+$ ]]; then
                echo -e "  ${C_RED} Invalid number.${C_RESET}"
                return
            fi
            duration_label="${duration_hours} Hours"
            ;;
        0) return ;;
        *) invalid_option; return ;;
    esac

    # Generate trial username and password
    local trial_id
    trial_id=$(head /dev/urandom | tr -dc '0-9' | head -c 4)
    local trial_user="trial${trial_id}"
    local trial_pass
    trial_pass=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8)

    # Create user
    useradd -m -s /usr/sbin/nologin "$trial_user" 2>/dev/null
    echo "${trial_user}:${trial_pass}" | chpasswd

    local expire_date
    expire_date=$(date -d "+${duration_hours} hours" +%Y-%m-%d)
    chage -E "$expire_date" "$trial_user"

    # Add to DB
    echo "${trial_user}:${trial_pass}:${expire_date}:1:0" >> "$DB_FILE"

    # Schedule auto-deletion
    echo "userdel -r ${trial_user} 2>/dev/null; sed -i '/^${trial_user}:/d' ${DB_FILE}" | \
        at now + ${duration_hours} hours 2>/dev/null || true

    echo ""
    echo -e "  ${C_GREEN}${C_BOLD}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║          Trial Account Created!                           ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}╠═══════════════════════════════════════════════════════════╣${C_RESET}"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Username:" "$trial_user"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Password:" "$trial_pass"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Duration:" "$duration_label"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Auto-Delete:" "After ${duration_label}"
    printf "  ${C_GREEN}${C_BOLD}║${C_RESET}  ${C_CYAN}%-20s${C_RESET} ${C_YELLOW}%-35s${C_RESET} ${C_GREEN}${C_BOLD}║${C_RESET}\n" "Server IP:" "${SERVER_IP:-N/A}"
    echo -e "  ${C_GREEN}${C_BOLD}╚═══════════════════════════════════════════════════════════╝${C_RESET}"

    log_action "TRIAL_CREATE" "user=${trial_user} duration=${duration_label} [${DEVELOPER_NAME}]"
    tg_report_action "Trial Account Created" "User: ${trial_user}, Duration: ${duration_label}, IP: ${SERVER_IP}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 11.8: Cleanup Expired Users
# ─────────────────────────────────────────────────────────────────────────────
cleanup_expired_users() {
    show_banner
    show_section_header "Cleanup Expired Users" "🧹"

    if [[ ! -s "$DB_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} No users in database.${C_RESET}"
        return
    fi

    local current_ts
    current_ts=$(date +%s)
    local -a expired_users=()

    while IFS=: read -r user pass expiry limit bw; do
        local expiry_ts
        expiry_ts=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
        if [[ "$expiry_ts" -gt 0 && "$expiry_ts" -lt "$current_ts" ]]; then
            expired_users+=("$user")
        fi
    done < "$DB_FILE"

    if [[ ${#expired_users[@]} -eq 0 ]]; then
        echo -e "\n  ${C_GREEN} No expired users found. Everything is clean!${C_RESET}"
        return
    fi

    echo -e "\n  ${C_WARN} Found ${#expired_users[@]} expired user(s): ${C_YELLOW}${expired_users[*]}${C_RESET}"

    if ! confirm_action "Delete all expired users?"; then
        echo -e "\n  ${C_YELLOW} Cleanup cancelled.${C_RESET}"
        return
    fi

    for user in "${expired_users[@]}"; do
        killall -u "$user" -9 2>/dev/null || true
        userdel -r "$user" 2>/dev/null || userdel "$user" 2>/dev/null || true
        sed -i "/^${user}:/d" "$DB_FILE"
        echo -e "  ${C_GREEN}[✓]${C_RESET} Removed expired user: ${C_YELLOW}${user}${C_RESET}"
    done

    echo -e "\n  ${C_GREEN} Cleaned up ${#expired_users[@]} expired user(s).${C_RESET}"
    log_action "CLEANUP_EXPIRED" "count=${#expired_users[@]} [${DEVELOPER_NAME}]"
}

# ─────────────────────────────────────────────────────────────────────────────
# 11.9: Backup & Restore User Data
# ─────────────────────────────────────────────────────────────────────────────
backup_user_data() {
    show_banner
    show_section_header "Backup User Data" "💾"

    mkdir -p "$BACKUP_DIR"
    local backup_file="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S).tar.gz"

    echo -e "\n  ${C_BLUE} Creating backup...${C_RESET}"

    local -a files_to_backup=("$DB_FILE")
    [[ -f "$DNSTT_CONFIG_FILE" ]] && files_to_backup+=("$DNSTT_CONFIG_FILE")
    [[ -d "$DNSTT_KEYS_DIR" ]] && files_to_backup+=("$DNSTT_KEYS_DIR")
    [[ -f "$LOG_FILE" ]] && files_to_backup+=("$LOG_FILE")

    tar -czf "$backup_file" "${files_to_backup[@]}" 2>/dev/null

    if [[ -f "$backup_file" ]]; then
        local size
        size=$(du -h "$backup_file" | awk '{print $1}')
        echo -e "  ${C_GREEN}[✓]${C_RESET} Backup created: ${C_YELLOW}${backup_file}${C_RESET} (${size})"
        log_action "BACKUP" "file=${backup_file} [${DEVELOPER_NAME}]"
    else
        echo -e "  ${C_RED} Backup failed.${C_RESET}"
    fi
}

restore_user_data() {
    show_banner
    show_section_header "Restore User Data" "📥"

    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        echo -e "\n  ${C_YELLOW} No backups found in ${BACKUP_DIR}.${C_RESET}"
        return
    fi

    echo ""
    local -a backups=()
    local i=1
    for f in "$BACKUP_DIR"/backup_*.tar.gz; do
        [[ -f "$f" ]] || continue
        backups+=("$f")
        local size
        size=$(du -h "$f" | awk '{print $1}')
        local date_str
        date_str=$(basename "$f" | sed 's/backup_//;s/.tar.gz//;s/_/ /')
        printf "  ${C_CHOICE}[%2d]${C_RESET} %-40s ${C_DIM}(%s)${C_RESET}\n" "$i" "$date_str" "$size"
        ((i++))
    done

    echo -e "\n  ${C_WARN}[ 0]${C_RESET} Cancel"
    echo ""

    local selection
    read -p "$(echo -e "  ${C_PROMPT} Select backup to restore: ${C_RESET}")" selection

    if [[ "$selection" == "0" || -z "$selection" ]]; then return; fi
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#backups[@]}" ]]; then
        echo -e "\n  ${C_RED} Invalid selection.${C_RESET}"
        return
    fi

    local backup_file="${backups[$((selection-1))]}"

    if confirm_action "Restore from ${backup_file}? This will overwrite current data."; then
        tar -xzf "$backup_file" -C / 2>/dev/null
        echo -e "  ${C_GREEN}[✓]${C_RESET} Data restored from backup."
        log_action "RESTORE" "file=${backup_file} [${DEVELOPER_NAME}]"
    fi
}


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 12: SSH BANNER CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
configure_ssh_banner() {
    show_banner
    show_section_header "SSH Banner Configuration" "🎨"

    echo ""
    echo -e "  ${C_GREEN}[ 1]${C_RESET} Set custom banner message"
    echo -e "  ${C_GREEN}[ 2]${C_RESET} Set default ${DEVELOPER_NAME} banner"
    echo -e "  ${C_GREEN}[ 3]${C_RESET} Remove banner"
    echo -e "  ${C_GREEN}[ 4]${C_RESET} View current banner"
    echo -e "  ${C_RED}[ 0]${C_RESET} Back"
    echo ""

    local choice
    read -p "$(echo -e "  ${C_PROMPT} Select option: ${C_RESET}")" choice

    case "$choice" in
        1)
            echo -e "\n  ${C_BLUE} Enter your banner text (type 'END' on a new line to finish):${C_RESET}"
            local banner_text=""
            while IFS= read -r line; do
                [[ "$line" == "END" ]] && break
                banner_text+="${line}\n"
            done
            echo -e "$banner_text" > "$SSH_BANNER_FILE"
            if ! grep -q "^Banner" "$SSHD_CONFIG" 2>/dev/null; then
                echo "Banner ${SSH_BANNER_FILE}" >> "$SSHD_CONFIG"
            else
                sed -i "s|^#*Banner.*|Banner ${SSH_BANNER_FILE}|" "$SSHD_CONFIG"
            fi
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
            echo -e "  ${C_GREEN}[✓]${C_RESET} Custom banner set."
            ;;
        2)
            cat > "$SSH_BANNER_FILE" <<-'BANNEREOF'
╔═══════════════════════════════════════════════════╗
║                                                   ║
║          xxxjihad VPN Premium Service             ║
║          Telegram: @XxXjihad                      ║
║                                                   ║
║   Unauthorized access is strictly prohibited.     ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
BANNEREOF
            if ! grep -q "^Banner" "$SSHD_CONFIG" 2>/dev/null; then
                echo "Banner ${SSH_BANNER_FILE}" >> "$SSHD_CONFIG"
            else
                sed -i "s|^#*Banner.*|Banner ${SSH_BANNER_FILE}|" "$SSHD_CONFIG"
            fi
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
            echo -e "  ${C_GREEN}[✓]${C_RESET} Default ${DEVELOPER_NAME} banner set."
            ;;
        3)
            rm -f "$SSH_BANNER_FILE"
            sed -i '/^Banner/d' "$SSHD_CONFIG"
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
            echo -e "  ${C_GREEN}[✓]${C_RESET} Banner removed."
            ;;
        4)
            if [[ -f "$SSH_BANNER_FILE" ]]; then
                echo -e "\n  ${C_CYAN}Current Banner:${C_RESET}"
                echo -e "  ${C_DIM}─────────────────────────────────────────────────${C_RESET}"
                cat "$SSH_BANNER_FILE"
                echo -e "  ${C_DIM}─────────────────────────────────────────────────${C_RESET}"
            else
                echo -e "\n  ${C_YELLOW} No banner is currently set.${C_RESET}"
            fi
            ;;
        0) return ;;
        *) invalid_option ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 13: SMART UNINSTALL SYSTEM (Full Script Removal)
# ═══════════════════════════════════════════════════════════════════════════════
uninstall_script() {
    show_banner
    echo ""
    echo -e "  ${C_RED}${C_BOLD}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║                                                           ║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║    DANGER: COMPLETE SCRIPT UNINSTALLATION                 ║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║                                                           ║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}╠═══════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}                                                           ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}  ${C_YELLOW}This will PERMANENTLY remove:${C_RESET}                          ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}  ${C_WHITE} - The main 'xxxjihad' command${C_RESET}                              ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}  ${C_WHITE} - All configuration & user data (${DB_DIR})${C_RESET}     ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}  ${C_WHITE} - DNSTT service and all DNS records${C_RESET}                    ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}  ${C_WHITE} - All SSH VPN user accounts (optional)${C_RESET}                 ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}  ${C_WHITE} - All DNS records from ${DESEC_DOMAIN}${C_RESET}            ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}                                                           ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}  ${C_RED}${C_BLINK}THIS ACTION IS IRREVERSIBLE!${C_RESET}                            ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}║${C_RESET}                                                           ${C_RED}${C_BOLD}║${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""

    local confirm
    read -p "$(echo -e "  ${C_RED} Type 'yes' to confirm complete uninstallation: ${C_RESET}")" confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "\n  ${C_GREEN} Uninstallation cancelled. Your system is safe.${C_RESET}"
        return
    fi

    # Ask about SSH users
    local remove_users=false
    if [[ -s "$DB_FILE" ]]; then
        local user_count
        user_count=$(wc -l < "$DB_FILE")
        echo -e "\n  ${C_WARN} Found ${user_count} managed SSH user(s) in the database.${C_RESET}"
        if confirm_action "Also delete all SSH VPN user accounts from the system?"; then
            remove_users=true
        fi
    fi

    # Switch to silent mode for sub-uninstalls
    export UNINSTALL_MODE="silent"

    echo ""
    echo -e "  ${C_BLUE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "  ${C_BLUE}${C_BOLD}          STARTING COMPLETE UNINSTALLATION                 ${C_RESET}"
    echo -e "  ${C_BLUE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"

    # Step 1: Remove SSH users if requested
    if [[ "$remove_users" == "true" ]]; then
        echo -e "\n  ${C_BLUE}[1/5] Removing SSH VPN users...${C_RESET}"
        while IFS=: read -r user _rest; do
            [[ -z "$user" ]] && continue
            killall -u "$user" -9 2>/dev/null || true
            userdel -r "$user" 2>/dev/null || userdel "$user" 2>/dev/null || true
            echo -e "  ${C_DIM}  Removed user: ${user}${C_RESET}"
        done < "$DB_FILE"
        echo -e "  ${C_GREEN}[✓]${C_RESET} All SSH users removed."
    else
        echo -e "\n  ${C_BLUE}[1/5] Skipping SSH user removal (kept on system).${C_RESET}"
    fi

    # Step 2: Uninstall DNSTT (with DNS cleanup)
    echo -e "\n  ${C_BLUE}[2/5] Uninstalling DNSTT...${C_RESET}"
    uninstall_dnstt 2>/dev/null || true

    # Step 3: SMART DNS WIPE - Clean ALL records from the domain
    echo -e "\n  ${C_BLUE}[3/5] Wiping ALL DNS records from ${DESEC_DOMAIN}...${C_RESET}"
    desec_wipe_all_records 2>/dev/null || true

    # Step 4: Remove SSH banner
    echo -e "\n  ${C_BLUE}[4/5] Removing SSH banner and configurations...${C_RESET}"
    rm -f "$SSH_BANNER_FILE"
    sed -i '/^Banner/d' "$SSHD_CONFIG" 2>/dev/null || true
    chattr -i /etc/resolv.conf 2>/dev/null || true
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    echo -e "  ${C_GREEN}[✓]${C_RESET} SSH banner removed."

    # Step 5: Remove all script files and data
    echo -e "\n  ${C_BLUE}[5/5] Removing script files and data...${C_RESET}"

    # Remove systemd services
    systemctl daemon-reload 2>/dev/null || true

    # Remove all data
    rm -rf "$DB_DIR"
    echo -e "  ${C_DIM}  Removed: ${DB_DIR}/${C_RESET}"

    # Remove the menu command
    rm -f "$(command -v xxxjihad 2>/dev/null)" 2>/dev/null || true
    rm -f "/usr/local/bin/xxxjihad" 2>/dev/null || true
    echo -e "  ${C_DIM}  Removed: /usr/local/bin/xxxjihad${C_RESET}"

    # Send final report
    log_action "SCRIPT_UNINSTALL" "complete [${DEVELOPER_NAME}]"
    tg_report_action "Script Uninstalled" "Complete removal from ${SERVER_IP}"

    echo ""
    echo -e "  ${C_GREEN}${C_BOLD}╔═══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║                                                           ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║   Script has been completely uninstalled.                  ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║   All data, services, and DNS records have been removed.   ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║                                                           ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║   The 'xxxjihad' command will no longer work.                  ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}║                                                           ║${C_RESET}"
    echo -e "  ${C_GREEN}${C_BOLD}╚═══════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 14: VIEW SYSTEM LOGS
# ═══════════════════════════════════════════════════════════════════════════════
view_system_logs() {
    show_banner
    show_section_header "System Activity Logs" "📊"

    if [[ ! -f "$LOG_FILE" || ! -s "$LOG_FILE" ]]; then
        echo -e "\n  ${C_YELLOW} No log entries found.${C_RESET}"
        return
    fi

    echo ""
    echo -e "  ${C_GREEN}[ 1]${C_RESET} View last 20 entries"
    echo -e "  ${C_GREEN}[ 2]${C_RESET} View last 50 entries"
    echo -e "  ${C_GREEN}[ 3]${C_RESET} View all entries"
    echo -e "  ${C_GREEN}[ 4]${C_RESET} Clear logs"
    echo -e "  ${C_RED}[ 0]${C_RESET} Back"
    echo ""

    local choice
    read -p "$(echo -e "  ${C_PROMPT} Select option: ${C_RESET}")" choice

    case "$choice" in
        1)
            echo -e "\n  ${C_CYAN}Last 20 Log Entries:${C_RESET}"
            echo -e "  ${C_DIM}─────────────────────────────────────────────────${C_RESET}"
            tail -20 "$LOG_FILE" | while IFS= read -r line; do
                echo -e "  ${C_DIM}${line}${C_RESET}"
            done
            ;;
        2)
            echo -e "\n  ${C_CYAN}Last 50 Log Entries:${C_RESET}"
            echo -e "  ${C_DIM}─────────────────────────────────────────────────${C_RESET}"
            tail -50 "$LOG_FILE" | while IFS= read -r line; do
                echo -e "  ${C_DIM}${line}${C_RESET}"
            done
            ;;
        3)
            echo -e "\n  ${C_CYAN}All Log Entries:${C_RESET}"
            echo -e "  ${C_DIM}─────────────────────────────────────────────────${C_RESET}"
            cat "$LOG_FILE" | while IFS= read -r line; do
                echo -e "  ${C_DIM}${line}${C_RESET}"
            done
            ;;
        4)
            if confirm_action "Clear all log entries?"; then
                > "$LOG_FILE"
                echo -e "  ${C_GREEN}[✓]${C_RESET} Logs cleared."
            fi
            ;;
        0) return ;;
        *) invalid_option ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 15: DNSTT MANAGEMENT SUBMENU
# ═══════════════════════════════════════════════════════════════════════════════
dnstt_menu() {
    while true; do
        show_banner

        local dnstt_status="${C_STATUS_I}(Inactive)${C_RESET}"
        if systemctl is-active --quiet dnstt.service 2>/dev/null; then
            dnstt_status="${C_STATUS_A}(Active)${C_RESET}"
        fi

        echo ""
        echo -e "  ${C_TITLE}${C_BOLD}═══════════════════[ DNSTT Management ]═══════════════════${C_RESET}"
        echo ""
        printf "  ${C_CHOICE}[ 1]${C_RESET} %-45s %s\n" "Install/View DNSTT (Port 53)" "$dnstt_status"
        printf "  ${C_CHOICE}[ 2]${C_RESET} %-45s\n" "Uninstall DNSTT"
        printf "  ${C_CHOICE}[ 3]${C_RESET} %-45s\n" "DNSTT Service Control (Start/Stop/Restart)"
        printf "  ${C_CHOICE}[ 4]${C_RESET} %-45s\n" "View DNSTT Connection Details"
        echo ""
        echo -e "  ${C_DIM}─────────────────────────────────────────────────────────${C_RESET}"
        echo -e "  ${C_WARN}[ 0]${C_RESET} Return to Main Menu"
        echo ""

        local choice
        read -p "$(echo -e "  ${C_PROMPT} Select option: ${C_RESET}")" choice

        case "$choice" in
            1) install_dnstt; press_enter ;;
            2) uninstall_dnstt; press_enter ;;
            3) dnstt_service_control; press_enter ;;
            4) show_dnstt_details; press_enter ;;
            0) return ;;
            *) invalid_option ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 16: USER MANAGEMENT SUBMENU
# ═══════════════════════════════════════════════════════════════════════════════
user_menu() {
    while true; do
        show_banner
        echo ""
        echo -e "  ${C_TITLE}${C_BOLD}═══════════════════[ SSH VPN User Management ]═══════════════════${C_RESET}"
        echo ""
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-35s  ${C_CHOICE}[%2s]${C_RESET} %-35s\n" "1" "Create New User" "2" "Delete User"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-35s  ${C_CHOICE}[%2s]${C_RESET} %-35s\n" "3" "Renew User Account" "4" "Lock User Account"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-35s  ${C_CHOICE}[%2s]${C_RESET} %-35s\n" "5" "Unlock User Account" "6" "Edit User Details"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-35s  ${C_CHOICE}[%2s]${C_RESET} %-35s\n" "7" "List All Users" "8" "Create Trial Account"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-35s\n" "9" "Cleanup Expired Users"
        echo ""
        echo -e "  ${C_DIM}─────────────────────────────────────────────────────────────────${C_RESET}"
        echo -e "  ${C_WARN}[ 0]${C_RESET} Return to Main Menu"
        echo ""

        local choice
        read -p "$(echo -e "  ${C_PROMPT} Select option: ${C_RESET}")" choice

        case "$choice" in
            1) create_ssh_user; press_enter ;;
            2) delete_ssh_user; press_enter ;;
            3) renew_ssh_user; press_enter ;;
            4) lock_ssh_user; press_enter ;;
            5) unlock_ssh_user; press_enter ;;
            6) edit_ssh_user ;;
            7) list_ssh_users; press_enter ;;
            8) create_trial_account; press_enter ;;
            9) cleanup_expired_users; press_enter ;;
            0) return ;;
            *) invalid_option ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 17: MAIN MENU - THE HEART OF THE SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        export UNINSTALL_MODE="interactive"
        show_banner

        # Get DNSTT status for display
        local dnstt_status_text="${C_STATUS_I}Inactive${C_RESET}"
        if systemctl is-active --quiet dnstt.service 2>/dev/null; then
            dnstt_status_text="${C_STATUS_A}Active${C_RESET}"
        fi

        # Get user count
        local user_count=0
        [[ -f "$DB_FILE" ]] && user_count=$(wc -l < "$DB_FILE" 2>/dev/null || echo 0)

        echo ""
        echo -e "  ${C_TITLE}${C_BOLD}═══════════════════════[ MAIN MENU ]═══════════════════════${C_RESET}"

        echo ""
        echo -e "  ${C_ACCENT}  --- USER MANAGEMENT ---${C_RESET}"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s ${C_DIM}(%s users)${C_RESET}\n" "1" "👤 SSH VPN User Management" "$user_count"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "2" "✨ Quick: Create New User"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "3" "📋 Quick: List All Users"

        echo ""
        echo -e "  ${C_ACCENT}  --- DNSTT & PROTOCOLS ---${C_RESET}"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s [%s]\n" "4" "📡 DNSTT Management" "$dnstt_status_text"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "5" "🔧 Quick: Install DNSTT"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "6" "🗑️  Quick: Uninstall DNSTT"

        echo ""
        echo -e "  ${C_ACCENT}  --- SYSTEM SETTINGS ---${C_RESET}"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "7" "🎨 SSH Banner Configuration"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "8" "💾 Backup User Data"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "9" "📥 Restore User Data"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "10" "📊 View System Logs"
        printf "  ${C_CHOICE}[%2s]${C_RESET} %-40s\n" "11" "🧹 Cleanup Expired Users"

        echo ""
        echo -e "  ${C_DANGER}═══════════════════[ DANGER ZONE ]═══════════════════${C_RESET}"
        echo -e "  ${C_DANGER}[99]${C_RESET} Uninstall Script & Wipe All Data"
        echo -e "  ${C_WARN}[ 0]${C_RESET} Exit"
        echo ""

        local choice
        if ! read -r -p "$(echo -e "  ${C_PROMPT}${C_BOLD} Select an option: ${C_RESET}")" choice; then
            echo ""
            exit 0
        fi

        case "$choice" in
            1)  user_menu ;;
            2)  create_ssh_user; press_enter ;;
            3)  list_ssh_users; press_enter ;;
            4)  dnstt_menu ;;
            5)  install_dnstt; press_enter ;;
            6)  uninstall_dnstt; press_enter ;;
            7)  configure_ssh_banner; press_enter ;;
            8)  backup_user_data; press_enter ;;
            9)  restore_user_data; press_enter ;;
            10) view_system_logs; press_enter ;;
            11) cleanup_expired_users; press_enter ;;
            99) uninstall_script ;;
            0)  echo -e "\n  ${C_GREEN} Goodbye! - ${DEVELOPER_NAME} VPN Manager${C_RESET}\n"; exit 0 ;;
            *)  invalid_option ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 18: SCRIPT ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

# Ensure running as root
check_root

# Check OS compatibility
check_os

# Get server IP
get_server_ip

# Ensure directories exist
ensure_directories

# Handle first-time setup
if [[ "$1" == "--install-setup" ]]; then
    initial_setup
    exit 0
fi

# Run initial setup if needed
initial_setup

# Ensure terminal is interactive
if [[ ! -t 0 ]]; then
    echo -e "${C_RED} Error: This script requires an interactive terminal.${C_RESET}"
    echo -e "${C_YELLOW} Please run it directly: sudo bash menu.sh${C_RESET}"
    exit 1
fi

# Launch main menu
main_menu
