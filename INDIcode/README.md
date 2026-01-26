# INDIcode

### In this section, there are two `.cpp` scripts that allow the Alpy 600 and QHY 16200A cameras to function. The script `indi.cpp` is responsible for operating the Alpy 600, while the script `qhy_ccd_test.cpp` ensures the functionality of the QHY 16200A.

These scripts must be placed in a specific path to work correctly, so it is necessary to follow these instructions if the packages are installed manually.

### **Installation Instructions**
1. **Install libindi**  
   LibINDI needs to be installed, which can be done as explained in this [link](https://github.com/indilib/indi/blob/master/INSTALL).

2. **Clone the required repository**  
   You need to clone this [repository](https://github.com/indigo-astronomy/indigo/tree/master/indigo_drivers/ccd_qhy) inside the INDIcode folder. Here is the command `git clone https://github.com/indigo-astronomy/indigo.git
`

3. **Modify the header file path of the qhy_ccd_test.cpp script**
   locate where the file `qhyccd.h` is located on the station.
   ```bash
   find / -name "qhyccd.h" 2>/dev/null
   ```

   So you can copy the path and modify it in the script.
   
   ```bash
   #include </home/indicatic-e1/Desktop/INDIcode/ccd_qhy/bin_externals/qhyccd/include/qhyccd.h>
   ```

5. **indiserver** : To install indiserver with the expension needed, that is primordial for the cameras to workds with their scripts, run:
   ```bash
   sudo apt install indi-bin indi-sx
   ```
   
   ```bash
   sudo apt-add-repository ppa:mutlaqja/ppa
   sudo apt update
   sudo apt install indi-qhy
   ```

6. Now, to compile the `indi.cpp` code used for Alpy, use the following command:

   ```bash
   g++ -o alpy indi.cpp -lindiclient
   ```

   For QHYCCD, you must be in the folder where the file `qhy_ccd_test.cpp` is located. Then, use the following commands:

   ```bash
   g++ -o qhy qhy_ccd_test.cpp -lqhyccd
   ```
   now you have the executable files `alpy` and `qhy`
