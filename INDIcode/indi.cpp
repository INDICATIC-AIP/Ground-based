#include <libindi/baseclient.h>
#include <libindi/basedevice.h>
#include <iostream>
#include <fstream>
#include <unistd.h>
#include <cstdlib>
#include <cstring>
#include <signal.h>

//Alpy script, programmed to capture data each Offset time with ExpositionTime as exposition duration.

double ExpositionTime = 10.0; // Time of expostition     0.1 segundos 
int Offset = 30; // Time between each capture
double TargetedTemp = 5.0; // Temperature targeted to reach before beginning to capture data
double AlertTemp = 21.0; // Temperature threshold for email alert and camera shutdown
double ShutdownTemp = 21.0; // Temperature to shutdown camera
int WarmupMinutes = 1; // Minutes to wait for initial cooling before monitoring temperature alerts
bool alertSent = false; // Flag to prevent multiple alerts
double lastEmailTemp = -100.0; // Last temperature when email was sent
double emailInterval = 5.0; // Send email every 5 degrees

// Variable global para control de terminación
volatile sig_atomic_t shouldTerminate = 0;

// Manejador de señales
void signalHandler(int /*signal*/) {
    // Evitar llamadas no reentrantes dentro de un signal handler.
    shouldTerminate = 1;
}

class MyClient : public INDI::BaseClient
{
public:
    MyClient();
    ~MyClient() = default;

    void executeProcess();
    void setTemperature(double value);
    void takeExposure(double seconds);
    void displayTelescopeProperties();
    void sendTemperatureAlert(double temperature);
    void shutdownCamera();

protected:
    void newMessage(INDI::BaseDevice baseDevice, int messageID) override;

private:
    INDI::BaseDevice mSxCCDDevice;
    double mCurrentTemp = 0.0; // <-- Agregado para guardar la temperatura actual
    time_t mStartTime = 0; // <-- Tiempo de inicio para controlar el período de calentamiento
    bool mWarmupComplete = false; // <-- Flag para indicar si el período de calentamiento ha terminado
};

MyClient::MyClient()
{
    
}

void MyClient::sendTemperatureAlert(double temperature)
{
    char emailCmd[512];
    char message[256];
    char subject[128];
    
    // Crear el mensaje
    sprintf(message, 
        "ALERTA DE TEMPERATURA ALPY\n\n"
        "La temperatura del ALPY ha alcanzado %.2f°C.\n"
        "El funcionamiento óptimo es a -10°C.\n"
        "Se requiere atención inmediata.", 
        temperature);
    
    // Crear el asunto
    sprintf(subject, "ALERTA: Temperatura ALPY Critica %.2f°C", temperature);
    
    // Llamar al script SendMail.sh
    sprintf(emailCmd, "/home/indicatice2/Desktop/AutoRun/SendMail.sh \"%s\" \"%s\"", subject, message);
    
    system(emailCmd);
    IDLog("Email alert sent for temperature: %.2f°C\n", temperature);
}


void MyClient::shutdownCamera()
{
    // 1. Primero desconectar el dispositivo INDI si está conectado
    if (mSxCCDDevice.isConnected()) {
        IDLog("Disconnecting ALPY from INDI server before shutdown...\n");
        disconnectDevice("SX CCD SX-825");
        sleep(2); // Esperar a que se desconecte completamente
    }
    
    // 2. Luego apagar la alimentación
    char shutdownCmd[256];
    sprintf(shutdownCmd, "/home/indicatice2/Desktop/app/camera_on_off.sh off alpy");
    system(shutdownCmd);
    IDLog("ALPY power turned off\n");
}

