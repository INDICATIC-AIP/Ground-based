#!/bin/bash

#Call the differents functions of the code to ensure the treatment of each files is executed properly, and then delete the files

source /home/indicatic-e1/Desktop/code/Interop_code/TrameArchitecture.sh
source /home/indicatic-e1/Desktop/code/Interop_code/connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/VariablesRefresh.sh
source /home/indicatic-e1/Desktop/code/Interop_code/info_Nass_connect.sh
source /home/indicatic-e1/Desktop/code/Interop_code/ChecksumGeneration.sh

execution() {

  #Create imageINfo directory if necesary
  mkdir -p "$imageInfo"

  #Creation of the Trame to be sent to the NAS
  MakeTram "$directory"

  #Create text file with the name of the file sent with info.txt at the end
  newFileName="info_${FileName%.*}.txt"
  FileInfo="$imageInfo/$newFileName"

  #Write the trame into the file
  echo "$TrameToSend" > "$FileInfo"

  #Info to conenct on the NAS profile
  Log_NASS
  #Connec to NAS and send the files
  Connect_To_NASS

  #Move to the directory and delete the file
  cd "$directory"
  rm -- "$File"
  
  # Delete the raw file if it exists
  if [ -n "$RAW_FILE" ] && [ -f "$RAW_FILE" ]; then
      rm -- "$RAW_FILE"
      echo "Deleted raw file: $RAW_FILE"
  fi

  #Move to the imageInfo directory and delete the new file
  cd "$imageInfo"

  rm -- "$newFileName"
  rm -- "$newFileNamechecksum"
  rm -- "$ChecksumToCrypt"

  #Delete the payload file meant to be sent to the NAS from tmp local machine (client) directory
  rm -- "$PAYLOAD_FILE"

  #Delete the Crypt file
  rm -- "$CryptFile"

  cd "/home/indicatic-e1/Desktop/code/CryptageC"

  rm "shamirPartsPayload.txt"
  rm  "shamirPartsInfo.txt"

  cd "/home/indicatic-e1/Desktop/code/RenameFile"

  if [ "$(ls -A .)" ]; then
  	rm *
  fi

  directory=""
  imageInfo=""
}
