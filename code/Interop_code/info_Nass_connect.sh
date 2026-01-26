#!/bin/bash
source /home/indicatic-e1/Desktop/.env
#Here is determinated the directory where the files must be sent, the Station variables contains the ID of the station

Log_NASS() {
  #SFTP connexion information
  HOST="$NAS_HOST"
  USER="$NAS_USER"
  PASSWD="$NAS_PASSWD"

  if [[ $index -eq 0 ]]; then
    REMOTE_DIR="/homes/INDICATIC/"$Station"/ALPY"
  elif [[ $index -eq 1 ]]; then
    REMOTE_DIR="/homes/INDICATIC/"$Station"/QHYCCD/U-Bessell"
  elif [[ $index -eq 2 ]]; then
    REMOTE_DIR="/homes/INDICATIC/"$Station"/QHYCCD/B-Bessell"
  elif [[ $index -eq 3 ]]; then
    REMOTE_DIR="/homes/INDICATIC/"$Station"/QHYCCD/V-Bessell"
  elif [[ $index -eq 4 ]]; then
    REMOTE_DIR="/homes/INDICATIC/"$Station"/QHYCCD/R-Bessell"
  elif [[ $index -eq 5 ]]; then
    REMOTE_DIR="/homes/INDICATIC/"$Station"/QHYCCD/I-Bessell"
  elif [[ $index -eq 6 ]]; then
    REMOTE_DIR="/homes/INDICATIC/"$Station"/NIKON"
  elif [[ $index -eq 7 ]]; then
    REMOTE_DIR="/homes/INDICATIC/"$Station"/TESS"$DESTINATION""
  else
    echo "error"
  fi

  LOCAL_FILE=$FilePath
}
