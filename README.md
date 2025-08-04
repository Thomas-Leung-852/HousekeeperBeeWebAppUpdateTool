# HousekeeperBeeWebAppUpdateTool
Check and Update the Housekeeper Bee Web APP to the latest version

1.  connect to remote server, the Raspberry Pi 5
    >ssh [username]@[IP Address or Hostname]    
    
    example: ssh ada@192.168.50.180
2. Download/ clone this tool to the Desktop of the Raspberry Pi 5.
    > cd ~/Desktop    
    > git clone https://github.com/Thomas-Leung-852/HousekeeperBeeWebAppUpdateTool.git

3. Change the shell script to executable      
    > cd ~/Desktop/HousekeeperBeeWebAppUpdate   
    > chomd +x update_version.sh

4. run the script

    > ./update_version.sh   

    - The script download the latest version profile file from Google drive
    - If current_app_version.json not exist, it performs update.
    - If current_app_version.json exists, it Compare the app versions. If local copy is outdated, it performs the update.    

5. After updated the app, the following files are created.    
    - a backup file of previous app's jar file. In case, you need rollback the app to previous version.
    - created a current_app_version.json file      

      
