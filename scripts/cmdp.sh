# cmdp - Convert a WSL path to its Windows equivalent and copy to clipboard
#
# Usage: cmdp [-q|--quiet] <path>
#
# Add this line to your shell config (before any prompt init like starship):
#   source "$HOME/.local/share/cmdp/cmdp.sh"

cmdp() {
    local quiet=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quiet) quiet=true; shift ;;
            *) break ;;
        esac
    done

    if [[ -z "$1" ]]; then
        echo "Usage: cmdp [-q|--quiet] <path>" >&2
        echo "Converts a WSL path to its Windows equivalent and copies it to the clipboard." >&2
        return 1
    fi

    local win_path
    win_path=$(wslpath -w "$1" 2>/dev/null)

    if [[ -z "$win_path" ]]; then
        echo "cmdp: cannot convert: $1" >&2
        return 1
    fi

    # Copy to clipboard
    local copied=true
    if command -v clip.exe > /dev/null 2>&1; then
        printf '%s' "$win_path" | clip.exe 2>/dev/null
    else
        copied=false
        if [[ "$quiet" == false ]]; then
            echo "cmdp: clip.exe not found — path not copied to clipboard." >&2
            echo "      Ensure /etc/wsl.conf does not set appendWindowsPath=false." >&2
        fi
    fi

    # Status message (skip in quiet mode)
    if [[ "$quiet" == false ]]; then
        local found
        if [[ -e "$1" ]]; then
            found="path found"
        else
            found="path not found"
        fi

        if [[ "$copied" == true ]]; then
            echo "Windows path copied to clipboard ($found)" >&2
        else
            echo "($found)" >&2
        fi
    fi

    printf '%s\n' "$win_path"
}
