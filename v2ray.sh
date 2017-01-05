#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

#Check Root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

#Check OS
if [ -f /etc/redhat-release ];then
        OS='CentOS'
    elif [ ! -z "`cat /etc/issue | grep bian`" ];then
        OS='Debian'
    elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ];then
        OS='Ubuntu'
    else
        echo "Not support OS, Please reinstall OS and retry!"
        exit 1
fi


# Get Public IP address
ipc=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
if [[ "$IP" = "" ]]; then
    ipc=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
fi

uuid=$(cat /proc/sys/kernel/random/uuid)

function Install(){
#Install Basic Packages
if [[ ${OS} == 'CentOS' ]];then
	yum install curl wget unzip ntp ntpdate -y
else
	apt-get update
	apt-get install curl unzip ntp wget ntpdate -y
fi

#Set DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf


#Update NTP settings
rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
ntpdate us.pool.ntp.org

#Disable SELinux
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi

#Run Install
cd /root

bash <(curl -L -s https://install.direct/go.sh)

}

clear
echo 'V2Ray 一键安装|配置脚本 Author：Kirito && 雨落无声'
echo ''
echo '此脚本会关闭iptables防火墙，切勿用于生产环境！'

while :; do echo
	read -p "输入用户等级（自用请输入1，共享请输入0）:" level
	if [[ ! $level =~ ^[0-1]$ ]]; then
		echo "${CWARNING}输入错误! 请输入正确的数字!${CEND}"
	else
		break
	fi
done


read -p "输入主要端口（默认：32000）:" mainport
[ -z "$mainport" ] && mainport=32000

read -p "输入数据端口起点（默认：32001）:" subport1
[ -z "$subport1" ] && subport1=32000

read -p "输入数据端口终点（默认：32500）:" subport2
[ -z "$subport2" ] && subport2=32500

read -p "输入每次开放端口数（默认：10）:" portnum
[ -z "$portnum" ] && portnum=10

read -p "输入端口变更时间（单位：分钟）:" porttime
[ -z "$porttime" ] && porttime=5

read -p "是否启用HTTP伪装?（默认开启） [y/n]:" ifhttpheader
	[ -z "$ifhttpheader" ] && ifhttpheader='y'
	if [[ $ifhttpheader == 'y' ]];then
		httpheader=',
    "streamSettings": {
      "network": "tcp",
      "tcpSettings": {
        "connectionReuse": true,
        "header": {
          "type": "http",
          "request": {
            "version": "1.1",
            "method": "GET",
            "path": ["/"],
            "headers": {
              "Host": ["www.baidu.com", "www.sogou.com/"],
              "User-Agent": [
                "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.75 Safari/537.36",
                        "Mozilla/5.0 (iPhone; CPU iPhone OS 10_0_2 like Mac OS X) AppleWebKit/601.1 (KHTML, like Gecko) CriOS/53.0.2785.109 Mobile/14A456 Safari/601.1.46"
              ],
              "Accept-Encoding": ["gzip, deflate"],
              "Connection": ["keep-alive"],
              "Pragma": "no-cache"
            }
          },
          "response": {
            "version": "1.1",
            "status": "200",
            "reason": "OK",
            "headers": {
              "Content-Type": ["application/octet-stream", "application/x-msdownload", "text/html", "application/x-shockwave-flash"],
              "Transfer-Encoding": ["chunked"],
              "Connection": ["keep-alive"],
              "Pragma": "no-cache"
            }
          }
        }
      }
    }'
	else
		httpheader=''
		read -p "是否启用mKCP协议?（默认开启） [y/n]:" ifmkcp
		[ -z "$ifmkcp" ] && ifmkcp='y'
		if [[ $ifmkcp == 'y' ]];then
        		mkcp=',
   		 		"streamSettings": {
   			 	"network": "kcp"
  				}'
		else
				mkcp=''
		fi

fi


#CheckIfInstalled
if [ ! -f "/usr/bin/v2ray/v2ray" ]; then
	Install
fi

#Disable iptables
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F

#Configure Server
service v2ray stop
rm -rf config
cat << EOF > config
{"log" : {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbound": {
    "port": $mainport,
    "protocol": "vmess",
    "settings": {
        "clients": [
            {
                "id": "$uuid",
                "level": $level,
                "alterId": 100
            }
        ],
        "detour": {
            "to": "detour"
        }
    }${mkcp}${httpheader}
  },
  "outbound": {
    "protocol": "freedom",
    "settings": {}
  },
  "inboundDetour": [
    {
      "protocol": "vmess",
      "port": "$subport1-$subport2",
      "tag": "detour",
      "settings": {},
        "allocate": {
            "strategy": "random",
            "concurrency": $portnum,
            "refresh": $porttime
        }${mkcp}${httpheader}
    }
  ],
  "outboundDetour": [
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "strategy": "rules",
    "settings": {
      "rules": [
        {
          "type": "field",
          "ip": [
            "0.0.0.0/8",
            "10.0.0.0/8",
            "100.64.0.0/10",
            "127.0.0.0/8",
            "169.254.0.0/16",
            "172.16.0.0/12",
            "192.0.0.0/24",
            "192.0.2.0/24",
            "192.168.0.0/16",
            "198.18.0.0/15",
            "198.51.100.0/24",
            "203.0.113.0/24",
            "::1/128",
            "fc00::/7",
            "fe80::/10"
          ],
          "outboundTag": "blocked"
        }
      ]
    }
  }
}
EOF
rm -rf /etc/v2ray/config.back
mv /etc/v2ray/config.json /etc/v2ray/config.back
mv config /etc/v2ray/config.json

rm /root/config.json
cat << EOF > /root/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbound": {
    "port": 1080,
    "listen": "127.0.0.1",
    "protocol": "http",
    "settings": {
      "auth": "noauth",
      "udp": false,
      "ip": "127.0.0.1"
    }
  },
  "outbound": {
    "protocol": "vmess",
    "settings": {
        "vnext": [
            {
                "address": "$ipc",
                "port": $mainport,
                "users": [
                    {
                        "id": "$uuid",
                        "alterId": 100
                    }
                ]
            }
        ]
    }${mkcp}${httpheader}
  },
  "outboundDetour": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    }
  ],
  "dns": {
    "servers": [
      "8.8.8.8",
      "8.8.4.4",
      "localhost"
    ]
  },
  "routing": {
    "strategy": "rules",
    "settings": {
      "rules": [
        {
          "type": "chinasites",
          "outboundTag": "direct"
        },
        {
          "type": "field",
          "ip": [
            "0.0.0.0/8",
            "10.0.0.0/8",
            "100.64.0.0/10",
            "127.0.0.0/8",
            "169.254.0.0/16",
            "172.16.0.0/12",
            "192.0.0.0/24",
            "192.0.2.0/24",
            "192.168.0.0/16",
            "198.18.0.0/15",
            "198.51.100.0/24",
            "203.0.113.0/24",
            "::1/128",
            "fc00::/7",
            "fe80::/10"
          ],
          "outboundTag": "direct"
        },
        {
          "type": "chinaip",
          "outboundTag": "direct"
        }
      ]
    }
  }
}
EOF

service v2ray start
clear

echo '教程地址：https://github.com/FunctionClub/V2ray-Bash/blob/master/README.md'
echo '配置完成，客户端配置文件在 /root/config.json'
echo ''
echo "程序主端口：$mainport"
echo "UUID: $uuid"
