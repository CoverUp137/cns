#!/bin/bash

#Stop xray & delete xray files.
Delete() {
	systemctl disable xray.service
	rm -rf /etc/init.d/xray /lib/systemd/system/xray.service
	if [ -f "${xray_install_directory:=/usr/local/xray}/xray.init" ]; then
		"$xray_install_directory"/xray.init stop
		rm -rf "$xray_install_directory"
	fi
}

#Print error message and exit.
Error() {
	echo $echo_e_arg "\033[41;37m$1\033[0m"
	echo -n "remove xray?[y]: "
	read remove
	echo "$remove"|grep -qi 'n' || Delete
	exit 1
}

makeTcpInbound() {
local port="$1"
local securityConfig="$2"
local protocol="$3"
local flow="$4"
echo '{
			"port": "'$port'",
			"protocol": "'$protocol'",
			"settings": {
				"udp": true,
				"clients": [{
					"id": "'$uuid'",
					"flow": "'$flow'",
					"level": 0,
					"alterId": 0
				}],
				"decryption": "none"
			},
			"streamSettings": {
				"sockopt": {
					"tcpFastOpen": '$tcpFastOpen'
				},
				"network": "tcp"'$securityConfig'
			}
		}'
}

makeTcpHttpInbound() {
local port="$1"
local securityConfig="$2"
local protocol="$3"
echo '{
			"port": "'$port'",
			"protocol": "'$protocol'",
			"settings": {
				"udp": true,
				"clients": [{
					"id": "'$uuid'",
					"level": 0,
					"alterId": 0
				}],
				"decryption": "none"
			},
			"streamSettings": {
				"sockopt": {
					"tcpFastOpen": '$tcpFastOpen'
				},
				"network": "tcp",
				"tcpSettings": {
					"header": {
						"type": "http"
					}
				}'$securityConfig'
			}
		}'
}

makeWSInbound() {
local port="$1"
local securityConfig="$2"
local url="$3"
local protocol="$4"
local flow="$5"
echo '{
			"port": "'$port'",
			"protocol": "'$protocol'",
			"settings": {
				"udp": true,
				"clients": [{
					"id": "'$uuid'",
					"flow": "'$flow'",
					"level": 0,
					"alterId": 0
				}],
				"decryption": "none"
			},
			"streamSettings": {
				"sockopt": {
					"tcpFastOpen": '$tcpFastOpen'
				},
				"network": "ws",
				"wsSettings": {
					"path": "'$url'"
				}'$securityConfig'
			}
		}'
}

makeMkcpInbound() {
local port="$1"
local securityConfig="$2"
local headerType="$3"
local protocol="$4"
local flow="$5"
echo '{
			"port": "'$port'",
			"protocol": "'$protocol'",
			"settings": {
				"udp": true,
				"clients": [{
					"id": "'$uuid'",
					"flow": "'$flow'",
					"level": 0,
					"alterId": 0
				}],
				"decryption": "none"
			},
			"streamSettings": {
				"network": "kcp",
				"kcpSettings": {
					"header": {
						"type": "'$headerType'"
					}
				}'$securityConfig'
			}
		}'
}

makeTrojanInbound() {
local port="$1"
local securityConfig="$2"
local flow="$3"
echo '{
			"port": "'$port'",
			"protocol": "trojan",
			"settings": {
				"clients": [{
					"password": "'$uuid'",
					"flow": "'$flow'",
					"level": 0
				}]
			},
			"streamSettings": {
				"netowork": "tcp"'$securityConfig'
			}
		}'
}

