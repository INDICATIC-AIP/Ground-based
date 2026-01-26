#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "alpy.h"
#include "unistd.h"

#define DIRECTORY_ALPY "/home/indicatic-e1/Desktop/ASTRODEVICES/ALPYFILE"
#define DIRECTORY_QHY "/home/indicatic-e1/Desktop/ASTRODEVICES/QHYCCDFILE"
#define DIRECTORY_NIKON "/home/indicatic-e1/Desktop/ASTRODEVICES/NIKONFILE"
#define DIRECTORY_TESS "/home/indicatic-e1/Desktop/ASTRODEVICES/TESSFILE"
#define POSMAIN_PATH "/home/indicatic-e1/Desktop/code/Posmain.txt"

//Traverse all directories of each device and check for files that need to be sent.

void processDirectory(const char *directory, char position, const char *script) {
    ChangeDirectory(directory);
    int fileCount = FilesNbALpy();

    if (fileCount > 0) {
        FILE *file = fopen(POSMAIN_PATH, "r+");
        if (file) {
            fseek(file, 0, SEEK_SET);
            fwrite(&position, sizeof(char), 1, file);
            fclose(file);
        } else {
            perror("Error opening Posmain.txt");
            return;
        }

        system(script);
    }
}

int main(int argc, char *argv[]) {
    int valorToGo = (argc > 1) ? atoi(argv[1]) : 1;

    while (1) {
        sleep(2);
        
        switch (valorToGo) {
            case 1:
                processDirectory(DIRECTORY_ALPY, '1', "bash /home/indicatic-e1/Desktop/code/Interop_code/alpy.sh");
                valorToGo++;
                break;
                
            case 2:
                processDirectory(DIRECTORY_QHY, '2', "bash /home/indicatic-e1/Desktop/code/Interop_code/QHYCCD.sh");
                valorToGo++;
                break;
                
            case 3:
                processDirectory(DIRECTORY_NIKON, '3', "bash /home/indicatic-e1/Desktop/code/Interop_code/Nikon.sh");
                valorToGo++;
                break;
                
            case 4:
                processDirectory(DIRECTORY_TESS, '4', "bash /home/indicatic-e1/Desktop/code/Interop_code/TESS.sh");
                valorToGo = 1;
                break;
                
            default:
                printf("Unexpected value: %d\n", valorToGo);
                valorToGo = 1;
                break;
        }
    }

    return 0;
}
