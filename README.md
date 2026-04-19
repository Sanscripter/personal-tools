# Personal Tools

A small collection of Windows batch utilities for everyday local development tasks.

## Repo layout

- `bin\` contains the user-facing command launchers that are easy to add to your `PATH`.
- `commands\` contains repo-local wrapper scripts if you want to run the tools directly from the clone.
- `scripts\` contains the internal PowerShell helpers for media, web, and speech features.
- `compat\` contains lightweight backward-compatibility PowerShell entrypoints.
- `setup\core\` contains shared setup utilities and the admin-shell flow.
- `setup\installers\` contains the individual tool installers.
- `addPath` now adds this tool repo's script directory to your user `PATH` instead of the folder you happen to be in.

## Included scripts

- `github` — interactive helper for creating or configuring a GitHub repository using the GitHub CLI.
- `github2` — a simpler alternative for GitHub repository initialization and configuration.
- `addPath` — adds this toolset to your user `PATH`.
- `reload` — reloads the Cmder shell environment.
- `say` — speaks text aloud using the built-in Windows speech synthesizer, including installed voices for other languages.
- `media` — sends global play, pause, next, and previous commands to the current Windows media session, so browser and app playback can be controlled the same way.
- `screen` — records the current screen to an MP4 file with audio or silent options when FFmpeg is available.
- `screenshot` — opens the built-in Windows screenshot tool and screenshot folder shortcuts.
- `spotify` — opens Spotify, searches music, controls playback, and now includes a built-in setup flow for new machines.
- `steam` — opens Steam, lists your installed games in the terminal, searches your library, and launches a game by name or app id.
- `youtube` — opens YouTube in Chrome, searches videos, jumps to watch or playlist links, and reuses the same global media controls.
- `keyboard` — switches Windows input language quickly, with Portuguese and English International as the first two quick options.
- `diag` — shows quick local diagnostics for disk space, local IPv4 and MAC details, RAM usage, and a Task Manager shortcut.
- `chrome` — launches Google Chrome and installs it automatically if it is not already available.
- `morgan` — a tiny plain-English toolbox helper that routes simple requests to your existing commands.
- `admin` — opens a new Administrator shell in the current folder after a loud visual warning and an optional audio prompt.
- `otp` — triggers the same short-lived approval challenge manually before a risky action.
- `google` — safely URL-encodes multilingual search text and opens the first Google result in Chrome.
- `whatsapp` — opens local WhatsApp, searches chats, and can draft or send messages through simple commands.
- `supabase` — runs the Supabase CLI locally and can bootstrap it on a new machine.
- `tools-setup` — a master setup catalog for bootstrapping common developer tools, now including Python, Cmder, and Supabase.
- `install-vscode` — installs Visual Studio Code and makes the `code` launcher available.
- `install-cmder` — installs Cmder and prepares the `reload` helper environment.
- `install-python` — installs Python and makes `python` and `pip` available.
- `install-nvm-node` — installs NVM for Windows, the latest Node.js, and the latest npm.
- `install-angular-cli` — installs Angular CLI globally and confirms the installed version.
- `install-podman` — installs Podman as an open-source Docker-compatible alternative.
- `install-godot` — installs Godot Engine.

## Requirements

Some scripts depend on tools already being installed:

- Windows Command Prompt / batch support
- [GitHub CLI](https://cli.github.com/) for `github` and `github2`
- Cmder for `reload`
- PowerShell with `System.Speech` available for `say`
- FFmpeg for `screen` recording, with `screen setup` available as a quick installer shortcut

## Setup

Run this once from the repo:

```bat
bin\addPath.bat
```

After that, the commands are available from any folder in new terminals. If you want to run them directly from the cloned repo without editing `PATH`, use the wrappers in `commands\`.

## Morgan helper

Morgan is a lightweight command router for this toolbox. It is intentionally small and composes with your existing scripts instead of replacing them.
It also supports a private local context file for your frequent sites, browser tabs, and known computers so you can jump around more naturally.

Typical use:

```bat
morgan help
morgan play daft punk
morgan search best mechanical keyboard switches
morgan setup status
morgan say Toolbox ready
morgan context
morgan sites
morgan open work
morgan tabs
morgan computers
```

Personal context lives in `setup\security\morgan-context.local.json`. The example template is in `setup\security\morgan-context.local.example.json`, and the local file is ignored by git so you can safely store your own machine names and shortcuts there.

## Spotify setup

Spotify now includes a first-run setup path so playback commands can bootstrap a machine when the app is missing.

Typical use:

```bat
spotify setup
spotify status
spotify play
spotify random
spotify next
media pause
media next
```

## Keyboard language helper

The new keyboard helper is built for Windows input-language switching and favors Portuguese and English International first.

Typical use:

```bat
keyboard
keyboard 1
keyboard 2
keyboard portuguese
keyboard english international
keyboard search canadian french
tools-setup keyboard
```

## Admin helper

Windows cannot upgrade the already-running terminal in place. Use `admin` when a task needs elevation.

What it does:
- shows a very visible warning before requesting Administrator access
- asks before playing any audible warning
- opens a new elevated shell in your current folder
- cancels cleanly without making changes if you decline the prompt

Typical use:

```bat
admin
tools-setup all
chrome install
```

Admin review for this repo:
- likely needed for `install-nvm-node`, `install-podman`, `install-godot`, and some `chrome install` paths
- usually not needed for `addPath`, `google`, `spotify`, `say`, `github`, `reload`, or `install-angular-cli`

Manual OTP check:

```bat
otp
otp install podman
```

Security model for approval:
- machines do **not** share a TOTP seed with each other
- each privileged request creates a short-lived approval record in Supabase
- approval happens from your trusted approver account plus MFA, typically on your phone
- for strict work/personal separation, use separate approver accounts or separate Supabase projects
- a dedicated `otp` helper can trigger the same approval challenge before you run something risky

## Diagnostics helper

Use the diagnostics helper for quick local machine checks without hunting through Windows menus.

Typical use:

```bat
diag
diag disk
diag net
diag ram
diag taskmgr
morgan disk
morgan ram
```

The RAM view also lists the top 5 processes using the most memory right now.

## WhatsApp helper

Use the WhatsApp launcher to open the desktop app, jump straight into chat search, or type a draft without touching the mouse.

Typical use:

```bat
whatsapp open
whatsapp search family
whatsapp chat Alice
whatsapp chat Alice -- Here is the link
whatsapp draft -- Quick note for the current chat
whatsapp send -- I am on my way
whatsapp draft Project Team -- Meeting moved to 3pm
whatsapp send Alice -- I am on my way
whatsapp phone +5511999999999 -- Hello from Windows
```
## Steam helper

Use the Steam launcher to open the client, browse your installed library in the terminal, search by name, and start a game quickly.

Typical use:

```bat
steam open
steam status
steam list
steam browse
steam search portal
steam play Hades
steam play 14
steam play "Mount & Blade: Warband"
steam run 620
morgan games
morgan steam open
```
## YouTube helper

Use YouTube through Chrome and keep the same keyboard-friendly workflow for browser playback.

Typical use:

```bat
youtube open
youtube search lo fi coding music
youtube watch https://www.youtube.com/watch?v=dQw4w9WgXcQ
youtube pause
youtube next
```

## Screen recorder

Use the screen helper for quick desktop captures with either audio or silent video-only mode.

Typical use:

```bat
screen audio
screen silent
screen silent demo.mp4 -seconds 10
screen audio meeting.mp4
screen openfolder
screen setup
```

Notes:
- recordings are saved to your Windows Videos\ScreenRecordings folder by default
- press `q` or `Ctrl+C` to stop a live recording
- audio mode tries the default Windows audio device and falls back to silent recording if that input is not available

## Screenshot helper

Use the screenshot helper to open the built-in Windows snipping UI quickly from the terminal.

Typical use:

```bat
screenshot
screenshot snip
screenshot openfolder
```

## Examples

```bat
github help
github init
install-vscode
tools-setup spotify
tools-setup vscode
github config
say Hello from Windows
say -list
say -languages
say -probe japanese
say -lang pt-BR Olá do Windows
say -lang "French" Bonjour tout le monde
say -voice "Microsoft Zira Desktop" Hello again
spotify search daft punk
steam list
steam search half-life
steam play Portal 2
media toggle
youtube search synthwave live
youtube pause
screen audio
screen silent quick-demo.mp4 -seconds 5
screenshot
screenshot openfolder
keyboard 1
keyboard english international
google café near shibuya
google results 東京 ラーメン
chrome google best mechanical keyboard switches
chrome open https://www.google.com
diag
diag disk
diag net
diag ram
diag taskmgr
whatsapp search family
whatsapp send Alice -- On my way
tools-setup
tools-setup vscode
tools-setup status
tools-setup all
morgan help
morgan play daft punk
morgan message Alice -- Running late
morgan search comfy desk setup ideas
```

## Purpose

This repository is meant to keep lightweight personal command-line helpers in one place so they can be reused across projects and machines.

