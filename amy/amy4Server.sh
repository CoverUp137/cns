#!/bin/bash

#Stop amy4Server & delete amy4Server files.
Delete() {
	systemctl disable amy4Server.service
	chkconfig --del amy4Server
	/etc/init.d/amy4Server disable
	if [ -f "${amy4Server_install_dir:=/usr/local/amy4Server}/amy4Server.init" ]; then
		"$amy4Server_install_dir"/amy4Server.init stop
		rm -rf "$amy4Server_install_dir"
	fi
	rm -f /etc/init.d/amy4Server /lib/systemd/system/amy4Server.service /etc/rc.d/rc5.d/S99amy4Server /etc/rc.d/S99amy4Server /etc/rc5.d/S99amy4Server
}

#Print error message and exit.
Error() {
	echo $echo_e_arg "\033[41;37m$1\033[0m"
	echo -n "remove amy4Server?[y]: "
	read remove
	echo "$remove"|grep -qi 'n' || Delete
	exit 1
}

#Make amy4Server start cmd
Config() {
	if [ -z "$amy4Server_install_dir" ]; then  #Variables come from the environment
		echo -n "请输入内部账号（如果没有请忽略）: "
		read amy4Server_auth_secret
		echo -n "请输入内部密码（如果没有请忽略）: "
		read amy4Server_secret_password
		echo -n "请输入amy4Server服务端口: "
		read amy4Server_port
		echo -n "请输入amy4Server连接密码(ClientKey): "
		read amy4Server_clientkey
		echo -n "服务器是否支持IPV6[n]: "
		read ipv6_support
		echo -n "请输入安装目录(默认/usr/local/amy4Server): "  #安装目录
		read amy4Server_install_dir
		[ -z "$amy4Server_install_dir" ] && amy4Server_install_dir=/usr/local/amy4Server
		echo -n "安装UPX压缩版本?[n]: "
		read amy4Server_UPX
		echo -n "是否使用HTTP代理拉取amy4Server配置(1.百度 2.联通UC):"
		read amy4Server_proxy_opt
	fi
	echo "$amy4Server_install_dir"|grep -q '^/' || amy4Server_install_dir="$PWD/$amy4Server_install_dir"
	[ -z "$amy4Server_auth_secret" ] && amy4Server_auth_secret='free'
	[ -z "$amy4Server_secret_password" ] && amy4Server_secret_password='free'
	echo "$ipv6_support"|grep -qi '^y' && ipv6_support="true" || ipv6_support="false"
	echo "$amy4Server_UPX"|grep -qi '^y' && amy4Server_UPX="upx" || amy4Server_UPX=""
	if [ "$amy4Server_proxy_opt" = '1' ]; then
		export http_proxy="157.0.148.53:443"
	elif [ "$amy4Server_proxy_opt" = '2' ]; then
		export http_proxy="101.71.140.5:8128"
	elif [ "$amy4Server_proxy_opt" != 'n' -a -n "$amy4Server_proxy_opt" ]; then
		export http_proxy="amy4Server_proxy_opt"
	fi
}

GetAbi() {
	machine=`uname -m`
	#mips[...] use 'le' version
	if echo "$machine"|grep -q 'mips64'; then
		shContent=`cat "$SHELL"`
		[ "${shContent:5:1}" = `echo $echo_e_arg "\x01"` ] && machine='mips64le' || machine='mips64'
	elif echo "$machine"|grep -q 'mips'; then
		shContent=`cat "$SHELL"`
		[ "${shContent:5:1}" = `echo $echo_e_arg "\x01"` ] && machine='mipsle' || machine='mips'
	elif echo "$machine"|grep -Eq 'i686|i386'; then
		machine='386'
	elif echo "$machine"|grep -Eq 'armv7|armv6'; then
		machine='arm'
	elif echo "$machine"|grep -Eq 'armv8|aarch64'; then
		machine='arm64'
	elif echo "$machine"|grep -q 's390x'; then
		machine='s390x'
	else
		machine='amd64'
	fi
}

