#!/bin/bash
# OpenClaw Guardian - 配置备份脚本
# 用法：./config-backup.sh [回滚延迟秒数]

set -e

# 配置
BACKUP_DIR="$HOME/.openclaw-backups"
LOG_FILE="/var/log/openclaw-backup.log"
OPENCLAW_DIR="$HOME/.openclaw"
DEFAULT_DELAY=300  # 5 分钟
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

ROLLBACK_DELAY="${1:-$DEFAULT_DELAY}"
CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"

log "开始配置备份"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    log "错误：配置文件不存在 $CONFIG_FILE"
    exit 1
fi

# 备份配置
BACKUP_FILE="$BACKUP_DIR/openclaw.json.$TIMESTAMP.bak"
cp $CONFIG_FILE $BACKUP_FILE
chmod 600 $BACKUP_FILE

log "配置已备份：$BACKUP_FILE"

# 备份凭证
if [ -d "$OPENCLAW_DIR/credentials" ]; then
    CREDENTIALS_BACKUP="$BACKUP_DIR/credentials.$TIMESTAMP.tar.gz"
    tar -czf $CREDENTIALS_BACKUP -C $OPENCLAW_DIR credentials 2>/dev/null || true
    log "凭证已备份：$CREDENTIALS_BACKUP"
fi

# 备份工作区
if [ -d "$OPENCLAW_DIR/workspace" ]; then
    WORKSPACE_BACKUP="$BACKUP_DIR/workspace.$TIMESTAMP.tar.gz"
    tar -czf $WORKSPACE_BACKUP -C $OPENCLAW_DIR workspace 2>/dev/null || true
    log "工作区已备份：$WORKSPACE_BACKUP"
fi

# 创建回滚标记
ROLLBACK_MARKER="$BACKUP_DIR/.rollback_pending_$TIMESTAMP"
cat > $ROLLBACK_MARKER << EOF
TIMESTAMP=$TIMESTAMP
CONFIG=$BACKUP_FILE
CREDENTIALS=$CREDENTIALS_BACKUP
WORKSPACE=$WORKSPACE_BACKUP
DELAY=$ROLLBACK_DELAY
CREATED=$(date -Iseconds)
EOF

log "回滚标记已创建"

# 启动回滚定时器
(
    sleep $ROLLBACK_DELAY
    
    if [ -f "$ROLLBACK_MARKER" ]; then
        log "超时未确认，开始自动回滚..."
        
        # 读取备份清单
        source $ROLLBACK_MARKER
        
        # 回滚配置
        if [ -f "$CONFIG" ]; then
            cp $CONFIG $OPENCLAW_DIR/openclaw.json
            log "已回滚配置"
        fi
        
        # 回滚凭证
        if [ -f "$CREDENTIALS" ]; then
            tar -xzf $CREDENTIALS -C $OPENCLAW_DIR 2>/dev/null || true
            log "已回滚凭证"
        fi
        
        # 回滚工作区
        if [ -f "$WORKSPACE" ]; then
            tar -xzf $WORKSPACE -C $OPENCLAW_DIR 2>/dev/null || true
            log "已回滚工作区"
        fi
        
        # 重启服务
        systemctl --user restart openclaw-gateway 2>/dev/null || true
        log "已重启服务"
        
        # 清理标记
        rm -f $ROLLBACK_MARKER
        log "回滚完成"
    fi
) &

# 输出信息
echo ""
echo "=========================================="
echo " 配置备份完成"
echo "=========================================="
echo "备份时间：$TIMESTAMP"
echo "回滚延迟：$((ROLLBACK_DELAY/60)) 分钟"
echo "取消回滚：oc-confirm $TIMESTAMP"
echo "手动回滚：oc-rollback $TIMESTAMP"
echo "=========================================="
echo ""
