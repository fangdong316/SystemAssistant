#!/bin/bash

# version:1.0
# author:wdfang
# date:2014-08-28
# mail:fangdong316@126.com


# Display install software menu
install_software(){
	clear
	install_software_menu
	#display_menu install_soft_menu
	if [ "$upgrade" == "back_to_main_menu" ];then
		clear
		mainMenu
	else
		eval $upgrade
	fi
}

# Install software menu
install_software_menu(){

	echo  "-------------------------------------------------------"
	echo -e "1) Apache Http Server\n2) Nginx\n3) JDK\n4) Tomcat\n5) Back to main menu"
	echo  "-------------------------------------------------------"
	
	while true
	do
		read -p "Please select the software you like to install: " software
		case $software in
			 1) install_apche;break;;
			 2) install_nginx;break;;
			 3) install_jdk;break;;
			 4) install_tomcat;break;;
			 5) clear;mainMenu;break;;
			 *) echo "input error.";;
		esac
	done
}

install_apche(){

    # Verify Requirements
	echo  "-------------------------------------------------------"
	echo  "Verify System Requirements"
	echo  "Check software development environment."
	echo  "System Ready for Installation"
	echo  "-------------------------------------------------------"
	
	apache_version="httpd-2.2.27"
	apache_filename="$apache_version.tar.gz"
	apache_offical_link="http://archive.apache.org/dist/httpd/httpd-2.2.27.tar.gz"
	
	if [ -s $cur_dir/soft/$apache_filename ]; then
		echo "$apache_filename...............[found]"
	else
		echo "Error: $apache_filename not found!!!Download now......"
		download_file "${apache_offical_link}" "${apache_filename}" "${cur_dir}/soft"
	fi
	echo  "-------------------------------------------------------"
	
	#apache location
	read -p "Install location(default:/opt/apache): " apache_location
	if [ "$apache_location" = "" ]; then
		apache_location="/opt/apache"
	fi

	echo  "-------------------------------------------------------"
	echo  "Install location: [$apache_location]"
	echo  "-------------------------------------------------------"

	#configure args
	apache_configure_args="--prefix=${apache_location} --enable-so --enable-deflate=shared --enable-ssl=shared --enable-expires=shared  --enable-headers=shared --enable-rewrite=shared --enable-static-support"
	
	echo  "-------------------------------------------------------"
	
	echo -n "Press Enter to continue....."
	read
	
	#提示是否更改编译参数
	#echo -e "Apache Http Server configure parameter is:\n${apache_configure_args}\n"

	# compile & install apache http server
	tar -zxvf $cur_dir/soft/$apache_filename -C $cur_dir/soft
	cd $cur_dir/soft/$apache_version
	./configure $apache_configure_args
	make && make install
	
	echo  "-------------------------------------------------------"
	echo  "Apache Http Server installation is complete"
	echo  "-------------------------------------------------------"
}

install_nginx(){

	# Verify Requirements
	echo  "-------------------------------------------------------"
	echo  "Verify System Requirements"
	echo  "System Ready for Installation"
	echo  "-------------------------------------------------------"
	
	nginx_version="nginx-1.6.0"
	nginx_filename="${nginx_version}.tar.gz"
	nginx_offical_link="http://nginx.org/download/nginx-1.6.0.tar.gz"
	
	if [ -s $cur_dir/soft/$nginx_filename ]; then
		echo "$nginx_filename...............[found]"
	else
		echo "Error: $nginx_filename not found!!!Download now....."
		download_file "${nginx_offical_link}" "${nginx_filename}" "${cur_dir}/soft"
	fi
	echo  "-------------------------------------------------------"
	
	read -p "Install location(default:/usr/local/nginx): " nginx_location
	if [ "$nginx_location" = "" ]; then
		nginx_location="/usr/local/nginx"
	fi
	echo  "-------------------------------------------------------"
	echo  "Install location: [$nginx_location]"
	echo  "-------------------------------------------------------"
	
	#Nginx configure args
	#nginx_configure_args="--prefix=${nginx_location} --enable-so --enable-deflate=shared --enable-ssl=shared --enable-expires=shared  --enable-headers=shared --enable-rewrite=shared --enable-static-support"
	nginx_configure_args="--prefix=${nginx_location} --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module --with-ipv6"
	
	#提示是否更改编译参数
	echo -e "Nginx configure parameter is:\n${nginx_configure_args}\n"

	echo  "-------------------------------------------------------"
	
	echo -n "Press Enter to continue....."
	read
	
	# compile & install apache http server
	tar -zxvf $cur_dir/soft/$nginx_filename -C $cur_dir/soft
	cd $cur_dir/soft/$nginx_version
	./configure $nginx_configure_args
	make && make install
	
	#Start Server

	cp $cur_dir/conf/template/nginx /etc/init.d
	chmod +x /etc/init.d/nginx
	/etc/init.d/nginx/start

	ps -ef|grep nginx
	
	echo  "-------------------------------------------------------"
	echo  "Nginx installation is complete"
	echo  "-------------------------------------------------------"
}