#Input xray.json
Config() {
	clear
	uuid=`cat /proc/sys/kernel/random/uuid`
	tcpFastOpen=`[ -f /proc/sys/net/ipv4/tcp_fastopen ] && echo -n 'true' || echo -n 'false'`
	if [ -z "$xray_install_directory" ]; then
		echo -n "Please input xray install directory(default is /usr/local/xray): "
		read xray_install_directory
		echo $echo_e_arg "options(TLS default self signed certificate, if necessary, please change it yourself.):
		\r1. tcp http                   (vmess)
		\r2. tcp tls                    (vmess)
		\r3. tcp reality                (vless)
		\r4. websocket                  (vmess)
		\r5. websocket tls              (vmess)
		\r6. websocket tls              (vless)
		\r7. mkcp                       (vmess)
		\r8. mkcp tls                   (vmess)
		\r9. mkcp tls                   (vless)
		\r10. trojan tls
		\rPlease input your options(Separate multiple options with spaces):"
		read xray_inbounds_options
		for opt in $xray_inbounds_options; do
			case $opt in
				1)
					echo -n "Please input vmess tcp http server port: "
					read vmess_tcp_http_port
				;;
				2)
					echo -n "Please input vmess tcp tls server port: "
					read vmess_tcp_tls_port
				;;
				3)
					echo -n "Please input vless tcp reality server port: "
					read vless_tcp_reality_port
				;;
				4)
					echo -n "Please input vmess websocket server port: "
					read vmess_ws_port
					echo -n "Please input vmess websocket Path(default is '/'): "
					read vmess_ws_path
					vmess_ws_path=${vmess_ws_path:-/}
				;;
				5)
					echo -n "Please input vmess websocket tls server port: "
					read vmess_ws_tls_port
					echo -n "Please input vmess websocket tls Path(default is '/'): "
					read vmess_ws_tls_path
					vmess_ws_tls_path=${vmess_ws_tls_path:-/}
				;;
				6)
					echo -n "Please input vless websocket tls server port: "
					read vless_ws_tls_port
					echo -n "Please input vless websocket tls Path(default is '/'): "
					read vless_ws_tls_path
					vless_ws_tls_path=${vless_ws_tls_path:-/}
				;;
				7)
					echo -n "Please input vmess mKCP server port: "
					read vmess_mkcp_port
				;;
				8)
					echo -n "Please input vmess mKCP tls server port: "
					read vmess_mkcp_tls_port
				;;
				9)
					echo -n "Please input vless mKCP tls server port: "
					read vless_mkcp_tls_port
				;;
				10)
					echo -n "Please input trojan tls server port: "
					read trojan_tls_port
				;;
			esac
		done
		echo -n "Install UPX compress version?[n]: "
		read xray_UPX
	fi
	echo "$xray_UPX"|grep -qi '^y' && xray_UPX="upx" || xray_UPX=""
}

