# Jerb-DpiDiscord

[TR · Türkçe](README.md) | **EN · English**

**Discord Launcher:** A small Windows tray tool that lets you use Discord, which is blocked in Türkiye, **without conflicting with your games**.

It uses ByeDPI and GoodbyeDPI together, each one only when it fits best. While Discord starts, it passes Discord's update check with GoodbyeDPI. Then it shuts GoodbyeDPI down completely and keeps Discord running through ByeDPI, which uses no driver. That way you can play games while Discord is open. Anti-cheat systems that are sensitive to network drivers, and game boosters (ping reducers), are not affected.

> **Note:** The launcher's own interface (tray menu, notifications, messages) is in Turkish. This document gives the Turkish menu labels together with their English meaning.

---

## Contents

- [Why does this tool exist?](#why-does-this-tool-exist)
- [How does it work?](#how-does-it-work)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Tray menu](#tray-menu)
- [Icon colors](#icon-colors)
- [Start with Windows](#start-with-windows)
- [Files it creates](#files-it-creates)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Security and verification](#security-and-verification)
- [Uninstalling](#uninstalling)
- [Credits](#credits)
- [License](#license)
- [Support](#support)
- [Disclaimer](#disclaimer)

---

## Why does this tool exist?

The most common way to reach Discord in Türkiye is **GoodbyeDPI**. It works well, but it relies on a network driver called **WinDivert**. This driver hooks into network traffic at kernel level, and that can cause problems:

- Some games' **anti-cheat systems** refuse to start, or crash after launch, while the WinDivert driver is loaded.
- **Game boosters / ping reducers** use their own network drivers and conflict with GoodbyeDPI.
- Limiting GoodbyeDPI to Discord's addresses with `--blacklist` does not fix this. The problem is not the traffic but the driver being loaded at all.

The other option, **ByeDPI**, uses no driver. It runs as a small local SOCKS5 proxy and only touches traffic sent to it. Games never see it. But there is a catch: **Discord's updater ignores proxy settings.** Discord checks for updates every time it starts, and with ByeDPI alone that check gets blocked. The result is the "Update failed" screen.

**Discord Launcher combines the two:**

| Stage | Tool used | Why |
|---|---|---|
| While Discord starts (update check) | GoodbyeDPI + ByeDPI | The updater only gets through with GoodbyeDPI |
| After Discord has started | **ByeDPI only** | No driver, no conflict with games |

GoodbyeDPI stays on for only a few seconds. It shuts down as soon as the update check finishes, and its driver is unloaded.

---

## How does it work?

```
 Baslat.bat
     │
     ▼
 discord.ps1 (hidden, as administrator)
     │
     ├─► Start ByeDPI hidden (127.0.0.1:1080)
     │
     ├─► Start GoodbyeDPI temporarily (Discord addresses only)
     │
     ├─► Discord not installed? → download and install it
     │
     ├─► Start Discord with the ByeDPI proxy setting
     │         │
     │         ▼
     │   Update check finished? (checked every second)
     │         │
     │         ▼ yes
     ├─► Stop GoodbyeDPI and the WinDivert driver  🟢
     │
     └─► Watch in the background:
           • ByeDPI crashed?             → restart it
           • Discord started w/o proxy?  → restart it with the proxy
           • Connection lost?            → find a working ByeDPI setting
           • Discord fully closed?       → stop ByeDPI and exit
```

The end of the update check is detected by any of these:
- A line in Discord's log showing the update finished
- The updater window closing and the main Discord window opening
- (When started hidden) Discord making a connection through ByeDPI

---

## Features

- 🎮 **Game friendly.** The WinDivert driver is not loaded while Discord is open.
- 🔄 **Discord updates work.** No "Update failed".
- 🖥️ **Runs in the system tray.** No black console window.
- 🟢 **Colored status icon.** Shows the state at a glance.
- 📥 **Installs Discord for you** if it isn't installed.
- 🔧 **Heals dropped connections.** Tests the connection every minute. If it drops, it first checks DNS and other GoodbyeDPI instances, then restarts ByeDPI; if that isn't enough, it tries 12 ByeDPI settings and saves the one that works.
- 🌍 **Adapts to different ISPs.** If the startup update check doesn't get through, it tries the settings from the GoodbyeDPI-Turkey package (main setting + 6 Superonline alternatives) one by one and remembers the one that works.
- 📝 **Event log.** Writes drops, automatic fixes and errors to `baslatici.log`.
- 🛡️ **Restarts ByeDPI** if it crashes.
- 🔁 **Fixes Discord started without the proxy** (for example after a big update) by restarting it with the right setting.
- 🚀 **Start with Windows.** No admin prompt, Discord starts minimized to the tray.
- 📁 **Keeps working at startup even if you rename or move the folder.**
- 🚫 **Catches other GoodbyeDPI instances.** If another GoodbyeDPI is installed as a service by some other package, or runs from another folder (it conflicts with games), it asks and shuts it down.
- 🩺 **Driver repair.** Clears the common WinDivert "1058" error with one click.
- 🔕 **Quiet mode.** Shows only problem notifications.
- 📶 **Connection info.** Shows the connection time to Discord and the ByeDPI setting in use.
- 🌐 **Sets up DNS for you.** Detects your ISP's DNS block and, with your permission, switches to encrypted DNS. You can undo it any time.
- 🔔 **Update notifications.** When a new version is released on GitHub, it shows a notification and puts a download link at the top of the menu.
- 🧹 **Closes everything when Discord closes.** Nothing is left running in the background.

---

## Requirements

- **Windows 10 or Windows 11** (64-bit)
- **Administrator rights** (needed for GoodbyeDPI's driver; the launcher asks for them itself)
- **Windows PowerShell 5.1** (built into Windows)
- **curl** (built into Windows 10 1803 and later)
- ByeDPI and GoodbyeDPI (included in this repository)
- **Encrypted DNS (DNS over HTTPS)** (the launcher can set it up; requires Windows 11)

---

## Installation

### 1. Download

Download **`JerbDpiDiscord-vX.zip`** from the [**Releases**](https://github.com/erendmrbs/JerbDpiDiscord/releases/latest) page. (Or green **Code** button → **Download ZIP**.) ByeDPI and GoodbyeDPI are included, you don't need to download anything else.

**Before extracting (recommended):** Right-click the zip → **Properties** → tick **"Unblock"** at the bottom → **OK.** Then extract it to any folder.

> **Why?** Windows marks files downloaded from the internet. Every file extracted from the zip gets that mark too, and `Baslat.bat` shows a **"The publisher could not be verified"** warning when opened. "Unblock" removes the mark up front, so you never see the warning.
>
> If you skip this step, that's fine: click **Run** on the first warning. On its first run the launcher removes the mark from every file in its folder, and the warning won't come back.

### 2. Folder layout

The extracted folder should look like this:

```
JerbDpiDiscord\
├── Baslat.bat                   ← the launcher, double-click this
├── LICENSE
├── README.md
├── README.en.md
├── byedpi\
│   ├── ciadpi.exe               ← ByeDPI 17.3 (64-bit)
│   ├── discord.ps1              ← the launcher itself
│   └── LICENSE-byedpi.txt
└── goodbyedpi\
    ├── goodbyedpi.exe           ← GoodbyeDPI 0.2.3rc3 (64-bit)
    ├── WinDivert.dll
    ├── WinDivert64.sys
    ├── discord.txt              ← the only Discord addresses GoodbyeDPI touches
    └── licenses\               ← GoodbyeDPI and WinDivert licenses
```

The name of the main folder doesn't matter. Put it anywhere and name it anything. Just keep `Baslat.bat`, `byedpi` and `goodbyedpi` next to each other.

> **Want newer versions?** Download [ByeDPI](https://github.com/hufrea/byedpi/releases) and [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI/releases) from their official pages and put the files in the same places. GoodbyeDPI also works from a `goodbyedpi\x86_64\` subfolder.

### 3. DNS (the launcher does it for you)

Your ISP also blocks Discord at the DNS level: when you look up Discord, it returns the address of a block page instead of the real one. Then Discord can't connect, and your browser shows **"Your connection is not private" / `NET::ERR_CERT_AUTHORITY_INVALID`**.

**The launcher checks this every time it starts.** If `discord.com` resolves to the wrong address, it offers to switch your DNS to **Cloudflare encrypted DNS (1.1.1.1, DNS over HTTPS)**:

- It **asks for permission** before changing anything.
- Your old DNS settings are **backed up** to `%LocalAppData%\DiscordBaslatici\dns_yedek.json`.
- You can undo it any time from the tray menu: **DNS → Eski haline döndür** (Restore previous).
- If you say "No", it won't ask again. You can do it later from **DNS → DNS ayarını kontrol et / yap** (Check / set up DNS).
- When started hidden with Windows, it doesn't ask; it only shows a warning notification.

> **Windows 10:** Encrypted DNS (DNS over HTTPS) is a Windows 11 feature. On Windows 10 the launcher sets DNS to 1.1.1.1, but that may not be enough to get past your ISP's DNS block.

#### Doing it manually

If the automatic setup doesn't work, the launcher shows these steps:

1. **Settings → Network & internet →** your connection (Ethernet or Wi-Fi)
2. **DNS server assignment → Edit → Manual**
3. **IPv4: On**
   - Preferred DNS: `1.1.1.1` → **DNS over HTTPS: On (automatic template)**
   - Alternate DNS: `1.0.0.1` → **DNS over HTTPS: On (automatic template)**
   - For both: **"Fallback to plaintext": Off** (important, see below)
4. **Save**
5. In an administrator command prompt: `ipconfig /flushdns`

**Check:** Run `ping discord.com` in a command prompt. If the address starts with `162.159.`, it's correct.

> Typing `1.1.1.1` alone is not enough; **"DNS over HTTPS"** must be on. ISPs can intercept unencrypted DNS requests and answer them themselves.
>
> **"Fallback to plaintext" must be off.** When it's on and encrypted DNS briefly fails, Windows falls back to plain DNS. At that moment your ISP returns a fake address for `discord.com` (for example `195.175.254.2`), and a few minutes later Discord loses its connection. When the launcher sets up DNS itself, this option is already off.

### 4. Remove an old GoodbyeDPI install (if any)

If you previously installed GoodbyeDPI **as a service** (for example with the `service_install` scripts), remove it, or the drivers will conflict. In an administrator command prompt:

```bat
sc stop GoodbyeDPI
sc delete GoodbyeDPI
sc stop WinDivert
sc delete WinDivert
```

Then **restart your PC.** You can also delete the old GoodbyeDPI folder. The launcher only uses the copy in its own folder.

### 5. Turn off Discord's own autostart

In Discord, go to **User Settings → Windows Settings** and turn off **"Open Discord"**. Otherwise Discord will also try to start without the proxy when Windows starts and conflict with the launcher.

I also recommend turning on **"Minimize to tray"** in the same place.

---

## Usage

1. Double-click **`Baslat.bat`**. (If "The publisher could not be verified" appears the first time, click **Run**; see [Installation](#installation).)
2. Windows asks for administrator permission. Click **Yes**.
3. A **Discord icon** appears in the system tray (next to the clock). The dot in its corner is **yellow**.
4. Discord starts and checks for updates. Hover over the icon to see the status.
5. When the dot turns **green**, GoodbyeDPI is off and Discord is running through ByeDPI.
6. Now you can start your game.

> ⚠️ **Don't start your game before the icon turns green.** GoodbyeDPI is on during the update check, so games sensitive to network drivers may crash if started in those few seconds.

**Closing Discord:** Right-click Discord's own tray icon → **Quit Discord.** Within a few seconds the launcher notices, stops ByeDPI and exits.

**You'll see two Discord icons in the tray:** one is Discord itself, the other is the launcher. The launcher's has a colored dot and shows "Discord Başlatıcı" when you hover over it.

---

## Tray menu

**Left-click** the launcher icon to bring Discord's window to the front.

**Right-click** opens this menu:

| Item (Turkish) | Meaning | What it does |
|---|---|---|
| **⬆ Yeni sürüm var** | New version available | Only appears when a new version is out; opens the download page |
| **Jerb-DpiDiscord GitHub** | | Opens this project's GitHub page |
| **Destek ol (bağış)** | Support (donate) | Opens the GitHub Sponsors page |
| **Durum** | Status | Shows what's happening (waiting for update, running, etc.) |
| **Bağlantı süresi** | Connection time | How many ms it takes to reach Discord through ByeDPI. Measured each time the menu opens. |
| **ByeDPI ayarı** | ByeDPI setting | The ByeDPI parameters in use |
| **Discord'u yeniden başlat** | Restart Discord | Closes Discord, passes it through the update check and starts it again |
| **Programı yeniden başlat** | Restart program | Closes the whole launcher (Discord, ByeDPI, GoodbyeDPI included) and starts it fresh |
| **ByeDPI ayarını otomatik bul** | Find ByeDPI setting | Tests the connection; if it fails, tries other settings and saves the one that works |
| **Güncellemeleri denetle** | Check for updates | Checks GitHub for a new version right away. The launcher also does this 30 seconds after starting and every 6 hours. |
| **Kayıtları aç** | Open log | Opens the event log (`baslatici.log`) in Notepad |
| **Arka plandaki GoodbyeDPI'ı kapat** | Close background GoodbyeDPI | Finds and stops GoodbyeDPI services and programs the launcher didn't start. The launcher also checks this at startup and every 30 seconds. |
| **Sürücü hatasını onar** | Repair driver | Clears the WinDivert driver registration and offers a restart |
| **DNS → DNS ayarını kontrol et / yap** | Check / set up DNS | Checks whether DNS resolves Discord correctly; switches to encrypted DNS if needed |
| **DNS → Eski haline döndür** | Restore previous | Restores your DNS settings from before the launcher changed them |
| **Bilgisayar açılınca başlat** | Start with Windows | Turns autostart on/off |
| **Sessiz mod** | Quiet mode | Shows only warnings and errors |
| **Her şeyi kapat** | Close everything | Closes Discord, ByeDPI and GoodbyeDPI and exits the launcher |

> ⚠️ **"Discord'u yeniden başlat"** (Restart Discord) turns GoodbyeDPI on for a few seconds. Don't use it while a game that is sensitive to network drivers is running.

---

## Icon colors

| Color | Meaning |
|---|---|
| 🟡 **Yellow** | Starting, waiting for the update check, or searching for a ByeDPI setting. **GoodbyeDPI may be on.** |
| 🟢 **Green** | All set. Discord is running through ByeDPI, GoodbyeDPI is off. |
| 🔴 **Red** | Something is wrong: GoodbyeDPI couldn't start, the update check didn't finish, or Discord can't be reached. |

---

## Start with Windows

Tick **"Bilgisayar açılınca başlat"** (Start with Windows) in the right-click menu.

- A task named **"Discord Baslatici"** is added to Windows **Task Scheduler**. It runs with administrator rights, so there's no permission prompt at every startup.
- It starts **5 seconds after you sign in**. If the internet connection isn't up yet, the launcher notices and waits until it is (yellow icon, status: "internet bekleniyor"), then starts Discord.
- Discord's window doesn't open; it starts **minimized to the tray**. The "Discord ready" notification isn't shown either.

### If you move or rename the folder

When autostart is turned on, a small **finder** script is placed in `%LocalAppData%\DiscordBaslatici\`. The task runs this finder directly. The finder:

1. Looks at the launcher's last known location.
2. If it isn't there, searches around the old location, your **Desktop**, **Documents**, **Downloads** and user folder.
3. Checks that the file it found really is this launcher, saves the new location and starts it.
4. If it finds nothing, it shows a warning. Then just run `Baslat.bat` once by hand.

---

## Files it creates

| File | Location | Purpose |
|---|---|---|
| `byedpi_ayar.txt` | `byedpi\` | The working ByeDPI setting found automatically |
| `goodbyedpi_ayar.txt` | `byedpi\` | The GoodbyeDPI setting that worked for the update check (if different from the default) |
| `sessiz_mod.txt` | `byedpi\` | If present, quiet mode is on |
| `baslatici.log` | `byedpi\` | Event log: connection drops, automatic fixes and errors. Open it with **"Kayıtları aç"** (Open log) in the menu. |
| `dns_sorma.txt` | `byedpi\` | If present, the DNS question isn't asked at startup |
| `dis_goodbyedpi_kapat.txt` | `byedpi\` | If present, other GoodbyeDPI instances are closed without asking |
| `dns_yedek.json` | `%LocalAppData%\DiscordBaslatici\` | Your DNS settings before the launcher changed them |
| `bulucu.ps1` | `%LocalAppData%\DiscordBaslatici\` | The finder script used at startup |
| `yol.txt` | `%LocalAppData%\DiscordBaslatici\` | The launcher's last known location |
| `DiscordSetup.exe` | `%TEMP%\` | The Discord installer, downloaded if Discord isn't installed |

To reset the settings, just delete `byedpi_ayar.txt` and `goodbyedpi_ayar.txt`.

---

## Troubleshooting

### "GoodbyeDPI başlatılamadı" (GoodbyeDPI couldn't start) / `Error opening filter: 1058`

The WinDivert driver's registration in Windows is stuck in a broken state. This usually happens when the driver is started and stopped many times, or when GoodbyeDPI copies in different folders try to use the same driver.

**Fix:** The launcher offers a repair when it notices this. Or choose **"Sürücü hatasını onar"** (Repair driver) from the menu, then **restart your PC.** The restart is required; the removed driver registration is only fully cleared then.

To do it by hand, in an administrator command prompt:
```bat
sc stop WinDivert
sc delete WinDivert
sc stop WinDivert14
sc delete WinDivert14
```
then restart.

> Don't run these commands at every startup. Deleting a driver that is in use marks it "pending deletion", and you'll get the same error until you restart.

### Discord says "Update failed"

- Make sure the icon stays **yellow**; GoodbyeDPI needs to be running. If it's red, do the driver repair above.
- **Windows proxy** may have been left on: Settings → Network & internet → **Proxy** → "Use a proxy server" must be **Off**.
- Run `netsh winhttp show proxy` in an administrator command prompt; it should say "Direct access". If not: `netsh winhttp reset proxy`
- If `%AppData%\discord\settings.json` contains `SKIP_HOST_UPDATE` or `SKIP_MODULE_UPDATE` lines, delete them.
- If nothing helps, uninstall Discord, delete the `%LocalAppData%\Discord` and `%AppData%\discord` folders and run the launcher. It will download and install Discord itself.

### Browser shows "Your connection is not private" / `ERR_CERT_AUTHORITY_INVALID`

This means the block was bypassed, but you reached your ISP's block page. The cause is DNS. Choose **DNS → DNS ayarını kontrol et / yap** (Check / set up DNS) in the tray menu, or [set it up manually](#doing-it-manually).

### Discord opens but can't connect (stuck on "Connecting…")

- Choose **"ByeDPI ayarını otomatik bul"** (Find ByeDPI setting) from the menu.
- If no setting works, the icon turns red. Check your internet connection and DNS.
- Your ISP may have changed its blocking method. You can add new ByeDPI parameters to the `$script:onAyarlar` list in `discord.ps1`.

### Works for a while, then the connection drops (restarting fixes it)

The most common cause is **DNS**. When encrypted DNS briefly fails, Windows may fall back to plain DNS, and at that moment your ISP returns a fake address for `discord.com` (for example `195.175.254.2`). Restarting seems to fix it for a few minutes because GoodbyeDPI, which runs while the launcher starts, temporarily fixes DNS.

The launcher checks this every minute. If it sees a fake answer, it clears the DNS cache and re-applies the encrypted DNS settings. To check by hand:

```powershell
Resolve-DnsName discord.com -Type A | Select-Object -First 1 IPAddress
```

If the address doesn't start with `162.159.`, open your DNS settings and turn **"Fallback to plaintext"** under DNS over HTTPS **Off**.

### The icon stays yellow, then turns red ("güncelleme bitmedi" / update didn't finish)

The launcher tried all 7 settings from the GoodbyeDPI-Turkey package (20 seconds each) and the update check didn't get through with any of them, so GoodbyeDPI was stopped for safety. Try **"Discord'u yeniden başlat"** (Restart Discord) from the menu. If the problem continues, check the log with **"Kayıtları aç"** (Open log).

### The launcher doesn't start at all

- Make sure `Baslat.bat` is **next to** the `byedpi` folder.
- If Windows SmartScreen warns you, click **More info → Run anyway.**
- Your antivirus may be blocking the WinDivert driver. See [Antivirus warnings](#antivirus-warnings).

### "Discord Başlatıcı zaten çalışıyor" (already running)

The launcher is already open. Look for its tray icon. It may be among the hidden icons (click the **^** arrow next to the clock).

---

## FAQ

**How do I update when a new version comes out?**
The launcher tells you. Click the notification or **"⬆ Yeni sürüm var"** (New version available) at the top of the menu and download the zip from the release page. Close the launcher ("Her şeyi kapat"), then copy the files from the new zip over the old folder. Your settings (`byedpi_ayar.txt`, `sessiz_mod.txt`) are kept.

**Why does it need administrator rights?**
To load the WinDivert driver used by GoodbyeDPI. ByeDPI and Discord itself don't need administrator rights.

**Could my game account get banned because of this?**
No network driver is loaded while Discord is open. ByeDPI is just an ordinary local proxy that carries Discord's traffic. Still, nobody can give guarantees on behalf of any game's anti-cheat. Use at your own risk.

**Does voice chat work?**
Yes. Discord's voice chat goes another way (UDP) and doesn't pass through the proxy, but since the block is usually placed on website addresses, voice works fine.

**Can I use Discord in a browser?**
This tool is for the desktop app. For a browser, you can run ByeDPI on its own and set the browser's proxy to `socks5://127.0.0.1:1080`. In Firefox, don't forget to tick "Proxy DNS when using SOCKS v5".

**Why not use only ByeDPI?**
Discord's updater ignores proxy settings: neither the `--proxy-server` flag, nor environment variables, nor the Windows proxy setting. Skipping the update check with settings like `SKIP_HOST_UPDATE` isn't reliable either. So GoodbyeDPI is needed briefly for the update check.

**Why not use only GoodbyeDPI?**
Because that is the actual problem: some games won't start, or crash, while the WinDivert driver is loaded.

**Does it work with other DPI bypass tools (zapret, etc.)?**
zapret also uses WinDivert, so it has the same problem with games. It could replace GoodbyeDPI for the update stage, but this version doesn't support that.

**Does my ISP matter?**
The launcher was built for common ISPs in Türkiye. The blocking method can differ between ISPs; that's why the automatic ByeDPI setting search exists.

---

## Security and verification

The launcher runs with administrator rights, loads a network driver and, if you allow it, changes your DNS settings. So it matters that you know what it does. That is the biggest benefit of this project being open source.

### Read the code yourself

The launcher is made entirely of plain text files. There is no hidden compiled part:
- `Baslat.bat`: only starts `discord.ps1` hidden.
- `byedpi/discord.ps1`: the script that does everything. Open it in Notepad and read every line. The code comments are in Turkish.

The launcher only connects to the internet for: Discord's own servers (connection test and downloading the Discord installer) and Cloudflare (1.1.1.1) for DNS. It collects no data and sends nothing anywhere.

### Verify the program files (SHA-256)

The `.exe`, `.dll` and `.sys` files in this repository are not readable code. You can verify yourself that they are identical to the official ByeDPI and GoodbyeDPI files. SHA-256 hashes of the files in this repository:

| File | Source | SHA-256 |
|---|---|---|
| `byedpi/ciadpi.exe` | ByeDPI 17.3, `byedpi-17.3-x86_64-w64.zip` | `eb53ceeeb981cc6735ac24bb1e51e725280b86630e80fdf19ddc4ee4a5b54ef4` |
| `goodbyedpi/goodbyedpi.exe` | GoodbyeDPI 0.2.3rc3, `x86_64` | `8d412b094bb9c137ff25ba9a794d1122ecc84bb776debff6c249723a13cc31cd` |
| `goodbyedpi/WinDivert.dll` | GoodbyeDPI 0.2.3rc3, `x86_64` | `6110bfa44667405179c3e15e12af1b62037e447ed59b054b19042032995e6c7e` |
| `goodbyedpi/WinDivert64.sys` | GoodbyeDPI 0.2.3rc3, `x86_64` | `e69b5ba3f0cd6cfb2983e442636e7f0b342b61b15264b0328317d4559c82cf50` |

**How to check:**
1. Compute the hash of the file from this repository. In PowerShell:
   ```powershell
   Get-FileHash .\byedpi\ciadpi.exe -Algorithm SHA256
   ```
   or in a command prompt:
   ```bat
   certutil -hashfile byedpi\ciadpi.exe SHA256
   ```
2. Download the same version from the official page ([ByeDPI](https://github.com/hufrea/byedpi/releases), [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI/releases)) and compute its hash too.
3. If the two hashes are exactly the same, the files are identical and unmodified.

If the hashes don't match, or you don't want to trust them, delete these files and put the ones you downloaded from the official pages in the same places. The launcher works the same way with them.

> Only download this project from **this repository**. Copies shared on other sites or in forks may have been modified.

### Antivirus warnings

Some antivirus programs (including Windows Defender) may flag files in this project as **suspicious**. Why:

- The **WinDivert** driver hooks into network traffic at kernel level. Because the same driver is also used by some malware, antivirus programs may flag the driver itself. WinDivert is an open source, legitimate tool.
- **DPI bypass tools** (GoodbyeDPI, ByeDPI) modify network packets, so some antivirus programs show a generic "HackTool" or "RiskWare" warning. That doesn't mean it's a virus; it means "this tool modifies network traffic".
- A **PowerShell script running hidden** and a `.bat` file **asking for administrator rights** can also look suspicious to some security software.

**What to do:**
1. First verify the files with the SHA-256 hashes above.
2. If you like, upload the files to [VirusTotal](https://www.virustotal.com/) to see the results of dozens of antivirus engines together. A few engines saying "HackTool" is normal for tools like these.
3. If you trust it, add the project folder to your antivirus **exclusions**. In Windows Defender: **Windows Security → Virus & threat protection → Manage settings → Exclusions → Add an exclusion → Folder.**

---

## Uninstalling

1. Untick **"Bilgisayar açılınca başlat"** (Start with Windows) in the menu (removes the task).
2. If the launcher changed your DNS, choose **DNS → Eski haline döndür** (Restore previous).
3. Choose **"Her şeyi kapat"** (Close everything).
4. Delete the folder.
5. Delete the `%LocalAppData%\DiscordBaslatici` folder.
6. Optionally clear the WinDivert driver registration:
   ```bat
   sc delete WinDivert
   ```

---

## Credits

This tool is a launcher built on top of the open source projects below. They do the real work:

- [**ByeDPI**](https://github.com/hufrea/byedpi): hufrea
- [**GoodbyeDPI**](https://github.com/ValdikSS/GoodbyeDPI): ValdikSS
- [**WinDivert**](https://github.com/basil00/WinDivert): basil00

For easy setup, compiled Windows builds of these programs are included in this repository unmodified, together with their licenses:

| Program | Version | License | License file |
|---|---|---|---|
| ByeDPI | 17.3 (x86_64) | MIT | `byedpi/LICENSE-byedpi.txt` |
| GoodbyeDPI | 0.2.3rc3 (x86_64) | Apache 2.0 | `goodbyedpi/licenses/LICENSE-goodbyedpi.txt` |
| WinDivert | bundled with GoodbyeDPI | LGPL v3 | `goodbyedpi/licenses/LICENSE-windivert.txt` |

Their source code is available at the links above.

---

## License

**Jerb-DpiDiscord**'s own code (`Baslat.bat`, `byedpi/discord.ps1`) is open source under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for details.

In short:
- ✅ You can use, read, modify and share the code for free.
- ✅ You can distribute modified versions, but **only under the same GPL-3.0 license and together with the source code**.
- ❌ You can't turn this code into a closed source program.
- ⚠️ The software comes with no warranty.

The bundled ByeDPI, GoodbyeDPI and WinDivert are not covered by this license. Each is under its own license (see [Credits](#credits)).

---

## Support

This project is free and will stay free. If it helped you and you'd like to support it:

- 💖 [**Donate with GitHub Sponsors**](https://github.com/sponsors/erendmrbs)
- ⭐ **Star** the repository so it reaches more people.
- 🐛 Found a bug or have an idea? Report it under [**Issues**](https://github.com/erendmrbs/JerbDpiDiscord/issues).

You can also reach the donation page from the **"Destek ol (bağış)"** (Support) item in the tray menu.

---

## Disclaimer

This tool is made for personal use and provided as is, without any warranty. The legal status of tools for bypassing access blocks varies from country to country. You are solely responsible for how you use it. This project is not affiliated with Discord Inc., ByeDPI, GoodbyeDPI or any game company.