void MyClient::executeProcess()
{
    time_t lastCaptureTime = 0;
    
    // Inicializar tiempo de inicio para el período de calentamiento
    mStartTime = time(nullptr);
    IDLog("Starting warmup period of %d minutes. Temperature alerts will be disabled during this time.\n", WarmupMinutes);

    // Configurar manejador de señales
    signal(SIGUSR1, signalHandler);
    IDLog("Signal handler configured. Program will terminate on SIGUSR1 signal.\n");

    while (!shouldTerminate)
    {
        if (ExpositionTime > Offset - 20)
        {
            printf("The offset must be greater than the exposition time");
        }
        
        bool stopWatchingTemperature = false;

        watchDevice("SX CCD SX-825", [this, &stopWatchingTemperature, &lastCaptureTime](INDI::BaseDevice device)
        {
            mSxCCDDevice = device;
        
            device.watchProperty("CONNECTION", [this](INDI::Property)
            {
                IDLog("connection to INDI pilot...\n");
                connectDevice("SX CCD SX-825");
            }, INDI::BaseDevice::WATCH_NEW);

            device.watchProperty("CCD_TEMPERATURE", [this, &stopWatchingTemperature, &lastCaptureTime](INDI::PropertyNumber property)
            {
                if (mSxCCDDevice.isConnected())
                {
                    IDLog("CCD connected.\n");
                    setTemperature(TargetedTemp);
                }

                property.onUpdate([property, this, &stopWatchingTemperature, &lastCaptureTime]()
                {
                    if (stopWatchingTemperature) return; //If there is an exposition, then stop watching the temperature obtained

                    double currentTemp = property[0].getValue(); //Get the temperature
                    mCurrentTemp = currentTemp; // <-- Guardar la temperatura actual
                    IDLog("Received temperature : %g C\n", currentTemp);
                    
                    // Verificar si el período de calentamiento ha terminado
                    time_t currentTime = time(nullptr);
                    int elapsedMinutes = (currentTime - mStartTime) / 60;
                    
                    if (!mWarmupComplete && elapsedMinutes >= WarmupMinutes)
                    {
                        mWarmupComplete = true;
                        IDLog("Warmup period completed (%d minutes). Temperature monitoring and alerts are now active.\n", WarmupMinutes);
                    }
                    
                    // Solo verificar alertas de temperatura después del período de calentamiento
                    if (mWarmupComplete)
                    {
                        // Verificar si la temperatura es crítica (21°C) y apagar cámara
                        // if (currentTemp >= ShutdownTemp)
                        // {
                        //     IDLog("CRITICAL TEMPERATURE: %.2f°C - SHUTTING DOWN CAMERA\n", currentTemp);
                        //     shutdownCamera();
                        //     shouldTerminate = true; // Terminar el programa
                        //     return; // Salir del loop de temperatura
                        // }
                        
                        // Enviar correo cada 5°C desde 0°C
                        if (currentTemp >= 0.0)
                        {
                            int tempStep = static_cast<int>(currentTemp / emailInterval);
                            double tempThreshold = tempStep * emailInterval;
                            
                            if (currentTemp >= tempThreshold && tempThreshold > lastEmailTemp)
                            {
                                sendTemperatureAlert(currentTemp);
                                lastEmailTemp = tempThreshold;
                                IDLog("Temperature alert sent at %.2f°C (threshold: %.1f°C)\n", currentTemp, tempThreshold);
                            }
                        }
                        else
                        {
                            // Reset lastEmailTemp when temperature goes below 0°C
                            lastEmailTemp = -100.0;
                        }
                    }
                    else
                    {
                        // Durante el período de calentamiento, mostrar progreso
                        IDLog("Warmup in progress: %d/%d minutes completed. Temperature: %.2f°C\n", 
                              elapsedMinutes, WarmupMinutes, currentTemp);
                    }
                    
                    // Enviar temperatura por MQTT
                    char tempCmd[256];
                    sprintf(tempCmd, "/home/indicatice2/Desktop/app/alpy_monitor.sh temperature_update %.2f >> /tmp/alpyMQTT.txt 2>&1", currentTemp);
                    system(tempCmd);

                    // Solo comenzar capturas después del período de calentamiento
                    if (mWarmupComplete && currentTemp <= TargetedTemp && currentTime - lastCaptureTime >= Offset)
                    {
                        IDLog("CCD temperature reached!\n");
                        stopWatchingTemperature = true;
                        lastCaptureTime = currentTime;

                        // Enviar inicio de captura por MQTT
                        char startCmd[256];
                        sprintf(startCmd, "/home/indicatice2/Desktop/app/alpy_monitor.sh capture_start %g >> /tmp/alpyMQTT.txt 2>&1", ExpositionTime);
                        system(startCmd);

                        takeExposure(ExpositionTime); //Exposure of ExpositionTime seconds
                        IDLog("Exposition of %g has been executed\n",ExpositionTime);

                        stopWatchingTemperature = false;
                    }
                    else if (!mWarmupComplete)
                    {
                        IDLog("Waiting for warmup period to complete before starting captures. Current temp: %.2f°C, Target: %.2f°C\n", 
                              currentTemp, TargetedTemp);
                    }
                });
            }, INDI::BaseDevice::WATCH_NEW);

            device.watchProperty("CCD1", [this](INDI::PropertyBlob property)
            {
                std::ofstream myfile;

                char filePath[256];
                time_t timestamp = time(0);
                char dateTime[128];
                strncpy(dateTime, ctime(&timestamp), sizeof(dateTime) - 1);
                dateTime[sizeof(dateTime) - 1] = '\0';
                dateTime[strcspn(dateTime, "\n")] = '\0';
                size_t length = strlen(dateTime);

                for (size_t i = 0; i < length; i++) {
                    if (dateTime[i] == ' ') {
                        dateTime[i] = '_';
                    }
                }

                snprintf(filePath, sizeof(filePath), "/home/indicatice2/Desktop/ASTRODEVICES/ALPYFILE/ccd_sx_825_%gsecondes_%s.fits", ExpositionTime, dateTime); //Path where are saved the capture.
                const char* filename = strrchr(filePath, '/');
                filename = filename ? filename + 1 : filePath;
                char captureCompleteCmd[512];
                // use mCurrentTemp (stored when temperature updates arrived)
                snprintf(captureCompleteCmd, sizeof(captureCompleteCmd), "/home/indicatice2/Desktop/app/alpy_monitor.sh capture_complete %s \"%s\" %.2f >> /tmp/alpyMQTT.txt 2>&1", filename, dateTime, mCurrentTemp);
                system(captureCompleteCmd);

                for (size_t i = 0; i < strlen(filePath); i++) {
                    if (filePath[i] == ':') {
                        filePath[i] = '_';
                    }
                }

                myfile.open(filePath, std::ios::out | std::ios::binary);
                myfile.write(static_cast<char *>(property[0].getBlob()), property[0].getBlobLen());
                myfile.close();

                IDLog("Image saved in %s\n", filePath);
                
            }, INDI::BaseDevice::WATCH_UPDATE);
        });

        sleep(5);
        //IDLog("New iteration\n");
    }

    // Apagar ALPY al terminar
    IDLog("Program terminating. Shutting down ALPY...\n");
    // shutdownCamera();
    IDLog("ALPY shutdown complete. Program finished.\n");
}

