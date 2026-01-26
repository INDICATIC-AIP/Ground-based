/*
 QHY Test CCD

 Copyright (C) 2017 Jan Soldan

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Lesser General Public License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <iostream>
#include <ctime>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <csignal>
#include </home/indicatic-e1/Desktop/INDIcode/indigo/indigo_drivers/ccd_qhy/bin_externals/qhyccd/include/qhyccd.h>

#define VERSION 1.00

//This program automates the QHYCCD to capture data each x offset times for the five different filters until it is terminated by the crontab.

volatile sig_atomic_t signalRecu = 0; //Detect the kill signal from crontab, to terminate the processus properly.

void signalHandler(int signum) {
    signalRecu = 1;
    std::cout << "Signal received : " << signum << std::endl;
}

// void shutdownCamera()
// {
//     // Apagar la alimentación
//     char shutdownCmd[256];
//     sprintf(shutdownCmd, "/home/indicatic-e1/Desktop/app/camera_on_off.sh off qhy");
//     system(shutdownCmd);
//     IDLog("QHY power turned off\n");
// }

int main(int, char **)
{

    int USB_TRAFFIC = 10;
    int CHIP_GAIN = 10;
    int CHIP_OFFSET = 140;
    int EXPOSURE_TIME = 10000000 ; //Exposure time in microseconds
    int camBinX = 1;
    int camBinY = 1;

    double chipWidthMM;
    double chipHeightMM;
    double pixelWidthUM;
    double pixelHeightUM;

    unsigned int roiStartX;
    unsigned int roiStartY;
    unsigned int roiSizeX;
    unsigned int roiSizeY;

    unsigned int overscanStartX;
    unsigned int overscanStartY;
    unsigned int overscanSizeX;
    unsigned int overscanSizeY;

    unsigned int effectiveStartX;
    unsigned int effectiveStartY;
    unsigned int effectiveSizeX;
    unsigned int effectiveSizeY;

    unsigned int maxImageSizeX;
    unsigned int maxImageSizeY;
    unsigned int bpp;
    unsigned int channels;

    unsigned char *pImgData = 0;

    char SelectedPos = 0; // Variable that select the filter to use
    int Offset = 45; //Time between each filter changing
    int k = 0;
    char filePath[256]; //Contains the path where captures are saved
    double TargetedTemp = -5.0; // Temperature wanted for the camera to take captures
    double Tempoffset = 0.00;
    int ReguTemp = 7;
    int ReadTemp = -1; // Boolean to know if it i possible to read the temperature
    double ActualTemp = 0.0; // Actual temperature of the camera
    double elapsedTime = 0.0;
    int elapsedTimeSeconds = 0;
    //double voltage = 12.0; //Voltage of the camera
    double maxPower = 72.0; //Max power
    double voltage, temperature;

    std::signal(SIGUSR1, signalHandler);

        printf("QHY Test CCD using SingleFrameMode, Version: %.2f\n", VERSION);

        // init SDK
        int retVal = InitQHYCCDResource();
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("SDK resources initialized.\n");
        }
        else
        {
            printf("Cannot initialize SDK resources, error: %d\n", retVal);
            return 1;
        }

        // scan cameras
        int camCount = ScanQHYCCD();
        if (camCount > 0)
        {
            printf("Number of QHYCCD cameras found: %d \n", camCount);
        }
        else
        {
            printf("No QHYCCD camera found, please check USB or power.\n");
            return 1;
        }

        // iterate over all attached cameras
        bool camFound = false;
        char camId[32];

        for (int i = 0; i < camCount; i++)
        {
            retVal = GetQHYCCDId(i, camId);
            if (QHYCCD_SUCCESS == retVal)
            {
                printf("Application connected to the following camera from the list: Index: %d,  cameraID = %s\n", (i + 1), camId);
                camFound = true;
                break;
            }
        }

        if (!camFound)
        {
            printf("The detected camera is not QHYCCD or other error.\n");
            // release sdk resources
            retVal = ReleaseQHYCCDResource();
            if (QHYCCD_SUCCESS == retVal)
            {
                printf("SDK resources released.\n");
            }
            else
            {
                printf("Cannot release SDK resources, error %d.\n", retVal);
            }
            return 1;
        }

        // open camera
        qhyccd_handle *pCamHandle = OpenQHYCCD(camId);
        if (pCamHandle != nullptr)
        {
            printf("Open QHYCCD success.\n");
        }
        else
        {
            printf("Open QHYCCD failure.\n");
            return 1;
        }

        // set single frame mode
        int mode = 0;
        retVal = SetQHYCCDStreamMode(pCamHandle, mode);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("SetQHYCCDStreamMode set to: %d, success.\n", mode);
        }
        else
        {
            printf("SetQHYCCDStreamMode: %d failure, error: %d\n", mode, retVal);
            return 1;
        }

        // initialize camera
        retVal = InitQHYCCD(pCamHandle);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("InitQHYCCD success.\n");
        }
        else
        {
            printf("InitQHYCCD faililure, error: %d\n", retVal);
            return 1;
        }

        voltage = GetQHYCCDParam(pCamHandle, CONTROL_AMPV);
        std::cout << "Tension actuelle : " << voltage << "V" << std::endl;

        // Check if filter wheel is connected
        retVal = IsQHYCCDCFWPlugged(pCamHandle);
        if (retVal == QHYCCD_SUCCESS)
        {
            printf("Filter wheel is connected.\n");
            int filterCount = GetQHYCCDParam(pCamHandle, CONTROL_CFWSLOTSNUM);
            if (filterCount > 0 && filterCount <= 16)
            {
                printf("Filter wheel has %d positions.\n", filterCount);

                char currentPos[64] = {0};
                if (GetQHYCCDCFWStatus(pCamHandle, currentPos) == QHYCCD_SUCCESS)
                {
                    int position = strtol(currentPos, nullptr, 16) + 1;
                    printf("Current filter position: %d\n", position);
                    if (position != 0 && k == 0)
                    {      
                        char targetPos[1] = {'0'};
                        SendOrder2QHYCCDCFW(pCamHandle, targetPos, 1);
                        printf("Filter posiotioned at position 0\n");
                        k++;
                    }
                    
                }
            }
            else
            {
                printf("Filter wheel reports invalid number of positions: %d\n", filterCount);
            }
        }
        else
        {
            printf("No filter wheel detected.\n");
        }

        //Set the camera temperature to TargetedTemp degrees
        if (pCamHandle != NULL) {
            uint32_t GetTemp = ControlQHYCCDTemp(pCamHandle, TargetedTemp);
            //uint32_t GetTemp = SetQHYCCDParam(pCamHandle,CONTROL_CURTEMP, TargetedTemp);
            if (GetTemp == QHYCCD_SUCCESS) {
                printf("The temperature has been settled to %.2f °C.\n", TargetedTemp);
            } else {
                printf("Fail to set the temperature.\n");
            }
        } else {
            printf("Fail to connect the camera.\n");
        }

        uint32_t status = SetQHYCCDParam(pCamHandle, CONTROL_COOLER, 1.0);
        if (status == QHYCCD_SUCCESS) {
            printf("Cooler activated.\n");
        } else {
            printf("Fail to activate cooler.\n");
        }

            if (ReadTemp == QHYCCD_SUCCESS)
            {
                    if (ReadTemp == QHYCCD_SUCCESS) {
                        printf("Actual temperature : %.2f°C\n", ActualTemp);
                    } else {
                        printf("Could not read the temperature.\n");
                    }
                    sleep(2);
            } else {
                printf("The temperature is not available");
            }

            double min, max, step;
            uint32_t res = GetQHYCCDParamMinMaxStep(pCamHandle, (CONTROL_ID)10, &min, &max, &step);
            if (res == QHYCCD_SUCCESS) {
                printf("Température min: %.2f°C, max: %.2f°C, step: %.2f°C\n", min, max, step);
            }








        //Wait Offset time and change filter
        sleep(Offset);
        char targetPos[2] = {static_cast<char>(SelectedPos + '0'), '\0'};
        printf("This is the targetPos value: %s\n", targetPos);
        retVal = SendOrder2QHYCCDCFW(pCamHandle, &targetPos[0], 1);
        if (retVal == QHYCCD_SUCCESS)
        {
            printf("Filter wheel moved to position %d successfully.\n", SelectedPos);
        }
        else
        {
            printf("Failed to move filter wheel to position %d. Error code: %d\n",SelectedPos , retVal);
        }

        sleep(10);

        // get overscan area
        retVal = GetQHYCCDOverScanArea(pCamHandle, &overscanStartX, &overscanStartY, &overscanSizeX, &overscanSizeY);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("GetQHYCCDOverScanArea:\n");
            printf("Overscan Area startX x startY : %d x %d\n", overscanStartX, overscanStartY);
            printf("Overscan Area sizeX  x sizeY  : %d x %d\n", overscanSizeX, overscanSizeY);
        }
        else
        {
            printf("GetQHYCCDOverScanArea failure, error: %d\n", retVal);
            return 1;
        }

        // get effective area
        retVal = GetQHYCCDOverScanArea(pCamHandle, &effectiveStartX, &effectiveStartY, &effectiveSizeX, &effectiveSizeY);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("GetQHYCCDEffectiveArea:\n");
            printf("Effective Area startX x startY: %d x %d\n", effectiveStartX, effectiveStartY);
            printf("Effective Area sizeX  x sizeY : %d x %d\n", effectiveSizeX, effectiveSizeY);
        }
        else
        {
            printf("GetQHYCCDOverScanArea failure, error: %d\n", retVal);
            return 1;
        }

        // get chip info
        retVal = GetQHYCCDChipInfo(pCamHandle, &chipWidthMM, &chipHeightMM, &maxImageSizeX, &maxImageSizeY, &pixelWidthUM,
                                &pixelHeightUM, &bpp);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("GetQHYCCDChipInfo:\n");
            printf("Effective Area startX x startY: %d x %d\n", effectiveStartX, effectiveStartY);
            printf("Chip  size width x height     : %.3f x %.3f [mm]\n", chipWidthMM, chipHeightMM);
            printf("Pixel size width x height     : %.3f x %.3f [um]\n", pixelWidthUM, pixelHeightUM);
            printf("Image size width x height     : %d x %d\n", maxImageSizeX, maxImageSizeY);
        }
        else
        {
            printf("GetQHYCCDChipInfo failure, error: %d\n", retVal);
            return 1;
        }

        // set ROI
        roiStartX = 0;
        roiStartY = 0;
        roiSizeX = maxImageSizeX;
        roiSizeY = maxImageSizeY;

        // check color camera
        retVal = IsQHYCCDControlAvailable(pCamHandle, CAM_COLOR);
        if (retVal == BAYER_GB || retVal == BAYER_GR || retVal == BAYER_BG || retVal == BAYER_RG)
        {
            printf("This is a color camera.\n");
            SetQHYCCDDebayerOnOff(pCamHandle, true);
            SetQHYCCDParam(pCamHandle, CONTROL_WBR, 20);
            SetQHYCCDParam(pCamHandle, CONTROL_WBG, 20);
            SetQHYCCDParam(pCamHandle, CONTROL_WBB, 20);
        }
        else
        {
            printf("This is a mono camera.\n");
        }

        // check traffic
        retVal = IsQHYCCDControlAvailable(pCamHandle, CONTROL_USBTRAFFIC);
        if (QHYCCD_SUCCESS == retVal)
        {
            retVal = SetQHYCCDParam(pCamHandle, CONTROL_USBTRAFFIC, USB_TRAFFIC);
            if (QHYCCD_SUCCESS == retVal)
            {
                printf("SetQHYCCDParam CONTROL_USBTRAFFIC set to: %d, success.\n", USB_TRAFFIC);
            }
            else
            {
                printf("SetQHYCCDParam CONTROL_USBTRAFFIC failure, error: %d\n", retVal);
                getchar();
                return 1;
            }
        }

        // check gain
        retVal = IsQHYCCDControlAvailable(pCamHandle, CONTROL_GAIN);
        if (QHYCCD_SUCCESS == retVal)
        {
            retVal = SetQHYCCDParam(pCamHandle, CONTROL_GAIN, CHIP_GAIN);
            if (retVal == QHYCCD_SUCCESS)
            {
                printf("SetQHYCCDParam CONTROL_GAIN set to: %d, success\n", CHIP_GAIN);
            }
            else
            {
                printf("SetQHYCCDParam CONTROL_GAIN failure, error: %d\n", retVal);
                getchar();
                return 1;
            }
        }

        // check offset
        retVal = IsQHYCCDControlAvailable(pCamHandle, CONTROL_OFFSET);
        if (QHYCCD_SUCCESS == retVal)
        {
            retVal = SetQHYCCDParam(pCamHandle, CONTROL_OFFSET, CHIP_OFFSET); 
            if (QHYCCD_SUCCESS == retVal)
            {
                printf("SetQHYCCDParam CONTROL_GAIN set to: %d, success.\n", CHIP_OFFSET);
            }
            else
            {
                printf("SetQHYCCDParam CONTROL_GAIN failed.\n");
                getchar();
                return 1;
            }
        }

        /*
        // check read mode in QHY42
        uint32_t currentReadMode = 0;
        char *modeName = (char *)malloc((200) * sizeof(char));;
        retVal = GetQHYCCDReadMode(pCamHandle, &currentReadMode);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("Default read mode: %d \n", currentReadMode);
            retVal = GetQHYCCDReadModeName(pCamHandle, currentReadMode, modeName);
            if (QHYCCD_SUCCESS == retVal)
            {
                printf("Default read mode name %s \n", modeName);
            }
            else
            {
                printf("Error reading mode name \n");
                getchar();
                return 1;
            }

            // Set read modes and read resolution for each one
            uint32_t readModes = 0;
            uint32_t imageRMw, imageRMh;
            uint32_t i = 0;
            retVal = GetQHYCCDNumberOfReadModes(pCamHandle, &readModes);
            for(i = 0; i < readModes; i++)
            {
                // Set read mode and get resolution
                retVal = SetQHYCCDReadMode(pCamHandle, i);
                if (QHYCCD_SUCCESS == retVal)
                {
                    // Get resolution
                    retVal = GetQHYCCDReadModeName(pCamHandle, i, modeName);
                    if (QHYCCD_SUCCESS == retVal)
                    {
                        printf("Read mode name %s \n", modeName);
                    }
                    else
                    {
                        printf("Error reading mode name \n");
                        getchar();
                        return 1;
                    }
                    retVal = GetQHYCCDReadModeResolution(pCamHandle, i, &imageRMw, &imageRMh);
                    printf("GetQHYCCDChipInfo in this ReadMode: imageW: %d imageH: %d \n", imageRMw, imageRMh);
                }
            }

        }

        */


        // set exposure time
        retVal = SetQHYCCDParam(pCamHandle, CONTROL_EXPOSURE, EXPOSURE_TIME);
        printf("SetQHYCCDParam CONTROL_EXPOSURE set to: %d, success.\n", EXPOSURE_TIME);
        if (QHYCCD_SUCCESS == retVal)
        {
        }
        else
        {
            printf("SetQHYCCDParam CONTROL_EXPOSURE failure, error: %d\n", retVal);
            getchar();
            return 1;
        }

        // set image resolution
        retVal = SetQHYCCDResolution(pCamHandle, roiStartX, roiStartY, roiSizeX, roiSizeY);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("SetQHYCCDResolution roiStartX x roiStartY: %d x %d\n", roiStartX, roiStartY);
            printf("SetQHYCCDResolution roiSizeX  x roiSizeY : %d x %d\n", roiSizeX, roiSizeY);
        }
        else
        {
            printf("SetQHYCCDResolution failure, error: %d\n", retVal);
            return 1;
        }

        // set binning mode
        retVal = SetQHYCCDBinMode(pCamHandle, camBinX, camBinY);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("SetQHYCCDBinMode set to: binX: %d, binY: %d, success.\n", camBinX, camBinY);
        }
        else
        {
            printf("SetQHYCCDBinMode failure, error: %d\n", retVal);
            return 1;
        }

        // set bit resolution
        retVal = IsQHYCCDControlAvailable(pCamHandle, CONTROL_TRANSFERBIT);
        if (QHYCCD_SUCCESS == retVal)
        {
            retVal = SetQHYCCDBitsMode(pCamHandle, 16);
            if (QHYCCD_SUCCESS == retVal)
            {
                printf("SetQHYCCDParam CONTROL_GAIN set to: %d, success.\n", CONTROL_TRANSFERBIT);
            }
            else
            {
                printf("SetQHYCCDParam CONTROL_GAIN failure, error: %d\n", retVal);
                getchar();
                return 1;
            }
        }

       while (true) {
            temperature = GetQHYCCDParam(pCamHandle, CONTROL_CURTEMP);
            std::cout << "Actual temperature : " << temperature << "°C" << std::endl;

            if (temperature > 0.00) {
                std::cout << "Activation du refroidisseur (PWM=" << 200 << ")" << std::endl;
                SetQHYCCDParam(pCamHandle, CONTROL_MANULPWM, 200);
            } 
            else if (temperature > -5.00) {
                std::cout << "Activation du refroidisseur (PWM=" << 225 << ")" << std::endl;
                SetQHYCCDParam(pCamHandle, CONTROL_MANULPWM, 225);
            } 
            else if (temperature > TargetedTemp) {
                std::cout << "Activation du refroidisseur (PWM=" << 255 << ")" << std::endl;
                SetQHYCCDParam(pCamHandle, CONTROL_MANULPWM, 255);
            } 
            else {
                break;
            }

            sleep(5);
        }
        SetQHYCCDParam(pCamHandle, CONTROL_COOLER, TargetedTemp);

        printf("QHYCCD is operational \n");
        while (true)
        {
            
            if (signalRecu)
            {
                printf("Signal received to terminated");
                //Wait Offset time and change filter
                char targetPos[2] = {static_cast<char>('0'), '\0'};
                printf("This is the targetPos value: %s\n", targetPos);
                retVal = SendOrder2QHYCCDCFW(pCamHandle, &targetPos[0], 1);
                if (retVal == QHYCCD_SUCCESS)
                {
                    printf("Filter wheel moved to position %s successfully to terminate.\n", targetPos);
                }
                else
                {
                    printf("Failed to move filter wheel to position %s to terminate. Error code: %d\n",targetPos , retVal);
                }
                goto Terminated;
            }
            
            if (SelectedPos == 5) //Clear logs for each cycle terminated
            {
                SelectedPos = 0;
                int ret = system("/home/indicatic-e1/Desktop/AutoRun/QHYCCDLog.sh");
                if (ret != 0) {
                    std::cerr << "Erreur lors de l'exécution du script QHYCCDLog.sh. Code de retour : " << ret << std::endl;
                } else {
                    printf("Clean logs");
                }

            }

            //Wait Offset time and change filter
            char targetPos[2] = {static_cast<char>(SelectedPos + '0'), '\0'};
            printf("This is the targetPos value: %s\n", targetPos);
            retVal = SendOrder2QHYCCDCFW(pCamHandle, &targetPos[0], 1);
            if (retVal == QHYCCD_SUCCESS)
            {
                printf("Filter wheel moved to position %d successfully.\n", SelectedPos);
            }
            else
            {
                printf("Failed to move filter wheel to position %d. Error code: %d\n",SelectedPos , retVal);
            }

            //std::cout << "Time spend after back : " << elapsedTime << " ms" << std::endl;
            //std::cout << "Difference time after function betwen offset and calculated seconds : " << Offset - elapsedTimeSeconds << " s" << std::endl;

            sleep((Offset-elapsedTimeSeconds)-1);

            // single frame
            //printf("ExpQHYCCDSingleFrame(pCamHandle) - start...\n");
            // --- MQTT: Notificar inicio de captura ---
            char monitorCmd[512];
            sprintf(monitorCmd, "/home/indicatic-e1/Desktop/app/qhy_monitor.sh capture_start %d  >> /tmp/qhyMQTT.txt 2>&1", EXPOSURE_TIME);
            system(monitorCmd);
            retVal = ExpQHYCCDSingleFrame(pCamHandle);
            //printf("ExpQHYCCDSingleFrame(pCamHandle) - end...\n");
            if (QHYCCD_ERROR != (uint32_t) retVal)
            {
                printf("ExpQHYCCDSingleFrame success (%d).\n", retVal);
                if (QHYCCD_READ_DIRECTLY != retVal)
                {
                    sleep(1);
                }
            }
            else
            {
                printf("ExpQHYCCDSingleFrame failure, error: %d\n", retVal);
                return 1;
            }
            
            //Beginning to get time
            auto start = std::chrono::high_resolution_clock::now();

            // get requested memory lenght
            uint32_t length = GetQHYCCDMemLength(pCamHandle);

            if (length > 0)
            {
                pImgData = new unsigned char[length];
                memset(pImgData, 0, length);
                printf("Allocated memory for frame: %d [uchar].\n", length);
            }
            else
            {
                printf("Cannot allocate memory for frame.\n");
                return 1;
            }

            time_t timestamp = time(0);
            char dateTime[128];
            strncpy(dateTime, ctime(&timestamp), sizeof(dateTime) - 1);
            dateTime[sizeof(dateTime) - 1] = '\0';
            dateTime[strcspn(dateTime, "\n")] = '\0';

            // get single frame
            retVal = GetQHYCCDSingleFrame(pCamHandle, &roiSizeX, &roiSizeY, &bpp, &channels, pImgData);
            if (QHYCCD_SUCCESS == retVal)
            {
                printf("GetQHYCCDSingleFrame: %d x %d, bpp: %d, channels: %d, success.\n", roiSizeX, roiSizeY, bpp, channels);

                sprintf(filePath, "/home/indicatic-e1/Desktop/code/RawQHYImg/image%s_%dus_CFW%d.raw", dateTime,EXPOSURE_TIME, SelectedPos + 1); //Writing captured data into path.
                for (size_t i = 0; i < strlen(filePath); i++) {
                    if (filePath[i] == ':') {
                        filePath[i] = '_';
                    }
                }
                FILE *file = fopen(filePath, "wb");
                if (file != NULL)
                {
                    fwrite(pImgData, 1, roiSizeX * roiSizeY * (bpp / 8) * channels, file);
                    fclose(file);
                    printf("Capture saved in => /home/indicatic-e1/Desktop/code/RawQHYImg/image_%s_%dus_CFW%d.raw\n", dateTime,EXPOSURE_TIME,SelectedPos+1);
                    
                    time_t timestamp = time(0);
                    struct tm *tm_info = localtime(&timestamp);
                    char timeStr[16];
                    strftime(timeStr, sizeof(timeStr), "%H:%M:%S", tm_info);
                    
                    const char* filename = strrchr(filePath, '/');
                    filename = filename ? filename + 1 : filePath;

                    // --- MQTT: Notificar captura completa ---
                    sprintf(monitorCmd, "/home/indicatic-e1/Desktop/app/qhy_monitor.sh capture_complete %s \"%s\" %.2f >> /tmp/qhyMQTT.txt 2>&1", filename, timeStr, temperature);
                    system(monitorCmd);
                }
                else
                {
                    printf("Fail to save the file.\n");
                }
            }
            else
            {
                printf("GetQHYCCDSingleFrame failure, error: %d\n", retVal);
            }

        
            delete [] pImgData;
            memset(filePath, 0, sizeof(filePath)); 
            filePath[0] = '\0';

            SelectedPos++; //Position of filter
            //End to get time
            auto end = std::chrono::high_resolution_clock::now();
            elapsedTime = std::chrono::duration<double, std::milli>(end - start).count();

            //std::cout << "Times spend before back: " << elapsedTime << " ms" << std::endl;
            elapsedTimeSeconds = elapsedTime/1000;
            //std::cout << "Time spend before back in seconds : " << elapsedTimeSeconds << " " << std::endl;
            printf("QHYCCD send capture.\n");

            double currentPWM = GetQHYCCDParam(pCamHandle, CONTROL_CURPWM);
            if (currentPWM > 0.0) {
                printf("Current used for the cooling : %.2f%%\n", currentPWM);
            } else {
                printf("Impossible to ge the actual PWM.\n");
            }

            //Treatment of the voltage, current, power

            /*
            voltage = GetQHYCCDParam(pCamHandle, CONTROL_AMPV);
            std::cout << "Actual voltage : " << voltage << "V" << std::endl;

            double powerConsumed = (currentPWM / 100.0) * maxPower;
            double currentConsumed = powerConsumed / voltage;

            printf("Power consumption : %.2f W\n", powerConsumed);
            printf("Current consumption : %.2f A\n", currentConsumed);

            */

            //Check the CCD temperature
            temperature = GetQHYCCDParam(pCamHandle, CONTROL_CURTEMP);
            std::cout << "Actual temperature : " << temperature << "°C" << std::endl;
            // --- MQTT: Notificar actualización de temperatura ---
            sprintf(monitorCmd, "/home/indicatic-e1/Desktop/app/qhy_monitor.sh temperature_update %.2f >> /tmp/qhyMQTT.txt 2>&1", temperature);
            system(monitorCmd);

            if (temperature > -15 && temperature < -25) {
                std::string arg1 = "\"Temperature problem QHYCCD\"";
                std::string arg2 = "\"The QHYCCD has an actual temperature of " + std::to_string(temperature) + " °C, but should be around -10 °C.\"";
                
                std::string command = "/home/indicatic-e1/Desktop/AutoRun/SendMail.sh " + arg1 + " " + arg2; //Send an email if an error occur
                
                system(command.c_str());
            }
        }

        Terminated:

        retVal = CancelQHYCCDExposingAndReadout(pCamHandle);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("CancelQHYCCDExposingAndReadout success.\n");
        }
        else
        {
            printf("CancelQHYCCDExposingAndReadout failure, error: %d\n", retVal);
            int ret = system("/home/indicatic-e1/Desktop/AutoRun/QHYCCDLog.sh");
            if (ret != 0) {
                std::cerr << "Erreur lors de l'exécution du script QHYCCDLog.sh. Code de retour : " << ret << std::endl;
            }
            return 1;
        }

        // close camera handle
        retVal = CloseQHYCCD(pCamHandle);
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("Close QHYCCD success.\n");
        }
        else
        {
            printf("Close QHYCCD failure, error: %d\n", retVal);
        }

        // release sdk resources
        retVal = ReleaseQHYCCDResource();
        if (QHYCCD_SUCCESS == retVal)
        {
            printf("SDK resources released.\n");
        }
        else
        {
            printf("Cannot release SDK resources, error %d.\n", retVal);
            int ret = system("/home/indicatic-e1/Desktop/AutoRun/QHYCCDLog.sh");
            if (ret != 0) {
                std::cerr << "Erreur lors de l'exécution du script QHYCCDLog.sh. Code de retour : " << ret << std::endl;
            }
            return 1;
        }  

        // shutdownCamera();

        int ret = system("/home/indicatic-e1/Desktop/AutoRun/QHYCCDLog.sh");
        if (ret != 0) {
            std::cerr << "Erreur lors de l'exécution du script QHYCCDLog.sh. Code de retour : " << ret << std::endl;
        }

        return 0;
}