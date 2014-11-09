#!/bin/bash

# version:1.0
# author:wdfang
# date:2014-08-08
# mail:fangdong316@126.com

cur_dir=`pwd`

# Toolbox
tool_box(){
	clear
	display_menu toolbox
	if [ "$toolbox" == "back_to_main_menu" ];then
		clear
		mainMenu
	else
		eval $tools
	fi	

}

disable_selinux(){
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0
fi
}

#更改ssh server端口
Change_sshd_port(){
	local listenPort=`netstat -nlpt | awk '/sshd/{print $4}' | grep -o -E "[0-9]+$" | awk 'NR==1{print}'`
	local configPort=`grep -v "^#" /etc/ssh/sshd_config | sed -n -r 's/^Port\s+([0-9]+).*/\1/p'`
	configPort=${configPort:=22}

	echo "the ssh server is listenning at port $listenPort."
	echo "the /etc/ssh/sshd_config is configured port $configPort."

	local newPort=''
	while true; do
		read -p "please input your new ssh server port(range 0-65535,greater than 1024 is recommended.): " newPort
		if verify_port "$newPort";then
			break
		else
			echo "input error,must be a number(range 0-65535)."
		fi
	done

	#备份配置文件
	echo "backup sshd_config to sshd_config_original..."
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config_original

	#开始改端口
	if grep -q -E "^Port\b" /etc/ssh/sshd_config;then
		sed -i -r "s/^Port\s+.*/Port $newPort/" /etc/ssh/sshd_config
	elif grep -q -E "#Port\b" /etc/ssh/sshd_config; then
		sed -i -r "s/#Port\s+.*/Port $newPort/" /etc/ssh/sshd_config
	else
		echo "Port $newPort" >> /etc/ssh/sshd_config
	fi
	
	#重启sshd
	local restartCmd=''
	if check_sys sysRelease debian || check_sys sysRelease ubuntu; then
		restartCmd="service ssh restart"
	else
		restartCmd="service sshd restart"
	fi
	$restartCmd

	#验证是否成功
	local nowPort=`netstat -nlpt | awk '/sshd/{print $4}' | grep -o -E "[0-9]+$" | awk 'NR==1{print}'`
	if [[ "$nowPort" == "$newPort" ]]; then
		echo "change ssh server port to $newPort successfully."
	else
		echo "fail to change ssh server port to $newPort."
		echo "rescore the backup file /etc/ssh/sshd_config_original to /etc/ssh/sshd_config..."
		\cp /etc/ssh/sshd_config_original /etc/ssh/sshd_config
		$restartCmd
	fi

	exit
}

#清空iptables表
clean_iptables_rule(){
	iptables -P INPUT ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -X
	iptables -F
}

#iptables首次设置
iptables_init(){
	yes_or_no "we'll clean all rules before configure iptables,are you sure?[Y/n]: " "clean_iptables_rule" "Iptables_settings"

	echo "start to add a iptables rule..."
	echo

	#列出监听端口
	echo "the server is listenning below address:"
	echo 
	netstat -nlpt | awk -F'[/ ]+' 'BEGIN{printf("%-20s %-20s\n%-20s %-20s\n","Program name","Listen Address","------------","--------------")} $1 ~ /tcp/{printf("%-20s %-20s\n",$8,$4)}'
	echo
	#端口选择
	local ports=''
	local ports_arr=''
	while true; do
		read -p "please input one or more ports allowed(ie.22 80 3306): " ports
		ports_arr=($ports)
		local step=false
		for p in ${ports_arr[@]};do
			if ! verify_port "$p";then
				echo "your input is invalid."
				step=false
				break
			fi
			step=true
		done
		$step && break
		[ "$ports" == "" ] && echo "input can not be empty."
	done

	#检查端口是否包含ssh端口,否则自动加入,防止无法连接ssh
	local sshPort=`netstat -nlpt | awk '/sshd/{print $4}' | grep -o -E "[0-9]+$" | awk 'NR==1{print}'`
	local sshNotInput=true
	for p in ${ports_arr[@]};do
		if [[ $p == "$sshPort" ]];then
			sshNotInput=false
		fi
	done

	$sshNotInput && ports="$ports $sshPort"

	#开始设置防火墙
	iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	ports_arr=($ports)
	for p in ${ports_arr[@]};do
		iptables -A INPUT -p tcp -m tcp --dport $p -j ACCEPT
	done

	iptables -A INPUT -i lo -j ACCEPT
	iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
	iptables -A INPUT -p icmp -m icmp --icmp-type 11 -j ACCEPT
	iptables -P INPUT DROP

	save_iptables
	list_iptables
	echo "configure iptables done."
}

