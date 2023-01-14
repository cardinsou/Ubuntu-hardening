#!/usr/bin/bash

usage() {
	echo "Usage: hardenize.sh [-u <username>]";
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
	apt-get update;
	apt-get -y dist-upgrade;
	apt-get -y autoremove;
	clear
}

checkPackage() {
	dpkg -s $1 &> /dev/null
	if [ $? -eq 1 ]
	then
		echo "[+] Package $1 not found, installing ...";
		apt-get -qq -y install $1 &> /dev/null;
	fi
}

configureAutomaticUpgrade() {
	echo "[+] Configuring automatic upgrade ...";
	checkPackage "unattended-upgrades" 
	checkPackage "apt-config-auto-update"
	sed -i '/"${distro_id}:${distro_codename}-updates"/ s/^\/\///' /etc/apt/apt.conf.d/50unattended-upgrades
	sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot "false";/Unattended-Upgrade::Automatic-Reboot "true";/g' /etc/apt/apt.conf.d/50unattended-upgrades;
	sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot-WithUsers "true";/Unattended-Upgrade::Automatic-Reboot-WithUsers "false";/g' /etc/apt/apt.conf.d/50unattended-upgrades;
	sed -i 's/\/\/Unattended-Upgrade::Automatic-Reboot-Time "02:00";/Unattended-Upgrade::Automatic-Reboot-Time "08:00";/g' /etc/apt/apt.conf.d/50unattended-upgrades;
	sed -i 's/Unattended-Upgrade::DevRelease "auto";/\/\/Unattended-Upgrade::DevRelease "auto";/g' /etc/apt/apt.conf.d/50unattended-upgrades;
}

setUpFirewall() {
	echo "[+] Configuring firewall ...";
	checkPackage "ufw"
	cp /etc/default/ufw /etc/default/ufw.bck
	sed -i 's/IPV6=no/IPV6=yes/g' /etc/default/ufw
	ufw default deny incoming &> /dev/null;
	ufw default allow outgoing &> /dev/null;
	echo "[+] Firewall allow outgoing connection";
	ufw allow ssh &> /dev/null;
	echo "[+] Firewall allow only incoming connection on port 22 (SSH)";
	ufw --force enable &> /dev/null;
}

configureNTP() {
	echo "[+] Configuring NTP server...";
	cp /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf.bck;
	sed -i 's/#NTP=/NTP=ntp.ubuntu.com/g' /etc/systemd/timesyncd.conf;
	sed -i 's/#PollIntervalMinSec=32/PollIntervalMinSec=60/g' /etc/systemd/timesyncd.conf;
	sed -i 's/#PollIntervalMaxSec=2048/PollIntervalMaxSec=2048/g' /etc/systemd/timesyncd.conf;
	timedatectl set-ntp on;
}

enforcePasswordPolicy() {
	echo "[+] Configuring password policy...";
	checkPackage "libpam-pwquality"
	cp /etc/login.defs /etc/login.defs.bck;
	sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/g' /etc/login.defs;
	cp /etc/security/pwquality.conf /etc/security/pwquality.conf.bck;
	sed -i 's/# minlen = 8/minlen = 12/g' /etc/security/pwquality.conf;
	sed -i 's/# minclass = 0/minclass = 3/g' /etc/security/pwquality.conf;
	sed -i 's/# usercheck = 1/usercheck = 1/g' /etc/security/pwquality.conf;
	cp /etc/pam.d/common-password /etc/pam.d/common-password.bck
	sed -i '/^password\t\[success\=2 default=ignore\]/ s/$/ remember=5/' /etc/pam.d/common-password
}

createUser() {
	echo "[+] Creating user $username...";
	if id -u "$username" &> /dev/null
	then
    		echo "[+] User already exist";
    		echo "[+] Changing password for user $username...";
    	else
    		useradd -m -s /bin/bash $username;
    		echo "[+] Setting password for user $username...";
    	fi
	password=`tr -dc A-Za-z0-9 </dev/urandom | head -c 14`;
	echo -en "$password\n$password\n" | passwd "$username" &> /dev/null;
	echo "[+] Adding user $username to sudo group...";
	checkPackage "sudo";
	usermod -aG sudo $username;
}

configureOTP() {
	echo "[+] Configuring Google OTP...";
	checkPackage "libpam-google-authenticator";
	checkPackage "openssh-server";
	cp /etc/pam.d/sshd /etc/pam.d/sshd.bck;
	echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd;
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bck;
	sed -i 's/KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/g' /etc/ssh/sshd_config;
	echo "AuthenticationMethods keyboard-interactive" >> /etc/ssh/sshd_config;	
	echo "[+] Configuring Google OTP for user $username...";
	su - $username -c "google-authenticator -t -d -f -r 3 -R 30 -w 3 -C -q";
	otp_code=`head -1 /home/$username/.google_authenticator`;
}

remountProc() {
	echo "[+] Mounting /proc with user restriction...";
	cp /etc/fstab /etc/fstab.bck
	echo "" >> /etc/fstab
	echo "#Mount /proc with hidepid=2 parameter, so users cannot see other users processes" >> /etc/fstab
	echo "proc    /proc    proc    defaults,nosuid,nodev,noexec,relatime,hidepid=2     0     0" >> /etc/fstab
}

addTimestampToHistory() {
	echo "[+] Adding timestamp to bash history...";
	cp /etc/profile /etc/profile.bck
	echo "" >> /etc/profile
	echo "#Add timestamp to command in bash history" >> /etc/profile
	echo "export HISTTIMEFORMAT='%F %T '" >> /etc/profile
}

disableRootUser() {
	echo "[+] Disabling root user ...";
	passwd -l root &> /dev/null;
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
		   remountProc
		   addTimestampToHistory
		   disableRootUser
		   printInfo
		   exit 0;;
	esac
done

usage;
