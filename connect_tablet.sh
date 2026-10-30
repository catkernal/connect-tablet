#!/bin/bash

# If invoked with 'sh connect_tablet.sh', re-execute with bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# Parse command line options
PAIR_MODE=false
for arg in "$@"; do
    case "$arg" in
        --pair|-p)
            PAIR_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --pair, -p   Pair with tablet using Android Wireless Debugging pairing code"
            echo "  --help, -h   Show this help message"
            exit 0
            ;;
    esac
done

# --- Paths & Environment Setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If .env does not exist yet, initialize it from .env.example if available
if [[ ! -f "$SCRIPT_DIR/.env" && -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
fi

# Load .env file
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
elif [[ -f "$SCRIPT_DIR/.connect_tablet.env" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.connect_tablet.env"
elif [[ -f "$HOME/.connect_tablet.env" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.connect_tablet.env"
fi

# Fallback defaults if not set in .env
HOME_SCRIPT="${HOME_SCRIPT:-$HOME/connect_tablet.sh}"
HOME_ICON="${HOME_ICON:-$HOME/connect_tablet_icon.png}"
DESKTOP_SHORTCUT="${DESKTOP_SHORTCUT:-$HOME/Desktop/Connect Tablet.desktop}"
ADB_PORT="${ADB_PORT:-5555}"

# --- Install desktop shortcut ---
install_shortcut() {
    # Only copy if running from a different directory than HOME_SCRIPT
    if [[ "$SCRIPT_DIR/connect_tablet.sh" != "$HOME_SCRIPT" ]]; then
        echo "Setting up desktop shortcut..."
        cp -f "$SCRIPT_DIR/connect_tablet.sh" "$HOME_SCRIPT"
        chmod +x "$HOME_SCRIPT"
        echo "  Copied script to $HOME_SCRIPT"

        if [[ -f "$SCRIPT_DIR/connect_tablet_icon.png" ]]; then
            cp -f "$SCRIPT_DIR/connect_tablet_icon.png" "$HOME_ICON"
            echo "  Copied icon to $HOME_ICON"
        fi

        # Sync .env to home directory as .connect_tablet.env
        if [[ -f "$SCRIPT_DIR/.env" ]]; then
            cp -f "$SCRIPT_DIR/.env" "$HOME/.connect_tablet.env"
            echo "  Synced .env to $HOME/.connect_tablet.env"
        fi

        cat > "$DESKTOP_SHORTCUT" <<EOF
[Desktop Entry]
Name=Connect Tablet
Comment=Connect to tablet wirelessly and launch scrcpy
Exec=bash $HOME_SCRIPT
Icon=$HOME_ICON
Terminal=true
Type=Application
Categories=Utility;
EOF
        chmod +x "$DESKTOP_SHORTCUT"
        gio set "$DESKTOP_SHORTCUT" metadata::trusted true 2>/dev/null
        echo "  Created desktop shortcut: $DESKTOP_SHORTCUT"
        echo ""
    fi
}

install_shortcut

# --- Helper Functions ---

# Function to pair device using Android 11+ pairing code (only when explicitly requested)
pair_device() {
    local target_ip="$1"
    echo ""
    echo "================================================"
    echo "        Wireless Debugging Device Pairing       "
    echo "================================================"
    echo "1. On your tablet, go to Settings -> Developer Options -> Wireless debugging."
    echo "2. Tap 'Pair device with pairing code'."
    echo "3. A dialog will show an IP, a 5-digit PORT, and a 6-digit CODE."
    echo "================================================"
    echo ""
    read -rp "Enter the 5-digit pairing PORT (from the popup): " PAIR_PORT
    read -rp "Enter the 6-digit pairing CODE: " PAIR_CODE

    if [[ -z "$PAIR_PORT" || -z "$PAIR_CODE" ]]; then
        echo "Pairing cancelled."
        return 1
    fi

    echo "Pairing with $target_ip:$PAIR_PORT..."
    local pair_result
    pair_result=$(adb pair "$target_ip:$PAIR_PORT" "$PAIR_CODE" 2>&1)
    echo "$pair_result"

    if echo "$pair_result" | grep -qi "successfully paired"; then
        echo ""
        echo "Device successfully paired!"
        return 0
    else
        echo "Pairing was not successful. Please verify the code and port."
        return 1
    fi
}

# Auto-detect active Wireless Debugging / ADB port on the target IP
find_active_adb_port() {
    local target_ip="$1"

    # 1. Check if adb is already connected to this IP on any port
    local existing_device
    existing_device=$(adb devices 2>/dev/null | grep "^$target_ip:" | grep -w "device" | head -n 1 | awk '{print $1}')
    if [[ -n "$existing_device" ]]; then
        echo "${existing_device#*:}"
        return 0
    fi

    # 2. Check if default 5555 or configured ADB_PORT is open
    local candidate_port="${ADB_PORT:-5555}"
    if nc -z -w 1 "$target_ip" "$candidate_port" 2>/dev/null; then
        echo "$candidate_port"
        return 0
    fi

    # 3. Quickly scan Android Wireless Debugging dynamic port range (30000-50000)
    local detected_port
    detected_port=$(nmap -sT --open -p 5555,30000-50000 "$target_ip" 2>/dev/null | awk -F'/' '/\/tcp open/{print $1}' | head -n 1)
    if [[ -n "$detected_port" ]]; then
        echo "$detected_port"
        return 0
    fi

    echo "${ADB_PORT:-5555}"
}

# Function to connect and launch scrcpy
connect_and_launch() {
    local target_ip="$1"
    local port="$2"

    echo "Connecting to $target_ip:$port..."
    local connect_result
    connect_result=$(adb connect "$target_ip:$port" 2>&1)
    echo "$connect_result"

    if echo "$connect_result" | grep -qi -E "connected|already connected"; then
        echo "Connected successfully! Launching scrcpy..."
        scrcpy -s "$target_ip:$port"
        return 0
    else
        return 1
    fi
}

# Function to lookup IP from ARP / neighbor cache
lookup_ip() {
    local ip
    ip=$(ip neigh 2>/dev/null | grep -i "$CLEAN_MAC" | awk '{print $1}' | head -n 1)
    if [[ -z "$ip" ]]; then
        ip=$(arp -an 2>/dev/null | grep -i "$CLEAN_MAC" | grep -oP '\(\K[0-9.]+(?=\))' | head -n 1)
    fi
    if [[ -z "$ip" ]]; then
        ip=$(arp -n 2>/dev/null | grep -i "$CLEAN_MAC" | awk '{print $1}' | head -n 1)
    fi
    echo "$ip"
}

# --- Main Logic ---

# Prompt if TARGET_MAC is not set
if [[ -z "$TARGET_MAC" ]]; then
    read -rp "Enter your tablet's Wi-Fi MAC address (e.g. cc:42:10:b1:7d:61): " TARGET_MAC
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        if grep -q "^TARGET_MAC=" "$SCRIPT_DIR/.env"; then
            sed -i "s/^TARGET_MAC=.*/TARGET_MAC=\"$TARGET_MAC\"/" "$SCRIPT_DIR/.env"
        else
            echo "TARGET_MAC=\"$TARGET_MAC\"" >> "$SCRIPT_DIR/.env"
        fi
        echo "Saved MAC address to $SCRIPT_DIR/.env"
        cp -f "$SCRIPT_DIR/.env" "$HOME/.connect_tablet.env" 2>/dev/null
    fi
fi

# Normalize MAC format (lowercase, replace dashes with colons, remove spaces)
CLEAN_MAC=$(echo "$TARGET_MAC" | tr '[:upper:]' '[:lower:]' | tr '-' ':' | tr -d ' ')

echo "Looking for tablet with MAC: $CLEAN_MAC..."

# 1. Try finding in cache first (instant)
IP=$(lookup_ip)

# 2. If not found in cache, scan the local network to refresh ARP cache
if [[ -z "$IP" ]]; then
    echo "Device not in ARP cache. Scanning network..."

    SUBNET=$(ip -4 route show default 2>/dev/null | awk '{print $3}' | sed 's/\.[0-9]*$/.0\/24/')
    if [[ -z "$SUBNET" ]]; then
        SUBNET=$(ip -4 addr show 2>/dev/null | grep -oP 'inet \K[0-9.]+' | grep -v '^127\.' | head -n 1 | sed 's/\.[0-9]*$/.0\/24/')
    fi

    if [[ -n "$SUBNET" ]]; then
        nmap -sn -PS5555,80,443 "$SUBNET" > /dev/null 2>&1
    fi

    BROADCAST_IP=$(ip -4 addr show 2>/dev/null | grep -oP 'brd \K[0-9.]+' | head -n 1)
    if [[ -n "$BROADCAST_IP" ]]; then
        ping -b -c 1 -W 1 "$BROADCAST_IP" > /dev/null 2>&1
    fi

    IP=$(lookup_ip)
fi

# 3. Fallback: Check if device hostname (Xiaomi) is discovered if MAC didn't match
if [[ -z "$IP" ]]; then
    FALLBACK_LINE=$(arp -a 2>/dev/null | grep -i "Xiaomi" | head -n 1)
    if [[ -n "$FALLBACK_LINE" ]]; then
        FALLBACK_IP=$(echo "$FALLBACK_LINE" | grep -oP '\(\K[0-9.]+(?=\))')
        FALLBACK_MAC=$(echo "$FALLBACK_LINE" | awk '{print $4}')
        echo ""
        echo "Found Xiaomi device on network at $FALLBACK_IP (Active MAC: $FALLBACK_MAC)."
        IP="$FALLBACK_IP"
    fi
fi

if [[ -z "$IP" ]]; then
    echo ""
    echo "Could not find a device with MAC address $CLEAN_MAC on your network."
    echo "Please check:"
    echo "  1. Tablet is awake and connected to the same Wi-Fi."
    echo "  2. Wi-Fi privacy is set to 'Use device MAC' (not randomized MAC)."
    echo "  3. MAC address '$CLEAN_MAC' matches the one shown in Wi-Fi settings."
    exit 1
fi

echo "Found tablet at IP: $IP"

# If --pair flag was passed explicitly, run pairing
if [[ "$PAIR_MODE" == "true" ]]; then
    pair_device "$IP"
fi

# Automatically find active ADB port on tablet
PORT=$(find_active_adb_port "$IP")
echo "Detected active Wireless Debugging port: $PORT"

# Attempt connection
if ! connect_and_launch "$IP" "$PORT"; then
    echo ""
    echo "Connection failed."
    echo "If this is the first time connecting, run with --pair to pair once:"
    echo "  ./connect_tablet.sh --pair"
    exit 1
fi
