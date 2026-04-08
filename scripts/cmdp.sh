# cmdp - Convert a WSL path to its Windows equivalent and copy to clipboard
#
# Usage: cmdp [-q|--quiet] <path>
#
# Add this line to your shell config (before any prompt init like starship):
#   source "$HOME/.local/share/cmdp/cmdp.sh"

CMDP_VERSION="1.1.0"

cmdp() {
    local quiet=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quiet) quiet=true; shift ;;
            -h|--help)
                cat >&2 <<EOF
cmdp $CMDP_VERSION -- Convert WSL paths to Windows paths

Usage:
  cmdp <path>
  cmdp [options]

Options:
  -q, --quiet      Suppress all output (clipboard only)
  -h, --help       Show this help
  -V, --version    Show version

Examples:
  cmdp /mnt/c/Users/janot    C:\\Users\\janot
  cmdp /home/user             \\\\wsl.localhost\\Ubuntu\\home\\user
  cmdp . | clip.exe           Pipe to other commands

The converted path is copied to the clipboard and printed to stdout.
EOF
                return 0
                ;;
            -V|--version)
                printf 'cmdp %s\n' "$CMDP_VERSION"
                return 0
                ;;
            *) break ;;
        esac
    done

    if [[ -z "$1" ]]; then
        echo "Usage: cmdp [-q|--quiet] <path>" >&2
        echo "Try 'cmdp --help' for more information." >&2
        return 1
    fi

    local win_path
    win_path=$(wslpath -w "$1" 2>/dev/null)

    if [[ -z "$win_path" ]]; then
        if [[ "$quiet" == false ]]; then
            echo "cmdp: cannot convert: $1" >&2
        fi
        return 1
    fi

    # Validate converted path
    # Must start with a drive letter (X:\) or UNC prefix (\\)
    if [[ ! "$win_path" =~ ^[A-Za-z]:\\ ]] && [[ ! "$win_path" == \\\\* ]]; then
        if [[ "$quiet" == false ]]; then
            echo "cmdp: invalid conversion result (unexpected format): $win_path" >&2
        fi
        return 1
    fi

    # No control characters (null bytes, etc.)
    if [[ "$win_path" =~ [[:cntrl:]] ]]; then
        if [[ "$quiet" == false ]]; then
            echo "cmdp: invalid conversion result (control characters detected)" >&2
        fi
        return 1
    fi

    # Copy to clipboard
    if command -v clip.exe > /dev/null 2>&1; then
        printf '%s' "$win_path" | clip.exe 2>/dev/null
    else
        if [[ "$quiet" == false ]]; then
            echo "cmdp: clip.exe not found — path not copied to clipboard." >&2
            echo "      Ensure /etc/wsl.conf does not set appendWindowsPath=false." >&2
        fi
    fi

    # Quiet mode: clipboard only, no output at all
    if [[ "$quiet" == true ]]; then
        return 0
    fi

    # Status message
    local found
    if [[ -e "$1" ]]; then
        found="path found"
    else
        found="path not found"
    fi
    echo "Windows path copied to clipboard ($found)" >&2

    printf '%s\n' "$win_path"
}
