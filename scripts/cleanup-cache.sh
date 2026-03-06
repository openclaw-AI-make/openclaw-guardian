#!/bin/bash
# OpenClaw Guardian - 缓存清理脚本
# 用法：./cleanup-cache.sh [light|medium|full|nuclear]

set -e

OPENCLAW_DIR="$HOME/.openclaw"
LOG_FILE="/var/log/openclaw-cache-cleanup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 清理缓存（分级清理）
cleanup_cache() {
    local level="$1"
    
    case $level in
        "light")
            log "轻量清理：清理临时文件..."
            rm -rf /tmp/openclaw/*.lock 2>/dev/null || true
            rm -rf /tmp/openclaw/*.tmp 2>/dev/null || true
            ;;
        
        "medium")
            log "中等清理：清理临时文件和会话缓存..."
            rm -rf /tmp/openclaw/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/cache/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/sessions/*.json 2>/dev/null || true
            ;;
        
        "full")
            log "完全清理：清理所有缓存（保留凭证）..."
            rm -rf /tmp/openclaw/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/cache/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/sessions/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/plugins/cache/* 2>/dev/null || true
            rm -rf ~/.cache/openclaw/* 2>/dev/null || true
            rm -rf ~/.local/state/systemd/user/openclaw* 2>/dev/null || true
            ;;
        
        "nuclear")
            log "核弹清理：清理所有数据（包括凭证，慎用！）..."
            rm -rf /tmp/openclaw/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/cache/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/sessions/* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/plugins/cache/* 2>/dev/null || true
            rm -rf ~/.cache/openclaw/* 2>/dev/null || true
            rm -rf ~/.local/state/systemd/user/openclaw* 2>/dev/null || true
            rm -rf $OPENCLAW_DIR/credentials/* 2>/dev/null || true
            ;;
    esac
    
    log "清理完成：$level"
}

# 检查缓存状态
check_cache_status() {
    log "检查缓存状态..."
    
    # 检查临时文件
    tmp_count=$(ls -1 /tmp/openclaw/*.lock 2>/dev/null | wc -l)
    if [ $tmp_count -gt 0 ]; then
        log "发现 $tmp_count 个锁文件"
    fi
    
    # 检查会话缓存
    session_count=$(ls -1 $OPENCLAW_DIR/sessions/*.json 2>/dev/null | wc -l)
    if [ $session_count -gt 100 ]; then
        log "警告：会话缓存过多 ($session_count 个)"
    fi
    
    # 检查缓存大小
    if [ -d "$OPENCLAW_DIR/cache" ]; then
        cache_size=$(du -sh $OPENCLAW_DIR/cache 2>/dev/null | cut -f1)
        if [ "$cache_size" != "" ]; then
            log "缓存大小：$cache_size"
        fi
    fi
}

# 主函数
main() {
    local level="${1:-medium}"
    
    # 帮助信息
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "用法：cleanup-cache.sh [light|medium|full|nuclear]"
        echo ""
        echo "清理级别:"
        echo "  light   - 轻量清理（锁文件）"
        echo "  medium  - 中等清理（临时文件 + 会话缓存）"
        echo "  full    - 完全清理（所有缓存，保留凭证）"
        echo "  nuclear - 核弹清理（所有数据，包括凭证）"
        echo ""
        echo "示例:"
        echo "  cleanup-cache.sh light"
        echo "  cleanup-cache.sh medium"
        exit 0
    fi
    
    log "开始清理缓存（级别：$level）"
    check_cache_status
    cleanup_cache $level
    log "缓存清理完成"
}

main "$@"
