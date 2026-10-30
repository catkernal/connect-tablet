# Connect Tablet

Wirelessly connect your Android tablet to your Linux PC and mirror its screen using [scrcpy](https://github.com/Genymobile/scrcpy). It uses your tablet's fixed Wi-Fi MAC address to automatically resolve its IP and connect with a single click.

## Features

- **No hardcoded IP needed:** Dynamically looks up your tablet's current IP address on your local network using its MAC address.
- **Auto Port Discovery:** Automatically scans and detects the active dynamic port assigned by Android Wireless Debugging in under a second.
- **Wireless Debugging Pairing:** Built-in support to pair with Android 11+ Wi-Fi pairing codes (`adb pair`).
- **Reliable ARP Refresh:** Performs an unprivileged, fast network sweep (`nmap -sn`) to find the device even if it was idle or missing from the local ARP cache.
- **One-Click Desktop Shortcut:** Automatically sets up a desktop launcher (`Connect Tablet.desktop`) with a custom icon on the first run.
- **Environment Configuration:** Sensitive values (like your personal MAC address) are stored in `.env` and kept out of Git.

---

## Prerequisites

Install the required packages on your Linux PC:

```bash
sudo apt update
sudo apt install adb scrcpy nmap
```

---

## One-time Tablet Setup

### 1. Set Wi-Fi to use Device MAC (not randomized)
Android randomizes MAC addresses by default for privacy on public networks. Set it to stay fixed on your home Wi-Fi:
1. Open **Settings → Wi-Fi** on your tablet.
2. Tap your connected Wi-Fi network (or the gear icon next to it).
3. Tap **Privacy** and select **"Use device MAC"**.
4. **Turn Wi-Fi OFF and back ON once** so Android applies the device MAC to the active connection.
5. Note down the **MAC address** shown in that network's status.

> **Note:** Toggling Wi-Fi off and on is only needed *once* to apply the setting. Your tablet will keep this MAC address permanently on your home network.

### 2. Enable Wireless Debugging
1. Go to **Settings → About Tablet**.
2. Tap **Build Number** 7 times to unlock Developer Options.
3. Go to **Settings → Developer Options**.
4. Turn on **Wireless Debugging**.

### Do I need to turn on regular "USB Debugging"?
- **For wireless mirroring (viewing):** **NO**. Only **Wireless Debugging** is required.
- **For mouse & keyboard control on Xiaomi / HyperOS / MIUI:** **YES**. Xiaomi requires turning on:
  - **USB Debugging**
  - **USB Debugging (Security settings)** (grants permission to simulate touch/mouse input from your PC).
- **For older Android versions (Android 10 or below):** Older devices without native Wireless Debugging require connecting via USB once with USB Debugging enabled and running `adb tcpip 5555`.

### 💡 Pro Tip: Add the 1-Tap Quick Settings Tile
Android automatically turns off Wireless Debugging if Wi-Fi disconnects (as a security safeguard). To turn it back on with a single tap instead of opening Settings:
1. On your tablet, go to **Settings → Developer Options → Quick settings developer tiles**.
2. Turn ON the toggle for **Wireless debugging**.
3. Now, whenever you swipe down from the top of your tablet screen, you can toggle Wireless Debugging on or off with one tap!

---

## Installation & Setup

1. **Clone this repository:**
   ```bash
   git clone https://github.com/your-username/connect-tablet.git
   cd connect-tablet
   ```

2. **Configure your `.env` file:**
   Copy the example configuration:
   ```bash
   cp .env.example .env
   ```
   Open `.env` and set your tablet's Wi-Fi MAC address:
   ```ini
   TARGET_MAC="cc:42:10:b1:7d:61"
   ADB_PORT="5555"
   ```
   *(If you don't edit `.env` manually, the script will prompt you for your MAC address on first run and save it automatically).*

3. **Make the script executable and run:**
   ```bash
   chmod +x connect_tablet.sh
   ./connect_tablet.sh
   ```

---

## Usage

### Connecting (Daily Use)
- **From terminal:**
  ```bash
  ./connect_tablet.sh
  ```
- **From desktop:**
  Double-click the **Connect Tablet** shortcut created on your Desktop!

The script automatically finds your tablet by its MAC address, discovers its active port, and launches **scrcpy** immediately without asking for any codes or ports.

### Pairing with a Pairing Code (One-time)
If your tablet has never been paired with this PC before, or if you deleted the PC from the tablet's "Paired devices" list:
1. On the tablet, open **Developer Options → Wireless debugging → Pair device with pairing code**.
2. On your PC, run:
   ```bash
   ./connect_tablet.sh --pair
   ```
3. Enter the 5-digit port and 6-digit code shown in the popup.

Once paired, your PC is saved in the tablet's paired devices list, and subsequent connections will work with 1 click!

---

## Project Structure

```
connect-tablet/
├── connect_tablet.sh       # Main launcher script (handles MAC lookup, port scan, connect)
├── connect_tablet_icon.png # Desktop shortcut icon
├── .env.example            # Environment variables template
├── .env                    # Your local configuration (ignored by git)
├── .gitignore              # Git ignore rules
├── LICENSE                 # MIT License
└── README.md               # Documentation
```

---

## Troubleshooting

- **"Could not find a device with MAC address ..."**
  - Verify that the tablet and PC are connected to the same Wi-Fi network.
  - Make sure the tablet's Wi-Fi Privacy setting is set to **"Use device MAC"** (and Wi-Fi was toggled off/on once after changing it).
  - Wake up the tablet screen so power-saving mode does not sleep the Wi-Fi.

- **"Connection failed (device is not paired or port changed)"**
  - Make sure **Wireless Debugging** is turned ON on the tablet.
  - If you recently deleted the PC from "Paired devices" on the tablet, run `./connect_tablet.sh --pair` to pair again.

- **Screen mirrors, but mouse clicks don't work (Xiaomi / HyperOS)**
  - Go to **Developer Options**, turn on **USB Debugging** and **USB Debugging (Security settings)**.

---

## License

This project is licensed under the [MIT License](LICENSE).
