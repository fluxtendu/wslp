# wslp

Convert Windows paths to WSL paths — and back — from the terminal or right-click menu.

```
C:\Users\janot\projects\foo  →  /mnt/c/Users/janot/projects/foo
\\wsl.localhost\Ubuntu\home\fluxtendu  →  /home/fluxtendu
```

The converted path is automatically copied to your clipboard.

**Why not just `wslpath`?** `wslpath` only works inside WSL. `wslp` brings path conversion to Windows — as a terminal command, a right-click menu entry, and a clipboard shortcut — so you can grab a WSL path from Explorer or CMD without ever opening a WSL shell. `cmdp` covers the reverse direction from inside WSL, matching what `wslpath -w` does but with automatic clipboard copy.

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
scoop bucket add wslp https://github.com/erratos/wslp
scoop install wslp
```

Scoop installs the `wslp` command and adds it to your PATH automatically.
After install, an interactive script runs to set up optional features (context menu, cmdp).

### Manual

1. Download or clone this repository.
2. Copy `src\wslp.cmd`, `src\_wslp.ps1`, and `src\ubp.exe` to a folder of your choice
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

The entry appears in the classic context menu (Shift+right-click on Win11, always visible on Win10). No admin rights required.

To remove: `scripts\uninstall-registry.ps1`

### cmdp (WSL)

`cmdp` is the inverse of `wslp`: run it inside WSL to convert a WSL path to a Windows path and copy it to your clipboard.

The installer copies `cmdp.sh` to `~/.local/share/cmdp/` and tells you the line to add. To do it manually:

```bash
mkdir -p ~/.local/share/cmdp
cp /path/to/wslp/scripts/cmdp.sh ~/.local/share/cmdp/
```

Then add this line to your shell config (`~/.zshrc` or `~/.bashrc`), **before** any prompt initializer (starship, oh-my-zsh…):

```bash
source "$HOME/.local/share/cmdp/cmdp.sh"
```

Then restart your shell.

---

## Usage

### wslp (Windows)

```powershell
wslp "C:\Users\janot\projects"
# → /mnt/c/Users/janot/projects  (copied to clipboard)

wslp "\\wsl.localhost\Ubuntu\home\janot"
# → /home/janot  (copied to clipboard)

wslp -q "C:\Users\janot"    # quiet: clipboard only, no output
wslp --help                  # show help
wslp --version               # show version
```

Works from PowerShell, CMD, and Windows Terminal.

### cmdp (WSL)

```bash
cmdp /home/janot/projects
# → \\wsl.localhost\Ubuntu\home\janot\projects  (copied to clipboard)

cmdp /mnt/c/Users/janot/projects
# → C:\Users\janot\projects  (copied to clipboard)

cmdp -q /home/janot          # quiet: clipboard only, no output
cmdp --help                  # show help
cmdp --version               # show version
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
