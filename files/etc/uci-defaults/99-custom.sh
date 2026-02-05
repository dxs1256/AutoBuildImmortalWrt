#!/bin/sh
# 99-custom.sh - ImmortalWrt 首次启动配置脚本 (NanoPi R4S 优化版)
# 路径: AutoBuildImmortalWrt/files/etc/uci-defaults/99-custom.sh

# 调试日志
LOGFILE="/etc/config/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >>$LOGFILE

# 0. 基础防火墙设置
# 允许 WAN 口入站流量 (方便调试或单网口模式下访问)，配置完成后可在 WebUI 手动关闭
uci set firewall.@zone[1].input='ACCEPT'

# 1. 解决安卓原生 TV 无法联网问题 (NTP 时间同步劫持)
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"

# 2. 读取 PPPoE 预设配置 (由 build24.sh 生成)
SETTINGS_FILE="/etc/config/pppoe-settings"
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "PPPoE settings file not found. Skipping." >>$LOGFILE
else
    . "$SETTINGS_FILE"
fi

# 3. 获取物理网卡列表
ifnames=""
for iface in /sys/class/net/*; do
    iface_name=$(basename "$iface")
    # 仅筛选 eth 或 en 开头的物理网卡
    if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
        ifnames="$ifnames $iface_name"
    fi
done
# 排序并去重
ifnames=$(echo "$ifnames" | tr ' ' '\n' | sort | tr '\n' ' ' | awk '{$1=$1};1')
count=$(echo "$ifnames" | wc -w)

echo "Detected physical interfaces: $ifnames" >>$LOGFILE
echo "Interface count: $count" >>$LOGFILE

# 4. 识别板子型号并映射 WAN/LAN
board_name=$(cat /tmp/sysinfo/board_name 2>/dev/null || echo "unknown")
echo "Board detected: $board_name" >>$LOGFILE

wan_ifname=""
lan_ifnames=""

case "$board_name" in
    "friendlyarm,nanopi-r4s"|"friendlyarm,nanopi-r2s")
        # NanoPi R4S/R2S 专用映射 (防乱序)
        # eth0 (靠近电源) = WAN
        # eth1 (PCIe转接/USB3) = LAN
        wan_ifname="eth0"
        lan_ifnames="eth1"
        echo "Using R4S/R2S mapping: WAN=$wan_ifname LAN=$lan_ifnames" >>"$LOGFILE"
        ;;
    "radxa,e20c"|"friendlyarm,nanopi-r5c")
        # R5C 等设备通常反向
        wan_ifname="eth1"
        lan_ifnames="eth0"
        echo "Using $board_name mapping: WAN=$wan_ifname LAN=$lan_ifnames" >>"$LOGFILE"
        ;;
    *)
        # 默认通用策略：第一个为 WAN，其余为 LAN
        wan_ifname=$(echo "$ifnames" | awk '{print $1}')
        lan_ifnames=$(echo "$ifnames" | cut -d ' ' -f2-)
        echo "Using default mapping: WAN=$wan_ifname LAN=$lan_ifnames" >>"$LOGFILE"
        ;;
esac

# 5. 应用网络配置
if [ "$count" -eq 1 ]; then
    # 单网口模式 (旁路由/虚拟机/调试)
    uci set network.lan.proto='dhcp'
    uci delete network.lan.ipaddr
    uci delete network.lan.netmask
    uci delete network.lan.gateway
    uci delete network.lan.dns
    uci commit network
elif [ "$count" -gt 1 ]; then
    # 多网口模式 (R4S 走这里)
    
    # 配置 WAN
    uci set network.wan=interface
    uci set network.wan.device="$wan_ifname"
    uci set network.wan.proto='dhcp' # 默认 DHCP，下面会检查是否开启 PPPoE

    # 配置 WAN6
    uci set network.wan6=interface
    uci set network.wan6.device="$wan_ifname"
    uci set network.wan6.proto='dhcpv6'

    # 配置 LAN 网桥
    section=$(uci show network | awk -F '[.=]' '/\.@?device\[\d+\]\.name=.br-lan.$/ {print $2; exit}')
    if [ -n "$section" ]; then
        uci -q delete "network.$section.ports"
        for port in $lan_ifnames; do
            uci add_list "network.$section.ports"="$port"
        done
        echo "Updated br-lan ports to: $lan_ifnames" >>$LOGFILE
    fi

    # 设置 LAN 口静态 IP
    uci set network.lan.proto='static'
    uci set network.lan.netmask='255.255.255.0'

    # 检查是否有自定义 IP 文件 (由 build24.sh 生成)
    IP_VALUE_FILE="/etc/config/custom_router_ip.txt"
    if [ -f "$IP_VALUE_FILE" ]; then
        CUSTOM_IP=$(cat "$IP_VALUE_FILE")
        uci set network.lan.ipaddr="$CUSTOM_IP"
        echo "Set custom router IP: $CUSTOM_IP" >> $LOGFILE
    else
        uci set network.lan.ipaddr='192.168.100.1'
        echo "Set default router IP: 192.168.100.1" >> $LOGFILE
    fi

    # 应用 PPPoE 设置
    if [ "$enable_pppoe" = "yes" ]; then
        echo "Enabling PPPoE..." >>$LOGFILE
        uci set network.wan.proto='pppoe'
        uci set network.wan.username="$pppoe_account"
        uci set network.wan.password="$pppoe_password"
        uci set network.wan.peerdns='1'
        uci set network.wan.auto='1'
        uci set network.wan6.proto='none'
    fi

    uci commit network
fi

# 6. 配置 Docker 防火墙 (针对 R4S 优化)
# 允许 Docker 容器访问外网及 LAN 口
if command -v dockerd >/dev/null 2>&1; then
    echo "Configuring Docker firewall..." >>$LOGFILE
    FW_FILE="/etc/config/firewall"
    
    # 清理旧配置 (防止重复)
    uci delete firewall.docker 2>/dev/null
    for idx in $(uci show firewall | grep "=forwarding" | cut -d[ -f2 | cut -d] -f1 | sort -rn); do
        src=$(uci get firewall.@forwarding[$idx].src 2>/dev/null)
        dest=$(uci get firewall.@forwarding[$idx].dest 2>/dev/null)
        if [ "$src" = "docker" ] || [ "$dest" = "docker" ]; then
            uci delete firewall.@forwarding[$idx]
        fi
    done
    uci commit firewall

    # 写入新规则 (扩大 Docker 子网范围，允许转发)
    cat <<EOF >>"$FW_FILE"

config zone 'docker'
  option input 'ACCEPT'
  option output 'ACCEPT'
  option forward 'ACCEPT'
  option name 'docker'
  list subnet '172.16.0.0/12'

config forwarding
  option src 'docker'
  option dest 'lan'

config forwarding
  option src 'docker'
  option dest 'wan'

config forwarding
  option src 'lan'
  option dest 'docker'
EOF
else
    echo "Docker not found, skipping firewall config." >>$LOGFILE
fi

# 7. 系统访问权限放行
# 允许所有接口访问 ttyd (网页终端)
uci delete ttyd.@ttyd[0].interface 2>/dev/null
# 允许所有接口访问 SSH
uci set dropbear.@dropbear[0].Interface='' 2>/dev/null
uci commit

# 8. 修改固件描述信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Packaged by wukongdaily"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

exit 0
