#!/bin/bash

#Generate the Checksum of payload and info files with sha256 encryption

CkeckSumGenerate() {
  #Checksum to be compared with what received the NAS to ensure the integrity of the payload
  checksumPayload=$(sha256sum "$LOCAL_FILE" | awk '{print $1}')
  echo "SHA-256 of the file : $checksumPayload"
  echo "local file : $LOCAL_FILE"

  #File in wich there is the checksum, this file have always the same name
  ChecksumToCrypt="$imageInfo"/"StringCrypt.txt"
  #File in which there is the checksum with the name of the appropriate file
  newFileNamechecksum="Checksum_${FileName%.*}.txt"

  ###############################checksum treatment################################
  # ShamirsParts.py expects two space-separated 64-char hashes; repeat payload hash
  echo "$checksumPayload $checksumPayload" > "$ChecksumToCrypt"

  #Definition of the path
  FileInfochecksum="$imageInfo/$newFileNamechecksum"

  #Sending the crypted cheksum into the file
  echo -e "$checksumPayload\n$checksumPayload" > "$FileInfochecksum"

  #Execution of the encryption code
  EXECUTABLE="/home/indicatic-e1/Desktop/code/CryptageC/mainCrypt"
  $EXECUTABLE

}