GetOs() {
	if [ -f '/system/bin/sh' -a "$machine" = 'arm64' ]; then
		os=android
	else
		os=linux
	fi
}

#install amy4Server files
InstallFiles() {
	GetAbi
	GetOs
	if echo "$machine" | grep -q '^mips'; then
		cat /proc/cpuinfo | grep -qiE 'fpu|neon|vfp|softfp|asimd' || softfloat='_softfloat'
	fi
	mkdir -p "$amy4Server_install_dir" || Error "Create amy4Server install directory failed."
	cd "$amy4Server_install_dir" || exit 1
	
    github_repo="https://gh.0507.dpdns.org/https://github.com/CoverUp137/cns/releases/download/amy"
    download_tool amy4Server "$github_repo/amy4Server-${os}_${machine}" || Error "amy4Server download failed."
	download_tool amy4Server.init https://gh.0507.dpdns.org/https://raw.githubusercontent.com/CoverUp137/cns/refs/heads/main/amy/amy4Server.init || Error "amy4Server.init download failed."
	[ -f '/etc/rc.common' ] && rcCommon='/etc/rc.common'
	sed -i "s~#!/bin/sh~#!$SHELL $rcCommon~" amy4Server.init
	sed -i "s~\[amy4Server_install_dir\]~$amy4Server_install_dir~g" amy4Server.init
	sed -i "s~\[amy4Server_tcp_port_list\]~$amy4Server_port~g" amy4Server.init
	ln -s "$amy4Server_install_dir/amy4Server.init" /etc/init.d/amy4Server
	cat >amy4Server.json <<-EOF
	{
		"ListenAddr": ":${amy4Server_port}",
		"IPV6Support": ${ipv6_support},
		"PidFile": "${amy4Server_install_dir}/run.pid",
		"ClientKeys": ["$amy4Server_clientkey"],
		"AmyVerifyServer": {
			"authUser": "${amy4Server_auth_secret}",
			"authPass": "${amy4Server_secret_password}",
			"proxyAddr": "$http_proxy"
		}
	}
	EOF
	chmod -R +rwx "$amy4Server_install_dir" /etc/init.d/amy4Server
	if type systemctl &>/dev/null && [ -z "$(systemctl --failed|grep -q 'Host is down')" ]; then
		download_tool /lib/systemd/system/amy4Server.service https://gh.0507.dpdns.org/https://raw.githubusercontent.com/CoverUp137/cns/refs/heads/main/amy/amy4Server.service || Error "amy4Server.service download failed."
		chmod +rwx /lib/systemd/system/amy4Server.service
		sed -i "s~\[amy4Server_install_dir\]~$amy4Server_install_dir~g"  /lib/systemd/system/amy4Server.service
		systemctl daemon-reload
	fi
}

#install initialization
InstallInit() {
	echo -n "make a update?[n]: "
	read update
	PM=`type apt-get &>/dev/null || type yum &>/dev/null`
	PM=`echo "$PM" | grep -o '/.*'`
	echo "$update"|grep -qi 'y' && $PM -y update
	$PM -y install curl wget unzip sed
	if type curl &>/dev/null; then
		download_tool() {
			curl --header "Proxy-Authorization: Basic dWMxMC43LjE2My4xNDQ6MWY0N2QzZWY1M2IwMzU0NDM0NTFjN2VlNzg3M2ZmMzg=" --header "X-T5-Auth: 1967948331"  --user-agent "curl baiduboxapp" -L -ko $@
		}
	else
		download_tool() {
			wget --header "Proxy-Authorization: Basic dWMxMC43LjE2My4xNDQ6MWY0N2QzZWY1M2IwMzU0NDM0NTFjN2VlNzg3M2ZmMzg=" --header "X-T5-Auth: 1967948331"  --user-agent "curl baiduboxapp" --no-check-certificate -O $@
		}
	fi
}

