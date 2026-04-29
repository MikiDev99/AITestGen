#!/bin/bash

# Trova la cartella del progetto Xcode attualmente aperto
PROJECT_PATH=$(osascript <<'EOF'
tell application "Xcode"
    set workspacePath to path of active workspace document
    return workspacePath
end tell
EOF
)

# Rimuove il nome del file .xcodeproj o .xcworkspace per ottenere la cartella
PROJECT_DIR=$(dirname "$PROJECT_PATH")

# Apre un terminale e lancia aitestgen nella cartella del progetto
osascript <<EOF
tell application "Terminal"
    activate
    do script "cd '$PROJECT_DIR' && aitestgen"
end tell
EOF
