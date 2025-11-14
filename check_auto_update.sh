#!/bin/bash

# Script to check crontab for housekeeper_bee_auto_update.sh
# Returns JSON format for RESTful API response with multiple scheduled times

# Set content type header for JSON response
#echo "Content-Type: application/json"
#echo ""

# Define the script filename to search for in crontab
SCRIPT_NAME="update_version.sh"

# Get current user's crontab and search for the script (exclude commented lines)
CRON_ENTRIES=$(crontab -l 2>/dev/null | grep "$SCRIPT_NAME" | grep -v "^#")

# Check if any cron entries exist
if [ -n "$CRON_ENTRIES" ]; then
    # Array to store all scheduled times
    TIMES=()
    
    # Read each cron entry line by line
    while IFS= read -r CRON_ENTRY; do
        # Extract hour and minute from cron entry
        # Cron format: minute hour day month weekday command
        MINUTE=$(echo "$CRON_ENTRY" | awk '{print $1}')
        HOUR=$(echo "$CRON_ENTRY" | awk '{print $2}')
        
        # Check if we got valid time values (not wildcards or special characters)
        if [[ "$HOUR" =~ ^[0-9]+$ ]] && [[ "$MINUTE" =~ ^[0-9]+$ ]]; then
            # Format to HH:MM
            TIME=$(printf "%02d:%02d" "$HOUR" "$MINUTE")
            TIMES+=("\"$TIME\"")
        fi
    done <<< "$CRON_ENTRIES"
    
    # Check if we found any valid times
    if [ ${#TIMES[@]} -gt 0 ]; then
        # Join times with comma
        TIMES_JSON=$(IFS=,; echo "${TIMES[*]}")
        echo "{\"auto_update\": [$TIMES_JSON]}"
    else
        # Cron exists but with special scheduling (*/5, @daily, etc.)
        echo '{"auto_update": "scheduled"}'
    fi
else
    # No cron entry found
    echo '{"auto_update": null}'
fi

exit 0
