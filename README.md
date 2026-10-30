# Connect Tablet

Wirelessly connect your Android tablet to your Linux PC and mirror its screen using [scrcpy](https://github.com/Genymobile/scrcpy). It uses your tablet's fixed Wi-Fi MAC address to automatically resolve its IP and connect with a single click.

## Features

- **No hardcoded IP needed:** Dynamically looks up your tablet's current IP address on your local network using its MAC address.
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
4. Note down the **MAC address** shown in that network's status.

### 2. Enable ADB / Wireless Debugging
1. Go to **Settings → About Tablet**.
2. Tap **Build Number** 7 times to unlock Developer Options.
3. Go to **Settings → Developer Options**.
4. Turn on **USB Debugging**.
5. Turn on **Wireless Debugging** (or **ADB over network**).

*(If your tablet does not have a wireless debugging switch, plug it into your PC with a USB cable once, run `adb tcpip 5555`, and unplug).*

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

- **First run:** Running `./connect_tablet.sh` connects to your tablet and creates a **"Connect Tablet"** shortcut on your Desktop.
- **Subsequent runs:** Simply double-click the **Connect Tablet** desktop shortcut anytime!

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
  - Make sure the tablet's Wi-Fi Privacy setting is set to **"Use device MAC"**.
  - Wake up the tablet screen so power-saving mode does not sleep the Wi-Fi.

- **"Connection refused" / ADB Error**
  - Verify Wireless Debugging is turned on in Developer Options.
  - If ADB TCP mode stopped after a tablet reboot, connect via USB once and run `adb tcpip 5555`.

---

## License

This project is licensed under the [MIT License](LICENSE).
