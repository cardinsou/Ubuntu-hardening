# Ubuntu 22.04 hardening

This script are made to automatically configure and hardenize Ubuntu 22.04 VPS. 

## hardenize.sh

Usage:

```
hardenize.sh -u <username>
```

The script must be executed with administrative privileges, so if you are not root run it with sudo command.
Script automated the following configurations:

- **Upgrade Ubuntu packages to the last version**

- **Setup automatic upgrade**
  
  COnfiugured with unattended-upgrade package. Upgrade will be at 6:00 AM and the server reboot automatically at 8:00 AM if no user are connected.
  
- **Setup firewall**

  Configured with ufw package. Will be allow all outgoing connection and incoming connetion on port 22 (SSH). 
  
- **Setup NTP**

  Configured with timesyncd. Timestamp will be syncronzed every 60 seconds.
 
- **Enforce password policy**

  Configured with libpam-pwquality. User must change password every 90 days. Password must be 12 characters lenght and contains at leat 3 of the following:
  - Uppercase
  - Lowercase
  - Number
  - Symbol
  
  Password must be different from the last 5 that the user used.

- **Create/Modify user**
  
  If the user specified with -u parameter exist the script modify that user otherwise it create a new user. The script set a strong password for the user and add it to sudo group.

- **Enable SSH OTP**

  Configured with libpam-google-authenticator. After configuration user must insert password and OTP code to login. OTP code can be retrieved from "Google authenticator" mobile app.

- **Disable root user login**
 

## create_user.sh

Usage:

```
create_user.sh -u <username>
```

The script must be executed with administrative privileges, so if you are not root run it with sudo command.

Script automate user creation after hardening operations, so it:
- create user if not exists
- Set password that match the enforced password policies
- Configure OTP
- Set that the user must change password at next logon