GetAbi() {
	machine=`uname -m`
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

#install xray xray.init xray.service
InstallFile() {
	GetAbi
	if echo "$machine" | grep -q '^mips'; then
		cat /proc/cpuinfo | grep -qiE 'fpu|neon|vfp|softfp|asimd' || softfloat='_softfloat'
	fi
	mkdir -p "${xray_install_directory:=/usr/local/xray}" || Error "Create xray install directory failed."
	cd "$xray_install_directory" || Error "Create cns install directory failed."
	#install xray
	$download_tool_cmd xray https://cns.010504.xyz/xray/${xray_UPX}/linux_${machine}${softfloat} || Error "xray download failed."
	$download_tool_cmd xray.init https://cns.010504.xyz/xray/xray.init || Error "xray.init download failed."
	[ -f '/etc/rc.common' ] && rcCommon='/etc/rc.common'
	sed -i "s~#!/bin/sh~#!$SHELL $rcCommon~" xray.init
	sed -i "s~\[xray_install_directory\]~$xray_install_directory~g" xray.init
	sed -i "s~\[xray_tcp_port_list\]~$xray_http_port $xray_http_tls_port $vmess_ws_port $vmess_ws_tls_port $trojan_tls_port $xray_trojan_xtls_port~g" xray.init
	sed -i "s~\[xray_udp_port_list\]~$vmess_mkcp_port $xray_mkcp_xtls_port~g" xray.init
	ln -s "$xray_install_directory/xray.init" /etc/init.d/xray
	chmod -R +rwx "$xray_install_directory" /etc/init.d/xray
	if which systemctl &>/dev/null && [ -z "$(systemctl --failed|grep -q 'Host is down')" ]; then
		$download_tool_cmd /lib/systemd/system/xray.service https://cns.010504.xyz/xray/xray.service || Error "xray.service download failed."
		chmod +rwx /lib/systemd/system/xray.service
		sed -i "s~\[xray_install_directory\]~$xray_install_directory~g" /lib/systemd/system/xray.service
		systemctl daemon-reload
	fi
	#make json config
	realityKey=`./xray x25519`
	realityPvk=`echo "$realityKey"|grep 'Private key: '`
	realityPvk=${realityPvk#*: }
	realityPbk=`echo "$realityKey"|grep 'Public key: '`
	realityPbk=${realityPbk#*: }
	sid=${uuid##*-}
	realitySni='www.apple.com'
	realityServerNames='"www.apple.com", "images.apple.com"'
	local realityConfig=',
			"security": "reality",
			"realitySettings": {
				"show": false,
				"dest": "'$realitySni':443",
				"xver": 0,
				"serverNames": [
					'$realityServerNames'
				],
				"privateKey": "'$realityPvk'",
				"shortIds": [
					"'${sid}'"
				]
			}'
	local tlsConfig=',
			"security": "tls",
			"tlsSettings": {
				"certificates": ['"`./xray tls cert`"']
			}'
	for opt in $xray_inbounds_options; do
		[ -n "$in_networks" ] && in_networks="$in_networks, "
		case $opt in
			1) in_networks="$in_networks"`makeTcpHttpInbound "$vmess_tcp_http_port" "" 'vmess' ''`;;
			2) in_networks="$in_networks"`makeTcpInbound "$vmess_tcp_tls_port" "$tlsConfig" 'vmess' ''`;;
			3) in_networks="$in_networks"`makeTcpInbound "$vless_tcp_reality_port" "$realityConfig" 'vless' 'xtls-rprx-vision'`;;
			4) in_networks="$in_networks"`makeWSInbound "$vmess_ws_port" "" "$vmess_ws_path" 'vmess' ''`;;
			5) in_networks="$in_networks"`makeWSInbound "$vmess_ws_tls_port" "$tlsConfig" "$vmess_ws_tls_path" 'vmess' ''`;;
			6) in_networks="$in_networks"`makeWSInbound "$vless_ws_tls_port" "$tlsConfig" "$vless_ws_tls_path" 'vless' ''`;;
			7) in_networks="$in_networks"`makeMkcpInbound "$vmess_mkcp_port" "" "utp" 'vmess' ''`;;
			8) in_networks="$in_networks"`makeMkcpInbound "$vmess_mkcp_tls_port" "$tlsConfig" "none" 'vmess' ''`;;
			9) in_networks="$in_networks"`makeMkcpInbound "$vless_mkcp_tls_port" "$tlsConfig" "none" 'vless' ''`;;
			10) in_networks="$in_networks"`makeTrojanInbound "$trojan_tls_port" "$tlsConfig" ''`;;
		esac
	done
	echo $echo_E_arg '
	{
		"log" : {
			"loglevel": "none"
		},
		"inbounds": ['"$in_networks"'],
		"outbounds": [{
			"protocol": "freedom"
		}]
	}
	' >xray.json
}

#install initialization
InstallInit() {
	echo -n "make a update?[n]: "
	read update
	PM=`which apt-get &>/dev/null || which yum &>/dev/null`
	echo "$update"|grep -qi 'y' && $PM -y update
	$PM -y install curl wget #unzip
	type curl && download_tool_cmd='curl -L --connect-timeout 7 -ko' || download_tool_cmd='wget -T 60 --no-check-certificate -O'
	getip_urls="http://myip.parso.org http://myip.dnsomatic.com/ http://ip.sb/"
	for url in $getip_urls; do
		ip=`$download_tool_cmd - "$url" | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}|:'`
		[ -n "$ip" ] && break
	done
}

