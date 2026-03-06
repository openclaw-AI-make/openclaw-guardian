#!/bin/bash
# OpenClaw Guardian - 服务监控脚本
# 用法：./watchdog.sh [--test-health]

set -e

# 配置
BACKUP_DIR="$HOME/.openclaw-backups"
LOG_FILE="/var/log/openclaw-watchdog.log"
CONFIG_FILE="$HOME/.openclaw/openclaw.json"
SERVICE="openclaw-gateway"
PORT=18789
HEALTH_URL="http://127.0.0.1:$PORT/health"
OPENCLAW_DIR="$HOME/.openclaw"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 健康检查函数
health_check() {
    # 1. 检查进程
    if ! pgrep -f "openclaw-gateway" > /dev/null 2>&1; then
        echo "process_missing"
        return
    fi
    
    # 2. 检查端口
    if ! ss -tln 2>/dev/null | grep -q ":$PORT "; then
        echo "port_missing"
        return
    fi
    
    # 3. 检查 API（超时 5 秒）
    if ! curl -s --max-time 5 "$HEALTH_URL" > /dev/null 2>&1; then
        echo "api_unreachable"
        return
    fi
    
    # 4. 检查响应内容
    response=$(curl -s --max-time 5 "$HEALTH_URL" 2>/dev/null)
    if ! echo "$response" | grep -q '"status".*"ok"' 2>/dev/null; then
        echo "api_error"
        return
    fi
    
    echo "healthy"
}

