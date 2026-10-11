pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

        function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "bash", "-c",
            "if command -v dnf &>/dev/null; then echo '=== Updating Fedora & Flatpak Packages ==='; sudo dnf upgrade --refresh && flatpak update -y; elif command -v yay &>/dev/null; then yay -Syu; elif command -v paru &>/dev/null; then paru -Syu; elif command -v pacman &>/dev/null; then sudo pacman -Syu; fi"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

        function runUpdateDots() {
        const updateScript = `
            echo '====================================='
            echo '       Updating End4-pC Dots         '
            echo '====================================='

            CONFIG_PATH="$HOME/.config/quickshell/end4-pC"
            if [ -L "$CONFIG_PATH" ]; then
                REPO_DIR="$(readlink -f "$CONFIG_PATH")"
            elif [ -d "$CONFIG_PATH" ]; then
                REPO_DIR="$CONFIG_PATH"
            else
                echo "Error: $CONFIG_PATH does not exist!"
                exit 1
            fi

            echo "Repository: $REPO_DIR"
            cd "$REPO_DIR"

            if [ -d ".git" ]; then
                BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'main')"
                REMOTE="origin"
                if git remote | grep -q "^fedora$"; then
                    REMOTE="fedora"
                fi
                echo "Pulling latest changes from $REMOTE ($BRANCH)..."
                git pull "$REMOTE" "$BRANCH"
                echo ""
                echo "=== Update Successful! ==="
                echo "Press Super + Shift + R to reload Quickshell."
            else
                echo "Error: $REPO_DIR is not a git repository."
            fi
        `

        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", updateScript])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }
}