outputLink() {
	[ -z "$ip" ] && return
	for opt in $xray_inbounds_options; do
		case $opt in
			1)
				link=`echo -n $echo_E_arg '{"add": "'$ip'", "port": '$vmess_tcp_http_port', "aid": "0", "host": "obfs.domain", "id": "'$uuid'", "net": "tcp", "path": "/", "ps": "vmess_tcp_http_'$ip:$vmess_tcp_http_port'", "tls": "", "type": "http", "v": "2"}'|base64 -w 0`
				echo $echo_e_arg "\033[45;37m\rvmess tcp http:\033[0m\n\t\033[4;35mvmess://$link\033[0m"
			;;
			2)
				link=`echo -n $echo_E_arg '{"add": "'$ip'", "port": '$vmess_tcp_tls_port', "aid": "0", "host": "", "id": "'$uuid'", "net": "tcp", "path": "", "ps": "vmess_tcp_tls_'$ip:$vmess_tcp_tls_port'", "tls": "tls", "type": "none", "v": "2", "fp": "chrome"}'|base64 -w 0`
				echo $echo_e_arg "\033[45;37m\rvmess tcp tls:\033[0m\n\t\033[4;35mvmess://$link\033[0m"
			;;
			3)
				echo $echo_e_arg "\033[45;37m\rvless tcp reality:\033[0m\n\t\033[4;35mvless://${uuid}@${ip}:${vless_tcp_reality_port}?security=reality&sni=${realitySni}&encryption=none&headerType=none&type=tcp&fp=chrome&flow=xtls-rprx-vision&sid=${sid}&pbk=$realityPbk&spx=/iphone-14-pro#vless_tcp_reality${ip}:${vless_tcp_reality_port}\033[0m"
			;;
			4)
				link=`echo -n $echo_E_arg '{"add": "'$ip'", "port": "'$vmess_ws_port'", "aid": "0", "host": "obfs.domain", "id": "'$uuid'", "net": "ws", "path": "'$vmess_ws_path'", "ps": "ws_'$ip:$vmess_ws_port'", "tls": "", "type": "none", "v": "2"}'|base64 -w 0`
				echo $echo_e_arg "\033[45;37m\rvmess ws:\033[0m\n\t\033[4;35mvmess://$link\033[0m"
			;;
			5)
				link=`echo -n $echo_E_arg '{"add": "'$ip'", "port": "'$vmess_ws_tls_port'", "aid": "0", "host": "obfs.domain", "id": "'$uuid'", "net": "ws", "path": "'$vmess_ws_tls_path'", "ps": "ws_tls_'$ip:$vmess_ws_tls_port'", "tls": "tls", "type": "none", "v": "2", "fp": "chrome"}'|base64 -w 0`
				echo $echo_e_arg "\033[45;37m\rvmess ws tls:\033[0m\n\t\033[4;35mvmess://$link\033[0m"
			;;
			6)
				echo $echo_e_arg "\033[45;37m\r vless ws tls:\033[0m\n\t\033[4;35mvless://${uuid}@${ip}:${vless_ws_tls_port}?security=tls&sni=obfs.domain&encryption=none&type=ws&path=$vless_ws_tls_path&host=obfs.domain&fp=chrome`date +%s`#vless_ws_tls${ip}:${vless_ws_tls_port}\033[0m"
			;;
			7)
				link=`echo -n $echo_E_arg '{"add": "'$ip'", "port": "'$vmess_mkcp_port'", "aid": "0", "host": "", "id": "'$uuid'", "net": "kcp", "path": "", "ps": "vmess_mkcp_'$ip:$vmess_mkcp_port'", "tls": "", "type": "utp", "v": "2"}'|base64 -w 0`
				echo $echo_e_arg "\033[45;37m\rvmess mkcp:\033[0m\n\t\033[4;35mvmess://$link\033[0m"
			;;
			8)
				link=`echo -n $echo_E_arg '{"add": "'$ip'", "port": "'$vmess_mkcp_tls_port'", "aid": "0", "host": "", "id": "'$uuid'", "net": "kcp", "path": "", "ps": "vmess_mkcp_tls_'$ip:$vmess_mkcp_port'", "tls": "tls", "type": "none", "v": "2", "fp": "chrome"}'|base64 -w 0`
				echo $echo_e_arg "\033[45;37m\rvmess mkcp tls:\033[0m\n\t\033[4;35mvmess://$link\033[0m"
			;;
			9)
				echo $echo_e_arg "\033[45;37m\r vless mkcp tls:\033[0m\n\t\033[4;35mvless://${uuid}@${ip}:${vless_mkcp_tls_port}?security=tls&sni=obfs.domain&encryption=none&type=kcp&headerType=none&fp=chrome`date +%s`#vless_ws_tls${ip}:${vless_mkcp_tls_port}\033[0m"
			;;
			10)
				echo $echo_e_arg "\033[45;37m\rtrojan tls:\033[0m\n\t\033[4;35mtrojan://${uuid}@${ip}:${trojan_tls_port}?security=tls&sni=obfs.domain#trojan_tls_${ip}:${trojan_tls_port}\033[0m"
			;;
		esac
	done
}