#增加规则
add_iptables_rule(){
	#协议选择
	while true; do
		echo -e "1) tcp\n2) udp\n3) all\n"
		read -p "please specify the Protocol(default:tcp): " protocol
		protocol=${protocol:=1}
		case  $protocol in
			1) protocol="-p tcp";break;;
			2) protocol="-p udp";break;;
			3) protocol="";break;;
			*) echo "input error,please input a number(ie.1 2 3)";;
		esac
	done

	#来源ip选择
	while true; do
		read -p "please input the source ip address(ie. 8.8.8.8 192.168.0.0/24,leave blank for all.): " sourceIP
		if [[ $sourceIP != "" ]];then
			local ip=`echo $sourceIP | awk -F'/' '{print $1}'`
			local mask=`echo $sourceIP | awk -F'/' '{print $2}'`
			local step1=false
			local step2=false
			if [[ $mask != "" ]];then
				if echo $mask | grep -q -E "^[0-9]+$" && [[ $mask -ge 0 ]] && [[ $mask -le 32 ]];then
					step1=true
				fi	
			else
				step1=true
			fi	
			
			if verify_ip "$ip";then
				step2=true
			fi
			
			if $step1 && $step2;then
				sourceIP="-s $sourceIP"
				break
			else
				echo "the ip is invalid."
			fi
		else
			break
		fi		
	done

	#端口选择
	local port=''
	if [[ $protocol != "" ]];then
		while true; do
			read -p "please input one port(ie.3306,leave blank for all): " port
			if [[ $port != "" ]];then
				if  verify_port "$port";then
					port="--dport $port"
					break
				else
					echo "your input is invalid."
				fi
			else
				break
			fi	
		done
	fi	

	#动作选择
	while true; do
		echo -e "1) ACCEPT\n2) DROP\n"
		read -p "select action(default:ACCEPT): " action
		action=${action:=1}
		case $action in
			1) action=ACCEPT;break;;
			2) action=DROP;break;;
			*) echo "input error,please input a number(ie.1 2)."
		esac
	done

	#开始添加记录
	local cmd='-A'
	if [[ "$action" == "ACCEPT" ]];then
		cmd="-A"
	elif [[ "$action" == "DROP" ]]; then
		cmd="-I"
	fi
	
	if iptables $cmd INPUT $protocol $sourceIP $port -j $action;then
		echo "add iptables rule successfully."
	else
		echo "add iptables rule failed."
	fi
	save_iptables
	list_iptables
}

#删除规则
delete_iptables_rule(){
	iptables -nL INPUT --line-number --verbose
	echo
	while true; do
		read -p "please input the number according to the first column: " number
		if echo "$number" | grep -q -E "^[0-9]+$";then
			break
		else
			echo "input error,please input a number."
		fi		
	done

	#开始删除规则
	if iptables -D INPUT $number;then
		echo "delete the iptables rule successfully."
	else
		echo "delete the iptables rule failed."
	fi
	save_iptables
	list_iptables
}

#保存iptables 
save_iptables(){
	#保存规则
	if check_sys sysRelease ubuntu || check_sys sysRelease debian;then
		iptables-save > /etc/iptables.up.rule
	elif check_sys sysRelease centos;then
		service iptables save
	fi
}

