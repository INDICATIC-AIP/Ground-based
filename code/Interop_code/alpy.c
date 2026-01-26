#include <stdio.h> // In and out
#include <dirent.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include "alpy.h" // Communication with main c file

FILE *file; // File to ALpy data
char ch; // char to be used for the selection of the data
const char* directory = "/home/indicatic-e1/Desktop/ASTRODEVICES/ALPYFILE";
void ChangeDirectory(const char *directory) { // To go in the APly files directory
    if (chdir(directory) != 0) {
        perror("error changing directory");
    }
}

/*
void getcurrentdirectory() { // Indicate the current directory
    char *buffer = malloc((strlen(directory) + 1) * sizeof(char)); // Allocate memory for buffer
    strcpy(buffer, directory); // Copy of directory into buffer
    if (getcwd(buffer, 34) != NULL) { // If buffer is not empty
        printf("In the folder: %s\n", buffer);
    } else {
        perror("error");
    }
    free(buffer);
}
*/

int FilesNbALpy() { // Calculate the number of files
    struct dirent *entry; // Entry of the structure
    int fileNB = 0; // Number of file in directory
    struct stat file_info;

    DIR *dir = opendir("."); // Open the current directory to dir
    if (dir != NULL) {
        while ((entry = readdir(dir)) != NULL) { // Read each entry until NULL to know how many files there are
            if (stat(entry->d_name, &file_info) == 0 && S_ISREG(file_info.st_mode)) { // Check if it is a regular file
                fileNB++;
            }
        }
        closedir(dir); // Close the current directory of dir
    }
    return fileNB;
}
