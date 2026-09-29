#!/usr/bin/env bash
set -euo pipefail
LABEL="com.jcsl.smith-cadence"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true   # missing = success
rm -f "$PLIST"
echo "uninstalled: $LABEL (plist removed; log dir left in place)"
