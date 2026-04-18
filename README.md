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
- `spotify` — opens Spotify, searches music, controls playback, and now includes a built-in setup flow for new machines.
- `keyboard` — switches Windows input language quickly, with Portuguese and English International as the first two quick options.
- `chrome` — launches Google Chrome and installs it automatically if it is not already available.
- `morgan` — a tiny plain-English toolbox helper that routes simple requests to your existing commands.
- `admin` — opens a new Administrator shell in the current folder after a loud visual warning and an optional audio prompt.
- `google` — safely URL-encodes multilingual search text and opens the first Google result in Chrome.
- `whatsapp` — opens local WhatsApp, searches chats, and can draft or send messages through simple commands.
- `tools-setup` — a master setup catalog for bootstrapping common developer tools.
- `install-vscode` — installs Visual Studio Code and makes the `code` launcher available.
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

## Setup

Run this once from the repo:

```bat
bin\addPath.bat
```

After that, the commands are available from any folder in new terminals. If you want to run them directly from the cloned repo without editing `PATH`, use the wrappers in `commands\`.

## Morgan helper

Morgan is a lightweight command router for this toolbox. It is intentionally small and composes with your existing scripts instead of replacing them.

Typical use:

```bat
morgan help
morgan play daft punk
morgan search best mechanical keyboard switches
morgan setup status
morgan say Toolbox ready
```

## Spotify setup

Spotify now includes a first-run setup path so playback commands can bootstrap a machine when the app is missing.

Typical use:

```bat
spotify setup
spotify status
spotify play
spotify random
spotify next
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
keyboard 1
keyboard english international
google café near shibuya
google results 東京 ラーメン
chrome google best mechanical keyboard switches
chrome open https://www.google.com
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

