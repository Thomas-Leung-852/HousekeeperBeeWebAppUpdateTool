#!/bin/bash
TARGET_DIR=$(find ~ -type d -wholename "*/HousekeeperBeeWebAppUpdateTool/backup" | head -n 1)
find "$TARGET_DIR" -type d -mtime +30 -exec rm -rf {} +
echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup folders older than 30 days have been deleted from $TARGET_DIR."

