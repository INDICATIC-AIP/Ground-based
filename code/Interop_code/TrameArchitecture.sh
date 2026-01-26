#!/bin/bash

#Tram architecture of info files

MakeTram() {
  local directory="$1"

  #Assignment of the valors to their due variables
  #File=$(ls -1 "$directory" | head -n 1)
  FilePath="$directory/$File"
  FileName=$(basename "$FilePath")
  FileSize=$(stat --format=%s "$FilePath")
  LastModifTime=$(stat --format=%y "$FilePath")
  LastModifDay=$(date -r "$FilePath" +%A)
  RofAccess=$(stat --format=%A "$FilePath")
  FileFormat=$(file -b "$FilePath")

  #Tram architecture
  TrameToSend="$FileName $FileSize $LastModifTime $LastModifDay $RofAccess $FileFormat"
}
