# xianyu-link

Get a **Xianyu (闲鱼) product link while logged out** — no root, no Frida, no APK patching, no login.

Tapping *Share → 复制链接* on a product page while logged out throws a login wall at you. This tool sidesteps the app's share panel entirely and gives you the public product URL another way: one command, one URL.

By default it just **prints** the link and opens nothing. Add `--share` when you want it on the clipboard (via the Android share sheet).

```console
$ xianyu-link
https://www.goofish.com/item?id=863824608549

$ xianyu-link --share
  item  863824608549
  link  https://www.goofish.com/item?id=863824608549

> share sheet opened — tap Copy (or any app) to finish
```

---

## Why

Xianyu's own share panel needs an authenticated `mtop` call to build the share link, so logged out it can only show you a login screen. The item id, however, is **already on the device** — the app logs it every time it opens a product page. That log is readable over plain `adb`:

```console
$ adb shell "logcat -d -t 2000" | grep -oE 'itemId[^0-9]{0,8}[0-9]{8,20}' | tail -1
itemId=863824608549
```

Which means the link is one regex and a URL template away. No privilege escalation, no runtime hooking, nothing installed on the phone beyond the official app.

---

## Install

**Requirements:** `adb` (Android platform-tools) and USB debugging enabled. That is genuinely all — no root, no Python, no Frida.

Works with the stock `pidof`, falling back to `ps` on older or stripped ROMs.
`--doctor` reports which one your device provided.

```bash
git clone https://github.com/lyricalfrog3/xianyu-link.git
cd xianyu-link
./install.sh          # copies to ~/.local/bin
```

Or just run it in place — it's a single bash script with no dependencies beyond `adb`.

### macOS

```bash
brew install --cask android-platform-tools
```

### Linux (Debian/Ubuntu)

```bash
sudo apt install android-tools-adb
```

---

## Usage

```bash
xianyu-link                 # print the link for the product you're viewing
xianyu-link --share         # same, then open the Android share sheet
xianyu-link --open          # open the product page in your browser
xianyu-link --id 863824608549
xianyu-link --watch         # print links as you browse
xianyu-link --doctor        # diagnose setup problems
```

> **Nothing pops up unless you ask.** Plain `xianyu-link` prints a URL and opens
> nothing — safe to run in a terminal, a script, or a cron job. Only `--share`,
> `--open` and `--clipboard` touch the phone's UI.

**Typical flow — just the link**

1. Open a product in Xianyu on the phone.
2. Run `xianyu-link`.
3. Copy it from your terminal, or pipe it somewhere:

```bash
xianyu-link | pbcopy            # macOS
xianyu-link | wl-copy           # Wayland
xianyu-link | xclip -selection c  # X11
```

**Typical flow — get it onto the phone's clipboard**

1. Open a product in Xianyu on the phone.
2. Run `xianyu-link --share`.
3. Tap **Copy** in the Android share sheet that appears.
4. Paste anywhere on the phone.

**Or skip the phone entirely**

```bash
xianyu-link --open          # page opens in your desktop browser
```

---

## Commands

| Command | What it does |
|---|---|
| *(none)* | Prints the product URL. Opens nothing. |
| `--open` | Opens the product page in the default browser |
| `--print` | Same as the default: URL on stdout, nothing else |
| `--share` | Opens the Android share sheet with the URL |
| `--id <id>` | Uses a specific item id instead of reading logs |
| `--watch` | Prints a link for each new product; add `--share` to pop the sheet |
| `--clipboard` | Attempts a clipboard write; falls back to the share sheet (a direct write needs root) |
| `--doctor` | Checks adb, device, app state, and whether an id is available |
| `--device <serial>` | Targets a specific device when several are connected |
| `--no-color` | Plain output |

Exit codes: `0` ok · `1` setup/usage error · `2` no item id found.

---

## How it works

```
Xianyu opens a product  →  app logs itemId=863824608549
                                    ↓
                        adb logcat (no root needed)
                                    ↓
                  https://www.goofish.com/item?id=863824608549
                                    ↓
                      Android share sheet → you tap Copy
```

The `log` group (gid `1007`) includes the `shell` user, which is why plain `adb shell logcat` can read the app's own log output without any privilege escalation. The tool reads the **newest** match, so opening a different product updates the answer immediately.

### What this does NOT do

It does not repair Xianyu's share panel. The panel's own 复制链接 button still requires login, because the short link it copies is fetched from an authenticated endpoint. This tool gets you the same destination URL by a different route.

It also does not modify, patch, re-sign, or hook anything. The installed app is untouched, so its request signing and everything else keeps working normally.

---

## Clipboard: the honest answer

A root-free tool **cannot** write the Android clipboard directly. `cmd clipboard` has no implementation, and the clipboard binder service (`IClipboard`) is only reachable from an app process. So:

- **Root-free (this tool):** the URL goes to the share sheet, you tap **Copy**. One tap.
- **With root:** a Frida call can write the clipboard with zero taps, but that requires `frida-server` running as root, which most users don't have.

This tool deliberately does the root-free thing and tells you so, instead of silently requiring privileges.

---

## Troubleshooting

**"No product found in Xianyu's logs"**
Open a product page in the app first — that's what makes it log the id. If you just rebooted, the log buffer may be empty until you browse.

**"No device/emulator ready"**
USB debugging is off, or the RSA prompt wasn't accepted. Check with `adb devices`.
Some phones need *USB debugging (Security settings)* enabled too.

**The share sheet opens but there's no Copy option**
Long-press the text in the sheet, or use `--open` and copy from the browser.

**Wrong product's link**
The tool returns the *newest* id in the log. Open the product you want, then run it again — or use `--watch` so it always matches what's on screen.

When the app's own process buffer yields no id, the tool falls back to scanning
the **entire** logcat buffer, not just Xianyu's lines. On a busy device that could
in principle match an unrelated app's 8–20 digit number next to an `itemId`
token. If a link looks wrong, check it against the product on screen and re-run;
`--id` lets you supply the real one directly.

**Item id looks wrong**
Ids are 8–20 digits. If the log contains something that merely *looks* like an id (a timestamp, a session token), use `--id` with the real one.

Run `xianyu-link --doctor` for a full diagnosis.

---

## Compatibility

Tested against Xianyu `7.27.96.6` (versionCode 526) on Android 17, POCO `onyx`.

The technique depends on Xianyu logging item ids in its detail-page payloads. That has held across many versions, but a future release could change or drop it. If `--doctor` stops finding ids, the log pattern needs updating — it's a single regex near the top of `newest_id()`.

The general approach (read the id from logs, build the public URL) is version-independent as long as the logging exists.

---

## Licence

MIT — see [LICENSE](LICENSE).

Not affiliated with Alibaba or Xianyu. For personal use on your own device and your own account. Respect the app's terms of service.
