#!/usr/bin/bash

usage() {
	/usr/bin/echo "Usage: hardenize.sh [-u <username>]";
	exit 1;
}

checkAdmin() {
	if (( $EUID != 0 ))
	then
		echo "[-] Error - Please run the script with administrative user account";
		exit 1;
	fi
}

upgrade() {
	echo "[+] Upgrading packages ...";
	/usr/bin/apt-get update;
	/usr/bin/apt-get -y dist-upgrade;
	/usr/bin/apt-get -y autoremove;
	/usr/bin/clear
}

checkPackage() {
	/usr/bin/dpkg -s $1 &> /dev/null
	if [ $? -eq 1 ]
	then
		echo "[+] Package $1 not found, installing ...";
		/usr/bin/apt-get -qq -y install $1 &> /dev/null;
	fi
}

configureAutomaticUpgrade() {
	echo "[+] Configuring automatic upgrade ...";
	checkPackage "unattended-upgrades" 
	checkPackage "apt-config-auto-update"
	/usr/bin/sed -i '/"${distro_id}:${distro_codename}-updates"/ s/^\/\///' /etc/apt/apt.conf.d/50unattended-upgrades
	/usr/bin/sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot "false";/Unattended-Upgrade::Automatic-Reboot "true";/g' /etc/apt/apt.conf.d/50unattended-upgrades;
	/usr/bin/sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot-WithUsers "true";/Unattended-Upgrade::Automatic-Reboot-WithUsers "false";/g' /etc/apt/apt.conf.d/50unattended-upgrades;
	/usr/bin/sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot-Time "02:00";/Unattended-Upgrade::Automatic-Reboot-Time "08:00";/g' /etc/apt/apt.conf.d/50unattended-upgrades;
	/usr/bin/sed -i 's/Unattended-Upgrade::DevRelease "auto";/\/\/Unattended-Upgrade::DevRelease "auto";/g' /etc/apt/apt.conf.d/50unattended-upgrades;
}

setUpFirewall() {
	echo "[+] Configuring firewall ...";
	checkPackage "ufw"
	/usr/bin/cp /etc/default/ufw /etc/default/ufw.bck
	/usr/bin/sed -i 's/IPV6=no/IPV6=yes/g' /etc/default/ufw
	/usr/sbin/ufw default deny incoming &> /dev/null;
	/usr/sbin/ufw default allow outgoing &> /dev/null;
	echo "[+] Firewall allow outgoing connection";
	/usr/sbin/ufw allow ssh &> /dev/null;
	echo "[+] Firewall allow only incoming connection on port 22 (SSH)";
	/usr/sbin/ufw --force enable &> /dev/null;
}

configureNTP() {
	echo "[+] Configuring NTP server...";
	/usr/bin/cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.bck;
	/usr/bin/sed -i 's/#NTP=/NTP=ntp.ubuntu.com/g' /etc/systemd/timesyncd.conf;
	/usr/bin/sed -i 's/#PollIntervalMinSec=32/PollIntervalMinSec=60/g' /etc/systemd/timesyncd.conf;
	/usr/bin/sed -i 's/#PollIntervalMaxSec=2048/PollIntervalMaxSec=2048/g' /etc/systemd/timesyncd.conf;
	/usr/bin/timedatectl set-ntp on;
}

enforcePasswordPolicy() {
	echo "[+] Configuring password policy...";
	checkPackage "libpam-pwquality"
	/usr/bin/cp /etc/login.defs /etc/login.defs.bck;
	/usr/bin/sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/g' /etc/login.defs;
	/usr/bin/cp /etc/security/pwquality.conf /etc/security/pwquality.conf.bck;
	/usr/bin/sed -i 's/# minlen = 8/minlen = 12/g' /etc/security/pwquality.conf;
	/usr/bin/sed -i 's/# minclass = 0/minclass = 3/g' /etc/security/pwquality.conf;
	/usr/bin/sed -i 's/# usercheck = 1/usercheck = 1/g' /etc/security/pwquality.conf;
	/usr/bin/cp /etc/pam.d/common-password /etc/pam.d/common-password.bck
	/usr/bin/sed -i '/^password\t\[success\=2 default=ignore\]/ s/$/ remember=5/' /etc/pam.d/common-password
}

createUser() {
	echo "[+] Creating user $username ...";
	if id -u "$username" &> /dev/null
	then
    		echo "[+] User already exist";
    		echo "[+] Changing password for user $username...";
    	else
    		/usr/sbin/useradd -m -s /bin/bash $username;
    		echo "[+] Setting password for user $username...";
    	fi
	password=`/usr/bin/tr -dc A-Za-z0-9 </dev/urandom | /usr/bin/head -c 14`;
	echo -en "$password\n$password\n" | /usr/bin/passwd "$username" &> /dev/null;
	echo "[+] Adding user $username to sudo group ...";
	checkPackage "sudo";
	/usr/sbin/usermod -aG sudo $username;
}

configureOTP() {
	echo "[+] Configuring Google OTP ...";
	checkPackage "libpam-google-authenticator";
	checkPackage "openssh-server";
	/usr/bin/cp /etc/pam.d/sshd /etc/pam.d/sshd.bck;
	echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd;
	/usr/bin/cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bck;
	/usr/bin/sed -i 's/KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config;
	echo "AuthenticationMethods keyboard-interactive" >> /etc/ssh/sshd_config;	
	echo "[+] Configuring Google OTP for user $username ...";
	/usr/bin/su - $username -c "/usr/bin/google-authenticator -t -d -f -r 3 -R 30 -w 3 -C -q";
	otp_code=`/usr/bin/head -1 /home/$username/.google_authenticator`;
}

disableRootUser() {
	echo "[+] Disabling root user ...";
	/usr/bin/passwd -l root &> /dev/null;
}

printInfo() {
	host=`hostname`;
	echo "[+] Hardening operations completed";
	echo "";
	echo "What to do:";
	echo "	* Download and open 'Google authenticator' app on your smartphone";
	echo "	* Add item";
	echo "	* Insert $host";
	echo "	* Insert $otp_code";
	echo "	* Reboot with command 'reboot'";
	echo "	* Connect to $hostname with SSH client";
	echo "	* Insert username: $username";
	echo "	* Insert password: $password";
	echo "	* Insert OTP token from 'Google Autheticator' app";
	echo "	* Have fun";
	echo "";	
}

while getopts ":u:" flag
do
	case ${flag} in
        u) [ ! -z "${OPTARG}" ] || usage
		   username=${OPTARG}
		   checkAdmin
		   upgrade
		   configureAutomaticUpgrade
		   setUpFirewall
		   configureNTP
		   enforcePasswordPolicy
		   createUser
		   configureOTP
		   disableRootUser
		   printInfo
		   exit 0;;
	esac
done

usage;
