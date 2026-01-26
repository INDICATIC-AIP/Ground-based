# Interop_code and CryptageC

_In this README, payload refers to the data of a file sent, while info represents the information of the payload file, such as metadata._

## ⚠️ Security Notice - Encryption Implementation Required

**IMPORTANT:** The encryptation directory are **NOT included** in this repository for security reasons.

### What You Need to Do:

You **MUST implement your own encryption system** before using this interoperability framework. Your encryption implementation should:

1. Process payload and metadata files
2. Generate encrypted output compatible with the interoperability scripts
3. Create necessary executable files that the scripts will call

Update the paths in these scripts to match your encryption implementation location.

**Security Reminder:** Each station deployment should use a unique encryption implementation to maintain security across the network.

### In this section, serial empty folders can be seen, here is their explanation:

1. **RawQHYImg** : _The raw data from the QHYCCD are sent to this folder to be processed using the converter.py script._

2. **RenameFile** : _For the count.txt file, if files are meant to be renamed with (i), then these files are sent into this folder for processing._

3. **infoIMG** : _All info files of each processed payload file are stored in this folder._

4. **tmp** : _A temporary folder where some files are used in the code and deleted._


### In this section as well, serial other files can be seen, here is their explanation:

1. **NBstation** : _The path of the station in the NAS is written there, so when the station sends data, it is directed to the related directory of this station in the NAS._

2. **Posmain.txt** : _Position of the last file data sent, it can be used if the interoperability code is terminated for any reason, allowing a new interoperability code to resume from this position._

3. **converter.py** : _Converts raw files obtained from the qhy_ccd_test.cpp code into FITS format._

4. **count.txt** : _This file contains two numbers. The first one can have a value of 5 or 1. If it is 5, it means that a file or folder with the same name that was meant to be sent is already in the NAS. In that case, the second number (under 5) serves as an index (i) to prevent overwriting the existing file. If the first number is 1, it means the files do not exist in the NAS, and the second number is -1._

5. **mainTess.sh** : _Two different types of TESS, as mentioned in the README of the main page of this GitHub repository, are used for this project. The TESS stores its .csv files in different folders, so this script periodically checks these folders and transfers the files into the main TESS folder, from where the interoperability code retrieves files for transmission._

6. **nikon.sh** : _A script that periodically takes pictures with the Nikon D5600 and sends them to the folder where the interoperability code looks for files to transmit._

##### Concerning the Interoperability code, the `my_program` file in [Interop_code](https://github.com/INDICATIC-AIP/FID074-Estaciones/tree/main/code/Interop_code) is the executable file to run the interoperability code with `./my_program`. The `makefile` file is used to compile all C code if there are any changes with the command `make`, and the `compil.sh` file converts all `.sh` files from Windows encoding to Unix encoding with the command `./compil.sh`, allowing the `.sh` scripts to be executed on Linux.

##### Concerning the [CryptageC](https://github.com/INDICATIC-AIP/FID074-Estaciones/tree/main/code/CryptageC) folder, the `CryptFile.txt` file is used to transfer data that the NAS needs to process for integrity verification. The first line, consisting of 0 and 1 bits, represents the payload, while the second line contains the file information. The NAS performs decryption using the two values above, which correspond to the **Caesar cipher shift** and the **bitmask applied to the data**, ultimately comparing the obtained hashes to ensure consistency.

### **Installation Instructions**

##### Regarding the two folders, the required packages for their proper functioning are:

1. **secretsharing** : If `pip` is not installed, run:
   
   ```bash
   sudo apt install python3-pip
   ```
   
   And then install the different packages:

   ```bash
    pip install secretsharing astropy numpy
   ```
2. Move the files from the [secretsharingToCopy](https://github.com/INDICATIC-AIP/FID074-Estaciones/tree/main/code/secretsharingToCopy) folder to a path that looks like `/home/indicatic-e1/.local/lib/python3.10/site-packages/secretsharing` to replace them. The appropriate path can be found using the command:
   
    ```bash
    python3 -c "import secretsharing; print(secretsharing.__file__)"
   ```
   Once this is done, the secretsharingToCopy folder can be deleted, to do so use the command
   
   ```bash
   rm -rf secretsharingToCopy
   ```
5. The code uses `sshpass` and `lftp` to connect to the NAS. These can be installed with the command:

      ```bash
      sudo apt install openssh-server openssh-client lftp
      ```
6. Nikon needs the `gphoto2` library to work. Use the command:

      ```bash
      sudo apt install gphoto2 libgphoto2-dev libgphoto2-6 libgphoto2-port12
      ```
