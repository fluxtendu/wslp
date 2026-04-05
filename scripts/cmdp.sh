# cmdp - Convert a WSL path to its Windows equivalent and copy to clipboard
#
# Usage: cmdp <path>
#
# Source this file in your shell profile:
#   echo '[ -f "$HOME/.local/share/wslp/cmdp.sh" ] && source "$HOME/.local/share/wslp/cmdp.sh"' >> ~/.zshrc
#   echo '[ -f "$HOME/.local/share/wslp/cmdp.sh" ] && source "$HOME/.local/share/wslp/cmdp.sh"' >> ~/.bashrc

cmdp() {
    if [[ -z "$1" ]]; then
        echo "Usage: cmdp <path>" >&2
        echo "Converts a WSL path to its Windows equivalent and copies it to the clipboard." >&2
        return 1
    fi

    local win_path
    win_path=$(wslpath -w "$1" 2>/dev/null)

    if [[ -z "$win_path" ]]; then
        echo "cmdp: cannot convert: $1" >&2
        return 1
    fi

    printf '%s' "$win_path" | clip.exe
    printf '%s\n' "$win_path"
}
