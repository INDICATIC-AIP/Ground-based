#!/bin/bash

NASPath=( "Pacifico/INDICATIC/UTP" "Caribe" "Punto_medio/STRE" )

while :; do
  for dir in "${NASPath[@]}"; do

    cd "/var/services/homes/INDICATIC/"$dir"/ALPY"
    echo "In ALPY directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		folder=$(find . -type d ! -name "ALPYimages" ! -name "*.fits" ! -name "*.NEF" ! -name "*.SCV" ! -name "*.txt" -printf "%T@ %p\n" | sort -n | head -n 1)
		foldername=$(basename "$folder")
		echo "folder selected : $foldername"
		if [[ -n "$foldername" ]]; then
			directory="/var/services/homes/INDICATIC/"$dir"/ALPY/"$foldername""
			FolderDestination="/var/services/homes/INDICATIC/"$dir"/ALPY/ALPYimages"
			/var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			foldername=""
		fi
	fi	

    sleep 3

    cd "/var/services/homes/INDICATIC/"$dir"/NIKON"
    echo "In NIKON directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		 folder=$(find . -type d ! -name "NIKONimages" ! -name "@eaDir"  ! -name "*.*" -printf "%T@ %p\n" | sort -n | head -n 1)
	     foldername=$(basename "$folder")
	     echo "folder selected : $folder"
         echo "folder name : $foldername"
		 if [[ -n "$foldername" ]]; then
			 directory="/var/services/homes/INDICATIC/"$dir"/NIKON/"$foldername""
			 FolderDestination="/var/services/homes/INDICATIC/"$dir"/NIKON/NIKONimages"
			 /var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			 foldername=""
		 fi
	fi

      sleep 3

    cd "/var/services/homes/INDICATIC/"$dir"/QHYCCD/B-Bessell"
    echo "In QHYCCD B directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		folder=$(find . -type d ! -name "QHY_B_images" ! -name "*.*" -printf "%T@ %p\n" | sort -n | head -n 1)
		foldername=$(basename "$folder")
		echo "folder selected : $foldername"
		if [[ -n "$foldername" ]]; then
			directory="/var/services/homes/INDICATIC/"$dir"/QHYCCD/B-Bessell/"$foldername""
			FolderDestination="/var/services/homes/INDICATIC/"$dir"/QHYCCD/B-Bessell/QHY_B_images"
			/var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			foldername=""
		fi
	fi	

    sleep 3

    cd "/var/services/homes/INDICATIC/"$dir"/QHYCCD/I-Bessell"
    echo "In QHYCCD I directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		folder=$(find . -type d ! -name "QHY_I_images" ! -name "*.*" -printf "%T@ %p\n" | sort -n | head -n 1)
		foldername=$(basename "$folder")
		echo "folder selected : $foldername"
		if [[ -n "$foldername" ]]; then
			directory="/var/services/homes/INDICATIC/"$dir"/QHYCCD/I-Bessell/"$foldername""
			FolderDestination="/var/services/homes/INDICATIC/"$dir"/QHYCCD/I-Bessell/QHY_I_images"
			/var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			foldername=""
		fi
	fi
    
    sleep 3

    cd "/var/services/homes/INDICATIC/"$dir"/QHYCCD/R-Bessell"
    echo "In QHYCCD R directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		folder=$(find . -type d ! -name "QHY_R_images" ! -name "*.fits" ! -name "*.NEF" ! -name "*.SCV" ! -name "*.txt" -printf "%T@ %p\n" | sort -n | head -n 1)
		foldername=$(basename "$folder")
		echo "folder selected : $foldername"
		if [[ -n "$foldername" ]]; then
			directory="/var/services/homes/INDICATIC/"$dir"/QHYCCD/R-Bessell/"$foldername""
			FolderDestination="/var/services/homes/INDICATIC/"$dir"/QHYCCD/R-Bessell/QHY_R_images"
			/var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			foldername=""
		fi
	fi
	

    sleep 3

    cd "/var/services/homes/INDICATIC/"$dir"/QHYCCD/U-Bessell"
    echo "In QHYCCD U directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		folder=$(find . -type d ! -name "QHY_U_images" ! -name "*.fits" ! -name "*.NEF" ! -name "*.SCV" ! -name "*.txt" -printf "%T@ %p\n" | sort -n | head -n 1)
		foldername=$(basename "$folder")
		echo "folder selected : $foldername"
			if [[ -n "$foldername" ]]; then
			directory="/var/services/homes/INDICATIC/"$dir"/QHYCCD/U-Bessell/"$foldername""
			FolderDestination="/var/services/homes/INDICATIC/"$dir"/QHYCCD/U-Bessell/QHY_U_images"
			/var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			foldername=""
		fi
	fi
    sleep 3

    cd "/var/services/homes/INDICATIC/"$dir"/QHYCCD/V-Bessell"
    echo "In QHYCCD V directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		folder=$(find . -type d ! -name "QHY_V_images" ! -name "*.fits" ! -name "*.NEF" ! -name "*.SCV" ! -name "*.txt" -printf "%T@ %p\n" | sort -n | head -n 1)
		foldername=$(basename "$folder")
		echo "folder selected : $foldername"
		if [[ -n "$foldername" ]]; then
			directory="/var/services/homes/INDICATIC/"$dir"/QHYCCD/V-Bessell/"$foldername""
			FolderDestination="/var/services/homes/INDICATIC/"$dir"/QHYCCD/V-Bessell/QHY_V_images"
			/var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			foldername=""
		fi
	fi
    sleep 3

    cd "/var/services/homes/INDICATIC/"$dir"/TESS-W"
    echo "In TESS-W directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		folder=$(find . -type d ! -name "ok" ! -name "*.fits" ! -name "*.NEF" ! -name "*.SCV" ! -name "*.txt" -printf "%T@ %p\n" | sort -n | head -n 1)
		foldername=$(basename "$folder")
		echo "folder selected : $foldername"
		if [[ -n "$foldername" ]]; then
			directory="/var/services/homes/INDICATIC/"$dir"/TESS-W/"$foldername""
			FolderDestination="/var/services/homes/INDICATIC/"$dir"/TESS-W/TESSWimages"
			/var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			foldername=""
		fi
	fi
    sleep 3

    cd "/var/services/homes/INDICATIC/"$dir"/TESS-W4"
    echo "In TESS-W4 directory of "$dir""
	if [ $(find -mindepth 1 -maxdepth 1 -type d | wc -l) -ge 2 ]; then
		folder=$(find . -type d ! -name "ok" ! -name "*.fits" ! -name "*.NEF" ! -name "*.SCV" ! -name "*.txt" -printf "%T@ %p\n" | sort -n | head -n 1)
		foldername=$(basename "$folder")
		echo "folder selected : $foldername"
		if [[ -n "$foldername" ]]; then
			directory="/var/services/homes/INDICATIC/"$dir"/TESS-W4/"$foldername""
			FolderDestination="/var/services/homes/INDICATIC/"$dir"/TESS-W4/TESSW4images"
			/var/services/homes/INDICATIC/InteroperabilityCode/TreatmentFolder.sh "$directory" "$FolderDestination"
			foldername=""
		fi
	fi
  done
done
