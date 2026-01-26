# NAScode  

This section contains the interoperability code from the NAS side. Here, the reverse of cryptography is mainly used to retrieve information from the hash obtained in the `Hash.txt` file. This file contains the payload hash on the first line and the info hash on the second line.

## ⚠️ Security Notice - Decryption Implementation Required

**IMPORTANT:** The decryption implementation files are **NOT included** in this repository for security reasons.

### What You Need to Do:

You **MUST implement your own decryption system** that mirrors your station's encryption implementation. Your decryption code should:

1. Read encrypted data from the `tmpFile/` directory
2. Process and decrypt the data
3. Verify data integrity
4. Generate output compatible with the NAS workflow

### Integration Points:

The decryption executable is called by:
- `fileTreatment.sh` - Processes incoming encrypted files
- `main.sh` - Orchestrates the decryption workflow

Ensure your `mainTreatment` executable is compiled and placed in the `NAScode/` directory, or update the script paths accordingly.

**Security Reminder:** Your decryption implementation must exactly match the encryption used on the station side. Keep all cryptographic implementations confidential and unique to your deployment.  

In the `tmpFiles` folder, different files can be found:  

- `BitInfo.txt` – Contains the bit sequence of the info.  
- `BitPayload.txt` – Contains the bit sequence of the payload.  
- `Caesar.txt` – Contains the Caesar code.  
- `count.txt` – Indicates if a duplicate file is present in the NAS when sending a file (as explained [here](https://github.com/INDICATIC-AIP/FID074-Estaciones/blob/main/code/README.md)).  
- `Mask.txt` – Contains the Mask value.  

To access this code on the NAS, you need to connect to the INDICATIC account and navigate to the `InteroperabilityCode` folder using the following command: 

  ```bash
  cd /var/services/homes/INDICATIC/InteroperabilityCode
  ```
When you are inside the `InteroperabilityCode` folder, you will see an `env` folder that does not appear on GitHub.  
For the code to function correctly, it is necessary to be inside this environment, if you are inside the environment, you should see `(env)` before `INDICATIC@INDICATIC-S1`, if you are not inside it, you can activate it using the following command: 

  ```bash
  cd env/ && source bin/activate
  ```
Inside this environment, only the files from the [`secretsharingToCopy`](https://github.com/INDICATIC-AIP/FID074-Estaciones/tree/main/code/secretsharingToCopy) folder are present, ensuring cryptographic operations function properly.  

With the following command, if you see two different PIDs, then both scripts are running on the NAS and are ready to perform their tasks on each station path.  

  ```bash
  pidof main.sh OrderImages.sh
  ```
If both PIDs are missing or only one is present, terminate the existing process using the following command:

  ```bash
  kill pidnumber
  ```
Then, execute the `main.sh` script using the following command: 

  ```bash
  nohup /var/services/homes/INDICATIC/InteroperabilityCode/main.sh > /dev/null 2>&1 &
  ```
Then, verify that the PIDs of both scripts are running.
