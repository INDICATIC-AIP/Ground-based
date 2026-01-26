#!/bin/bash

# This code retrieves the CryptFile and the Info file to compare their hashes.
# If the hashes are equal, a directory with the name of the payload file is created,
# and both the payload and Info files are placed into it.
# If the hashes are not equal, all files related to the received payload file are deleted.

echo "Current directory : $1"

PayloadReceived=""
InfoReceived=""
PayloadHash=""
InfoHash=""
FilePathPayload=""
Prefix=""
info="info_"

#Find a CryptFile in the Current directory
FindFiles=$(find . \( -type f \) -name "*CryptFile*")

#Select the most older CryptFile
name=$(ls -lt $FindFiles | tail -n 1 | awk '{print $NF}')

#If the file second (*) at the beginnig, then ParaExtract contains (*)
ParaExtract=$(basename "$name")
if [[ $ParaExtract != \(* ]]; then
    Prefix=""
else
  Prefix=$(echo "$ParaExtract" | sed -n 's/^\((.*)\).*/\1/p')
fi


#Get the part exactly of the file that needs to be traited
FileName=$(echo "$name" | awk '{sub(".txt$", "", $0); print $0}')
FileName=$(echo "$FileName" | awk -F '_' '{print substr($0, index($0, "_") + 1)}')
echo "this is the name of the file $FileName"

#Get the Checksum file of the payload file
#nameChecksumfile=$(find . -maxdepth 1 -name "${Prefix}Checksum*_$FileName.txt*" | head -n 1)

FilePathPayload=$(find "$1" -maxdepth 1 -type f \( -name "${FileName}.fit" -o -name "${FileName}.fits" -o -name "${FileName}.NEF" -o -name "${FileName}.csv" \) | head -n 1)

#Get each differetns parts of the files and put it on an unique file
cat "$name" | tr '\n' ' ' | awk '{print $1}' > /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/BitPayloadToSend.txt
cat "$name" | tr '\n' ' ' | awk '{print $2}' > /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/BitInfoToSend.txt
cat "$name" | tr '\n' ' ' | awk '{print $3}' > /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/Caesar.txt
cat "$name" | tr '\n' ' ' | awk '{print $4}' > /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/Mask.txt

#Read the first and the second line that contains the two different hash
#read -r PayloadReceived < "$nameChecksumfile"
#read -r InfoReceived < <(tail -n +2 "$nameChecksumfile")

#Cancel space to be sure to not have a character in more
#PayloadReceived=$(echo -n "$PayloadReceived" | tr -d '[:space:]')
#InfoReceived=$(echo -n "$InfoReceived" | tr -d '[:space:]')

#Deleting the line feed at the end of the files, so it matche with the multidimensional tabs in c code
head -c -1 /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/BitPayloadToSend.txt > /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/BitPayload.txt
head -c -1 /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/BitInfoToSend.txt > /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/BitInfo.txt

#Delete the files with the line feed
rm /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/BitPayloadToSend.txt
rm /var/services/homes/INDICATIC/InteroperabilityCode/tmpFile/BitInfoToSend.txt

#Execute the main c code to decrypt from CryptFile
/var/services/homes/INDICATIC/InteroperabilityCode/mainTreatment

cd "/var/services/homes/INDICATIC/InteroperabilityCode/tmpFile"

#Get the hash calculated with crypto
HashFile="/var/services/homes/INDICATIC/InteroperabilityCode/Hash.txt"
read -r PayloadHash < "$HashFile"
read -r InfoHash < <(tail -n +2 "$HashFile")

#Cancel space to be sure to not have a character in more
PayloadHash=$(echo -n "$PayloadHash" | tr -d '[:space:]')
InfoHash=$(echo -n "$InfoHash" | tr -d '[:space:]')

echo "PayloadHash bash : $PayloadHash"
echo "InfoHash bash : $InfoHash"
#echo "PayloadHash received bash : $PayloadReceived"
#echo "InfoHash received bash : $InfoReceived"

###################To check the functioning of integrity, uncomment the four following lines.#####################

#PayloadHash="${PayloadHash::-1}g"
#echo "PayloadHash modified :$PayloadHash"

#InfoHash="${InfoHash::-1}g"
#echo "InfoHash modified :$InfoHash"

###############################################################################################################

echo "prefix : $Prefix"
echo "info : $info"
echo "FileName : $FileName"
echo "name : $name"
echo "nameChecksumfile : $nameChecksumfile"
 
PayloadToGet=$(sha256sum "$FilePathPayload" | awk '{print $1}')
InfoFileName="$1/${Prefix}${info}${FileName}.txt"

InfoToGet=$(sha256sum "$InfoFileName" | awk '{print $1}')
echo "name of the info file detected $InfoFileName"

#If the two hashes, info and payload are equal, then we treat them differently
if [[ "$PayloadHash" == "$PayloadToGet" ]]; then
  if [[ "$InfoHash" == "$InfoToGet" ]]; then
    cd $1
    mkdir -- "$Prefix$FileName"
    echo "Targeted file : $FileName"
    rm -- "$name"
   # rm -- "$nameChecksumfile"
    for file in *; do
      if [[ "$file" =~ ^"$Prefix$info$FileName"\.(fit|fits|txt|NEF|csv)$ || "$file" =~ ^"$Prefix$FileName"\.(fit|fits|txt|NEF|csv)$ ]]; then
		echo "Corresponding file : $file"
		mv -- "$file" "$Prefix$FileName/"
	  fi
	done
  else
	cd $1
    rm -- "$name"
    #rm -- "$nameChecksumfile"
    for file in *; do
      if [[ "$file" =~ ^"$Prefix$info$FileName"\.(fit|fits|txt|NEF|csv)$ || "$file" =~ ^"$Prefix$FileName"\.(fit|fits|txt|NEF|csv)$ ]]; then
		echo "Corresponding file to delete in case InfoHash are not the same  : $file"
		rm -- "$file"
      fi
	done
  fi
else
	cd $1
	rm -- "$name"
    #rm -- "$nameChecksumfile"
	for file in *; do
      if [[ "$file" =~ ^"$Prefix$info$FileName"\.(fit|fits|txt|NEF|csv)$ || "$file" =~ ^"$Prefix$FileName"\.(fit|fits|txt|NEF|csv)$ ]]; then
        echo "Corresponding file to delete in case PayloadHash are not the same : $file"
        rm -- "$file"
      fi
	done
fi

cd "/var/services/homes/INDICATIC/InteroperabilityCode/tmpFile"

#Delete all temporary files
#rm -- *