#开机加载iptables
load_iptables_onboot(){
	if check_sys sysRelease ubuntu || check_sys sysRelease debian;then
		if [[ ! -s "/etc/network/if-pre-up.d/iptablesload" ]]; then
			cat >/etc/network/if-pre-up.d/iptablesload<<EOF
#!/bin/sh
iptables-restore < /etc/iptables.up.rule
exit 0
EOF

		fi

		if [[ ! -s "/etc/network/if-post-down.d/iptablessave" ]]; then
			cat >/etc/network/if-post-down.d/iptablessave<<EOF
#!/bin/sh
iptables-save -c > /etc/iptables.up.rule
exit 0
EOF

		fi

		chmod +x /etc/network/if-post-down.d/iptablessave /etc/network/if-pre-up.d/iptablesload

	elif check_sys sysRelease centos;then
		chkconfig iptables on
	fi	
}

#停止ipables
stop_iptables(){
	save_iptables
	clean_iptables_rule
	list_iptables
}

#恢复iptables
rescore_iptables(){

	if check_sys sysRelease ubuntu || check_sys sysRelease debian;then
		if [ -s "/etc/iptables.up.rule" ];then
			iptables-restore < /etc/iptables.up.rule
			echo "rescore iptables done."
		else
			echo "/etc/iptables.up.rule not found,can not be rescore iptables."
		fi	
	elif check_sys sysRelease centos;then
		service iptables restart
		echo "rescore iptables done."
	fi
	list_iptables
}

#列出iptables
list_iptables(){
	iptables -nL INPUT --verbose
}
#iptales设置
Iptables_settings(){
	check_command_exist "iptables"
	load_iptables_onboot
	local select=''
	while true; do
		echo -e "1) clear all record,setting from nothing.\n2) add a iptables rule.\n3) delete any rule.\n4) backup rules and stop iptables.\n5) rescore iptables\n6) list iptables rules\n" 
		read -p "please input your select(ie 1): " select
		case  $select in
			1) iptables_init;break;;
			2) add_iptables_rule;break;;
			3) delete_iptables_rule;break;;
			4) stop_iptables;break;;
			5) rescore_iptables;break;;
			6) list_iptables;break;;
			*) echo "input error,please input a number.";;
		esac
	done

	yes_or_no "do you want to continue setting iptables[Y/n]: " "Iptables_settings" "echo 'setting iptables done,exit.';exit"
}

#设置时区及同步时间
Set_timezone_and_sync_time(){
	echo "current timezone is $(date +%z)"
	echo "current time is $(date +%Y-%m-%d" "%H:%M:%S)"
	echo
	yes_or_no "would you like to change the timezone[Y/n]: " "echo 'you select change the timezone.'" "echo 'you select do not change the timezone.'"
	if [[ $yn == "y" ]]; then
		timezone=`tzselect`
		echo "start to change the timezone to $timezone..."
		cp /usr/share/zoneinfo/$timezone /etc/localtime
	fi

	echo "start to sync time and add sync command to cronjob..."
	if check_sys sysRelease ubuntu || check_sys sysRelease debian;then
		apt-get -y install ntpdate
		check_command_exist ntpdate
		/usr/sbin/ntpdate -u pool.ntp.org
		! grep -q "/usr/sbin/ntpdate -u pool.ntp.org" /var/spool/cron/crontabs/root > /dev/null 2>&1 && echo "*/10 * * * * /usr/sbin/ntpdate -u pool.ntp.org > /dev/null 2>&1"  >> /var/spool/cron/crontabs/root
		service cron restart
	elif check_sys sysRelease centos; then
		yum -y install ntpdate
		check_command_exist ntpdate
		/usr/sbin/ntpdate -u pool.ntp.org
		! grep -q "/usr/sbin/ntpdate -u pool.ntp.org" /var/spool/cron/root > /dev/null 2>&1 && echo "*/10 * * * * /usr/sbin/ntpdate -u pool.ntp.org > /dev/null 2>&1" >> /var/spool/cron/root
		service crond restart
	fi
	echo "current timezone is $(date +%z)"
	echo "current time is $(date +%Y-%m-%d" "%H:%M:%S)"	

}

