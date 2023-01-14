# Ubuntu hardening

These scripts are made to automatically configure and hardenize Ubuntu fresh installation. Tested on Ubuntu 22.04 and 22.10.

**IMPORTANT**

Before executing the scripts you must verify that your mobile phone timezone matches with the machine timezone. You can use the following command to verify the timezone:

```
timedatectl
```
And the following to set new timezone:

```
timedatectl set-timezone <timezone>
```

## hardenize.sh

Usage:

```
hardenize.sh -u <username>
```

The script must be executed with administrative privileges, so if you are not root run it with sudo command.
Script automates the following configurations:

- **Upgrade Ubuntu packages to the last version**

- **Setup automatic upgrade**
  
  Confiugured with unattended-upgrade package. The upgrade will be executed at 6:00 AM and the server will reboot automatically at 8:00 AM if no user are connected.
  
- **Setup firewall**

  Configured with ufw package. It will allow all the outgoing connection and incoming connection on port 22 (SSH). 
  
- **Setup NTP**

  Configured with timesyncd. The timestamp will be syncronzed every 60 seconds.
 
- **Enforce password policy**

  Configured with libpam-pwquality. The user must change the password every 90 days. The password must be 12 characters long and must contain at least 3 of the following:
  - Uppercase
  - Lowercase
  - Number
  - Symbol
  
  Password must be different from the last 5 used by the user.

- **Create/Modify user**
  
  If the user specified with -u parameter exists, the script modifies that user, otherwise it creates a new user. The script set a strong password for the user and add it to sudo group.

- **Enable SSH OTP**

  Configured with libpam-google-authenticator. After the configuration, the user must insert the password and the OTP code in order to login on SSH. OTP code can be retrieved from "Google authenticator" mobile app. OTP codes are calculated based on timestamp, so if your mobile phone timezone doesn't match with server timezone you can't login.

- **Remount /proc filesystem**

  If the system is multiuser, every user can see only his own processes.

- **Add timestamp to history**

  Every command in history will be showed with the execution timestamp

- **Disable root login**
 

## create_user.sh

Usage:

```
create_user.sh -u <username>
```

The script must be executed with administrative privileges, so if you are not root run it with sudo command.

The script automates user creation after hardening operations, so it perform the following operations:
- Create user if it does not exists
- Set a password that matches the enforced password policies
- Configure the OTP
- Set that the user must change password at next login

## Troubleshooting and modification

- **I need to unlock inbound connection on other port**

    ```
    sudo ufw allow <port>
    ```
    
    For other configurations you can read [this](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-ubuntu-22-04) tutorial
    
- **OTP code doesn't work**

    Verify that date and time on your mobile phone and server are aligned. Google OTP pam library is configured to accept three codes, the code generated in the time period, one in the past and one in the future. So you can have only one minute skew between the mobile and the server.
    
    


