#!/bin/bash
clear
# script to partition a drive then copy ASD images to the partitions. Script must be run sudo!!
sudo -v

#list the ASD versions to be included. This will automatically partition the drive with an 8 GB partition for each version listed. Drive must be large enough!

ASD="108 116 123 132A 135 137 138 139 140 142 143 144 145A 146 147 148 149 150 151 152 155"
part_format=jhfs+ #global value for partitioning
part_size=8.0G


#list the disk ID - look in disk utility if you need!
echo "Select a disk to be erased and converted to ASD."
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
diskutil list ${diskID}
if [[ $? != 0 ]] #verify we have a valid disk id.
then
   echo "The disk number supplied appears invalid."
   exit 1
fi

#double confirmation before erasing
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

#operator has confirmed erase. Let the destruction begin!!!

#generate the partitioning command list for the ASDs listed
part_list="PartitionDisk ${diskID} GPTFormat" #the first options are straightforward

#build triplets of values for each partition needed
for file in $ASD 
do
     part_list="${part_list} ${part_format}  ${file}  ${part_size}"
done

#add a final partition to contain the extra space on the drive.
part_list="${part_list} HFS+  ExtraSpace 1.0G" #size doesn't matter it will expand to fill drive

diskutil ${part_list} #this is the command that actually partitions the disk

if [[ $? != 0 ]] #did partitioning fail?
then
   echo "Partitioning failed. Exiting script."
   exit 1
fi

#lets verify how many partitions were created

part_count=`diskutil list | grep ${diskID} | wc -l`
part_count=`expr ${part_count} - 4` #don't count the partition scheme or EFI partitions..

#echo "Number of partitions created on ${diskID}: ${part_count}"
list_count=`echo ${ASD} | wc -w`
#echo "Number of items in list: " ${list_count}

if [[ ! $part_count -eq $list_count ]] #somehow partitioning is off
then
   echo "Partitioning does not seem to be correct. Please try again."
   exit 1
fi

#now begin to copy each image to the corresponding partition
#exit 0
part_num=1

sleep 10 #let the drives "settle"

for file in $ASD

do
  src=/Volumes/MHQ/Backed\ Up/\~Everything\ by\ Company/Apple/Service\ Materials/Diagnostic\ Disc\ Images/Apple\ Service\ Diagnostics/ASD\ 3S"$file"/ASD\ OS\ 3S"$file".dmg
  echo "$part_num/$part_count complete"
  if [ ! -e "$src" ]       # Check if file exists.

  then
    echo "$file does not exist."; echo
    let "part_num += 1"
    continue                # On to next.
  else
    echo "Beginning to restore ASD $file"
    let "part_num += 1"
    vol_name="/dev/${diskID}s${part_num}"
    sudo asr restore --source "$src" --target /Volumes/$file --erase --noprompt
    if [[ $? != 0 ]]; then #restore failed
         echo `date` " - Writing ASD $file from server failed." >> make_asd_errors.log
         cp ${src} ./ASD\ OS\ 3S"${file}".dmg
         if [[ $? = 0 ]]; then #copy succeeded
             asr restore --source ./ASD\ OS\ 3S"$file".dmg --target /Volumes/$file --erase --noprompt
             if [[ $? = 0 ]]; then #success!!!
                diskutil renameVolume $vol_name $file
             else
                echo `date` " - Writing ASD $file from local copy failed." >> make_asd_errors.log
             fi
         else
             echo `date` " - Copying ASD $file to local directory failed." >> make_asd_errors.log
         fi
    else
         #rename the new partition if the restore succeeded
         diskutil renameVolume $vol_name $file
    fi
    continue                # On to next.
 
   fi
done


exit 0

