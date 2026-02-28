# NanoPi R4S ImmortalWrt 自动构建

## 简介
基于 GitHub Actions 为 NanoPi R4S 自动编译 ImmortalWrt 固件。

## 快速开始

### 使用方法
1. Fork 本项目
2. 进入 Actions 标签
3. 运行 build-rockchip-immortalWrt-24.10.x 工作流
4. 配置参数后点击运行

### 构建选项
- LUCI 版本: 选择 24.10.x 或 latest
- 管理地址: 默认 192.168.1.1
- Docker 支持: 可选集成
- PPPoE 配置: 可预设宽带信息

## 预装功能

### 网络工具
- 动态 DNS、防火墙、UPnP、SQM、WireGuard

### 系统管理  
- 定时任务、文件传输、Samba、网页终端

### Docker 支持（可选）
- Docker 容器管理界面

## 获取固件
构建完成后在 Release 页面下载 .img.gz 文件，使用 balenaEtcher 烧录即可。

## 自定义
- 修改 rockchip/imm.config 调整软件包
- 编辑 rockchip/build24.sh 修改构建逻辑
