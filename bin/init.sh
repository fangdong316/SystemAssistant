#!/bin/bash

# version:1.0
# author:wdfang
# date:2014-08-08
# mail:fangdong316@126.com

cur_dir=`pwd`

# MainMenu
mainMenu(){
while true
do
	echo  "+-----------------------------------------------------+"
	echo  "   User:`whoami`    Host:`hostname`"
	echo  "+-------------------SystemAssistant-------------------+"
	echo  
	echo  "1) Software Installation."
	echo  "2) Upgrade Software."
	echo  "3) Some Useful Tools."
	echo  "4) Exit."
	echo
	echo  "+-----------------------------------------------------+"
	read -p "Please select: " select
	echo
	case $select in
	1) echo "You select Software Installation." ; install_software ; break;;
	2) echo "You select Upgrade Software." ; upgrade_software ; break;;
	3) echo "You select Some Useful Tools." ; tools_setting ; break;;
	4) echo "You select exit." ; exit 1;;
	*) echo "Input error.";;
	esac
	echo  "-------------------------------------------------------"
done
}

