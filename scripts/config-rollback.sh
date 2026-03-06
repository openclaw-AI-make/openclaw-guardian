#!/bin/bash
# OpenClaw Guardian - 手动回滚脚本
# 用法：./config-rollback.sh [时间戳]

set -e

BACKUP_DIR="$HOME/.openclaw-backups"
LOG_FILE="/var/log/openclaw-rollback.log"
CONFIG_FILE="$HOME/.openclaw/openclaw.json"
OPENCLAW_DIR="$HOME/.openclaw"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

TIMESTAMP="$1"

if [ -z "$TIMESTAMP" ]; then
    # 显示所有备份
    echo "可用的备份："
    echo ""
    
    ls -lt $BACKUP_DIR/*.bak 2>/dev/null | head -10 | while read line; do
        echo "  $line"
    done
    
    if [ -z "$(ls -A $BACKUP_DIR/*.bak 2>/dev/null)" ]; then
        echo "暂无备份文件"
    fi
    echo ""
    echo "用法：oc-rollback [时间戳]"
    echo "例如：oc-rollback 20260307_020000"
    exit 0
fi

# 找到备份文件
BACKUP_FILE=$(ls $BACKUP_DIR/openclaw.json.$TIMESTAMP.bak 2>/dev/null | head -1)

if [ -z "$BACKUP_FILE" ]; then
    log "未找到备份：$TIMESTAMP"
    echo "未找到备份：$TIMESTAMP"
    echo "运行 oc-rollback 查看所有可用备份"
    exit 1
fi

# 确认回滚
echo ""
echo "警告：这将回滚配置到 $TIMESTAMP"
echo "备份文件：$BACKUP_FILE"
echo ""
read -p "确认回滚？(y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "回滚已取消"
    exit 0
fi

# 备份当前配置（回滚前的回滚）
CURRENT_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CURRENT_BACKUP="$BACKUP_DIR/openclaw.json.$CURRENT_TIMESTAMP.pre-rollback.bak"
cp "$CONFIG_FILE" "$CURRENT_BACKUP"
log "已保存当前配置：$CURRENT_BACKUP"

# 执行回滚
cp "$BACKUP_FILE" "$CONFIG_FILE"
log "已回滚配置：$BACKUP_FILE"

# 清理缓存
log "清理缓存..."
rm -rf $OPENCLAW_DIR/cache/* 2>/dev/null || true
rm -rf $OPENCLAW_DIR/sessions/*.json 2>/dev/null || true
rm -rf $OPENCLAW_DIR/plugins/cache/* 2>/dev/null || true

# 重启服务
log "重启服务..."
systemctl --user restart openclaw-gateway 2>/dev/null || true
sleep 5

# 检查服务状态
echo ""
echo "=========================================="
echo " 回滚完成"
echo "=========================================="
echo "回滚到：$TIMESTAMP"
echo "服务状态：$(systemctl --user is-active openclaw-gateway 2>/dev/null || echo 'unknown')"
echo "=========================================="
echo ""

if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
    echo "服务运行正常"
else
    echo "服务启动失败，请检查日志"
fi
