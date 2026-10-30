#!/bin/bash

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

# --- Main Logic ---

# Prompt if TARGET_MAC is not set
if [[ -z "$TARGET_MAC" ]]; then
    read -rp "Enter your tablet's Wi-Fi MAC address (e.g. cc:42:10:b1:7d:61): " TARGET_MAC
    # Automatically persist to .env if .env exists
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        if grep -q "^TARGET_MAC=" "$SCRIPT_DIR/.env"; then
            sed -i "s/^TARGET_MAC=.*/TARGET_MAC=\"$TARGET_MAC\"/" "$SCRIPT_DIR/.env"
        else
            echo "TARGET_MAC=\"$TARGET_MAC\"" >> "$SCRIPT_DIR/.env"
        fi
        echo "Saved MAC address to $SCRIPT_DIR/.env"
        # Also sync to home env copy
        cp -f "$SCRIPT_DIR/.env" "$HOME/.connect_tablet.env" 2>/dev/null
    fi
fi

# Normalize MAC format (lowercase, replace dashes with colons, remove spaces)
CLEAN_MAC=$(echo "$TARGET_MAC" | tr '[:upper:]' '[:lower:]' | tr '-' ':' | tr -d ' ')

echo "Looking for tablet with MAC: $CLEAN_MAC..."

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

# 1. Try finding in cache first (instant)
IP=$(lookup_ip)

# 2. If not found in cache, scan the local network to refresh ARP cache
if [[ -z "$IP" ]]; then
    echo "Device not in ARP cache. Scanning network..."

    # Determine subnet (e.g. 192.168.1.0/24)
    SUBNET=$(ip -4 route show default 2>/dev/null | awk '{print $3}' | sed 's/\.[0-9]*$/.0\/24/')
    if [[ -z "$SUBNET" ]]; then
        SUBNET=$(ip -4 addr show 2>/dev/null | grep -oP 'inet \K[0-9.]+' | grep -v '^127\.' | head -n 1 | sed 's/\.[0-9]*$/.0\/24/')
    fi

    if [[ -n "$SUBNET" ]]; then
        nmap -sn "$SUBNET" > /dev/null 2>&1
    fi

    # Broadcast ping fallback
    BROADCAST_IP=$(ip -4 addr show 2>/dev/null | grep -oP 'brd \K[0-9.]+' | head -n 1)
    if [[ -n "$BROADCAST_IP" ]]; then
        ping -b -c 1 -W 1 "$BROADCAST_IP" > /dev/null 2>&1
    fi

    # Check cache again
    IP=$(lookup_ip)
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
echo "Connecting and launching scrcpy..."
if [[ "$ADB_PORT" == "5555" || -z "$ADB_PORT" ]]; then
    scrcpy --tcpip="$IP"
else
    scrcpy --tcpip="$IP:$ADB_PORT"
fi