# 检查渠道配置
check_channel_config() {
    local channel="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    if grep -q "\"$channel\"" "$CONFIG_FILE" 2>/dev/null && \
       grep -A 5 "\"$channel\"" "$CONFIG_FILE" | grep -q '"enabled".*true' 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# 发送钉钉通知
send_dingtalk() {
    local title="$1"
    local content="$2"
    
    log "发送钉钉通知：$title"
    
    # 使用 openclaw 命令发送
    if command -v openclaw > /dev/null 2>&1; then
        openclaw message send --channel dingtalk --message "*$title*

$content" 2>/dev/null && return 0
    fi
    
    log "钉钉通知发送失败（openclaw 命令不可用）"
    return 1
}

# 发送 Telegram 通知
send_telegram() {
    local title="$1"
    local content="$2"
    
    log "发送 Telegram 通知：$title"
    
    # 使用 openclaw 命令发送
    if command -v openclaw > /dev/null 2>&1; then
        openclaw message send --channel telegram --message "*$title*

$content" 2>/dev/null && return 0
    fi
    
    log "Telegram 通知发送失败（openclaw 命令不可用）"
    return 1
}

# 多通道通知
send_multi_channel() {
    local title="$1"
    local content="$2"
    local sent=0
    
    log "开始多通道通知：$title"
    
    # 检查并发送钉钉
    if check_channel_config "dingtalk"; then
        log "检测到钉钉配置，发送通知..."
        send_dingtalk "$title" "$content" && sent=$((sent + 1))
    else
        log "钉钉未配置，跳过"
    fi
    
    # 检查并发送 Telegram
    if check_channel_config "telegram"; then
        log "检测到 Telegram 配置，发送通知..."
        send_telegram "$title" "$content" && sent=$((sent + 1))
    else
        log "Telegram 未配置，跳过"
    fi
    
    if [ $sent -eq 0 ]; then
        log "警告：没有配置任何通知渠道，只记录日志"
    else
        log "已发送 $sent 个渠道的通知"
    fi
}

# 获取最近日志错误
get_recent_errors() {
    journalctl --user -u $SERVICE --since "5 minutes ago" 2>/dev/null | \
        grep -i "error\|fail\|exception" | tail -5 || echo "无错误日志"
}

# 清理残留进程
cleanup_process() {
    log "清理残留进程..."
    pkill -9 -f "openclaw-gateway" 2>/dev/null || true
    sleep 3
    
    # 检查端口是否释放
    if ss -tln 2>/dev/null | grep -q ":$PORT "; then
        log "端口 $PORT 仍被占用，尝试强制释放..."
        fuser -k $PORT/tcp 2>/dev/null || true
        sleep 2
    fi
}

# 清理缓存（根据故障类型）
cleanup_cache_by_error() {
    local error_type="$1"
    
    case $error_type in
        "process_missing"|"port_missing")
            log "轻量清理缓存..."
            rm -rf /tmp/openclaw/*.lock 2>/dev/null || true
            ;;
        
        "api_unreachable"|"api_error")
            log "中等清理缓存..."
            rm -rf /tmp/openclaw/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/cache/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/sessions/*.json 2>/dev/null || true
            ;;
        
        "config_error"|"startup_failed")
            log "完全清理缓存..."
            rm -rf /tmp/openclaw/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/cache/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/sessions/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/plugins/cache/* 2>/dev/null || true
            rm -rf ~/.cache/openclaw/* 2>/dev/null || true
            ;;
        
        *)
            log "中等清理缓存..."
            rm -rf /tmp/openclaw/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/cache/* 2>/dev/null || true
            ;;
    esac
}

# 配置回滚
rollback_config() {
    local backup_file="$1"
    
    log "开始配置回滚..."
    
    # 1. 备份当前配置
    local crash_backup="$BACKUP_DIR/openclaw.json.$(date +%Y%m%d_%H%M%S).crash.bak"
    cp $CONFIG_FILE $crash_backup
    log "已保存当前配置：$crash_backup"
    
    # 2. 回滚配置
    cp $backup_file $CONFIG_FILE
    log "已回滚配置：$backup_file"
    
    # 3. 清理凭证缓存
    log "清理凭证缓存..."
    rm -rf $OPENCLAW_DIR/credentials/*.session 2>/dev/null || true
    rm -rf $OPENCLAW_DIR/credentials/*.token 2>/dev/null || true
    
    # 4. 清理渠道缓存
    log "清理渠道缓存..."
    rm -rf $OPENCLAW_DIR/cache/dingtalk/* 2>/dev/null || true
    rm -rf $OPENCLAW_DIR/cache/telegram/* 2>/dev/null || true
    
    # 5. 清理插件缓存
    log "清理插件缓存..."
    rm -rf $OPENCLAW_DIR/plugins/cache/* 2>/dev/null || true
    
    # 6. 清理会话缓存
    log "清理会话缓存..."
    rm -rf $OPENCLAW_DIR/sessions/*.json 2>/dev/null || true
    
    # 7. 清理系统缓存
    log "清理系统缓存..."
    rm -rf ~/.cache/openclaw/* 2>/dev/null || true
    
    log "缓存清理完成"
}

# 主恢复流程
main() {
    # 测试模式
    if [ "$1" = "--test-health" ]; then
        status=$(health_check)
        echo "健康检查结果：$status"
        exit 0
    fi
    
    status=$(health_check)
    
    if [ "$status" = "healthy" ]; then
        log "服务健康检查通过"
        exit 0
    fi
    
    log "发现异常：$status"
    log "最近错误日志："
    get_recent_errors | while read line; do log "  $line"; done
    
    # 第 1 步：尝试轻量重启
    log "尝试轻量重启..."
    systemctl --user restart $SERVICE 2>/dev/null || true
    sleep 10
    
    status=$(health_check)
    if [ "$status" = "healthy" ]; then
        log "轻量重启成功"
        send_multi_channel "OpenClaw 服务已恢复" "服务在 $(date) 自动重启成功，故障类型：$status"
        exit 0
    fi
    
    # 第 2 步：强制恢复
    log "轻量重启失败，执行强制恢复..."
    cleanup_process
    cleanup_cache_by_error "$status"
    
    systemctl --user start $SERVICE 2>/dev/null || true
    sleep 15
    
    status=$(health_check)
    if [ "$status" = "healthy" ]; then
        log "强制恢复成功"
        send_multi_channel "OpenClaw 服务已恢复" "服务在 $(date) 强制恢复成功，故障类型：$status"
        exit 0
    fi
    
    # 第 3 步：配置回滚
    log "强制恢复失败，尝试配置回滚..."
    
    LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.bak 2>/dev/null | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        log "未找到备份，无法回滚"
        send_multi_channel "OpenClaw 故障告警" "所有恢复尝试失败，未找到备份，需要人工干预！

故障类型：$status
时间：$(date)"
        exit 1
    fi
    
    log "找到备份：$LATEST_BACKUP"
    
    rollback_config "$LATEST_BACKUP"
    
    cleanup_process
    systemctl --user start $SERVICE 2>/dev/null || true
    sleep 15
    
    status=$(health_check)
    if [ "$status" = "healthy" ]; then
        log "配置回滚成功"
        send_multi_channel "OpenClaw 服务已恢复" "服务在 $(date) 通过配置回滚恢复成功

回滚到备份：$LATEST_BACKUP"
        exit 0
    fi
    
    # 第 4 步：完全失败
    log "所有恢复尝试失败！"
    log "服务状态：$(systemctl --user status $SERVICE --no-pager 2>/dev/null | head -5)"
    log "需要人工干预！"
    
    send_multi_channel "OpenClaw 故障告警" "所有恢复尝试失败，需要人工干预！

故障类型：$status
时间：$(date)

请检查日志：sudo journalctl -u openclaw-watchdog"
    
    exit 1
}

main "$@"