install_jdk(){

	# Verify Requirements
	echo  "-------------------------------------------------------"
	echo  "Verify System Requirements"
	echo  "`java -version`"
	echo  "System Ready for Installation"
	echo  "-------------------------------------------------------"


	# Remove Openjdk if exists.
	remove_openjdk(){
	for i in $(rpm -qa | grep jdk | grep -v grep)
	do
		echo "Deleting rpm ---> "$i
		rpm -e --nodeps $i
	done

	if [[ ! -z $(rpm -qa | grep jdk | grep -v grep) ]];then 
		echo "-->Failed to remove the defult Jdk."
	else
		echo ""
	fi
	}
	
	
	
	# JDK info
	jdk_version="jdk-6u33"
	jdk_filename="${jdk_version}-linux-x64.bin"
	jdk_offical_link="http://nginx.org/download/nginx-1.6.0.tar.gz"
	
	# Find jdk file 
	if [ -s $cur_dir/soft/$jdk_filename ]; then
		echo "$jdk_filename...............[found]"
	else
		echo "Error: $jdk_filename not found!!!Download now....."
		download_file "${jdk_offical_link}" "${jdk_filename}" "${cur_dir}/soft"
	fi
	echo  "-------------------------------------------------------"
	
	# JDK location
	read -p "Install location(default:/usr/java): " jdk_location
	if [ "$jdk_location" = "" ]; then
		jdk_location="/usr/java"
	fi
	
	echo  "-------------------------------------------------------"
	echo  "Install location: [$jdk_location]"
	echo  "-------------------------------------------------------"
	
	# unzip and install JDK
	if [ ! -d $jdk_location ];then
		mkdir $jdk_location
	fi
	cp $cur_dir/soft/$jdk_filename $jdk_location
	chmod +x $jdk_location/$jdk_filename
	cd $jdk_location/
	./$jdk_filename
	
	
	# if [[ ! -z $(ls /user/java/jdk1.6.0_45) ]];then
	#	echo "-->Failed to install JDK (jdk-6u45-linux-x64 : /usr/java/jdk1.6.0_45)"
	#else 
	#	echo "-->JDK has been successed installed."
	#	echo "java -version"
	#		java -version
	#	echo "javac -version"
	#		javac -version
	#	echo "ls \$JAVA_HOME"$JAVA_HOME
	#	ls $JAVA_HOME
	#fi


	#cp /etc/profile /etc/profile.beforeAddJDKenv.20140507.bak
	#echo "JAVA_HOME=/usr/java/jdk1.6.0_33" >> /etc/profile
	#echo "CLASSPATH=.:$JAVA_HOME/lib.tools.jar" >> /etc/profile
	#echo "PATH=$JAVA_HOME/bin:$PATH" >> /etc/profile
	#echo "export JAVA_HOME CLASSPATH PATH" >> /etc/profileo 
	#echo "CLASSPATH=.:$JAVA_HOME/lib.tools.jar" >> /etc/profile
	#echo "PATH=$JAVA_HOME/bin:$PATH" >> /etc/profile
	#echo "export JAVA_HOME CLASSPATH PATH" >> /etc/profile
	
	#echo "-->JDK environment has been successed set in /etc/profile."
	
	#cat >>/etc/profile<<eof
	#JAVA_HOME=/usr/java/jdk1.6.0_33
	#CLASSPATH=$JAVA_HOME/lib/tools.jar:$JAVA_HOME/lib/dt.jar
	#PATH=$JAVA_HOME/bin:$PATH
	#export JAVA_HOME CLASSPATH PATH
	#eof
	
	source /etc/profile
    
	echo  "`java -version`"
	echo  "-------------------------------------------------------"
	echo  "JDK installation is complete!"
	echo  "-------------------------------------------------------"
}

install_tomcat(){

    # Verify Requirements
	echo  "-------------------------------------------------------"
	echo  "Verify System Requirements"
	echo  "System Ready for Installation"
	echo  "-------------------------------------------------------"
	
	tomcat_version="apache-tomcat-7.0.55"
	tomcat_filename="${tomcat_version}.tar.gz"
	tomcat_offical_link="http://mirror.bit.edu.cn/apache/tomcat/tomcat-7/v7.0.55/bin/apache-tomcat-7.0.55.tar.gz"
	
	if [ -s $cur_dir/soft/$tomcat_filename ]; then
		echo "$tomcat_filename...............[found]"
	else
		echo "Error: $tomcat_filename not found!!!Download now......"
		download_file "${tomcat_offical_link}" "${tomcat_filename}" "${cur_dir}/soft"
	fi
	echo  "-------------------------------------------------------"
	
	#tomcat location
	read -p "Install location(default:/opt): " tomcat_location
	if [ "$tomcat_location" = "" ]; then
		tomcat_location="/opt"
	fi
	echo "Install location: $tomcat_location"
	echo  "-------------------------------------------------------"
	
	echo -n "Press Enter to continue....."
	read
	
	tar -zxvf $cur_dir/soft/$tomcat_filename -C $tomcat_location
	
	echo  "-------------------------------------------------------"
	echo  "Tomcat installation is complete!"
	echo  "-------------------------------------------------------"
}