#!/bin/bash
# OpenClaw Guardian - 完整备份脚本
# 用法：./full-backup.sh [备份名称]

set -e

# 配置
BACKUP_ROOT="$HOME/.openclaw-full-backups"
LOG_FILE="/var/log/openclaw-backup.log"
OPENCLAW_DIR="$HOME/.openclaw"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${1:-$TIMESTAMP}"
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_NAME"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "开始完整备份：$BACKUP_NAME"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份清单
MANIFEST="$BACKUP_DIR/manifest.json"
echo "{" > $MANIFEST
echo "  \"backup_name\": \"$BACKUP_NAME\"," >> $MANIFEST
echo "  \"timestamp\": \"$(date -Iseconds)\"," >> $MANIFEST
echo "  \"hostname\": \"$(hostname)\"," >> $MANIFEST
echo "  \"backup_items\": [" >> $MANIFEST

# 校验和文件
CHECKSUM_FILE="$BACKUP_DIR/checksum.sha256"
> $CHECKSUM_FILE

# 1. 备份核心配置
log "备份核心配置..."
CONFIG_TAR="$BACKUP_DIR/openclaw-config.tar.gz"
tar -czf $CONFIG_TAR -C $HOME/.openclaw openclaw.json credentials/ plugins/ 2>/dev/null || true

if [ -f "$CONFIG_TAR" ]; then
    echo "    \"openclaw-config.tar.gz\"," >> $MANIFEST
    (cd $BACKUP_DIR && sha256sum openclaw-config.tar.gz) >> $CHECKSUM_FILE
    log "  核心配置：$(du -h $CONFIG_TAR | cut -f1)"
fi

# 2. 备份工作区
log "备份工作区..."
WORKSPACE_TAR="$BACKUP_DIR/workspace.tar.gz"
tar -czf $WORKSPACE_TAR -C $HOME/.openclaw/workspace . 2>/dev/null || true

if [ -f "$WORKSPACE_TAR" ]; then
    echo "    \"workspace.tar.gz\"," >> $MANIFEST
    (cd $BACKUP_DIR && sha256sum workspace.tar.gz) >> $CHECKSUM_FILE
    log "  工作区：$(du -h $WORKSPACE_TAR | cut -f1)"
fi

# 3. 备份技能
log "备份技能..."
SKILLS_TAR="$BACKUP_DIR/skills.tar.gz"
if [ -d "$HOME/.openclaw/workspace/skills" ]; then
    tar -czf $SKILLS_TAR -C $HOME/.openclaw/workspace skills 2>/dev/null || true
    
    if [ -f "$SKILLS_TAR" ]; then
        echo "    \"skills.tar.gz\"," >> $MANIFEST
        (cd $BACKUP_DIR && sha256sum skills.tar.gz) >> $CHECKSUM_FILE
        log "  技能：$(du -h $SKILLS_TAR | cut -f1)"
    fi
fi

# 4. 备份 systemd 配置
log "备份系统服务配置..."
SYSTEMD_TAR="$BACKUP_DIR/systemd.tar.gz"
tar -czf $SYSTEMD_TAR -C $HOME/.config/systemd/user . 2>/dev/null || true

if [ -f "$SYSTEMD_TAR" ]; then
    echo "    \"systemd.tar.gz\"" >> $MANIFEST
    (cd $BACKUP_DIR && sha256sum systemd.tar.gz) >> $CHECKSUM_FILE
    log "  系统服务：$(du -h $SYSTEMD_TAR | cut -f1)"
fi

# 完成清单
echo "  ]" >> $MANIFEST
echo "}" >> $MANIFEST

# 计算总大小
TOTAL_SIZE=$(du -sh $BACKUP_DIR | cut -f1)
log "备份完成：$BACKUP_DIR"
log "总大小：$TOTAL_SIZE"

# 清理旧备份（保留最近 10 个）
log "清理旧备份..."
cd $BACKUP_ROOT
ls -dt */ 2>/dev/null | tail -n +11 | xargs -r rm -rf
KEPT=$(ls -d */ 2>/dev/null | wc -l)
log "保留最近 $KEPT 个备份"

# 输出信息
echo ""
echo "=========================================="
echo " 完整备份完成"
echo "=========================================="
echo "备份名称：$BACKUP_NAME"
echo "备份位置：$BACKUP_DIR"
echo "总大小：$TOTAL_SIZE"
echo ""
echo "恢复命令：oc-restore $BACKUP_NAME"
echo "验证命令：oc-verify $BACKUP_NAME"
echo "列表命令：oc-list"
echo "=========================================="
echo ""
