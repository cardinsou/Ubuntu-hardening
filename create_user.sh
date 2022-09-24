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
	password=`/usr/bin/tr -dc A-Za-z0-9 </dev/urandom | /usr/bin/head -c 12`;
}

createUser() {
	echo "[+] Creating user ...";
	/usr/sbin/useradd -m -s /bin/bash $username;
	/usr/bin/echo -en "$password\n$password\n" | /usr/bin/passwd "$username" &> /dev/null;
}

setOtp() {
	echo "[+] Add Google OTP to user ..."
	/usr/bin/su - $username -c "/usr/bin/google-authenticator -t -d -f -r 3 -R 30 -w 3 -C -q";
	otp_code=`/usr/bin/head -1 /home/$username/.google_authenticator`;
}

changePwd() {
	/usr/bin/chage -d0 $username;
}

printInfo() {
	echo "[+] User created";
	echo "";
	echo "Username : $username";
	echo "Password : $password";
	echo "OTP Code : $otp_code";
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
