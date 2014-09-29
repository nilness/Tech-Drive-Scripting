#!/bin/bash
clear
#############################################################
# script to partition a drive then copy tech drive images, os installers, create installers partition and copy files, and create free space partition. Script must be run sudo!!
#sudo -v

#set any global values here
error_log=make_techdrive_errors.log
working_directory=`dirname "$BASH_SOURCE"`  #working directory will be wherever the script is

# comment out any particular image to exclude it from being copied to the drive but you'll have to comment out the corresponding partition

tech_drive_network_location="/Volumes/MHQ/Backed Up/Service/Current Tech Drives/"

tech_images=( \
"tech9.dmg" \
"tech8.dmg" \
"tech7.dmg" \
"tech6.dmg" \
"tech5.dmg" \
) # tech_images

os_install_network_location="/Volumes/MHQ/Backed Up/~Everything by Company/Apple/Mac OS Software/OS X Installers/"

os_images=( \
"10.9 Install.dmg" \
"10.8 Install.dmg" \
"10.7 Install.dmg" \
"10.6 Install.dmg" \
"10.5 Install.dmg" \
) # os_images

os_updates_network_location="/Volumes/MHQ/Backed Up/~Everything by Company/Apple/Updaters- OS X/"

os_updates=( \
"10.4 Client Updates/MacOSXUpdCombo10.4.11Intel.dmg" \
"10.4 Client Updates/MacOSXUpdCombo10.4.11PPC.dmg" \
"10.5 Client Updates/MacOSXUpdCombo10.5.8.dmg" \
"10.6 Client Updates/MacOSXUpdCombo10.6.8.dmg" \
"10.7 Client Updates/MacOSXUpdCombo10.7.4.dmg" \
"10.8 Client Updates/OSXUpdCombo10.8.5.dmg" \
) # os_updates

ilife_network_location="/Volumes/MHQ/Backed Up/~Everything by Company/Apple/Updaters- OS X/iLife Updates/"
ilife_installers=( \
"iLife 11 Install/iLife 11 Install DVD NFR.cdr" \
"iLife 09 Install/iLife 09 Install DVD.cdr" \
"iLife 08 Install/iLife 08 Install DVD.dmg" \
"iLife 06 Install/iLife 06 Install DVD.dmg" \
"iLife 05 Install/iLife 05 Install DVD.dmg" \
"iLife 04 Install/iLife 04 DVD install.dmg" \
"iLife 03 Install/iLife (Original 03).dmg" \
) # ilife_installers

testing_apps_network_location="/Volumes/MHQ/Backed Up/Service/Testing"

appleworks_network_location="/Volumes/MHQ/Backed Up/~Everything by Company/Apple/Applications/Appleworks/AppleWorks Mac 6.2.9"


