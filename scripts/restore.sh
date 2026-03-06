#!/bin/bash
# OpenClaw Guardian - 系统恢复脚本
# 用法：./restore.sh [备份名称]

set -e

BACKUP_ROOT="$HOME/.openclaw-full-backups"
LOG_FILE="/var/log/openclaw-restore.log"
OPENCLAW_DIR="$HOME/.openclaw"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

BACKUP_NAME="$1"

if [ -z "$BACKUP_NAME" ]; then
    echo "可用的备份："
    echo ""
    ls -lt $BACKUP_ROOT/*/manifest.json 2>/dev/null | while read file; do
        dir=$(dirname $file)
        name=$(basename $dir)
        date=$(stat -c %y $dir | cut -d' ' -f1)
        echo "  $name ($date)"
    done
    
    if [ -z "$(ls -A $BACKUP_ROOT/*/manifest.json 2>/dev/null)" ]; then
        echo "暂无备份"
    fi
    echo ""
    echo "用法：oc-restore [备份名称]"
    exit 0
fi

BACKUP_DIR="$BACKUP_ROOT/$BACKUP_NAME"

if [ ! -d "$BACKUP_DIR" ]; then
    log "备份不存在：$BACKUP_NAME"
    echo "备份不存在：$BACKUP_NAME"
    exit 1
fi

# 验证备份完整性
log "验证备份完整性..."
if [ -f "$BACKUP_DIR/checksum.sha256" ]; then
    cd $BACKUP_DIR
    if sha256sum -c checksum.sha256 > /dev/null 2>&1; then
        log "校验和验证通过"
    else
        log "校验和验证失败，备份可能已损坏"
        echo "校验和验证失败，备份可能已损坏"
        exit 1
    fi
    cd - > /dev/null
fi

# 确认恢复
echo ""
echo "警告：这将恢复 OpenClaw 到备份状态"
echo "备份名称：$BACKUP_NAME"
echo "备份时间：$(stat -c %y $BACKUP_DIR | cut -d'.' -f1)"
echo ""
echo "以下配置将被覆盖："
echo "  - ~/.openclaw/openclaw.json"
echo "  - ~/.openclaw/credentials/"
echo "  - ~/.openclaw/workspace/"
echo "  - ~/.openclaw/plugins/"
echo ""
read -p "确认恢复？(y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "恢复已取消"
    exit 0
fi

# 备份当前状态
log "备份当前状态..."
CURRENT_BACKUP="$BACKUP_ROOT/pre-restore-$(date +%Y%m%d_%H%M%S)"
mkdir -p $CURRENT_BACKUP

if [ -d "$OPENCLAW_DIR" ]; then
    tar -czf "$CURRENT_BACKUP/pre-restore.tar.gz" -C $HOME/.openclaw . 2>/dev/null || true
    log "当前状态已保存：$CURRENT_BACKUP"
fi

# 停止服务
log "停止 OpenClaw 服务..."
systemctl --user stop openclaw-gateway 2>/dev/null || true
sleep 2

# 恢复配置
log "恢复核心配置..."
if [ -f "$BACKUP_DIR/openclaw-config.tar.gz" ]; then
    tar -xzf "$BACKUP_DIR/openclaw-config.tar.gz" -C $HOME/.openclaw
    log "核心配置已恢复"
fi

# 恢复工作区
log "恢复工作区..."
if [ -f "$BACKUP_DIR/workspace.tar.gz" ]; then
    tar -xzf "$BACKUP_DIR/workspace.tar.gz" -C $HOME/.openclaw/workspace
    log "工作区已恢复"
fi

# 恢复技能
log "恢复技能..."
if [ -f "$BACKUP_DIR/skills.tar.gz" ]; then
    tar -xzf "$BACKUP_DIR/skills.tar.gz" -C $HOME/.openclaw/workspace
    log "技能已恢复"
fi

# 恢复 systemd 配置
log "恢复系统服务配置..."
if [ -f "$BACKUP_DIR/systemd.tar.gz" ]; then
    tar -xzf "$BACKUP_DIR/systemd.tar.gz" -C $HOME/.config/systemd/user
    systemctl --user daemon-reload
    log "系统服务配置已恢复"
fi

# 设置权限
log "设置权限..."
chown -R ubuntu:ubuntu $OPENCLAW_DIR 2>/dev/null || true
chmod 600 $OPENCLAW_DIR/openclaw.json 2>/dev/null || true
chmod 700 $OPENCLAW_DIR/credentials 2>/dev/null || true

# 启动服务
log "启动 OpenClaw 服务..."
systemctl --user start openclaw-gateway 2>/dev/null || true
sleep 5

# 检查服务状态
if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
    log "服务启动成功"
    SERVICE_STATUS="运行正常"
else
    log "服务启动失败，需要检查"
    SERVICE_STATUS="启动失败"
fi

# 输出结果
echo ""
echo "=========================================="
echo " 恢复完成"
echo "=========================================="
echo "恢复自：$BACKUP_NAME"
echo "服务状态：$SERVICE_STATUS"
echo ""
echo "检查命令：oc-status"
echo "查看日志：oc-logs"
echo "=========================================="
echo ""
