#!/usr/bin/bash

usage() {
	echo "Usage: create_user.sh [-u <username>]";
	exit 1;
}

verifyUserExist() {
	if id -u "$username" &> /dev/null
	then
    		echo "[-] Error - User already exist";
    	exit 1;
    fi;
}

checkAdmin() {
	if (( $EUID != 0 ))
	then
		echo "[-] Error - Please run the script with administrative user account";
		exit 1;
	fi
}

createPwd() {
	echo "[+] Generating password ...";
	password=`tr -dc A-Za-z0-9 </dev/urandom | head -c 12`;
}

createUser() {
	echo "[+] Creating user $username...";
	useradd -m -s /bin/bash $username;
	echo -en "$password\n$password\n" | passwd "$username" &> /dev/null;
}

setOtp() {
	echo "[+] Add Google OTP to user $username..."
	su - $username -c "google-authenticator -t -d -f -r 3 -R 30 -w 3 -C -q";
	otp_code=`head -1 /home/$username/.google_authenticator`;
}

changePwd() {
	chage -d0 $username;
}

printInfo() {
	echo "[+] User created";
	echo "";
	echo "Username : $username";
	echo "Password : $password";
	echo "OTP initialization code : $otp_code";
	echo "";
	echo "User must change password at next logon";
	echo "";	
}

while getopts ":u:" flag
do
	case ${flag} in
        u) [ ! -z "${OPTARG}" ] || usage
		   username=${OPTARG}
		   verifyUserExist;
		   checkAdmin;
		   createPwd;
		   createUser;
		   setOtp;
		   changePwd;
		   printInfo;
		   exit;;
	esac
done

usage;
