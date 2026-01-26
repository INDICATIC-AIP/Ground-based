#!/bin/bash

#Capture image with Nikon each x times

#set storage location

#Configure camera to shoot in RAW format
gphoto2 --set-config capturetarget=10
#10        DARK
#10        FLAT
#1/4000    Offset

while true; do 

	#capture and download image 
	gphoto2 --capture-image-and-download --filename "/home/indicatic-e1/Desktop/ASTRODEVICES/NIKONFILE/image_%Y%m%d_%H%M%S.NEF"

	echo "Captured image"

	sleep 30

done


