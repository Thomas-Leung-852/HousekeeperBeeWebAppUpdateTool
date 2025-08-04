#!/bin/bash
#==========================================================================================
# init
#==========================================================================================

echo
echo
echo "***********************************************************************************************************************************"
echo "* Introducing the Housekeeper Bee Web App Update Tool: "
echo "* easily check for the latest version of Housekeeper Bee Web App, and download updates for efficient housekeeping management. "
echo "* Keep your app up to date effortlessly!"
echo "***********************************************************************************************************************************"
echo 

app_fn=$(find ~/Desktop/ -name "housekeeper-0.0.1-SNAPSHOT.jar" | grep "housekeeping_bee/files/prog" ) 

if [ -z $app_fn ]; then
   echo "Error: Housekeeper Bee Web App does not exist! Download from https://github.com/Thomas-Leung-852/HousekeeperBeeWebApp"
   echo
   exit 1
fi 


## Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Install it with: sudo apt-get install jq"
    exit 1
fi

## Create folder if missing
TMP_FOLDER_NAME="tmp"

if [ ! -d "$TMP_FOLDER_NAME" ]; then
   mkdir $TMP_FOLDER_NAME
fi

#==========================================================================================
# get version info 
#==========================================================================================

echo "Download latest version profile...."
echo

GDRIVE_FILE_ID="1u_jXIKHBDScf-2XHuoybkJ4XxPLyk9wd"
GDRIVE_URL="https://drive.google.com/uc?export=download&id=$GDRIVE_FILE_ID"
LOCAL_TARGET_FILE="app_version.json"

curl -L "$GDRIVE_URL" -o "$LOCAL_TARGET_FILE"

echo
echo "Comparing versions ..."

new_app_ver="unknown"

if [ ! -f "$LOCAL_TARGET_FILE" ]; then
    echo "Error: Get update info failure!"
    exit 1
else
    json_content=$(cat "$LOCAL_TARGET_FILE")

    new_app_ver=$(echo "$json_content" | jq -r '.version // "unknown"')
    file_id=$(echo "$json_content" | jq -r '.file_id // "unknown"')
    checksum=$(echo "$json_content" | jq -r '.checksum // "unknown"')
fi

if [ "$new_app_ver" = "unknown" ]; then
   echo "Error: Invalid update info!"
   exit 1
fi

if [ "$file_id" = "unknown" ]; then
    echo "Warning: No file id field found in JSON"
    exit 1
fi

if [ "$checksum" = "unknown" ]; then
    echo "Warning: No checksum field found in JSON"
    exit 1
fi

#==========================================================================================
# get last update info
#==========================================================================================

LST_UPD_FILE="current_app_version.json"

cur_app_ver="0.0.0"

if [ -f "$LST_UPD_FILE" ]; then
   cur_json_content=$(cat "$LST_UPD_FILE")
   cur_app_ver=$(echo "$cur_json_content" | jq -r '.version // "0.0.0"')
fi

if [ ! "$cur_app_ver" = "$new_app_ver" ]; then
   echo "Version needs update: $cur_app_ver -> $new_app_ver"

   FILE="./tmp/housekeeper-0.0.1-SNAPSHOT.jar"

   curl -L "https://drive.usercontent.google.com/download?id=${file_id}&confirm=xxx" -o $FILE

   dln_fn_checksum=$(sha256sum $FILE | cut -d' ' -f1)

   if [ "$checksum" = "$dln_fn_checksum" ]; then
   	#path_name=$(dirname "$fn")

        echo "---------------------------------------------"
	echo "Do backup and Update app                     "
        echo "---------------------------------------------"

        current_fn_checksum=$(sha256sum $app_fn | cut -d' ' -f1)

	mkdir -p backup
	cp "${app_fn}" "./backup/${current_fn_checksum}.jar"	# Backup file
        cp "${FILE}" "${app_fn}"				# Update jar file
        cp "${LOCAL_TARGET_FILE}" "${LST_UPD_FILE}"		# Update current version profile
        rm "${LOCAL_TARGET_FILE}"				# Delete app_version.json
        rm $FILE						# Delete downloaded file
	echo "Update Completed."
        read -n 1 -s -r -p "Press any key to reboot..."		# Wait
	echo  							# Add a newline after keypress
        sudo reboot
   else
      echo "File checksum problem!"
      exit 1 
   fi
else
    echo "Version is already up to date (ver $new_app_ver)"
    echo
    rm "${LOCAL_TARGET_FILE}"				# Delete app_version.json
fi


exit 0







