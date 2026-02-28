#!/bin/bash

OFFICIAL="downloads.immortalwrt.org"
MIRROR="mirrors.cernet.edu.cn/immortalwrt"
CONF_FILE="repositories.conf"

echo "========================================"
echo "🌐 开始检测软件源连通性..."

# 测试官方源是否能正常连通 (超时时间设为 3 秒)
if curl -I -s --connect-timeout 3 "https://${OFFICIAL}" > /dev/null; then
    echo "✅ 官方源 (${OFFICIAL}) 连通性良好，保持默认！"
    # 什么都不用做，直接用默认的 repositories.conf
else
    echo "⚠️ 官方源连接超时或失败，正在切换至备用镜像源..."
    echo ">>> Switching to mirror: $MIRROR"
    # 使用 sed 替换网址
    sed -i "s#https://${OFFICIAL}#https://${MIRROR}#g" "$CONF_FILE"
    sed -i "s#http://${OFFICIAL}#https://${MIRROR}#g" "$CONF_FILE"
    echo "✅ 镜像源切换完成！"
fi

echo "========================================"
echo "当前 repositories.conf 内容："
cat "$CONF_FILE"
echo "========================================"