void MyClient::setTemperature(double value)
{
    INDI::PropertyNumber ccdTemperature = mSxCCDDevice.getProperty("CCD_TEMPERATURE");

    if (!ccdTemperature.isValid())
    {
        IDLog("Error : cannot find temperature information...\n");
        return;
    }

    IDLog("Temperature settled at %g C.\n", value);
    ccdTemperature[0].setValue(value);
    sendNewProperty(ccdTemperature);
}

void MyClient::takeExposure(double seconds)
{
    INDI::PropertyNumber ccdExposure = mSxCCDDevice.getProperty("CCD_EXPOSURE");

    if (!ccdExposure.isValid())
    {
        IDLog("Error : icannot find exposure information...\n");
        return;
    }

    IDLog("Taking exposition of %g seconds.\n", seconds);
    ccdExposure[0].setValue(seconds);
    sendNewProperty(ccdExposure);
}

void MyClient::newMessage(INDI::BaseDevice baseDevice, int messageID)
{
    if (!baseDevice.isDeviceNameMatch("SX CCD SX-825"))
        return;

    IDLog("Message from INDI server :\n"
          "    %s\n\n",
          baseDevice.messageQueue(messageID).c_str());
}

int main(int, char *[])
{
    MyClient myClient;
    myClient.setServer("localhost", 7624);

    if (!myClient.connectServer())
    {
        std::cerr << "Failed to connect to INDI server.\n";
        return 1;
    }

    myClient.setBLOBMode(B_ALSO, "SX CCD SX-825", nullptr);
    myClient.enableDirectBlobAccess("SX CCD SX-825", nullptr);

    myClient.executeProcess();

    return 0;
}