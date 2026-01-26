#!/bin/bash

#This code handle the sending of the files, check if the files are receied on the NAS
#and validate them or delete them if a file is missing in the NASS
#Its handle the automatic rename of the files if the same files are located in the NAS

source /home/indicatic-e1/Desktop/code/Interop_code/ChecksumGeneration.sh

Connect_To_NASS() {

    ################################Generate the cheksum of the payload and the file info########
    CkeckSumGenerate
    ################################Sending the files payload and info#######################

    filePathCrypt="/home/indicatic-e1/Desktop/code/CryptageC/CryptFile.txt"

    #Change the name of the file
    mv "$filePathCrypt" "$(dirname "$filePathCrypt")/CryptFile_${FileName%.*}.txt"

    #Attribute the file to the variable
    CryptFile="/home/indicatic-e1/Desktop/code/CryptageC/CryptFile_${FileName%.*}.txt"

    #Send .fit payload file with SFTP protocole
    linuxdirectorytmp="/home/indicatic-e1/Desktop/code/tmp"
    cp $LOCAL_FILE $linuxdirectorytmp

    #Name of the file after copy
    PAYLOAD_FILE="$linuxdirectorytmp/$(basename $LOCAL_FILE)"
    NAMEfilePayload="$(basename "$PAYLOAD_FILE")"

    linuxpath=$(dirname "$PAYLOAD_FILE")

    ############################Variables used to check the files in the NAS, for the followinf ssh, sftp connexion##############

    #Get only the name of the file and not all the path
    FileInfoCheck=$(basename "$FileInfo")
    #FileInfochecksumCheck=$(basename "$FileInfochecksum")
    CryptFileCheck=$(basename "$CryptFile")
    
    # Check if RAW_FILE exists and prepare it for upload
    RAW_FILE_PATH=""
    RAW_FILE_CHECK=""
    if [ -n "$RAW_FILE" ]; then
        RAW_FILE_PATH="$directory/$RAW_FILE"
        RAW_FILE_CHECK=$(basename "$RAW_FILE_PATH")
        echo "Will upload raw file: $RAW_FILE_CHECK"
    fi
    
    #count variable to determinate if a file already exist with the same name
    count=0

    #Variables of the renamed files
    NAMEfilePayloadToSend=""
    FileInfoRenameToSend=""
    #FileInfochecksumRenameToSend=""
    CryptFileRenameToSend=""
    RAWfileRenameToSend=""

NASdirectory="/var/services"$REMOTE_DIR""

namewithoutextension=$(echo "$NAMEfilePayload" | awk -F. '{OFS="."; $NF=""; print $0}' | sed 's/\.$//')
echo "namewithoutextension : $namewithoutextension"

# SSH session to check of the files or folder already exist on the NAS, and return count value in count.text
#The variable maxValue indicate the higher prefix that the file of the name NAMEfilePayload have
sshpass -p "$PASSWD" ssh "$USER@$HOST" <<EOF
cd "$NASdirectory"

count=0
if [ -d "$namewithoutextension" ] || [ -f "$NAMEfilePayload" ]; then
    count=5
    echo "\$count" > /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/count.txt

    maxValue=0
    echo "Valeur de maxValue : \$maxValue"

    filesFound=\$(find . \( -type f -o -type d \) \( -name "\(*\)$NAMEfilePayload" -o -name "\(*\)$namewithoutextension" \))

    if [ -z "\$filesFound" ]; then
        echo "\$maxValue" >> /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/count.txt
        echo "valeur max sent : \$maxValue "
    else
        echo "\$filesFound" | while read -r file; do
            echo "Dans le directory : \$NASdirectory"
            echo "Juste avant déclaration de currentValue"
            currentValue=\$(echo "\$file" | awk -F'[()]' '{print \$2}')
            echo "Valeur de currentValue : \$currentValue"

            # Vérifier si currentValue est un nombre
            if [[ "\$currentValue" =~ ^[0-9]+$ ]]; then
                if (( currentValue > maxValue )); then
                    maxValue=\$currentValue
                fi
            fi

            echo "Valeur intermédiaire de maxValue trouvée : \$maxValue"
            echo "\$maxValue" >> /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/count.txt
        done
    fi
else
    count=1
    echo "\$count" > /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/count.txt
    echo -1 >> /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/count.txt
fi

exit
EOF

sleep 5

# Use scp to copy the file back to the local machine, to know if the file exist or not on it
sshpass -p "$PASSWD" scp "$USER@$HOST:/var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/count.txt" /home/indicatic-e1/Desktop/code/count.txt
count=$(sed -n '1p' /home/indicatic-e1/Desktop/code/count.txt) #read the first line of the file
PrefixVal=$(sed -n '$p' /home/indicatic-e1/Desktop/code/count.txt) #read the last line of the file
echo "Val of count on the local machine : $count"
echo "val of PrefixVal : $PrefixVal"

NewIndex=$((PrefixVal + 1)) #This value is the value assigned as prefix of the files if they already have a name
echo "newIndex value : $NewIndex"

#SFTP protocol to send the files into REMOTE_DIR directory
if [[ "$count" != 5 ]]; then
  # Build lftp commands - upload raw in same session to avoid latency
  if [ -n "$RAW_FILE_PATH" ] && [ -f "$RAW_FILE_PATH" ]; then
    lftp -u $USER,$PASSWD sftp://$HOST <<EOF
    set sftp:auto-confirm yes
    echo "Uploading files (with raw) - count not equal 5"
    cd "$REMOTE_DIR"
    put -- "$PAYLOAD_FILE"
    put -- "$FileInfo"
    put -- "$CryptFile"
    put -- "$RAW_FILE_PATH"
    bye
    exit
EOF
  else
    lftp -u $USER,$PASSWD sftp://$HOST <<EOF
    set sftp:auto-confirm yes
    echo "Uploading files (no raw) - count not equal 5"
    cd "$REMOTE_DIR"
    put -- "$PAYLOAD_FILE"
    put -- "$FileInfo"
    put -- "$CryptFile"
    bye
    exit
EOF
  fi
fi

if [[ "$count" = 5 ]]; then
  # Add "(NewIndex)" in front of the file names
  # Extract the base names for each file
  FileInfoRename=$(basename "$FileInfo")
  #FileInfochecksumRename=$(basename "$FileInfochecksum")
  CryptFileRename=$(basename "$CryptFile")

  # Copy the files to the new directory with "(NewIndex)" prepended to the file names
  mkdir -p /home/indicatic-e1/Desktop/code/RenameFile  # Ensure the destination directory exists

  #Copy the files into news files that will be renamed
  cp "$NAMEfilePayload" "/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$NAMEfilePayload"
  cp "$FileInfo" "/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$FileInfoRename"
  #cp "$FileInfochecksum" "/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$FileInfochecksumRename"
  cp "$CryptFile" "/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$CryptFileRename"
  
  # Copy raw file if it exists
  if [ -n "$RAW_FILE_PATH" ] && [ -f "$RAW_FILE_PATH" ]; then
      RAWfileRename=$(basename "$RAW_FILE_PATH")
      cp "$RAW_FILE_PATH" "/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$RAWfileRename"
  fi

  # Define new variables for the renamed files
  NAMEfilePayloadToSend="/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$NAMEfilePayload"
  FileInfoRenameToSend="/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$FileInfoRename"
  #FileInfochecksumRenameToSend="/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$FileInfochecksumRename"
  CryptFileRenameToSend="/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$CryptFileRename"
  
  # Set raw file variable if it exists
  if [ -n "$RAW_FILE_PATH" ] && [ -f "$RAW_FILE_PATH" ]; then
      RAWfileRenameToSend="/home/indicatic-e1/Desktop/code/RenameFile/("$NewIndex")$RAWfileRename"
  fi

  # Debugging: Print new file path
  echo "NAMEfilePayloadToSend: $NAMEfilePayloadToSend"
  echo "FileInfoRenameToSend: $FileInfoRenameToSend"
  #echo "FileInfochecksumRenameToSend: $FileInfochecksumRenameToSend"
  echo "CryptFileRenameToSend: $CryptFileRenameToSend"

  # Upload all renamed files in same lftp session to avoid latency
  if [ -n "$RAWfileRenameToSend" ] && [ -f "$RAWfileRenameToSend" ]; then
    lftp -u $USER,$PASSWD sftp://$HOST <<EOF
    set sftp:auto-confirm yes
    echo "Uploading renamed files (with raw) - count equal 5"
    cd "$REMOTE_DIR"
    put -- "$NAMEfilePayloadToSend"
    put -- "$FileInfoRenameToSend"
    put -- "$CryptFileRenameToSend"
    put -- "$RAWfileRenameToSend"
    bye
    exit
EOF
  else
    lftp -u $USER,$PASSWD sftp://$HOST <<EOF
    set sftp:auto-confirm yes
    echo "Uploading renamed files (no raw) - count equal 5"
    cd "$REMOTE_DIR"
    put -- "$NAMEfilePayloadToSend"
    put -- "$FileInfoRenameToSend"
    put -- "$CryptFileRenameToSend"
    bye
    exit
EOF
  fi
fi

sleep 5

####################################Check if the files are in the NAS##################

if [[ "$count" != 5 ]]; then
sshpass -p "$PASSWD" ssh "$USER@$HOST" <<EOF

cd "/var/services$REMOTE_DIR"

# Build condition to check all expected files including raw if it should be there
if [ -f "$NAMEfilePayload" ] && [ -f "$FileInfoCheck" ] && [ -f "$CryptFileCheck" ]; then
    # If raw was sent, verify it exists too
    if [ -n "$RAW_FILE_CHECK" ]; then
        if [ -f "$RAW_FILE_CHECK" ]; then
            echo "All files (including raw) exist. Closing connection."
        else
            echo "Raw file missing. Deleting all partially uploaded files..."
            [ -f "$NAMEfilePayload" ] && rm -- "$NAMEfilePayload"
            [ -f "$FileInfoCheck" ] && rm -- "$FileInfoCheck"
            [ -f "$CryptFileCheck" ] && rm -- "$CryptFileCheck"
        fi
    else
        echo "All files exist. Closing connection."
    fi
else
    echo "Some files are missing. Deleting any partially uploaded files..."
    [ -f "$NAMEfilePayload" ] && rm -- "$NAMEfilePayload"
    [ -f "$FileInfoCheck" ] && rm -- "$FileInfoCheck"
    #[ -f "$FileInfochecksumCheck" ] && rm -- "$FileInfochecksumCheck"
    [ -f "$CryptFileCheck" ] && rm -- "$CryptFileCheck"
    [ -f "$RAW_FILE_CHECK" ] && rm -- "$RAW_FILE_CHECK"
fi
exit
EOF
fi

NAMEfilePayloadToSend=$(basename "$NAMEfilePayloadToSend")
FileInfoRenameToSend=$(basename "$FileInfoRenameToSend")
#FileInfochecksumRenameToSend=$(basename "$FileInfochecksumRenameToSend")
CryptFileRenameToSend=$(basename "$CryptFileRenameToSend")

# Get basename for renamed raw file if it exists
if [ -n "$RAWfileRenameToSend" ]; then
    RAWfileRenameToSend=$(basename "$RAWfileRenameToSend")
fi

if [[ "$count" = 5 ]]; then

  echo " NAMEfilePayloadToSend : $NAMEfilePayloadToSend"

  sshpass -p "$PASSWD" ssh "$USER@$HOST" <<EOF

  cd "/var/services$REMOTE_DIR"

  # Check all expected files including raw if it should be there
  if [ -f "$NAMEfilePayloadToSend" ] && [ -f "$FileInfoRenameToSend" ] && [ -f "$CryptFileRenameToSend" ]; then
      # If raw was sent, verify it exists too
      if [ -n "$RAWfileRenameToSend" ]; then
          if [ -f "$RAWfileRenameToSend" ]; then
              echo "All renamed files (including raw) exist. Closing connection."
          else
              echo "Renamed raw file missing. Deleting all partially uploaded files..."
              [ -f "$NAMEfilePayloadToSend" ] && rm -- "$NAMEfilePayloadToSend"
              [ -f "$FileInfoRenameToSend" ] && rm -- "$FileInfoRenameToSend"
              [ -f "$CryptFileRenameToSend" ] && rm -- "$CryptFileRenameToSend"
          fi
      else
          echo "All renamed files exist. Closing connection."
      fi
  else
      echo "Some files are missing. Deleting any partially uploaded files..."
      [ -f "$NAMEfilePayloadToSend" ] && rm -- "$NAMEfilePayloadToSend"
      [ -f "$FileInfoRenameToSend" ] && rm -- "$FileInfoRenameToSend"
      #[ -f "$FileInfochecksumRenameToSend" ] && rm -- "$FileInfochecksumRenameToSend"
      [ -f "$CryptFileRenameToSend" ] && rm -- "$CryptFileRenameToSend"
      [ -f "$RAWfileRenameToSend" ] && rm -- "$RAWfileRenameToSend"
  fi
  exit
EOF
fi
sleep 5
}
