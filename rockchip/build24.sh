#!/bin/bash
# Log file for debugging
source shell/custom-packages.sh
source shell/switch_repository.sh
# 保留 shell/custom-packages.sh 中的预设，并与基础插件合并
CUSTOM_PACKAGES="$BASE_CUSTOM_PACKAGES $CUSTOM_PACKAGES"
echo "第三方软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
# yml 传入的路由器型号 PROFILE
echo "Building for profile: $PROFILE"
# yml 传入的固件大小 ROOTFS_PARTSIZE
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE"

echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # 下载 run 文件仓库
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
  git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo

  # 拷贝 run/arm64 下所有 run 文件和ipk文件 到 extra-packages 目录
  mkdir -p /home/build/immortalwrt/extra-packages
  cp -r /tmp/store-run-repo/run/arm64/* /home/build/immortalwrt/extra-packages/

  echo "✅ Run files copied to extra-packages:"
  ls -lh /home/build/immortalwrt/extra-packages/*.run
  # 解压并拷贝ipk到packages目录
  sh shell/prepare-packages.sh
  ls -lah /home/build/immortalwrt/packages/
  # 添加架构优先级信息
  sed -i '1i\
  arch aarch64_generic 10\n\
  arch aarch64_cortex-a53 15' repositories.conf
fi


# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."
echo "查看repositories.conf信息——————"
cat repositories.conf

# =======================================================
# 定义所需安装的包列表 (已整理并启用中文支持)
# =======================================================
PACKAGES=""

# 1. 基础系统与工具
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn" # 防火墙中文

# 2. 磁盘与存储/NAS (使用中文包自动依赖主程序)
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"  # 磁盘管理
PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"   # Samba 共享
PACKAGES="$PACKAGES luci-i18n-aria2-zh-cn"    # Aria2 下载

# 3. 网络加速与代理
PACKAGES="$PACKAGES luci-app-passwall"         # Passwall (通常自带语言或自适应)
PACKAGES="$PACKAGES luci-i18n-turboacc-zh-cn" # 网络加速
PACKAGES="$PACKAGES luci-app-openlist"         # OpenList

# 4. 广告过滤与安全控制
PACKAGES="$PACKAGES luci-i18n-adguardhome-zh-cn" # AdGuard Home
PACKAGES="$PACKAGES luci-i18n-accesscontrol-zh-cn" # 上网时间控制

# 5. 通知与推送
PACKAGES="$PACKAGES luci-app-pushbot"          # 推送机器人

# 6. 主题
PACKAGES="$PACKAGES luci-theme-argon"

# 7. 显式排除的包
PACKAGES="$PACKAGES -luci-app-cpufreq"


# ======== shell/custom-packages.sh =======
# 合并imm仓库以外的第三方插件
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# 按工作流输入开关 docker 相关插件
# 注意：请确保你的 .yml 配置文件中 include_docker 设置为 true/yes
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    # 添加你要求的 Docker (带中文)
    PACKAGES="$PACKAGES luci-app-docker"
    echo "✅ include_docker=yes，已添加 Docker 组件"
else
    echo "ℹ️ include_docker=no，跳过 Docker 相关组件"
fi

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
