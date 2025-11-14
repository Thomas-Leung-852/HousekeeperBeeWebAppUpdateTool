#!/bin/bash

# Script to manage auto-update crontab entries
# Usage: ./manage_auto_update.sh <action>
# Actions: enable-auto-update, disable-auto-update, cancel-scheduled-update, is-enabled

file=$(find ~ -wholename '*/HousekeeperBeeWebAppUpdateTool/update_version.sh' | head -n 1)

if [ "$file" == "" ]; then
   echo "HousekeeperBeeWebAppUpdateTool not yet install or file update_version.sh is missing."
   exit 1
fi

filepath=$(dirname $file)
tilde_path=$(echo "$filepath" | sed "s|^$HOME|~|")


# Set content type header for JSON response
# echo "Content-Type: application/json"
# echo ""

# Check if action parameter is provided
if [ $# -eq 0 ]; then
    echo '{"status": "error", "message": "No action parameter provided. Use: enable-auto-update or disable-auto-update"}'
    exit 1
fi

ACTION=$1
SCRIPT_NAME="cd $tilde_path && echo $HOUSEKEEPER_BEE_PWD_SUDO | sudo -S -E -k -u $USER ./add_update_app_job.sh pwd=$HOUSEKEEPER_BEE_PWD_SUDO "
CANCEL_SCRIPT_NAME="./update_version.sh slient=yes from=terminal"

# Function to remove existing update_app.sh entries from crontab
remove_update_entries() {
    # Get current crontab, remove lines containing update_app.sh
    crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" | crontab - 2>/dev/null
}

# Function to cancel existing scheduled update entries from crontab
cancel_update_entries() {
    # Get current crontab, remove lines containing update_app.sh
    crontab -l 2>/dev/null | grep -v "$CANCEL_SCRIPT_NAME" | crontab - 2>/dev/null
}

isEnabled(){
	crontab -l 2>/dev/null | grep "add_update_app_job.sh" >/dev/null
}

# Function to enable auto-update
enable_auto_update() {
    # First, remove any existing entries
    remove_update_entries
    
    # Get current crontab (may be empty after removal)
    CURRENT_CRON=$(crontab -l 2>/dev/null)
    
    # Create new crontab with update_app.sh entries at the top
    {
        echo "0 12 * * * $SCRIPT_NAME"
        echo "0 23 * * * $SCRIPT_NAME"
        echo "$CURRENT_CRON"
    } | crontab -
    
    if [ $? -eq 0 ]; then
        echo '{"status": "success", "enabled": true, "message": "Auto-update enabled", "schedule": ["12:00", "23:00"]}'
    else
        echo '{"status": "error", "enabled": null, "message": "Failed to enable auto-update"}'
        exit 1
    fi
}

# Function to disable auto-update
disable_auto_update() {
    # Remove scheduled update
    cancel_update_entries

    # Remove all update_app.sh entries
    remove_update_entries
    
    if [ $? -eq 0 ]; then
        echo '{"status": "success", "enabled": false, "message": "Auto-update disabled"}'
    else
        echo '{"status": "error", "enabled": null, "message": "Failed to disable auto-update"}'
        exit 1
    fi
}

# Function to cancel scheduled auto-update
cancel_scheduled_update(){
    
    cancel_update_entries
    
    if [ $? -eq 0 ]; then
        echo '{"status": "success", "message": "Cancelled scheduled update"}'
    else
        echo '{"status": "error", "message": "Failed to cancel scheduled update"}'
        exit 1
    fi
}

isAutoUpdateEnabled(){
    isEnabled

    if [ $? -eq 0 ]; then
        echo '{"status": "success", "enabled": true, "message": "" }'
    else
        echo '{"status": "success", "enabled": false, "message": ""}'
        exit 1
    fi
}

# Main logic
case "$ACTION" in
    enable-auto-update)
        enable_auto_update
        ;;
    disable-auto-update)
        disable_auto_update
        ;;
    cancel-scheduled-update)
        cancel_scheduled_update
        ;;
    is-enabled)
        isAutoUpdateEnabled
        ;;
    *)
        echo "{\"status\": \"error\", \"message\": \"Invalid action: $ACTION. Use: enable-auto-update or disable-auto-update\"}"
        exit 1
        ;;
esac

exit 0
