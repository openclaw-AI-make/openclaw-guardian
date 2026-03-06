#!/bin/bash
# OpenClaw Guardian - 确认口令脚本
# 用法：./confirm-config.sh [时间戳]

set -e

BACKUP_DIR="$HOME/.openclaw-backups"
LOG_FILE="/var/log/openclaw-backup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

TIMESTAMP="$1"

if [ -z "$TIMESTAMP" ]; then
    # 显示待确认的回滚
    echo "待确认的回滚："
    echo ""
    
    found=0
    for marker in $BACKUP_DIR/.rollback_pending_*; do
        if [ -f "$marker" ]; then
            ts=$(basename $marker | sed 's/.rollback_pending_//')
            echo "  时间：$ts"
            
            if [ -f "$marker" ]; then
                source $marker
                echo "  配置：$CONFIG"
                echo "  延迟：${DELAY:-300}秒"
                echo "  创建：$CREATED"
            fi
            echo ""
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo "暂无待确认的回滚"
    fi
    exit 0
fi

# 取消指定回滚
MARKER="$BACKUP_DIR/.rollback_pending_$TIMESTAMP"

if [ ! -f "$MARKER" ]; then
    log "未找到待回滚标记：$TIMESTAMP"
    echo "未找到待回滚标记：$TIMESTAMP"
    echo "运行 confirm-config 查看所有待确认项"
    exit 1
fi

# 删除标记
rm -f "$MARKER"
log "回滚已取消：$TIMESTAMP"

echo ""
echo "=========================================="
echo " 配置已确认"
echo "=========================================="
echo "时间戳：$TIMESTAMP"
echo "回滚保护已解除"
echo "=========================================="
echo ""
