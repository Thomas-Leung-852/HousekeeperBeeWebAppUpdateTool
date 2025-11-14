#!/bin/bash


#============== Prepare parameters array ==============

# Declare an associative array
declare -A g_params

# Loop through all arguments
for arg in "$@"; do
    # Check if the argument contains an equals sign, indicating a key-value pair
    if [[ "$arg" == *"="* ]]; then
        # Split the argument into key and value
        key="${arg%%=*}" # Everything before the first '='
        value="${arg#*=}" # Everything after the first '='
        g_params["$key"]="$value"
    else
        # Handle arguments without an equals sign (e.g., positional arguments or flags)
        # For simplicity, this example assigns a default value or handles them as keys with empty values.
        # You might want to implement more specific logic here based on your needs.
        g_params["$arg"]="" # Assign an empty value for arguments without '='
    fi
done


#============== Do Add Cron job ==============

# Script to check for app updates and schedule update if needed
# This script is called by cron jobs at scheduled times

# Redirect all output to log file
LOG_FILE="./update_app.log"
exec >> "$LOG_FILE" 2>&1
CURRENT_VERSION_FILE="current_app_version.json"
UPDATE_SCRIPT="update_version.sh"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"  # | tee -a "$LOG_FILE"
}

# Function to compare version numbers
# Returns 0 if version1 < version2, 1 otherwise
version_compare() {
    local ver1=$1
    local ver2=$2
    
    if [ "$ver1" = "$ver2" ]; then
        return 1
    fi
    
    local IFS=.
    local i ver1_array=($ver1) ver2_array=($ver2)
    
    # Fill empty positions with zeros
    for ((i=${#ver1_array[@]}; i<${#ver2_array[@]}; i++)); do
        ver1_array[i]=0
    done
    
    for ((i=0; i<${#ver1_array[@]}; i++)); do
        if [[ -z ${ver2_array[i]} ]]; then
            ver2_array[i]=0
        fi
        if ((10#${ver1_array[i]} > 10#${ver2_array[i]})); then
            return 1
        fi
        if ((10#${ver1_array[i]} < 10#${ver2_array[i]})); then
            return 0
        fi
    done
    
    return 1
}

log_message "Starting update check..."

# Step 1: Get publisher release version
log_message "Fetching publisher release version..."
PUBLISHER_VERSION=$(./get_version.sh 2>&1)

if [ $? -ne 0 ] || [ -z "$PUBLISHER_VERSION" ]; then
    log_message "ERROR: Failed to get publisher version"
    exit 1
fi

log_message "Publisher version: $PUBLISHER_VERSION"

# Step 2: Get installed app version
log_message "Checking installed app version..."

if [ -f "$CURRENT_VERSION_FILE" ]; then
    INSTALLED_VERSION=$(jq -r ".version" "$CURRENT_VERSION_FILE" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$INSTALLED_VERSION" ] || [ "$INSTALLED_VERSION" = "null" ]; then
        log_message "WARNING: Failed to read version from $CURRENT_VERSION_FILE, defaulting to 0.0.0"
        INSTALLED_VERSION="0.0.0"
    fi
else
    log_message "WARNING: $CURRENT_VERSION_FILE not found, defaulting to 0.0.0"
    INSTALLED_VERSION="0.0.0"
fi

log_message "Installed version: $INSTALLED_VERSION"

# Step 3: Compare versions
log_message "Comparing versions..."

if version_compare "$INSTALLED_VERSION" "$PUBLISHER_VERSION"; then
    log_message "Update available: $INSTALLED_VERSION -> $PUBLISHER_VERSION"
    
    # Step 4: Check if update_version.sh is already scheduled in crontab
    CRON_EXISTS=$(crontab -l 2>/dev/null | grep "$UPDATE_SCRIPT" | grep -v "^#")
    
    if [ -n "$CRON_EXISTS" ]; then
        log_message "Update already scheduled in crontab. Nothing to do."
    else
        log_message "Scheduling update_version.sh to run within the next 24 hours..."
        
        # Generate random time within next 24 hours
        RANDOM_HOUR=$((RANDOM % 24))
        RANDOM_MINUTE=$((RANDOM % 60))
        
        # Calculate the target date (today or tomorrow)
        CURRENT_HOUR=$(date +%H)
        CURRENT_MINUTE=$(date +%M)
        
        file=$(find ~ -wholename '*/HousekeeperBeeWebAppUpdateTool/update_version.sh' | head -n 1)

        if [ "$file" == "" ]; then
            log_message "HousekeeperBeeWebAppUpdateTool not yet install or file update_version.sh is missing."
            exit 1
        fi

        filepath=$(dirname $file)
        tilde_path=$(echo "$filepath" | sed "s|^$HOME|~|")

        pwd="${g_params["pwd"]}"  

        # Simple scheduling: use random hour and minute
        # For one-time execution, we'll add the job and it should be removed after execution
        CRON_JOB="$RANDOM_MINUTE $RANDOM_HOUR * * * cd $tilde_path && /bin/echo '${pwd}' | sudo -S -E -k -u $USER ./$UPDATE_SCRIPT slient=yes from=terminal pwd=${pwd} ; crontab -l | grep -v 'update_version.sh' | crontab - "
        
        log_message "Scheduled time: $(printf '%02d:%02d' $RANDOM_HOUR $RANDOM_MINUTE)"
        
        # Add the cron job
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        
        if [ $? -eq 0 ]; then
            log_message "Successfully scheduled update at $(printf '%02d:%02d' $RANDOM_HOUR $RANDOM_MINUTE)"
        else
            log_message "ERROR: Failed to add cron job"
            exit 1
        fi
    fi
else
    log_message "No update needed. Installed version is up to date."
fi

log_message "Update check completed."
exit 0


