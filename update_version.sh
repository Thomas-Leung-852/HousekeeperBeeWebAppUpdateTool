#!/usr/bin/bash

#============== Constants ==============
LOCAL_TARGET_FILE="app_version.json"
LST_UPD_FILE="current_app_version.json"
GIT_PATH="https://raw.githubusercontent.com/Thomas-Leung-852/HousekeeperBeeWebApp/main"
GDRIVE_FILE_ID="1u_jXIKHBDScf-2XHuoybkJ4XxPLyk9wd"
GDRIVE_URL="https://drive.google.com/uc?export=download&id=$GDRIVE_FILE_ID"

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

#============== Function :: inital global variables ==============

init_global_var(){
  g_app_fn=$(find ~/Desktop/ -name "housekeeper-0.0.1-SNAPSHOT.jar" | grep "housekeeping_bee/files/prog" | grep -Ev "_BACKUP" ) 
  g_app_path="$(dirname "${g_app_fn}")"
  g_app_install_path=$(echo "${g_app_path}" | sed 's@/housekeeping_bee/files/prog@@g' )
}

#============== Function :: Get latest version metadata ==============

get_latest_ver_profile(){
    curl -L "$GDRIVE_URL" -o "$LOCAL_TARGET_FILE"

    if [ ! -e $LOCAL_TARGET_FILE ]; then
      echo "ERROR: ${LOCAL_TARGET_FILE} not found!"
      return 1
    fi

    local json_content=$(cat "$LOCAL_TARGET_FILE")
    local filelist=$(echo "$json_content" | jq -r '.filelist // "unknown"')

    if [ "${filelist}" = "unknown" ]; then
      echo "ERROR: file list not found!"
      return 1
    fi

    return 0
}

#============== Function :: Backup file ==============

do_backup(){
   local backup_datetime=$(date +'%Y%m%d%H%M%S')

   if [ -e $LOCAL_TARGET_FILE ]; then
      jq -c '.filelist[]' $LOCAL_TARGET_FILE | while read -r path_obj; do
         local path=$(echo "$path_obj" | jq -r '.filepath')
         local filename=$(echo "$path_obj" | jq -r '.filename')
         local src_filepath="${g_app_install_path}${path}"
         local backup_filepath="backup/${backup_datetime}_BACKUP${src_filepath}"

         mkdir -p "${backup_filepath}"
         cp "${src_filepath}${filename}" "${backup_filepath}${filename}"
       done
   else
       echo "ERROR: Cannot found ${LOCAL_TARGET_FILE} file"
       return 1
   fi

   return 0
}

#============== Function :: Download file from github repository and update local files ==============

update_from_github(){
   if [ -e $LOCAL_TARGET_FILE ]; then
      jq -c '.filelist[]' $LOCAL_TARGET_FILE | while read -r path_obj; do
         local path=$(echo "$path_obj" | jq -r '.filepath')
         local filename=$(echo "$path_obj" | jq -r '.filename')

         local full_git_path="${GIT_PATH}${path}"
         local dest_filepath="${g_app_install_path}${path}"

         echo "> Updating file: ${dest_filepath}${filename}"
         echo
         curl -0 "${full_git_path}${filename}" > "${dest_filepath}~${filename}"
         rm "${dest_filepath}${filename}"
         mv "${dest_filepath}~${filename}" "${dest_filepath}${filename}" 
         if file "${dest_filepath}${filename}" | grep -q "shell script"; then
            chmod +x "${dest_filepath}${filename}"
         fi
       done
   else
       echo "ERROR: Cannot found ${LOCAL_TARGET_FILE} file"
       return 1
   fi 

   return 0
}

#============== Function :: Execute Commands ==============