#############################################################
restore_image () { # $1 = source

# get the file name of the source
source_file_name=`basename "${1}"`
target_volume_name=`basename -s ".dmg" "${1}"` #this strips the .dmg suffix off the filename

# make sure we have a local copy and it's up to date
# add --bwlimit=KBPS to limit bandwidth
/usr/bin/rsync -av --progress "${1}" "./${source_file_name}"
if [[ $? = 0 ]]; then #rysnc succeeded
# first we need to save the original disk id
    disk_id=`diskutil info "/Volumes/${target_volume_name}" | grep "Device Identifier:" | awk '{print $3}'`
    echo "Beginning to restore ${source_file_name} at ${disk_id}"
    /usr/sbin/asr restore --source "./${source_file_name}" --target "/Volumes/${target_volume_name}" --erase --noprompt 2>> "${error_log}"
    if [[ $? != 0 ]]; then #restore failed
         echo `date` " - Imaging ${source_file_name} failed." >> ${error_log}
    else
         echo
         echo "Imaging ${source_file_name} succeeded."
# rename the new partition if the restore succeeded
         diskutil renameVolume "${disk_id}" "${target_volume_name}" 2>> "${error_log}"
    fi
else
         echo `date` " - Rsync'ing ${source_file_name} to local directory failed. Make sure server is mounted." >> ${error_log}

fi

} #restore_image
#############################################################
copy_file () { # $1 = file path $2 = destination

if [ ! -e "${1}" ]; then       # Source doesn't exist.
    echo "${1} does not exist."; echo;
else
    echo "Beginning to copy ${1}"
    cp "${1}" "${2}" 2>> "${error_log}"
    if [[ $? != 0 ]]; then # error copying
         echo `date` " - Copying  ${1} from server failed." >> ${error_log}
    fi
fi
} #copy_file
#############################################################
partition_drive () { # $1 disk_id of drive to partition

diskutil PartitionDisk "${1}" APMFormat \
\
jhfs+ "tech9" 30.0G \
jhfs+ "tech8" 30.0G \
jhfs+ "tech7" 30.0G \
jhfs+ "tech6" 30.0G \
jhfs+ "tech5" 30.0G \
jhfs+ "10.9 Install" 10.0G \
jhfs+ "10.8 Install" 10.0G \
jhfs+ "10.7 Install" 10.0G \
jhfs+ "10.6 Install" 10.0G \
jhfs+ "10.5 Install" 10.0G \
jhfs+ "Installers" 80.0G \
jhfs+ "Free Space" 1.0G  2>> "${error_log}" #this will actually take the rest of the room on the drive.

if [[ $? != 0 ]] #did partitioning fail?
then
   echo "Partitioning failed. Exiting script."
   exit 1
fi
} #partition_drive
#############################################################
verify_server () { # make sure the required server is mounted

while [ ! -e "/Volumes/MHQ" ]; do
    open -g "afp://3GS4ever!@192.168.1.47/MHQ" 
    sleep 3
done
} #verify_server
#############################################################
# move to the working directory
cd "${working_directory}"
cd "${working_directory}/../../.." #when called via AppleScript app, we have to move out of the package...

# list the disk ID - look in disk utility if you need!
echo "Select a disk to be erased and converted to tech drive."
echo "These are the disks attached to this machine:"
diskutil list | grep /dev/disk

read -p "Please indicate the disk number to be erased:" -n 1
if [[ ! $REPLY =~ ^[01234567890]$ ]]
then
    echo "Invalid response"
    exit 1
fi
echo

diskID=disk$REPLY #set the disk id based on reply

echo "You are about to erase ${diskID}. This contains the partitions: "
diskutil list "${diskID}"
if [[ $? != 0 ]] #verify we have a valid disk id.
then
   echo "The disk number supplied appears invalid."
   exit 1
fi

# double confirmation before erasing
read -p "Are you sure? (y/n)" -n 1
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi
echo
read -p "Do you wish to cancel (y/n)?" -n 1
if [[ ! $REPLY =~ ^[Nn]$ ]]
then
    echo; echo "User cancelled"
    exit 1
fi

clear

# Turn off TimeMachine attempts to use the new partitions
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool YES

# operator has confirmed erase. Let the destruction begin!!!

partition_drive "${diskID}"

# make sure the network drive is mounted
verify_server

# create any folders that will be needed
mkdir "/Volumes/Installers/Updates"
mkdir "/Volumes/Installers/iLife"
mkdir "/Volumes/Installers/Testing"
mkdir "/Volumes/Installers/Installers"


# now begin to copy each image to the corresponding partition

for ix in ${!tech_images[*]} # expands to each of the indices in the array, handle each in turn
do
     restore_image "$tech_drive_network_location""${tech_images[$ix]}" # gets the element of the array for index 'ix'
done

for ix in ${!os_images[*]} # expands to each of the indices in the array, handle each in turn
do
     restore_image "$os_install_network_location""${os_images[$ix]}" # gets the element of the array for index 'ix'
done

# populate the installers partition

for ix in ${!os_updates[*]} # expands to each of the indices in the array, handle each in turn
do
     copy_file "$os_updates_network_location""${os_updates[$ix]}" "/Volumes/Installers/Updates/."
done


for ix in ${!ilife_installers[*]} # expands to each of the indices in the array, handle each in turn
do
     copy_file "$ilife_network_location""${ilife_installers[$ix]}" "/Volumes/Installers/iLife/."
done

# copy testing apps, etc.
cp -R "$testing_apps_network_location" "/Volumes/Installers/." 2>> "${error_log}"
cp -R "$appleworks_network_location" "/Volumes/Installers/Installers/." 2>> "${error_log}"


# Turn back on TimeMachine attempts to use the new partitions
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool NO

exit 0

