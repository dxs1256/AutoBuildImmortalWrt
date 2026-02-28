#!/bin/bash
# Log file for debugging

# 引入外部脚本 (确保你的仓库里有这几个文件)
source shell/custom-packages.sh
source shell/switch_repository.sh

# 保留 shell/custom-packages.sh 中的预设，并与基础插件合并
CUSTOM_PACKAGES="$BASE_CUSTOM_PACKAGES $CUSTOM_PACKAGES"
echo "第三方软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting build.sh at $(date)" >> $LOGFILE

# yml 传入的路由器型号 PROFILE
echo "Building for profile: $PROFILE"
# yml 传入的固件大小 ROOTFS_PARTSIZE
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE"

# ==========================================
# 1. 动态生成 PPPoE 配置文件
# ==========================================
echo "Create pppoe-settings"
mkdir -p /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供开机脚本读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "查看生成的 PPPoE 配置文件内容:"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

# ==========================================
# 2. 处理第三方 Run 包软件仓库
# ==========================================
if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择任何第三方软件包"
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

echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."
echo "查看 repositories.conf 信息:"
cat repositories.conf

# ==========================================
# 3. 定义必须安装的基础包列表 (已全盘汉化)
# ==========================================
PACKAGES=""

# 基础系统与工具
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"

# 磁盘与存储/NAS
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"
PACKAGES="$PACKAGES luci-i18n-aria2-zh-cn"

# 网络加速与其他工具
PACKAGES="$PACKAGES luci-i18n-turboacc-zh-cn"
PACKAGES="$PACKAGES luci-app-openlist"

# 广告过滤与安全控制
PACKAGES="$PACKAGES luci-i18n-adguardhome-zh-cn"
PACKAGES="$PACKAGES luci-i18n-accesscontrol-zh-cn"

# 通知与推送
PACKAGES="$PACKAGES luci-app-pushbot"

# 主题
PACKAGES="$PACKAGES luci-theme-argon"

# 显式排除不需要的包 (如果默认内核带了这个，排除防止冲突)
PACKAGES="$PACKAGES -luci-app-cpufreq"

# 合并外部预设的第三方插件
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# ==========================================
# 4. 根据 YAML 用户输入判断是否打包特色插件
# ==========================================

# 1) Docker 逻辑判断
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-app-docker luci-i18n-dockerman-zh-cn"
    echo "✅ include_docker=yes，已将 Docker 相关组件加入打包列表"
else
    echo "ℹ️ include_docker=no，跳过 Docker 相关组件"
fi

# 2) Passwall 逻辑判断
if [ "$INCLUDE_PASSWALL" = "yes" ]; then
    PACKAGES="$PACKAGES luci-app-passwall"
    echo "✅ include_passwall=yes，已将 Passwall 加入打包列表"
else
    echo "ℹ️ include_passwall=no，跳过 Passwall 组件"
fi

# ==========================================
# 5. 执行构建命令 (ImageBuilder)
# ==========================================
echo "$(date '+%Y-%m-%d %H:%M:%S') - 最终打包的软件包列表如下:"
echo "$PACKAGES"

make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

# 检查构建是否成功
if [ $? -ne 0 ]; then
    echo "❌ $(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "🎉 $(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
