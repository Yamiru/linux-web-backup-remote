# Linux Web Backup – Remote (Google Drive)

Simple and safe website backup system for Linux servers, with automatic
upload to **Google Drive** (or any other cloud supported by `rclone`).\
Backups are compressed, separated by timestamp, uploaded to the cloud,
and old backups and logs are automatically rotated both locally and
on the remote.

> 🔗 **Local-only version (no cloud upload):**
> [github.com/yamiru/linux-web-backup](https://github.com/yamiru/linux-web-backup)

------------------------------------------------------------------------

## 📚 Table of Contents

- [👋 Before you start](#-before-you-start)
- [📥 Step 0 – Get the script on your server](#-step-0-get-the-script-on-your-server)
- [🪟 Setup Guide – WINDOWS users](#-setup-guide-windows-users)
- [🍎 Setup Guide – MAC users](#-setup-guide-mac-users)
- [🐧 Setup Guide – LINUX users](#-setup-guide-linux-users)
- [⚙ Configuration](#-configuration)
- [🎛 Backup Modes](#-backup-modes)
- [🚫 Excluding files and folders](#-excluding-files-and-folders)
- [📖 Recipes — copy-paste configs](#-recipes-copy-paste-configs-for-common-setups)
- [🌐 Other cloud providers](#-other-cloud-providers)
- [📁 Restore Example](#-restore-example)
- [🛠 Troubleshooting](#-troubleshooting)
- [📜 License](#-license)

------------------------------------------------------------------------

## 👋 Before you start

### What is this?
This guide teaches your **server** how to send backups of your website
to **Google Drive** automatically every day.

### What do I need?
- A Linux **server** (with SSH access)
- Your own **laptop or desktop computer** (Windows, Mac, or Linux)
- A **Google account** with some free space on Drive

### Why two computers?
Your **server** has no screen and no web browser. It's a "headless" machine.
But Google requires you to log in through a browser to give permission.

So we'll:
1. Get the backup script onto the **server** (Step 0)
2. Install `rclone` on the **server** (Step 1)
3. Install the same `rclone` tool on your **laptop**
4. Use the **laptop** to log in to Google (because it has a browser)
5. Copy a special "permission key" from the laptop back to the server
6. From then on, the **server** uploads on its own — forever

You only do this once. After that, it's automatic.

### Order of operations
Follow the guide top to bottom:

1. **Step 0** – get the script onto the server *(do this first!)*
2. **Pick your OS guide** below and follow Steps 1–9

------------------------------------------------------------------------
------------------------------------------------------------------------

## 📥 Step 0 – Get the script on your server

The `backup_www.sh` file must **live on your server** before you continue.
The easiest way: download it straight from GitHub with one command.

### The easy way (recommended)

🟦 SSH into your server, then run these commands one by one:

```bash
sudo mkdir -p /opt/linux-web-backup
sudo curl -L -o /opt/linux-web-backup/backup_www.sh \
    https://raw.githubusercontent.com/Yamiru/linux-web-backup-remote/main/backup_www.sh
sudo chmod +x /opt/linux-web-backup/backup_www.sh
```

✅ That's it. The script is now on your server at
`/opt/linux-web-backup/backup_www.sh` and ready to use.

Verify it worked:

```bash
ls -la /opt/linux-web-backup/backup_www.sh
```

You should see something like:

```
-rwxr-xr-x 1 root root 11506 May 22 17:00 /opt/linux-web-backup/backup_www.sh
```

> 💡 The `-rwxr-xr-x` at the start means the file is executable. ✓

✅ Step 0 done. Now pick your OS guide below.

------------------------------------------------------------------------

<details>
<summary><b>📦 Alternative: upload from your own computer</b></summary>

If for some reason `curl` doesn't work on your server (very rare),
you can also download the script to your laptop first and then upload
it. Pick your OS:

### 🪟 From Windows (using WinSCP)

1. 🖱️ Open https://github.com/Yamiru/linux-web-backup-remote/blob/main/backup_www.sh
2. 🖱️ Click the **"Download raw file"** button (small download icon, top-right of file view)
3. Save `backup_www.sh` to your computer
4. Install **WinSCP** from https://winscp.net/eng/download.php
5. Open WinSCP, connect to your server (SFTP, your server IP, port 22, your SSH user/password)
6. On the server side, navigate to `/opt/`
7. Right-click → New → Directory → name it `linux-web-backup`
8. Drag `backup_www.sh` from your computer into that folder
9. Right-click the file on the server → Properties → set permissions to `755` → OK

Then SSH into the server and verify:

```bash
ls -la /opt/linux-web-backup/backup_www.sh
```

### 🍎 From Mac

```bash
# On your Mac:
curl -L -o backup_www.sh \
    https://raw.githubusercontent.com/Yamiru/linux-web-backup-remote/main/backup_www.sh

# Upload to server (replace username and IP):
scp backup_www.sh username@your-server-ip:/tmp/

# SSH in and place it:
ssh username@your-server-ip
sudo mkdir -p /opt/linux-web-backup
sudo mv /tmp/backup_www.sh /opt/linux-web-backup/
sudo chmod +x /opt/linux-web-backup/backup_www.sh
```

### 🐧 From Linux desktop

Same as Mac — `curl` to your machine, `scp` to the server, `mv` and `chmod`
on the server.

</details>

------------------------------------------------------------------------
------------------------------------------------------------------------

# 🪟 Setup Guide – WINDOWS users

> Follow this guide if your **laptop or desktop** runs Windows
> (Windows 10, Windows 11, etc.).
>
> ⚠️ Make sure you already finished
> [📥 Step 0](#-step-0-get-the-script-on-your-server) — the `backup_www.sh` script must
> already be on the server.

------------------------------------------------------------------------

## 🪟 Step 1 – Install rclone on the server

🟦 **What does this do?** It puts a small tool called `rclone` on your
server. This tool knows how to talk to Google Drive.

### 1.1 – Log in to your server via SSH

Open **PuTTY**, **MobaXterm**, **Windows Terminal**, or whatever SSH client
you use to connect to your server.

Type your server's address, username, and password.

> 💡 If you don't know how to SSH yet, ask your hosting provider for help
> first — this guide assumes you already have SSH access.

### 1.2 – Start a tmux session (safety net)

Type this into the server's terminal:

```bash
tmux new -s rclone
```

> 💡 **Why tmux?** If your internet drops while you're following this
> guide, you don't lose progress. You can reconnect and continue where
> you left off with: `tmux attach -t rclone`

### 1.3 – Install rclone

Type this into the server's terminal:

```bash
curl https://rclone.org/install.sh | sudo bash
```

✅ You should see this at the end:

```
rclone v1.74.0 has successfully installed.
Now run "rclone config" for setup.
```

------------------------------------------------------------------------

## 🪟 Step 2 – Configure rclone on the server

Type this into the server's terminal:

```bash
rclone config
```

Now answer each question that appears:

### 2.1 – "make a new one?"

You'll see:

```
No remotes found, make a new one?
n) New remote
s) Set configuration password
q) Quit config
n/s/q>
```

⌨️ Type **`n`** and press Enter.

### 2.2 – "Enter name"

You'll see:

```
Enter name for new remote.
name>
```

⌨️ Type **`gdrive`** and press Enter.

### 2.3 – "Type of storage"

You'll see a long list of storage providers. Don't scroll through it.

```
Storage>
```

⌨️ Type **`drive`** and press Enter.

### 2.4 – "client_id"

```
Google Application Client Id
client_id>
```

⌨️ Just press **Enter** (leave it empty).

```
OAuth Client Secret
client_secret>
```

⌨️ Just press **Enter** (leave it empty).

> 💡 You don't need to "get" these from anywhere. Skip them.

### 2.5 – "scope"

```
scope>
```

⌨️ Type **`1`** and press Enter.

### 2.6 – Skip a few more

```
root_folder_id>
```
⌨️ Just press **Enter** (empty).

```
service_account_file>
```
⌨️ Just press **Enter** (empty).

```
Edit advanced config? y/n>
```
⌨️ Type **`n`** and press Enter.

### 2.7 – ⚠️ THE IMPORTANT ONE

```
Use auto config?
y) Yes (default)
n) No
y/n>
```

⌨️ Type **`n`** and press Enter.

> ⚠️ **DON'T just press Enter!** Default is `y` but that won't work
> on a server with no browser. You MUST type `n`.

### 2.8 – The server is now waiting

You'll see this:

```
Option config_token.
Execute the following on the machine with the web browser:
    rclone authorize "drive"
Then paste the result.
config_token>
```

🛑 **STOP. Don't type anything. Don't close this window.**

Leave this SSH window alone. Now we move to your Windows computer.

------------------------------------------------------------------------

## 🪟 Step 3 – Install rclone on your Windows laptop

### 3.1 – Download rclone

1. 🖱️ Open your web browser
2. 🖱️ Go to **https://rclone.org/downloads/**
3. 🖱️ Find the line **"Windows / AMD64 - 64 Bit"**
4. 🖱️ Click the **".zip"** link next to it\
   *(File will be named something like `rclone-v1.74.1-windows-amd64.zip`)*

### 3.2 – Extract the zip file

1. 🖱️ Go to your **Downloads** folder
2. 🖱️ Find the downloaded zip file (e.g. `rclone-v1.74.1-windows-amd64.zip`)
3. 🖱️ **Right-click** on it → **"Extract All..."**
4. 🖱️ Click **"Extract"** in the dialog that appears
5. A new folder appears, e.g. `rclone-v1.74.1-windows-amd64`
6. 🖱️ **Double-click that folder** to open it

You should now see files inside, including **`rclone.exe`**.

### 3.3 – Open PowerShell in that folder

This is the tricky part — pay attention:

1. 🖱️ Make sure you're **inside** the `rclone-v1.74.1-windows-amd64` folder
   (where `rclone.exe` is visible)
2. 🖱️ Click on an **empty area** of the folder *(not on any file!)*
3. ⌨️ Hold **Shift** on your keyboard
4. 🖱️ While holding Shift, **right-click** on the empty area
5. A menu appears. Click **"Open PowerShell window here"**\
   *(On older Windows it might say "Open command window here")*

A blue or black terminal window opens. The path at the top should show
your rclone folder, something like:

```
PS C:\Users\YourName\Downloads\rclone-v1.74.1-windows-amd64>
```

### 3.4 – Run the authorize command

In that PowerShell window, type **exactly** this:

```powershell
.\rclone authorize "drive"
```

> ⚠️ **Don't forget the `.\` at the start!** That's a dot and a
> backslash. Without it, Windows will say *"rclone is not recognized"*.

Press Enter.

------------------------------------------------------------------------

## 🪟 Step 4 – Log in to Google in your browser

### 4.1 – Browser opens automatically

A browser tab opens. You'll see Google asking you to log in.

🖱️ **Click on the Google account** you want to use for backups.

### 4.2 – ⚠️ "Google hasn't verified this app"

You'll see a scary-looking page:

```
Google hasn't verified this app
The app is requesting access to sensitive info in your Google Account.
```

> 🛡️ **Don't worry — this is normal.** rclone is open-source software
> trusted by millions of people. Google just charges money to "verify"
> apps, and rclone is free, so it skips that.

What to click:

1. Look at the **bottom-left** of that warning box
2. You should see a small grey link saying **"Advanced"**\
   *(It's small and easy to miss. Scroll down a tiny bit if you don't
   see it.)*
3. 🖱️ Click **"Advanced"**
4. New text appears below it. Click **"Go to rclone (unsafe)"**

> 📌 Yes it says "unsafe". It really isn't. That's just Google's
> standard wording for any app they haven't formally verified.

### 4.3 – Allow permissions

Google asks if rclone can access your Drive. Click **"Continue"**.

If another permissions screen appears, click **"Allow"** or **"Continue"**.
*(Sometimes it asks 1-2 times in a row.)*

### 4.4 – "Success!"

The browser shows:

```
Success!
All done. Please go back to rclone.
```

🖱️ You can close this browser tab now.

------------------------------------------------------------------------

## 🪟 Step 5 – Copy the token from PowerShell

Switch back to the **PowerShell window** on your Windows computer.

You'll see something like this:

```
Paste the following into your remote machine --->
{"access_token":"ya29.a0AfB_byC...","token_type":"Bearer","refresh_token":"1//0g..."}
<---End paste
```

You need to **copy that long line in the middle**:

1. 🖱️ Click at the **`{`** (the curly bracket at the beginning)
2. 🖱️ While holding the left mouse button, **drag to the `}`** at the end
3. The whole line should be highlighted
4. 🖱️ **Right-click** to copy (PowerShell copies selected text on right-click)

> ⚠️ **Important:** Do **NOT** copy the arrows `-->` and `<---`.
> Copy **only** what's between them — just the `{...}` part.

> 💡 **Trick:** Triple-click on the line to select the entire line at
> once. Then right-click to copy.

------------------------------------------------------------------------

## 🪟 Step 6 – Paste the token back to the server

Switch back to your **SSH window** where the server is still waiting at
`config_token>`.

> 📌 If your SSH disconnected: SSH back in, then type
> `tmux attach -t rclone` to continue where you left off.

1. 🖱️ Click into the SSH window to focus it
2. 🖱️ **Right-click** to paste *(in PuTTY, MobaXterm, Windows Terminal)*\
   *(Or use the menu Edit → Paste, depending on your SSH client)*
3. ⌨️ Press **Enter**

### 6.1 – "Shared Drive?"

```
Configure this as a Shared Drive (Team Drive)? y/n>
```

⌨️ Type **`n`** and press Enter.

### 6.2 – "Keep this remote?"

```
Keep this "gdrive" remote? y/e/d>
```

⌨️ Type **`y`** and press Enter.

### 6.3 – Final menu

```
e/n/d/r/c/s/q>
```

⌨️ Type **`q`** and press Enter. *(This quits the config.)*

🎉 **rclone is now connected to your Google Drive!**

------------------------------------------------------------------------

## 🪟 Step 7 – Test that it works

On the server, type:

```bash
rclone lsd gdrive:
```

✅ You should see a list of folders from your Google Drive:

```
          -1 2026-04-15 14:23:11        -1 Documents
          -1 2026-04-15 14:23:11        -1 Photos
          -1 2026-05-01 09:11:42        -1 Music
```

🎉 **If you see your folders — it works!**

------------------------------------------------------------------------

## 🪟 Step 8 – Run the backup script

> 📌 The script should already be at
> `/opt/linux-web-backup/backup_www.sh` from Step 0. If not,
> go back to [📥 Step 0](#-step-0-get-the-script-on-your-server).

Run it manually first:

```bash
sudo /opt/linux-web-backup/backup_www.sh
```

You should see logs scrolling past, and the last line:

```
Backup finished. Saved in /opt/linux-web-backup/backups/...
```

### 8.1 – Check Google Drive

🖱️ Open https://drive.google.com in your browser.

You should see a new folder:

```
📁 linux-web-backup/
   └─ 📁 2026-05-22_HHMMSS/
        └─ 📦 www.tar.gz
```

🎉

------------------------------------------------------------------------

## 🪟 Step 9 – Schedule automatic backups

On the server, type:

```bash
sudo crontab -e
```

If asked which editor, choose **nano** (it's the easiest).

Scroll to the bottom of the file and add this line:

```cron
0 3 * * * /opt/linux-web-backup/backup_www.sh >/dev/null 2>&1
```

> 💡 This means: every day at **03:00 AM** (3 hours after midnight), run
> the backup.

Save: press **Ctrl+O**, then **Enter**, then **Ctrl+X** to exit.

✅ Done. Your server will now back up automatically every night while
you sleep.

**You're finished. 🎉 Skip to [Configuration](#-configuration) if you
want to change settings.**

------------------------------------------------------------------------
------------------------------------------------------------------------

# 🍎 Setup Guide – MAC users

> Follow this guide if your **laptop or desktop** is a Mac
> (macOS / OS X).
>
> ⚠️ Make sure you already finished
> [📥 Step 0](#-step-0-get-the-script-on-your-server) — the `backup_www.sh` script must
> already be on the server.

------------------------------------------------------------------------

## 🍎 Step 1 – Install rclone on the server

🟦 **What does this do?** It puts a small tool called `rclone` on your
server. This tool knows how to talk to Google Drive.

### 1.1 – Log in to your server via SSH

Open **Terminal** on your Mac (Cmd+Space, type "Terminal", Enter).

Type:

```bash
ssh username@your-server-ip
```

Replace with your actual username and server address.

### 1.2 – Start a tmux session (safety net)

On the server, type:

```bash
tmux new -s rclone
```

> 💡 **Why tmux?** If your internet drops, you don't lose progress.
> You can reconnect with: `tmux attach -t rclone`

### 1.3 – Install rclone on the server

```bash
curl https://rclone.org/install.sh | sudo bash
```

✅ You should see at the end:

```
rclone v1.74.0 has successfully installed.
```

------------------------------------------------------------------------

## 🍎 Step 2 – Configure rclone on the server

On the server, type:

```bash
rclone config
```

Answer each question:

### 2.1 – "make a new one?"

```
n/s/q>
```
⌨️ Type **`n`** and press Enter.

### 2.2 – "Enter name"

```
name>
```
⌨️ Type **`gdrive`** and press Enter.

### 2.3 – "Type of storage"

```
Storage>
```
⌨️ Type **`drive`** and press Enter.

### 2.4 – "client_id" and "client_secret"

```
client_id>
```
⌨️ Just press **Enter** (empty).

```
client_secret>
```
⌨️ Just press **Enter** (empty).

### 2.5 – "scope"

```
scope>
```
⌨️ Type **`1`** and press Enter.

### 2.6 – Skip a few

```
root_folder_id>
```
⌨️ Just press **Enter**.

```
service_account_file>
```
⌨️ Just press **Enter**.

```
Edit advanced config? y/n>
```
⌨️ Type **`n`** and press Enter.

### 2.7 – ⚠️ THE IMPORTANT ONE

```
Use auto config? y/n>
```

⌨️ Type **`n`** and press Enter.

> ⚠️ **Don't just press Enter!** Type `n`.

### 2.8 – The server is now waiting

```
config_token>
```

🛑 **STOP. Leave this SSH window alone.** Move to your Mac.

------------------------------------------------------------------------

## 🍎 Step 3 – Install rclone on your Mac

### 3.1 – Install Homebrew (if you don't have it)

Open a **new** Terminal window on your Mac (Cmd+N, or File → New Window).

Check if you have Homebrew:

```bash
brew --version
```

If you see a version number, skip to step 3.2.

If you see *"command not found"*, install Homebrew first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

> 💡 Follow the on-screen prompts. It may ask for your Mac password.

### 3.2 – Install rclone

```bash
brew install rclone
```

✅ When finished, verify:

```bash
rclone version
```

### 3.3 – Run authorize

```bash
rclone authorize "drive"
```

------------------------------------------------------------------------

## 🍎 Step 4 – Log in to Google in your browser

### 4.1 – Browser opens automatically

Your default browser opens. Google asks you to log in.

🖱️ **Click the Google account** you want to use for backups.

### 4.2 – ⚠️ "Google hasn't verified this app"

You'll see a scary-looking warning.

> 🛡️ **Don't worry — this is normal.** rclone is open-source and
> trusted by millions.

What to click:

1. Look at the **bottom-left** of the warning
2. Find the small grey link **"Advanced"**
3. 🖱️ Click **"Advanced"**
4. 🖱️ Click **"Go to rclone (unsafe)"**

### 4.3 – Allow permissions

🖱️ Click **"Continue"** / **"Allow"** *(may appear 1-2 times)*.

### 4.4 – "Success!"

Browser shows:

```
Success!
All done. Please go back to rclone.
```

🖱️ Close the browser tab.

------------------------------------------------------------------------

## 🍎 Step 5 – Copy the token from Terminal

Switch back to the **Mac Terminal** where you ran `rclone authorize`.

You'll see:

```
Paste the following into your remote machine --->
{"access_token":"ya29...","token_type":"Bearer","refresh_token":"1//..."}
<---End paste
```

To copy the line:

1. 🖱️ Click at the **`{`** at the start
2. 🖱️ Drag your mouse to the **`}`** at the end
3. Press **Cmd+C** to copy

> ⚠️ **Don't copy the arrows `-->` and `<---`.** Only the `{...}` part.

> 💡 **Trick:** Triple-click on the line selects it all at once.

------------------------------------------------------------------------

## 🍎 Step 6 – Paste the token to the server

Switch to your **SSH window** where the server is waiting at
`config_token>`.

> 📌 If SSH disconnected: SSH back in, then `tmux attach -t rclone`.

1. 🖱️ Click into the SSH window
2. ⌨️ Press **Cmd+V** to paste
3. ⌨️ Press **Enter**

### 6.1 – "Shared Drive?"

```
y/n>
```
⌨️ Type **`n`** and press Enter.

### 6.2 – "Keep this remote?"

```
y/e/d>
```
⌨️ Type **`y`** and press Enter.

### 6.3 – Final menu

```
e/n/d/r/c/s/q>
```
⌨️ Type **`q`** and press Enter.

🎉 **rclone is connected to Google Drive!**

------------------------------------------------------------------------

## 🍎 Step 7 – Test that it works

On the server:

```bash
rclone lsd gdrive:
```

✅ You should see your Google Drive folders listed.

------------------------------------------------------------------------

## 🍎 Step 8 – Run the backup script

> 📌 The script should already be at
> `/opt/linux-web-backup/backup_www.sh` from Step 0. If not,
> go back to [📥 Step 0](#-step-0-get-the-script-on-your-server).

```bash
sudo /opt/linux-web-backup/backup_www.sh
```

### 8.1 – Check Google Drive

🖱️ Open https://drive.google.com in your browser.

You should see:

```
📁 linux-web-backup/
   └─ 📁 2026-05-22_HHMMSS/
        └─ 📦 www.tar.gz
```

🎉

------------------------------------------------------------------------

## 🍎 Step 9 – Schedule automatic backups

```bash
sudo crontab -e
```

Add at the bottom:

```cron
0 3 * * * /opt/linux-web-backup/backup_www.sh >/dev/null 2>&1
```

Save and exit *(in nano: Ctrl+O, Enter, Ctrl+X)*.

✅ Done!

**You're finished. 🎉 Skip to [Configuration](#-configuration) if you
want to customize settings.**

------------------------------------------------------------------------
------------------------------------------------------------------------

# 🐧 Setup Guide – LINUX users

> Follow this guide if your **laptop or desktop** runs Linux (Ubuntu,
> Fedora, Mint, Debian, Arch, etc.).
>
> ⚠️ Make sure you already finished
> [📥 Step 0](#-step-0-get-the-script-on-your-server) — the `backup_www.sh` script
> must already be on the server.

------------------------------------------------------------------------

## 🐧 Step 1 – Install rclone on the server

🟦 **What does this do?** It puts `rclone` on your server. This tool
knows how to talk to Google Drive.

### 1.1 – SSH into your server

Open a terminal on your Linux desktop and type:

```bash
ssh username@your-server-ip
```

### 1.2 – Start a tmux session

```bash
tmux new -s rclone
```

> 💡 If your SSH drops, reconnect and do `tmux attach -t rclone`.

### 1.3 – Install rclone on the server

```bash
curl https://rclone.org/install.sh | sudo bash
```

✅ Output ends with:

```
rclone v1.74.0 has successfully installed.
```

------------------------------------------------------------------------

## 🐧 Step 2 – Configure rclone on the server

```bash
rclone config
```

### 2.1 – "make a new one?"

```
n/s/q>
```
⌨️ Type **`n`** + Enter.

### 2.2 – "Enter name"

```
name>
```
⌨️ Type **`gdrive`** + Enter.

### 2.3 – "Type of storage"

```
Storage>
```
⌨️ Type **`drive`** + Enter.

### 2.4 – client_id / client_secret

```
client_id>
```
⌨️ **Enter** (empty).

```
client_secret>
```
⌨️ **Enter** (empty).

### 2.5 – "scope"

```
scope>
```
⌨️ Type **`1`** + Enter.

### 2.6 – Skip a few

```
root_folder_id>
```
⌨️ **Enter**.

```
service_account_file>
```
⌨️ **Enter**.

```
Edit advanced config? y/n>
```
⌨️ Type **`n`** + Enter.

### 2.7 – ⚠️ THE IMPORTANT ONE

```
Use auto config? y/n>
```
⌨️ Type **`n`** + Enter.

> ⚠️ Don't just press Enter — type `n`.

### 2.8 – The server is waiting

```
config_token>
```

🛑 **STOP.** Open a new terminal on your Linux desktop.

------------------------------------------------------------------------

## 🐧 Step 3 – Install rclone on your Linux desktop

Open a **new** terminal on your desktop (not SSH — locally).

### 3.1 – Install via package manager or script

**Ubuntu / Debian / Mint:**

```bash
sudo apt update
sudo apt install rclone
```

**Fedora / RHEL:**

```bash
sudo dnf install rclone
```

**Arch / Manjaro:**

```bash
sudo pacman -S rclone
```

**Or use the universal installer (always latest version):**

```bash
curl https://rclone.org/install.sh | sudo bash
```

### 3.2 – Verify

```bash
rclone version
```

### 3.3 – Run authorize

```bash
rclone authorize "drive"
```

------------------------------------------------------------------------

## 🐧 Step 4 – Log in to Google in your browser

### 4.1 – Browser opens automatically

🖱️ **Click your Google account.**

### 4.2 – ⚠️ "Google hasn't verified this app"

> 🛡️ Normal warning, rclone is safe.

1. Look bottom-left for **"Advanced"** (small grey link)
2. 🖱️ Click **"Advanced"**
3. 🖱️ Click **"Go to rclone (unsafe)"**

### 4.3 – Allow permissions

🖱️ Click **"Continue"** / **"Allow"**.

### 4.4 – "Success!"

```
Success!
All done. Please go back to rclone.
```

🖱️ Close the tab.

------------------------------------------------------------------------

## 🐧 Step 5 – Copy the token

Back in your local terminal (where you ran `rclone authorize "drive"`):

```
Paste the following into your remote machine --->
{"access_token":"ya29...","token_type":"Bearer","refresh_token":"1//..."}
<---End paste
```

Select the JSON line with your mouse (from `{` to `}`).
Press **Ctrl+Shift+C** to copy *(or right-click → Copy)*.

> ⚠️ Don't copy the arrows. Only `{...}`.

------------------------------------------------------------------------

## 🐧 Step 6 – Paste the token to the server

Switch to your SSH window (server still waiting at `config_token>`).

> 📌 If SSH dropped: reconnect, `tmux attach -t rclone`.

🖱️ Click into the SSH window.\
⌨️ Press **Ctrl+Shift+V** to paste.\
⌨️ Press **Enter**.

### 6.1 – "Shared Drive?"

```
y/n>
```
⌨️ Type **`n`** + Enter.

### 6.2 – "Keep this remote?"

```
y/e/d>
```
⌨️ Type **`y`** + Enter.

### 6.3 – Final menu

```
e/n/d/r/c/s/q>
```
⌨️ Type **`q`** + Enter.

🎉 **rclone is connected to Google Drive!**

------------------------------------------------------------------------

## 🐧 Step 7 – Test

```bash
rclone lsd gdrive:
```

✅ You should see your Drive folders.

------------------------------------------------------------------------

## 🐧 Step 8 – Run the backup script

> 📌 The script should already be at
> `/opt/linux-web-backup/backup_www.sh` from Step 0. If not,
> go back to [📥 Step 0](#-step-0-get-the-script-on-your-server).

```bash
sudo /opt/linux-web-backup/backup_www.sh
```

### 8.1 – Check Google Drive

🖱️ Open https://drive.google.com.

You should see:

```
📁 linux-web-backup/
   └─ 📁 2026-05-22_HHMMSS/
        └─ 📦 www.tar.gz
```

🎉

------------------------------------------------------------------------

## 🐧 Step 9 – Schedule automatic backups

```bash
sudo crontab -e
```

Add at the bottom:

```cron
0 3 * * * /opt/linux-web-backup/backup_www.sh >/dev/null 2>&1
```

Save and exit. ✅ Done!

**You're finished. 🎉**

------------------------------------------------------------------------
------------------------------------------------------------------------

## ⚙ Configuration

At the top of `backup_www.sh`:

```bash
# Storage paths
BACKUP_DIR="/opt/linux-web-backup/backups"
LOG_DIR="/opt/linux-web-backup/logs"

# Rotation
RETENTION_COUNT=5       # local backups
LOG_RETENTION=5         # log files

# Backup mode
SPLIT_BY_SUBDIR=false   # false = full archive (default), true = per-subdir

# Sources
SOURCES=$(cat <<'EOF'
/var/www
EOF
)

# Exclude patterns (skip these inside archives, works in BOTH modes)
EXCLUDE_PATTERNS=$(cat <<'EOF'
cache
tmp
.git
node_modules
*.log
EOF
)

# Google Drive (rclone)
RCLONE_ENABLE=true
RCLONE_REMOTE="gdrive"
RCLONE_PATH="linux-web-backup"
RCLONE_RETENTION=5      # backups kept on Drive
```

------------------------------------------------------------------------

## 🎛 Backup Modes

### Mode 1: Full archive (DEFAULT)

```bash
SPLIT_BY_SUBDIR=false
```

`/var/www` → `www.tar.gz` (one archive of everything)

### Mode 2: Split by subdirectory

```bash
SPLIT_BY_SUBDIR=true
```

```
/var/www/web1 → web1.tar.gz
/var/www/web2 → web2.tar.gz
/var/www/web3 → web3.tar.gz
```

Use `EXCLUDE_SUBDIRS` to skip folders like `html`, `.well-known`, etc.

------------------------------------------------------------------------

## 🚫 Excluding files and folders

You don't always want everything in the backup. Cache folders, logs,
`node_modules`, and similar junk just waste space. The script has two
separate ways to exclude things:

### `EXCLUDE_PATTERNS` — exclude things **inside** archives (recommended)

Works in **BOTH modes** (FULL and SPLIT). Passed directly to `tar` as
`--exclude` arguments. Supports glob patterns:

```bash
EXCLUDE_PATTERNS=$(cat <<'EOF'
cache                # any folder named "cache" at any depth
tmp                  # any folder named "tmp" at any depth
.git                 # version control metadata
node_modules         # JS/Node dependencies
*.log                # all .log files anywhere
*.cache              # all .cache files
storage/logs         # specific path
EOF
)
```

✅ Examples that match:
- `cache` matches `/var/www/web1/cache/`, `/var/www/web2/cache/`, etc.
- `*.log` matches `/var/www/web1/access.log`, `/var/www/web2/logs/error.log`
- `storage/logs` matches `/var/www/web1/storage/logs/` *(exact path component)*

> 💡 **Tip:** the patterns are interpreted by `tar`. See `man tar` for
> the full syntax — but for 95% of cases, just folder names and `*.ext`
> patterns are enough.

> 💡 **Empty pattern list?** Just delete the lines between `EOF`s
> *(or comment them out with `#`)*. The script handles an empty list
> gracefully.

### `EXCLUDE_SUBDIRS` — skip whole top-level folders (SPLIT mode only)

Skip entire subdirectories during scanning *(no archive created at all)*.
Only applies when `SPLIT_BY_SUBDIR=true`:

```bash
EXCLUDE_SUBDIRS=$(cat <<'EOF'
html
.well-known
_letsencrypt
EOF
)
```

With `SOURCES=/var/www` and `SPLIT_BY_SUBDIR=true`, a folder named
`/var/www/html` won't get its own `html.tar.gz`. The folder isn't
"backed up smaller" — it's skipped entirely.

### When to use which?

| You want to...                                | Use                |
|-----------------------------------------------|--------------------|
| Skip a test/default site folder entirely      | `EXCLUDE_SUBDIRS`  |
| Strip caches, logs, junk from inside backups  | `EXCLUDE_PATTERNS` |
| Make backup smaller without losing whole sites | `EXCLUDE_PATTERNS` |
| Exclude something in FULL mode                | `EXCLUDE_PATTERNS` |

In practice you'll mostly use `EXCLUDE_PATTERNS`. The defaults
(`cache`, `tmp`, `.git`, `node_modules`, `*.log`) are reasonable for
most websites.

### 💡 Key insight: patterns are mode-independent

`tar --exclude` is **not anchored** — a pattern matches anywhere in the
file path inside the archive. That means the **same pattern works in
both modes**:

- In **FULL mode**, archive path = `www/proserver/templates_c/...`\
  → pattern `proserver/templates_c` matches the middle ✓
- In **SPLIT mode**, archive path = `proserver/templates_c/...`\
  → same pattern matches from the start ✓

So **don't write `www/proserver/...`** — just `proserver/...`. It works
identically regardless of `SPLIT_BY_SUBDIR`.

------------------------------------------------------------------------

## 📖 Recipes — copy-paste configs for common setups

Don't reinvent the wheel. Pick the recipe that matches your situation,
copy the config, paste it into `backup_www.sh`, done.

### 🍳 Recipe 1: Multiple sites in `/var/www/<site>` (most common)

You host several websites, each in its own subdirectory. You want
**one archive per site** with junk files stripped out of each.

```bash
SPLIT_BY_SUBDIR=true

SOURCES=$(cat <<'EOF'
/var/www
EOF
)

EXCLUDE_SUBDIRS=$(cat <<'EOF'
html
.well-known
_letsencrypt
EOF
)

EXCLUDE_PATTERNS=$(cat <<'EOF'
cache
tmp
.git
node_modules
*.log
EOF
)
```

Result: `web1.tar.gz`, `web2.tar.gz`, ... — each clean, no junk.

### 🍳 Recipe 2: Mixed layout with shared folders in `/var/www`

You have site folders **and** shared top-level folders like
`/var/www/cache`, `/var/www/tmp`, `/var/www/uploads`, `/var/www/logs`
that shouldn't be backed up as separate archives.

Use `EXCLUDE_SUBDIRS` to skip those entire top-level folders, and
`EXCLUDE_PATTERNS` for junk inside each site:

```bash
SPLIT_BY_SUBDIR=true

SOURCES=$(cat <<'EOF'
/var/www
EOF
)

EXCLUDE_SUBDIRS=$(cat <<'EOF'
html
.well-known
_letsencrypt
cache
tmp
uploads
logs
EOF
)

EXCLUDE_PATTERNS=$(cat <<'EOF'
cache
.git
node_modules
*.log
EOF
)
```

`EXCLUDE_SUBDIRS` makes sure no `cache.tar.gz` / `tmp.tar.gz` /
`uploads.tar.gz` / `logs.tar.gz` ever gets created. `EXCLUDE_PATTERNS`
then strips internal junk from each site archive.

### 🍳 Recipe 3: Site-specific exclusions

You want to exclude **specific paths in specific sites** — e.g. Smarty
compiled templates only in `proserver`, phpMyAdmin in `avalonia`, PHP
sessions in `avalonia/tmp/sessions`.

Just add site-prefixed patterns. Works in **both** modes:

```bash
EXCLUDE_PATTERNS=$(cat <<'EOF'
cache
.git
node_modules
*.log
proserver/templates_c
avalonia/phpmyadmin
avalonia/tmp/sessions
EOF
)
```

> ⚠️ **Don't prefix with `www/`** — the patterns work without it in
> both modes. Adding `www/` would make them match in FULL mode only
> and silently fail in SPLIT mode.

### 🍳 Recipe 4: One big archive of `/var/www`

You don't care about per-site separation, you just want everything in
`/var/www` in one tarball:

```bash
SPLIT_BY_SUBDIR=false

SOURCES=$(cat <<'EOF'
/var/www
EOF
)

EXCLUDE_PATTERNS=$(cat <<'EOF'
cache
tmp
.git
node_modules
*.log
EOF
)
```

Result: one `www.tar.gz` per run. `EXCLUDE_SUBDIRS` is ignored in this
mode — only `EXCLUDE_PATTERNS` apply.

### 🍳 Recipe 5: Back up multiple unrelated paths

You want to back up your web root **and** nginx config, with each as a
separate archive:

```bash
SPLIT_BY_SUBDIR=false

SOURCES=$(cat <<'EOF'
/var/www
/etc/nginx
/etc/letsencrypt
EOF
)

EXCLUDE_PATTERNS=$(cat <<'EOF'
cache
tmp
.git
node_modules
*.log
EOF
)
```

Result: `www.tar.gz`, `nginx.tar.gz`, `letsencrypt.tar.gz`.

### 🐛 Troubleshooting your excludes

After a run, check what actually ended up in the archive:

```bash
# List everything in the newest archive
tar -tzf /opt/linux-web-backup/backups/$(ls -t /opt/linux-web-backup/backups | head -1)/proserver.tar.gz | head -30

# Check if a specific pattern was excluded
tar -tzf .../proserver.tar.gz | grep templates_c
# empty output = ✓ excluded successfully
```

If something you wanted excluded is still there:
- Check `Active exclude patterns: N` in the log to see how many were loaded
- Drop the `www/` prefix if you have one
- Make the pattern more specific: `proserver/templates_c` instead of just `templates_c`

------------------------------------------------------------------------

## 🌐 Other cloud providers

Same setup, different storage type in step 2.3:

| Provider           | Type in `rclone config` |
|--------------------|-------------------------|
| Google Drive       | `drive`                 |
| Dropbox            | `dropbox`               |
| Microsoft OneDrive | `onedrive`              |
| Amazon S3          | `s3`                    |
| Backblaze B2       | `b2`                    |
| pCloud             | `pcloud`                |
| WebDAV / Nextcloud | `webdav`                |

Full list: https://rclone.org/overview/

------------------------------------------------------------------------

## 📁 Restore Example

### From local backup

```bash
tar -xzf /opt/linux-web-backup/backups/2026-05-22_030000/www.tar.gz -C /var/
```

### From Google Drive

```bash
rclone lsd gdrive:linux-web-backup
rclone copy gdrive:linux-web-backup/2026-05-22_030000 ./restore/
tar -xzf ./restore/www.tar.gz -C /var/
```

------------------------------------------------------------------------

## 🛠 Troubleshooting

### ❌ Windows: `rclone : The term 'rclone' is not recognized`

You forgot the `.\` prefix in PowerShell. Use:

```powershell
.\rclone authorize "drive"
```

### ❌ `WARNING: rclone not installed`

Install rclone on the **server**:

```bash
curl https://rclone.org/install.sh | sudo bash
```

### ❌ `WARNING: rclone remote 'gdrive:' not configured`

Check existing remotes:

```bash
rclone listremotes
```

If empty, run `rclone config` again.\
If you see a different name, either rename it in `rclone config` (option `r`),
or change `RCLONE_REMOTE` in the script.

### ❌ `ERROR: Drive upload FAILED`

Check the log file in `/opt/linux-web-backup/logs/`.

Most common cause: token expired. Fix:

```bash
rclone config reconnect gdrive:
```

### ❌ Cron runs as root but rclone works only as my user

rclone stores tokens per-user in `~/.config/rclone/rclone.conf`.\
Either run cron as your user (`crontab -u username -e`), or re-run
`rclone config` **as root** (`sudo rclone config`).

### ❌ SSH disconnects during authorization

Always use `tmux new -s rclone` before `rclone config`. If you forgot
and got disconnected, just SSH back in and run `tmux attach -t rclone`.

### ❌ "I can't find the 'Advanced' link in Google's warning"

It's a small **grey** link in the **bottom-left** of the warning. Easy
to miss. Try scrolling down a bit inside that warning box.

### ❌ Token paste cuts off / weird characters on the server

Some SSH clients mangle very long paste content. Try:
- Maximize the SSH terminal window first
- Or save the token to a file on your laptop, then upload it via scp
- Or use Windows Terminal / iTerm2 / kitty (handle long pastes better)

### ❌ "Permission denied" when running the script

Did you forget `chmod +x`? Run:

```bash
sudo chmod +x /opt/linux-web-backup/backup_www.sh
```

------------------------------------------------------------------------

## 👍 Notes

The `backups/` and `logs/` folders are git-ignored.

`tar` warnings about files changing during archiving (common on a live
web server) are non-fatal and logged as `OK (with warnings)`.

If `rclone` is missing or no remote is configured, the script logs a
warning and continues with the local backup. You can disable Drive
upload entirely with `RCLONE_ENABLE=false`.

------------------------------------------------------------------------

## 📜 License

MIT License – see [LICENSE](LICENSE) for details.

------------------------------------------------------------------------

If you find this project useful, please ⭐ star it on GitHub!

Created with ❤️ by [Yamiru](https://yamiru.com/)
