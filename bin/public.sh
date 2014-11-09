#!/bin/bash

# version:1.0
# author:wdfang
# date:2014-08-28
# mail:fangdong316@126.com

# Check if user is root
rootNeed(){
if [ `id -u` -ne 0 ];then
	echo 'Error: You must be root to run this script, please use root to run this script!';
	exit 1;
fi
}

# Download File
download_file(){
local url=$1
local filename=$2
local location=$3
if [ -s "${cur_dir}/soft/${filename}" ];then
	echo "${filename} is existed.Check the file integrity."

	if check_integrity "$location/${filename}";then
		echo "the file $filename is complete."
	else
		echo "the file $filename is incomplete.redownload now..."
		rm -f ${cur_dir}/soft/${filename}
		download_file "$url" "$filename"	
	fi

else
	[ ! -d "${cur_dir}/soft" ] && mkdir -p ${cur_dir}/soft
	cd ${cur_dir}/soft
	wget_file "${url}" "${filename}"
fi
}

# Wget file
wget_file(){
	local url=$1
	local filename=$2
	local location=$3
	if ! wget --no-check-certificate --tries=3 ${url} -O $filename -p $location;then
		echo "Fail to download $filename with url $url."
	fi
}

# Check file integrity
check_integrity(){
	local filename=$1
	if echo $filename | grep -q -E "(tar\.gz|tgz)$";then
		return `gzip -t ${cur_dir}/soft/$filename`
	elif echo $filename | grep -q -E "tar\.bz2$";then
		return `bzip2 -t ${cur_dir}/soft/$filename`
	fi
}

# Check OS Bit
is_64bit(){
	if [ `getconf WORD_BIT` = '32' ] && [ `getconf LONG_BIT` = '64' ] ; then
		return 0
	else
		return 1
	fi		
}



kill_pid(){
	local processType=$1
	local content=$2
	
	if [[ $processType == "port" ]]; then
		local port=$content
		if [[ `netstat -nlpt | awk '{print $4}' | grep ":${port}$"` != "" ]]; then
			processName=`netstat -nlp | grep -E ":${port} +" | awk '{print $7}' | awk -F'/' '{print $2}' | awk -F'.' 'NR==1{print $1}'`
			pid=`netstat -nlp | grep -E ":${port} +" | awk '{print $7}' | awk -F'/' 'NR==1{print $1}'`
			yes_or_no "We found port $port is occupied by process $processName.would you like to kill this process [Y/n]: " "kill $pid" "echo 'will not kill this process.'"
			if [[ $yn == "y" ]];then
				echo "gonna be kill $processName process,please wait for 5 seconds..."
				sleep 5
				if [[ `ps aux | awk '{print $2}' | grep "^${pid}$"` == "" ]]; then
					echo "kill ${processName} successfully."
				else
					echo "kill ${processName} failed."
				fi
				sleep 2
			fi			
		fi

	elif [[ $processType == "socket" ]]; then
		local socket=$content
		if [[ `netstat -nlp | awk '$1 ~/unix/{print $10}' | grep "^$socket$"` != "" ]]; then
			processName=`netstat -nlp | grep ${socket} | awk '{print $9}' | awk -F'/' '{print $2}'`
			pid=`netstat -nlp | grep $socket | awk '{print $9}' | awk -F'/' '{print $1}'`
			yes_or_no "We found socket $socket is occupied by process $processName.would you like to kill this proess [Y/n]: " "kill $pid" "echo 'will not kill this process.'"
			if [[ $yn == "y" ]];then
				echo "gonna be kill $processName process,please wait for 5 seconds..."
				sleep 5
				if [[ `ps aux | awk '{print $2}' | grep "^${pid}$"` == "" ]]; then
					echo "kill ${processName} successfully."
				else
					echo "kill ${processName} failed."
				fi
				sleep 2
			fi			
		fi
	else
		echo "unknow processType."
	fi

}

upcase_to_lowcase(){
words=$1
echo $words | tr '[A-Z]' '[a-z]'
}

