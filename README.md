# 📦 NanoPi R4S ImmortalWrt 自动构建

## 📖 简介
基于 GitHub Actions 为 NanoPi R4S 自动编译 ImmortalWrt 固件。

## 🚀 快速开始

### 🔧 使用方法
1. Fork 本项目
2. 进入 **Actions** 标签
3. 运行 **build-rockchip-immortalWrt-24.10.x** 工作流
4. 配置参数后点击运行

### ⚙️ 构建选项
- **LUCI 版本**: 选择 24.10.x 或 latest
- **管理地址**: 默认 192.168.1.1
- **Docker 支持**: 可选集成
- **PPPoE 配置**: 可预设宽带信息

## 📋 预装插件

### 🌐 网络工具
- 🛡️ luci-app-adguardhome - 广告拦截
- 🔥 luci-app-firewall - 防火墙管理
- 🌍 luci-app-passwall - 科学上网
- ⚡ luci-app-turboacc - 网络加速

### 📁 文件管理
- 📥 luci-app-aria2 - 下载工具
- 💾 luci-app-diskman - 磁盘管理
- 📂 luci-app-samba4 - 文件共享

### 🛠️ 系统工具
- 🐳 luci-app-docker - Docker管理
- 📋 luci-app-openlist - OpenList
- 📦 luci-app-package-manager - 软件包管理

### 🎨 界面主题
- 🌈 luci-theme-argon - Argon主题
- 🎯 luci-theme-bootstrap - 默认主题

### 🇨🇳 中文语言包
- 防火墙、基础、磁盘管理、PassWall、Samba等中文界面

## 📥 获取固件
构建完成后在 **Release** 页面下载 `.img.gz` 文件，使用 balenaEtcher 烧录即可。

## ⚡ 自定义
- 修改 `rockchip/imm.config` 调整软件包
- 编辑 `rockchip/build24.sh` 修改构建逻辑
