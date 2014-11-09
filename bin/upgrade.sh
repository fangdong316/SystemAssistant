#!/bin/bash

# version:1.0
# author:wdfang
# date:2014-08-08
# mail:fangdong316@126.com

cur_dir=`pwd`

# Display upgrade software menu
upgrade_software(){
	clear
	display_menu upgrade
	if [ "$upgrade" == "back_to_main_menu" ];then
		clear
		mainMenu
	else
		eval $upgrade
	fi
}
