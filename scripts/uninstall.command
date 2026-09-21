#!/bin/zsh
pkill -x Blackout >/dev/null 2>&1 || true
rm -rf "$HOME/Applications/Blackout.app"
echo "Blackout removed."