# Verfy ip
verify_ip(){
	local ip=$1
	local i1=`echo $ip | awk -F'.' '{print $1}'`
	local i2=`echo $ip | awk -F'.' '{print $2}'`
	local i3=`echo $ip | awk -F'.' '{print $3}'`
	local i4=`echo $ip | awk -F'.' '{print $4}'`

	#检查第1位
	if ! echo $i1 | grep -E -q "^[0-9]+$" || [[ $i1 -eq 127 ]]  || [[ $i1 -le 0  ]] || [[ $i1 -ge 255 ]];then
		return 1
	fi
	
	#检查第2位
	if ! echo $i2 | grep -E -q "^[0-9]+$" || [[ $i2 -lt 0 ]] || [[ $i2 -gt 255 ]];then
		return 1
	fi

	#检查第3位
	if ! echo $i3 | grep -E -q "^[0-9]+$" || [[ $i3 -lt 0 ]] || [[ $i3 -gt 255 ]];then
		return 1
	fi

	#检查第4位
	if ! echo $i4 | grep -E -q "^[0-9]+$" || [[ $i4 -lt 0 ]] || [[ $i4 -gt 255 ]];then
		return 1
	fi		
	
	return 0
}

# Verify port
verify_port(){
	local port=$1
	if echo $port | grep -q -E "^[0-9]+$";then
		if [[ "$port" -lt 0 ]] || [[ "$port" -gt 65535 ]];then
			return 1
		else
			return 0
		fi	
	else
		return 1
	fi		
}


#检测服务器的系统硬件信息
#检测信息[ip地址(内网、所有)、cpu信息(核数)、内存、硬盘、机器码、制造商、产品名称等]
check_hardwareinfo(){
# manufacturer
manufacturer=`dmidecode | grep -A6 'System Information' | sed -rn 's/^\s*Manufacturer:\s+(.+)\s*$/\1/p'`

# product
product=`dmidecode | grep -A6 'System Information' | sed -rn 's/^\s*Product Name:\s+(.+)\s*$/\1/p'`

# cpuinfo
cpu=`sed -r 's/[ \t]+/ /g' /proc/cpuinfo | awk -F": +"  '/^model name/{a[$2]++} END{for(i in a) printf "%s (x%s)\n",i,a[i]}'`

# memory
memory=`dmidecode | grep -A6 '^Memory Device' | sed -r 's/^[ \t]+//' | awk '/^Size.*MB/{a[$2/1024]++} END{for(i in a) printf "%sx%s,",i,a[i]}' | sed 's/,$//'`

# disk
disk=`fdisk -l 2>/dev/null | awk '/^Disk/{printf "%.0f+",$3}' | sed 's/+$//'`

echo "Manufacturer:[$manufacturer] Product:[$product] CPU:[$cpu] Memory:[$memory] Disk:[$disk]"	
}

#检测服务器的软件环境
check_softwareinfo(){
# os version
echo 
# arch


}






get_char(){
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}
echo "Press any key to continue...or Press Ctrl+C to cancel"
char=`get_char`


check_packageslist(){

local pkg_list=$1

echo "============================================"
echo "	Package"                     
echo "============================================"

for pkg in $pkg_list
do
	result=`rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE} (%{ARCH})\n' \$pkg`

	if [ "$result" = "packages $pkg is not installed" ];then
		echo "$pkg is not installed!"
	else  
 		echo "$pkg is installed!"
	fi
done
}


# Check environment
check_environment(){

check_hardwareinfo
check_softwareinfo

}



# Install development compile tool
install_compile_tool(){ 

local pkg_list=$1
# binutils compat-db compat-gcc-34 compat-gcc-34-c++ compat-libstdc++-296 compat-libstdc++-33 gcc gcc-c++ glibc glibc-common glibc-devel glibc-headers libaio libaio-devel libgcc libstdc++ libstdc++-devel libgomp make numactl-devel sysstat libXp elfutils-libelf elfutils-libelf-devel elfutils-libelf-devel-static kernel-headers unixODBC unixODBC-devel apr apr-util

for packages in $pkg_list
do
result=`rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE} (%{ARCH})\n' \$packages`
if [ "$result" = "package $packages is not installed" ];then
	echo -n "Press Enter to continue....."
	read
	
	echo "Install $packages..."
	yum -y install $packages
else 
	echo "Compile tool is installed"
fi
done

}

chang_hostname(){
local hostname=$1
hostname $hostname && sed -i s/HOSTNAME=.*/HOSTNAME=\$hostname/g /etc/sysconfig/network

}