AddAutoStart() {
	if [ -n "$rcCommon" ]; then
		if /etc/init.d/amy4Server enable; then
			echo '已添加开机自启, 如需关闭请执行: /etc/init.d/amy4Server disable'
			return
		fi
	fi
	if type systemctl &>/dev/null && [ -z "$(systemctl --failed|grep -q 'Host is down')" ]; then
		if systemctl enable amy4Server &>/dev/null; then
			echo '已添加开机自启, 如需关闭请执行: systemctl disable amy4Server'
			return
		fi
	fi
	if type chkconfig &>/dev/null; then
		if chkconfig --add amy4Server &>/dev/null && chkconfig amy4Server on &>/dev/null; then
			echo '已添加开机自启, 如需关闭请执行: chkconfig amy4Server off'
			return
		fi
	fi
	if [ -d '/etc/rc.d/rc5.d' -a -f '/etc/init.d/amy4Server' ]; then
		if ln -s '/etc/init.d/amy4Server' '/etc/rc.d/rc5.d/S99amy4Server'; then
			echo '已添加开机自启, 如需关闭请执行: rm -f /etc/rc.d/rc5.d/S99amy4Server'
			return
		fi
	fi
	if [ -d '/etc/rc5.d' -a -f '/etc/init.d/amy4Server' ]; then
		if ln -s '/etc/init.d/amy4Server' '/etc/rc5.d/S99amy4Server'; then
			echo '已添加开机自启, 如需关闭请执行: rm -f /etc/rc5.d/S99amy4Server'
			return
		fi
	fi
	if [ -d '/etc/rc.d' -a -f '/etc/init.d/amy4Server' ]; then
		if ln -s '/etc/init.d/amy4Server' '/etc/rc.d/S99amy4Server'; then
			echo '已添加开机自启, 如需关闭请执行: rm -f /etc/rc.d/S99amy4Server'
			return
		fi
	fi
	echo '没有添加开机自启, 如需开启请手动添加'
}

Install() {
	Config
	Delete >/dev/null 2>&1
	InstallInit
	InstallFiles
	ret=`"${amy4Server_install_dir}/amy4Server.init" start`
	if ! echo "$ret"|grep -q 'OK' || echo "$ret"|grep -q 'FAILED'; then
		Error "amy4Server install failed."
	fi
	type systemctl &>/dev/null && [ -z "$(systemctl --failed|grep -q 'Host is down')" ] && systemctl restart amy4Server
	echo $echo_e_arg \
		"\033[44;37mamy4Server install success.\033[0;34m
		\r	amy4Server server port:\033[35G${amy4Server_port}
		\r	amy4Server auth secret:\033[35G${amy4Server_auth_secret}
		\r	amy4Server client key:\033[35G${amy4Server_clientkey}
		\r`[ -f /etc/init.d/amy4Server ] && /etc/init.d/amy4Server usage || \"$amy4Server_install_dir/amy4Server.init\" usage`
		\r`AddAutoStart`\033[0m"
}

Uninstall() {
	if [ -z "$amy4Server_install_dir" ]; then
		echo -n "Please input amy4Server install directory(default is /usr/local/amy4Server): "
		read amy4Server_install_dir
	fi
	Delete >/dev/null 2>&1 && \
		echo $echo_e_arg "\n\033[44;37mamy4Server uninstall success.\033[0m" || \
		echo $echo_e_arg "\n\033[41;37mamy4Server uninstall failed.\033[0m"
}

#script initialization
ScriptInit() {
	emulate bash 2>/dev/null #zsh emulation mode
	if echo -e ''|grep -q 'e'; then
		echo_e_arg=''
		echo_E_arg=''
	else
		echo_e_arg='-e'
		echo_E_arg='-E'
	fi
}

ScriptInit
echo $*|grep -qi uninstall && Uninstall || Install
