# AutoRun

This section of the interoperability code is responsible for automating tasks on the station. To do so, the script `Launch.sh` must be executed with the following command:

  ```bash
  ./Launch.sh
  ```

When the script is executed, any errors can be observed, such as missing drivers, whether devices like Nikon, Alpy, and QHY are detected or not, whether `indiserver` is functioning properly, etc.

When it is required to enter `ACTUAL`, `VIEW`, or `DEFAULT`, it is recommended to set the variables `BegingDefaultAllHour`, `BegingDefaultAllMinute`, `EndDefaultAllHour`, and `EndDefaultAllMinute` to define the time at which the station should start and stop executing the interoperability code by writting `DEFAULT`.

### **Installation Instructions**

To install the automatic system of email sending, follow the next instructions.

1. Open the SMTP port 587 for inbound/outbound traffic on the firewall with the following commands:

  ```bash
  sudo iptables -A INPUT -p tcp --dport 587 -j ACCEPT
  ```
and

  ```bash
  sudo iptables -A OUTPUT -p tcp --dport 587 -j ACCEPT
  ```
2. Updating packages and installing Postfix.

  ```bash
  sudo apt-get update && sudo apt-get upgrade
  ```
  ```bash
  sudo apt-get install postfix mailutils libsasl2-2 ca-certificates libsasl2-modules
  ```

In Postfix configuration, select `Site Internet` in system mail name you can put for exemple `INDICATIC`

3. Activation of the Postfix service.

  ```bash
  sudo systemctl enable postfix
  ```
4. Creation of the SSL certificate.

  ```bash
  sudo mkdir /etc/postfix/ssl/
  ```
  ```bash
  cd /etc/postfix/ssl/
  ```
  ```bash
  sudo openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout cacert-smtp-gmail.key -out cacert-smtp-gmail.pem
  ```
In the `tmpFiles` folder, different files can be found:  

- `Country Name` – PA  
- `State or Province Name` – PANAMA  
- `Locality Name` – PANAMA  
- `Organization Name` – INDICATIC
- `Organization Unit Name` – INDICATIC
- `Common Name` – INDICATIC
- `Email,Adress` – leave empty

5. Configuration of Postfix.

  ```bash
  sudo nano /etc/postfix/main.cf
  ```
Cancel the `relayhost` line, and add it above `mynetworks`.

  ```bash
  relayhost = [smtp.gmail.com]:587
  ```
Add this under `inet_protocols`.

```bash
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/smtp_sasl_password_map
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/postfix/ssl/cacert-smtp-gmail.pem
smtp_use_tls = yes
```
6. Creation of the smtp_sasl_password_map file
   
```bash
sudo nano /etc/postfix/smtp_sasl_password_map
```
  and add the following line in the file

  ```bash
  [smtp.gmail.com]:587 indicatic@gmail.com:sitginysxavylalv
  ```
  and execute the two command

  ```bash
  sudo chmod 400 /etc/postfix/smtp_sasl_password_map
  ```

  ```bash
  sudo postmap /etc/postfix/smtp_sasl_password_map
  ```
7. Start and check the status of postfix

```bash
sudo systemctl restart postfix
 ```

```bash
sudo systemctl status postfix
```
### Installation of Tailscale

  Download Tailscale and execute it

  ```bash
  curl -fsSL https://tailscale.com/install.sh | sh
  ```

Once executed, connect the station to the account of `proy.ind@hotmail.com` whose password is `indicatic1`