AddAutoStart() {
	if [ -n "$rcCommon" ]; then
		if /etc/init.d/xray enable; then
			echo 'Autostart enabled, if you need to close it, run: /etc/init.d/xray disable'
			return
		fi
	fi
	if type systemctl &>/dev/null && [ -z "$(systemctl --failed|grep -q 'Host is down')" ]; then
		if systemctl enable xray &>/dev/null; then
			echo 'Autostart enabled, if you need to close it, run: systemctl disable xray'
			return
		fi
	fi
	if type chkconfig &>/dev/null; then
		if chkconfig --add xray &>/dev/null && chkconfig xray on &>/dev/null; then
			echo 'Autostart enabled, if you need to close it, run: chkconfig xray off'
			return
		fi
	fi
	if [ -d '/etc/rc.d/rc5.d' -a -f '/etc/init.d/xray' ]; then
		if ln -s '/etc/init.d/xray' '/etc/rc.d/rc5.d/S99xray'; then
			echo 'Autostart enabled, if you need to close it, run: rm -f /etc/rc.d/rc5.d/S99xray'
			return
		fi
	fi
	if [ -d '/etc/rc5.d' -a -f '/etc/init.d/xray' ]; then
		if ln -s '/etc/init.d/xray' '/etc/rc5.d/S99xray'; then
			echo 'Autostart enabled, if you need to close it, run: rm -f /etc/rc5.d/S99xray'
			return
		fi
	fi
	if [ -d '/etc/rc.d' -a -f '/etc/init.d/xray' ]; then
		if ln -s '/etc/init.d/xray' '/etc/rc.d/S99xray'; then
			echo 'Autostart enabled, if you need to close it, run: rm -f /etc/rc.d/S99xray'
			return
		fi
	fi
	echo 'Autostart disabled'
}

Install() {
	Config
	Delete >/dev/null 2>&1
	InstallInit
	InstallFile
	"$xray_install_directory/xray.init" start|grep -q FAILED && Error "xray install failed."
	which systemctl &>/dev/null && [ -z "$(systemctl --failed|grep -q 'Host is down')" ] && systemctl restart xray &>/dev/null
	echo $echo_e_arg \
		"\033[44;37mxray install success.\033[0;34m
		`
			for opt in $xray_inbounds_options; do
				case $opt in
					1)
						echo $echo_e_arg "\r	vmess tcp http server:\033[34G port=${vmess_tcp_http_port}";;
					2)
						echo $echo_e_arg "\r	vmess tcp tls server:\033[34G port=${vmess_tcp_tls_port}";;
					3)
						echo $echo_e_arg "\r	vless tcp reality server:\033[34G port=${vless_tcp_reality_port}"
						echo $echo_e_arg "\r	flow:\033[34G xtls-rprx-vision"
						echo $echo_e_arg "\r	serverName:\033[34G ${realitySni}"
						echo $echo_e_arg "\r	publicKey:\033[34G ${realityPbk}"
						echo $echo_e_arg "\r	shortId:\033[34G ${sid}"
					;;
					4)
						echo $echo_e_arg "\r	vmess ws server:\033[34G port=${vmess_ws_port} path=${vmess_ws_path}";;
					5)
						echo $echo_e_arg "\r	vmess ws tls server:\033[34G port=${vmess_ws_tls_port} path=${vmess_ws_tls_path}";;
					6)
						echo $echo_e_arg "\r	vless ws tls server:\033[34G port=${vless_ws_tls_port} path=${vless_ws_tls_path}";;
					7)
						echo $echo_e_arg "\r	vmess mkcp server:\033[34G port=${vmess_mkcp_port} type=utp";;
					8)
						echo $echo_e_arg "\r	vmess mkcp tls server:\033[34G port=${vmess_mkcp_tls_port} type=none";;
					9)
						echo $echo_e_arg "\r	vless mkcp tls server:\033[34G port=${vless_mkcp_tls_port} type=none";;
					10)
						echo $echo_e_arg "\r	trojan tls server:\033[34G port=${trojan_tls_port}";;
				esac
			done
		`
		\r	uuid:\033[35G$uuid
		\r	alterId:\033[35G0
		\r`[ -f /etc/init.d/xray ] && /etc/init.d/xray usage || \"$xray_install_directory/xray.init\" usage`
		\r`AddAutoStart`
		`outputLink`\033[0m"
}

Uninstall() {
	if [ -z "$xray_install_directory" ]; then
		echo -n "Please input xray install directory(default is /usr/local/xray): "
		read xray_install_directory
	fi
	Delete &>/dev/null && \
		echo $echo_e_arg "\n\033[44;37mxray uninstall success.\033[0m" || \
		echo $echo_e_arg "\n\033[41;37mxray uninstall failed.\033[0m"
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