#网络分析工具
Network_analysis(){
	LANG=c
	export LANG	
	while true; do
		echo -e "1) real time traffic.\n2) tcp traffic and connection overview.\n3) udp traffic overview\n4) http request count\n"
		read -p "please input your select(ie 1): " select
		case  $select in
			1) realTimeTraffic;break;;
			2) tcpTrafficOverview;break;;
			3) udpTrafficOverview;break;;
			4) httpRequestCount;break;;
			*) echo "input error,please input a number.";;
		esac
	done	
}

#实时流量
realTimeTraffic(){
	local eth=""
	local nic_arr=(`ifconfig | grep -E -o "^[a-z0-9]+" | grep -v "lo" | uniq`)
	local nicLen=${#nic_arr[@]}
	if [[ $nicLen -eq 0 ]]; then
		echo "sorry,I can not detect any network device,please report this issue to author."
		exit 1
	elif [[ $nicLen -eq 1 ]]; then
		eth=$nic_arr
	else
		display_menu nic
		eth=$nic
	fi	

	local clear=true
	local eth_in_peak=0
	local eth_out_peak=0
	local eth_in=0
	local eth_out=0

	while true;do
		#移动光标到0:0位置
		printf "\033[0;0H"
		#清屏并打印Now Peak
		[[ $clear == true ]] && printf "\033[2J" && echo "$eth--------Now--------Peak-----------"
		traffic_be=(`awk -v eth=$eth -F'[: ]+' '{if ($0 ~eth){print $3,$11}}' /proc/net/dev`)
		sleep 2
		traffic_af=(`awk -v eth=$eth -F'[: ]+' '{if ($0 ~eth){print $3,$11}}' /proc/net/dev`)
		#计算速率
		eth_in=$(( (${traffic_af[0]}-${traffic_be[0]})*8/2 ))
		eth_out=$(( (${traffic_af[1]}-${traffic_be[1]})*8/2 ))
		#计算流量峰值
		[[ $eth_in -gt $eth_in_peak ]] && eth_in_peak=$eth_in
		[[ $eth_out -gt $eth_out_peak ]] && eth_out_peak=$eth_out
		#移动光标到2:1
		printf "\033[2;1H"
		#清除当前行
		printf "\033[K"    
		printf "%-20s %-20s\n" "Receive:  $(bit_to_human_readable $eth_in)" "$(bit_to_human_readable $eth_in_peak)"
		#清除当前行
		printf "\033[K"
		printf "%-20s %-20s\n" "Transmit: $(bit_to_human_readable $eth_out)" "$(bit_to_human_readable $eth_out_peak)"
		[[ $clear == true ]] && clear=false
	done
}

#tcp流量概览
tcpTrafficOverview(){
    if ! which tshark > /dev/null;then
        echo "tshark not found,going to install it."
        if check_sys packageManager apt;then
            apt-get -y install tshark
        elif check_sys packageManager yum;then
            yum -y install wireshark
        fi
    fi
 
    local reg=""
    local eth=""
    local nic_arr=(`ifconfig | grep -E -o "^[a-z0-9]+" | grep -v "lo" | uniq`)
    local nicLen=${#nic_arr[@]}
    if [[ $nicLen -eq 0 ]]; then
        echo "sorry,I can not detect any network device,please report this issue to author."
        exit 1
    elif [[ $nicLen -eq 1 ]]; then
        eth=$nic_arr
    else
        display_menu nic
        eth=$nic
    fi
 
    echo "please wait for 10s to generate network data..."
    echo
    #当前流量值
    local traffic_be=(`awk -v eth=$eth -F'[: ]+' '{if ($0 ~eth){print $3,$11}}' /proc/net/dev`)
    #tshark监听网络
	tshark -n -s 100 -i $eth -f 'ip' -a duration:10 -R 'tcp' -T fields -e ip.src_host -e tcp.srcport -e ip.dst_host  -e tcp.dstport  -e ip.len | grep -v , > /tmp/tcp.txt
    clear

    #10s后流量值
    local traffic_af=(`awk -v eth=$eth -F'[: ]+' '{if ($0 ~eth){print $3,$11}}' /proc/net/dev`)
    #打印10s平均速率
    local eth_in=$(( (${traffic_af[0]}-${traffic_be[0]})*8/10 ))
    local eth_out=$(( (${traffic_af[1]}-${traffic_be[1]})*8/10 ))
    echo -e "\033[32mnetwork device $eth average traffic in 10s: \033[0m"
    echo "$eth Receive: $(bit_to_human_readable $eth_in)/s"
    echo "$eth Transmit: $(bit_to_human_readable $eth_out)/s"
    echo

    local ipReg=$(ifconfig | grep -A 1 $eth | awk -F'[: ]+' '$0~/inet addr:/{printf $4"|"}' | sed -e 's/|$//' -e 's/^/^(/' -e 's/$/)/')
  

    #统计每个端口在10s内的平均流量
    echo -e "\033[32maverage traffic in 10s base on server port: \033[0m"
	awk -F'\t' -v ipReg=$ipReg '{if ($0 ~ ipReg) {line=$1":"$2}else{line=$3":"$4};sum[line]+=$NF*8/10}END{for (line in sum){printf "%s %d\n",line,sum[line]}}' /tmp/tcp.txt | sort -k 2 -nr | head -n 10 | while read addr len;do
			echo "$addr $(bit_to_human_readable $len)/s"
	done
	
    #echo -ne "\033[11A"
    #echo -ne "\033[50C"
	echo
    echo -e "\033[32maverage traffic in 10s base on client port: \033[0m"
	awk -F'\t' -v ipReg=$ipReg '{if ($0 ~ ipReg) {line=$3":"$4}else{line=$1":"$2};sum[line]+=$NF*8/10}END{for (line in sum){printf "%s %d\n",line,sum[line]}}' /tmp/tcp.txt | sort -k 2 -nr | head -n 10 | while read addr len;do
			echo "$addr $(bit_to_human_readable $len)/s"
	done  
        
    echo

    #统计在10s内占用带宽最大的前10个ip
    echo -e "\033[32mtop 10 ip average traffic in 10s base on server: \033[0m"
	awk -F'\t' -v ipReg=$ipReg '{if ($0 ~ ipReg) {line=$1}else{line=$3};sum[line]+=$NF*8/10}END{for (line in sum){printf "%s %d\n",line,sum[line]}}' /tmp/tcp.txt | sort -k 2 -nr | head -n 10 | while read addr len;do
			echo "$addr $(bit_to_human_readable $len)/s"
	done
    #echo -ne "\033[11A"
    #echo -ne "\033[50C"
	echo
    echo -e "\033[32mtop 10 ip average traffic in 10s base on client: \033[0m"
	awk -F'\t' -v ipReg=$ipReg '{if ($0 ~ ipReg) {line=$3}else{line=$1};sum[line]+=$NF*8/10}END{for (line in sum){printf "%s %d\n",line,sum[line]}}' /tmp/tcp.txt | sort -k 2 -nr | head -n 10 | while read addr len;do
			echo "$addr $(bit_to_human_readable $len)/s"
	done

    echo
    #统计连接状态
    local regSS=$(ifconfig | grep -A 1 $eth | awk -F'[: ]+' '$0~/inet addr:/{printf $4"|"}' | sed -e 's/|$//')
    ss -an | grep -v -E "LISTEN|UNCONN" | grep -E "$regSS" > /tmp/ss
    echo -e "\033[32mconnection state count: \033[0m"
    awk 'NR>1{sum[$(NF-4)]+=1}END{for (state in sum){print state,sum[state]}}' /tmp/ss | sort -k 2 -nr
    echo
    #统计各端口连接状态
    echo -e "\033[32mconnection state count by port base on server: \033[0m"
    awk 'NR>1{sum[$(NF-4),$(NF-1)]+=1}END{for (key in sum){split(key,subkey,SUBSEP);print subkey[1],subkey[2],sum[subkey[1],subkey[2]]}}' /tmp/ss | sort -k 3 -nr | head -n 10   
    echo -ne "\033[11A"
    echo -ne "\033[50C"
    echo -e "\033[32mconnection state count by port base on client: \033[0m"
    awk 'NR>1{sum[$(NF-4),$(NF)]+=1}END{for (key in sum){split(key,subkey,SUBSEP);print subkey[1],subkey[2],sum[subkey[1],subkey[2]]}}' /tmp/ss | sort -k 3 -nr | head -n 10 | awk '{print "\033[50C"$0}'   
    echo   
    #统计状态为ESTAB连接数最多的前10个IP
    echo -e "\033[32mtop 10 ip ESTAB state count at port 80: \033[0m"
    cat /tmp/ss | grep ESTAB | awk -F'[: ]+' '{sum[$(NF-2)]+=1}END{for (ip in sum){print ip,sum[ip]}}' | sort -k 2 -nr | head -n 10
    echo
    #统计状态为SYN-RECV连接数最多的前10个IP
    echo -e "\033[32mtop 10 ip SYN-RECV state count at port 80: \033[0m"
    cat /tmp/ss | grep -E "$regSS" | grep SYN-RECV | awk -F'[: ]+' '{sum[$(NF-2)]+=1}END{for (ip in sum){print ip,sum[ip]}}' | sort -k 2 -nr | head -n 10
}

#udp流量概览
udpTrafficOverview(){
    if ! which tshark > /dev/null;then
        echo "tshark not found,going to install it."
        if check_sys packageManager apt;then
            apt-get -y install tshark
        elif check_sys packageManager yum;then
            yum -y install wireshark
        fi
    fi
 
    local reg=""
    local eth=""
    local nic_arr=(`ifconfig | grep -E -o "^[a-z0-9]+" | grep -v "lo" | uniq`)
    local nicLen=${#nic_arr[@]}
    if [[ $nicLen -eq 0 ]]; then
        echo "sorry,I can not detect any network device,please report this issue to author."
        exit 1
    elif [[ $nicLen -eq 1 ]]; then
        eth=$nic_arr
    else
        display_menu nic
        eth=$nic
    fi
 
    echo "please wait for 10s to generate network data..."
    echo
    #当前流量值
    local traffic_be=(`awk -v eth=$eth -F'[: ]+' '{if ($0 ~eth){print $3,$11}}' /proc/net/dev`)
    #tshark监听网络
	tshark -n -s 100 -i $eth -f 'ip' -a duration:10 -R 'udp' -T fields -e ip.src_host -e udp.srcport -e ip.dst_host  -e udp.dstport  -e ip.len | grep -v , > /tmp/udp.txt
    clear

    #10s后流量值
    local traffic_af=(`awk -v eth=$eth -F'[: ]+' '{if ($0 ~eth){print $3,$11}}' /proc/net/dev`)
    #打印10s平均速率
    local eth_in=$(( (${traffic_af[0]}-${traffic_be[0]})*8/10 ))
    local eth_out=$(( (${traffic_af[1]}-${traffic_be[1]})*8/10 ))
    echo -e "\033[32mnetwork device $eth average traffic in 10s: \033[0m"
    echo "$eth Receive: $(bit_to_human_readable $eth_in)/s"
    echo "$eth Transmit: $(bit_to_human_readable $eth_out)/s"
    echo
	
    local ipReg=$(ifconfig | grep -A 1 $eth | awk -F'[: ]+' '$0~/inet addr:/{printf $4"|"}' | sed -e 's/|$//' -e 's/^/^(/' -e 's/$/)/')
 
    #统计每个端口在10s内的平均流量
    echo -e "\033[32maverage traffic in 10s base on server port: \033[0m"
	awk -F'\t' -v ipReg=$ipReg '{if ($0 ~ ipReg) {line=$1":"$2}else{line=$3":"$4};sum[line]+=$NF*8/10}END{for (line in sum){printf "%s %d\n",line,sum[line]}}' /tmp/udp.txt | sort -k 2 -nr | head -n 10 | while read addr len;do
			echo "$addr $(bit_to_human_readable $len)/s"
	done
	
    #echo -ne "\033[11A"
    #echo -ne "\033[50C"
	echo
    echo -e "\033[32maverage traffic in 10s base on client port: \033[0m"
	awk -F'\t' -v ipReg=$ipReg '{if ($0 ~ ipReg) {line=$3":"$4}else{line=$1":"$2};sum[line]+=$NF*8/10}END{for (line in sum){printf "%s %d\n",line,sum[line]}}' /tmp/udp.txt | sort -k 2 -nr | head -n 10 | while read addr len;do
			echo "$addr $(bit_to_human_readable $len)/s"
	done  
        
    echo

    #统计在10s内占用带宽最大的前10个ip
    echo -e "\033[32mtop 10 ip average traffic in 10s base on server: \033[0m"
	awk -F'\t' -v ipReg=$ipReg '{if ($0 ~ ipReg) {line=$1}else{line=$3};sum[line]+=$NF*8/10}END{for (line in sum){printf "%s %d\n",line,sum[line]}}' /tmp/udp.txt | sort -k 2 -nr | head -n 10 | while read addr len;do
			echo "$addr $(bit_to_human_readable $len)/s"
	done
    #echo -ne "\033[11A"
    #echo -ne "\033[50C"
	echo
    echo -e "\033[32mtop 10 ip average traffic in 10s base on client: \033[0m"
	awk -F'\t' -v ipReg=$ipReg '{if ($0 ~ ipReg) {line=$3}else{line=$1};sum[line]+=$NF*8/10}END{for (line in sum){printf "%s %d\n",line,sum[line]}}' /tmp/udp.txt | sort -k 2 -nr | head -n 10 | while read addr len;do
			echo "$addr $(bit_to_human_readable $len)/s"
	done
}

#http请求统计
httpRequestCount(){
    if ! which tshark > /dev/null;then
        echo "tshark not found,going to install it."
        if check_sys packageManager apt;then
            apt-get -y install tshark
        elif check_sys packageManager yum;then
            yum -y install wireshark
        fi
    fi

    local eth=""
    local nic_arr=(`ifconfig | grep -E -o "^[a-z0-9]+" | grep -v "lo" | uniq`)
    local nicLen=${#nic_arr[@]}
    if [[ $nicLen -eq 0 ]]; then
        echo "sorry,I can not detect any network device,please report this issue to author."
        exit 1
    elif [[ $nicLen -eq 1 ]]; then
        eth=$nic_arr
    else
        display_menu nic
        eth=$nic
    fi
 
    echo "please wait for 10s to generate network data..."
    echo
	# tshark抓包
	tshark -n -s 512 -i $eth -a duration:10 -w /tmp/tcp.cap
	# 解析包
	tshark -n -R 'http.host and http.request.uri' -T fields -e http.host -e http.request.uri  -r /tmp/tcp.cap | tr -d '\t' > /tmp/url.txt
	echo -e "\033[32mHTTP Requests Per seconds:\033[0m"
	(( qps=$(wc -l /tmp/url.txt | cut -d ' ' -f1) / 10 ))
	echo "${qps}/s"
	echo
	echo -e "\033[32mTop 10 request url for all requests excluding static resource:\033[0m"
	grep -v -i -E "\.(gif|png|jpg|jpeg|ico|js|swf|css)" /tmp/url.txt | sort | uniq -c | sort -nr | head -n 10
	echo
	echo -e "\033[32mTop 10 request url for all requests excluding static resource and without args:\033[0m"
	grep -v -i -E "\.(gif|png|jpg|jpeg|ico|js|swf|css)" /tmp/url.txt | awk -F'?' '{print $1}' |  sort | uniq -c | sort -nr | head -n 10
	echo
	echo -e "\033[32mTop 10 request url for all requests:\033[0m"
	cat /tmp/url.txt | sort | uniq -c | sort -nr | head -n 10
	echo
	echo -e "\033[32mRespond code count:\033[0m"
	tshark -n -R 'http.response.code' -T fields -e http.response.code -r /tmp/tcp.cap | sort | uniq -c | sort -nr
}
