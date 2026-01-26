#!/bin/bash

#Generate the Checksum of payload and info files with sha256 encryption

CkeckSumGenerate() {
  #Checksum to be compared with what received the NAS to ensure the integrity of the payload
  checksumPayload=$(sha256sum "$LOCAL_FILE" | awk '{print $1}')
  echo "SHA-256 of the file : $checksumPayload"
  echo "local file : $LOCAL_FILE"

  #Checksum to be compared with what received the NAS to ensure the integrity of the info file
  checksumInfo=$(sha256sum "$FileInfo" | awk '{print $1}')
  echo "SHA-256 of the file info : $checksumInfo"

  #File in wich there is the checksum, this file have always the same name
  ChecksumToCrypt="$imageInfo"/"StringCrypt.txt"
  #File in which there is the checksum with the name of the appropriate file
  newFileNamechecksum="Checksum_${FileName%.*}.txt"

  ###############################checksum treatment################################
  #Both checksum to crypt in the ChecksumToCrypt's file
  echo "$checksumPayload $checksumInfo" > "$ChecksumToCrypt"

  #Definition of the path
  FileInfochecksum="$imageInfo/$newFileNamechecksum"

  #Sending the crypted cheksum into the files
  echo -e "$checksumPayload\n$checksumInfo" > "$FileInfochecksum"

  #Execution of the encryption code
  EXECUTABLE="/home/indicatic-e1/Desktop/code/CryptageC/mainCrypt"
  $EXECUTABLE

}
