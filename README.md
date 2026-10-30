# Connect Tablet

Wirelessly connect your Android tablet to your Linux PC and mirror its screen using [scrcpy](https://github.com/Genymobile/scrcpy). It uses your tablet's fixed Wi-Fi MAC address to automatically resolve its IP and connect with a single click.

## Features

- **No hardcoded IP needed:** Dynamically looks up your tablet's current IP address on your local network using its MAC address.
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
Android randomizes MAC addresses by default for privacy on public networks. Set it to use the device's fixed MAC on your home Wi-Fi:
1. Open **Settings → Wi-Fi** on your tablet.
2. Tap your connected Wi-Fi network (or the gear icon next to it).
3. Tap **Privacy** and select **"Use device MAC"**.
4. **Turn Wi-Fi OFF and back ON** on the tablet so the setting takes effect.
5. Note down the **MAC address** shown in that network's status.

### 2. Enable ADB / Wireless Debugging
1. Go to **Settings → About Tablet**.
2. Tap **Build Number** 7 times to unlock Developer Options.
3. Go to **Settings → Developer Options**.
4. Turn on **USB Debugging**.
5. Turn on **Wireless Debugging** (or **ADB over network**).

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

- **Standard Connect:**
  ```bash
  ./connect_tablet.sh
  ```
  Connects to your tablet and creates a **"Connect Tablet"** shortcut on your Desktop.

- **Pairing with a Pairing Code:**
  ```bash
  ./connect_tablet.sh --pair
  ```
  Prompts for the 5-digit port and 6-digit code shown when you tap **"Pair device with pairing code"** under Wireless Debugging.

- **Subsequent runs:**
  Double-click the **Connect Tablet** desktop shortcut anytime!

---

## Project Structure

```
connect-tablet/
├── connect_tablet.sh       # Main launcher script
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
  - Make sure the tablet's Wi-Fi Privacy setting is set to **"Use device MAC"** and Wi-Fi was toggled off/on.
  - Wake up the tablet screen so power-saving mode does not sleep the Wi-Fi.

- **"Connection refused" / ADB Error**
  - Verify Wireless Debugging is turned on in Developer Options.
  - Run `./connect_tablet.sh --pair` to pair with your tablet using a pairing code.

---

## License

This project is licensed under the [MIT License](LICENSE).
