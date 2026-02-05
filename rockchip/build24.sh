#!/bin/bash
# AutoBuildImmortalWrt/rockchip/build24.sh
# 适配 NanoPi R4S 构建脚本

# -----------------------------------------------------------------------------
# 1. 导入自定义包列表
# -----------------------------------------------------------------------------
# 假设脚本在 repo 根目录执行，或者在 rockchip 目录下执行
if [ -f "shell/custom-packages.sh" ]; then
    source shell/custom-packages.sh
elif [ -f "../shell/custom-packages.sh" ]; then
    source ../shell/custom-packages.sh
else
    CUSTOM_PACKAGES=""
fi

echo "第三方软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "Building for profile: $PROFILE"
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE"

# 定义构建环境中的 files 目录 (用于存放将要打包进固件的文件)
# 这是 ImageBuilder 工作目录下的 files
FILES_DIR="/home/build/immortalwrt/files"
mkdir -p "$FILES_DIR/etc/config"
mkdir -p "$FILES_DIR/etc/uci-defaults"

# -----------------------------------------------------------------------------
# 2. 同步仓库中的 files 目录到构建环境
# -----------------------------------------------------------------------------
# 这一步非常重要，它确保了 AutoBuildImmortalWrt/files/ 下的内容(包括99-custom.sh)
# 被复制到实际编译使用的 FILES_DIR 中
if [ -d "files" ]; then
    echo "✅ Copying repository 'files' directory to build environment..."
    cp -r files/* "$FILES_DIR/" 2>/dev/null
elif [ -d "../files" ]; then
    # 如果脚本是在 rockchip/ 目录下运行
    echo "✅ Copying repository '../files' directory to build environment..."
    cp -r ../files/* "$FILES_DIR/" 2>/dev/null
fi

# -----------------------------------------------------------------------------
# 3. 生成动态配置文件 (配合 99-custom.sh)
# -----------------------------------------------------------------------------

echo "Creating pppoe-settings..."
cat << EOF > "$FILES_DIR/etc/config/pppoe-settings"
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

# 如果环境变量设置了自定义 IP
if [ -n "$CUSTOM_IP" ]; then
    echo "Setting custom router IP to: $CUSTOM_IP"
    echo "$CUSTOM_IP" > "$FILES_DIR/etc/config/custom_router_ip.txt"
fi

# -----------------------------------------------------------------------------
# 4. 确保启动脚本有执行权限
# -----------------------------------------------------------------------------
SCRIPT_PATH="$FILES_DIR/etc/uci-defaults/99-custom.sh"
if [ -f "$SCRIPT_PATH" ]; then
    echo "✅ Found 99-custom.sh, setting executable permission."
    chmod +x "$SCRIPT_PATH"
else
    echo "⚠️ Warning: 99-custom.sh not found in $FILES_DIR/etc/uci-defaults/"
    echo "Check if AutoBuildImmortalWrt/files/etc/uci-defaults/99-custom.sh exists."
fi

# -----------------------------------------------------------------------------
# 5. 处理第三方软件包仓库
# -----------------------------------------------------------------------------
if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # 下载 run 文件仓库
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
  git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo

  # 拷贝 run/arm64 下所有 run 文件和ipk文件 到 extra-packages 目录
  # NanoPi R4S 是 arm64 架构
  mkdir -p /home/build/immortalwrt/extra-packages
  cp -r /tmp/store-run-repo/run/arm64/* /home/build/immortalwrt/extra-packages/

  echo "✅ Run files copied to extra-packages:"
  ls -lh /home/build/immortalwrt/extra-packages/*.run
  
  # 尝试执行准备脚本
  if [ -f "shell/prepare-packages.sh" ]; then
      sh shell/prepare-packages.sh
  elif [ -f "../shell/prepare-packages.sh" ]; then
      sh ../shell/prepare-packages.sh
  else
      # 简单的 fallback: 直接拷贝 ipk
      cp /home/build/immortalwrt/extra-packages/*.ipk /home/build/immortalwrt/packages/ 2>/dev/null
  fi
  
  ls -lah /home/build/immortalwrt/packages/
  
  # 添加架构优先级信息 (针对 R4S/ARMv8 优化)
  # 这一步是为了让 ImageBuilder 能正确识别第三方 generic 包
  sed -i '1i\
  arch aarch64_generic 10\n\
  arch aarch64_cortex-a53 15' repositories.conf
fi

echo "$BUILD_DATE - 开始构建固件..."
echo "查看 repositories.conf 信息:"
cat repositories.conf

# -----------------------------------------------------------------------------
# 6. 定义所需安装的包列表
# -----------------------------------------------------------------------------
PACKAGES=""

# 基础必备
PACKAGES="$PACKAGES curl openssh-sftp-server"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"

# 界面与主题
PACKAGES="$PACKAGES luci-theme-argon"

# 常用插件 (Diskman, Samba, Aria2等)
PACKAGES="$PACKAGES luci-app-diskman luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-app-hd-idle luci-i18n-hd-idle-zh-cn"
PACKAGES="$PACKAGES luci-app-samba4 luci-i18n-samba4-zh-cn"
PACKAGES="$PACKAGES luci-app-aria2 luci-i18n-aria2-zh-cn"
PACKAGES="$PACKAGES luci-i18n-openlist-zh-cn"
PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"

# Docker (R4S 强劲性能，推荐安装，根据变量决定)
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES dockerd luci-app-dockerman luci-i18n-dockerman-zh-cn"
    echo "🐳 Adding Docker packages"
fi

# 注入 custom-packages.sh 中的内容
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# -----------------------------------------------------------------------------
# 7. 执行构建
# -----------------------------------------------------------------------------
echo "$BUILD_DATE - Building image with the following packages:"
echo "$PACKAGES"

# 这里的 FILES="$FILES_DIR" 确保了我们的 99-custom.sh 和配置文件会被打包
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES" FILES="$FILES_DIR" ROOTFS_PARTSIZE="$ROOTFS_PARTSIZE"

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ❌ Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Build completed successfully."