exec_cmd(){
   if [ -e $LOCAL_TARGET_FILE ]; then
      jq -c '.commandlist[]' $LOCAL_TARGET_FILE | while read -r cmd_obj; do
         local desc=$(echo "$cmd_obj" | jq -r '.description')
         local cmd=$(echo "$cmd_obj" | jq -r '.command')

         echo "> Command Description: ${desc}"
         echo
#            eval "echo $HOUSEKEEPER_BEE_PWD_SUDO | ${cmd} "   # e.g. sudo ufw allow 8080 with sudo


         if [[ "${g_params["from"]}" == "terminal" ]]; then
            eval "echo '${g_params["pwd"]}' | sudo -S ${cmd} "   # e.g. sudo ufw allow 8080 with sudo
         else
	    # default from web
            cmd="${cmd/sudo /}"
            eval "echo $HOUSEKEEPER_BEE_PWD_SUDO | sudo -S ${cmd} "   # e.g. ufw allow 8080 without sudo
         fi

       done
   else
       echo "ERROR: Cannot found ${LOCAL_TARGET_FILE} file"
       return 1
   fi

   return 0
}


#************************************************************************************
#* Main
#************************************************************************************

echo
echo
echo "***********************************************************************************************************************************"
echo "* Introducing the Housekeeper Bee Web App Update Tool: "
echo "* easily check for the latest version of Housekeeper Bee Web App, and download updates for efficient housekeeping management. "
echo "* Keep your app up to date effortlessly!"
echo "* Version: 1.3 "
echo "***********************************************************************************************************************************"
echo 

## Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Install it with: sudo apt-get install jq"
    exit 1
fi

## inital global variables
init_global_var

if [ -z $g_app_fn ]; then
   echo "Error: Housekeeper Bee Web App does not exist! Download from https://github.com/Thomas-Leung-852/HousekeeperBeeWebApp"
   echo
   exit 1
fi

echo "<< download latest app version profile >>" | get_latest_ver_profile 

if [[ $? -ne 0 ]]; then rm "${LOCAL_TARGET_FILE}"; exit 1; fi   # Exit if error

#==========================================================================================
# compare versions
#==========================================================================================
latest_app_ver=$(jq -r '.version // "unknown"' $LOCAL_TARGET_FILE)

cur_app_ver="0.0.0"

if [ -f "$LST_UPD_FILE" ]; then
  cur_json_content=$(cat "$LST_UPD_FILE")
  cur_app_ver=$(echo "$cur_json_content" | jq -r '.version // "0.0.0"')
fi

if [[ "${g_params["force-update"]}" == "yes" ]]; then
  cur_app_ver="0.0.0"
fi

if [ ! "$cur_app_ver" = "$latest_app_ver" ]; then
   echo
   echo "Version needs update: $cur_app_ver -> $latest_app_ver"
   
   echo
   echo "<< Backup files >>" | do_backup
   if [[ $? -ne 0 ]]; then rm "${LOCAL_TARGET_FILE}"; exit 1; fi   # Exit if error

   echo
   echo "<< Update files from GitHub >>" | update_from_github
   if [[ $? -ne 0 ]]; then rm "${LOCAL_TARGET_FILE}"; exit 1; fi   # Exit if error

   echo
   echo "<< Execute Commands >>" | exec_cmd                        
   if [[ $? -ne 0 ]]; then rm "${LOCAL_TARGET_FILE}"; exit 1; fi   # Exit if error

   cp "${LOCAL_TARGET_FILE}" "${LST_UPD_FILE}"                  # Update current version profile
   rm "${LOCAL_TARGET_FILE}"                                    # Delete app_version.json

   echo
   echo "Update Completed."

   echo
   echo "Backup folders older than 30 days is deleting..."
   ./del_old_backup.sh


   if [[ "${g_params["slient"]}" == "yes" ]]; then
      echo "Preparing reboot (1 minute)...You need logout and login again after reboot!"

         if [[ "${g_params["from"]}" == "terminal" ]]; then
            eval "echo '${g_params["pwd"]}' | sudo -S sudo shutdown -r +1 "
         else
            echo $HOUSEKEEPER_BEE_PWD_SUDO | sudo -S -k shutdown -r +1
         fi
   else
      echo                                                         # Add a newline after keypress
      read -n 1 -s -r -p "Press any key to reboot..."              # Wait
      echo                                                         # Add a newline after keypress
      sudo reboot                                                 # reboot to apply the changes
   fi

else
   echo "Version is already up to date (ver $latest_app_ver)"
   echo
   rm "${LOCAL_TARGET_FILE}"                                       # Delete app_version.json
fi



