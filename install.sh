#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install curl crontabs -y
    else
        apt install curl cron -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/dalacin.service ]]; then
        return 2
    fi
    temp=$(systemctl status dalacin | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_dalacin() {
    mkdir -p /tmp/dalacin-installer/
    cd /tmp/dalacin-installer/

    url="https://github.com/wloot/v2ray-dalacin/archive/master.tar.gz"
    echo -e "开始安装 dalacin"
    curl -L -o ./dalacin.tar.gz ${url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 dalacin 失败${plain}"
        exit 1
    fi

    tar -xzf dalacin.tar.gz
    cd v2ray-dalacin-master

    chmod +x dalacin dalacin.sh xray
    mkdir -p /usr/local/dalacin/
    rm -rf /usr/local/dalacin/*
    cp -f dalacin /usr/local/dalacin/
    cp -f xray /usr/local/dalacin/
    cp -f dalacin.sh /usr/bin/dalacin
    cp -f dalacin.service /etc/systemd/system/

    curl -L -o ./geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
    curl -L -o ./geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
    cp -f geosite.dat geoip.dat /usr/local/dalacin/

    systemctl daemon-reload
    systemctl stop dalacin
    systemctl enable dalacin
    echo -e "${green}dalacin${plain} 安装完成，已设置开机自启"
    if [[ ! -f /etc/dalacin/config.yaml ]]; then
        mkdir /etc/dalacin/ -p
        cp -f config.yaml /etc/dalacin/
        echo -e ""
        echo -e "全新安装，请先配置 /etc/dalacin/config.yaml"
    else
        systemctl start dalacin
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}dalacin 重启成功${plain}"
        else
            echo -e "${red}dalacin 可能启动失败${plain}"
        fi
    fi
    rm -rf /tmp/dalacin-installer/
}

echo -e "${green}开始安装${plain}"
install_base
install_acme
install_dalacin
