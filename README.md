# wslp

Convert Windows paths to WSL paths — and back — from the terminal or right-click menu.

```
C:\Users\janot\projects\foo  →  /mnt/c/Users/janot/projects/foo
\\wsl.localhost\Ubuntu\home\janot  →  /home/janot
```

The converted path is automatically copied to your clipboard.

---

## Features

| Tool | Where | What it does |
|------|-------|--------------|
| `wslp` | Windows terminal | Converts a Windows path → WSL path, copies to clipboard |
| `cmdp` | WSL (bash/zsh) | Converts a WSL path → Windows path, copies to clipboard |
| Right-click menu | Windows Explorer | "Copy WSL path" on any file or folder |

Everything is optional. Install what you need.

---

## Installation

### Via Scoop (recommended)

```powershell
scoop bucket add wslp https://github.com/fluxtendu/wslp
scoop install wslp
```

Scoop installs the `wslp` command and adds it to your PATH automatically.
After install, an interactive script runs to set up optional features (context menu, cmdp).

### Manual

1. Download or clone this repository.
2. Copy `src\wslp.ps1`, `src\wslp.cmd`, and `src\wslp.vbs` to a folder of your choice
   (e.g. `%LOCALAPPDATA%\Programs\wslp\`).
3. Add that folder to your PATH (user-level, no admin required):
   ```powershell
   [Environment]::SetEnvironmentVariable(
       "PATH",
       $env:PATH + ";$env:LOCALAPPDATA\Programs\wslp",
       "User"
   )
   ```
4. Optionally run the extras installer:
   ```powershell
   .\scripts\install-registry.ps1 -InstallDir "C:\path\to\wslp"
   ```

---

## Optional features

### Context menu — "Copy WSL path"

Run `scripts\install-registry.ps1` and follow the prompts.

Two styles are available:

| Style | Visibility | Admin required? |
|-------|-----------|-----------------|
| **Classic** | Shift+right-click (Win11), always visible (Win10) | No |
| **Modern** | Always visible in Win11 right-click menu | Yes |

The script will ask which you prefer and re-launch as administrator if needed.

To remove: `scripts\uninstall-registry.ps1`

### cmdp (WSL)

`cmdp` is the inverse of `wslp`: run it inside WSL to convert a WSL path to a Windows path and copy it to your clipboard.

The installer can set it up automatically. To do it manually:

```bash
# Copy the script
mkdir -p ~/.local/share/wslp
cp /path/to/wslp/scripts/cmdp.sh ~/.local/share/wslp/

# Source it in your shell profile
echo '[ -f "$HOME/.local/share/wslp/cmdp.sh" ] && source "$HOME/.local/share/wslp/cmdp.sh"' >> ~/.zshrc
# or for bash:
echo '[ -f "$HOME/.local/share/wslp/cmdp.sh" ] && source "$HOME/.local/share/wslp/cmdp.sh"' >> ~/.bashrc
```

Then restart your shell or run `source ~/.local/share/wslp/cmdp.sh`.

---

## Usage

### wslp (Windows)

```powershell
wslp "C:\Users\janot\projects"
# → /mnt/c/Users/janot/projects  (copied to clipboard)

wslp "\\wsl.localhost\Ubuntu\home\janot"
# → /home/janot  (copied to clipboard)
```

Works from PowerShell, CMD, and Windows Terminal.

### cmdp (WSL)

```bash
cmdp /home/janot/projects
# → \\wsl.localhost\Ubuntu\home\janot\projects  (copied to clipboard)

cmdp /mnt/c/Users/janot/projects
# → C:\Users\janot\projects  (copied to clipboard)
```

### Right-click menu

Right-click (or Shift+right-click on Win11 with the classic style) any file or folder in Explorer → **Copy WSL path**.

---

## Uninstall

### Via Scoop

```powershell
scoop uninstall wslp
```

This removes the command, PATH entry, registry keys, and WSL cmdp automatically.

### Manual

1. Delete the install folder.
2. Remove the PATH entry.
3. Run `scripts\uninstall-registry.ps1` to clean up registry and WSL.

---

## Compatibility

- Windows 10 / Windows 11
- WSL 1 and WSL 2
- PowerShell 5.1+
- bash or zsh for `cmdp` (fish is not supported)

---

## Roadmap

- [ ] winget package (MSIX)

---

## License

MIT
