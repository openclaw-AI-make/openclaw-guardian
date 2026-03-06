#!/bin/bash
# OpenClaw Guardian - 完整测试脚本
# 用法：./test-all.sh

set -e

SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="/var/log/openclaw-test.log"
TEST_PASSED=0
TEST_FAILED=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

test_pass() {
    log "PASS: $1"
    TEST_PASSED=$((TEST_PASSED + 1))
}

test_fail() {
    log "FAIL: $1"
    TEST_FAILED=$((TEST_FAILED + 1))
}

# 测试 1：脚本语法检查
test_syntax() {
    log "测试 1：脚本语法检查..."
    
    for script in $SCRIPT_DIR/*.sh; do
        if bash -n "$script" 2>/dev/null; then
            test_pass "$(basename $script) 语法正确"
        else
            test_fail "$(basename $script) 语法错误"
        fi
    done
}

# 测试 2：目录权限检查
test_permissions() {
    log "测试 2：目录权限检查..."
    
    for dir in $SCRIPT_DIR $HOME/.openclaw-backups $HOME/.openclaw-full-backups; do
        if [ -d "$dir" ]; then
            test_pass "$dir 目录存在"
        else
            test_fail "$dir 目录不存在"
        fi
    done
}

# 测试 3：健康检查函数测试
test_health_check() {
    log "测试 3：健康检查函数测试..."
    
    status=$($SCRIPT_DIR/watchdog.sh --test-health 2>&1) || true
    
    if echo "$status" | grep -q "healthy\|process_missing\|port_missing\|api_unreachable\|api_error"; then
        test_pass "健康检查返回正确状态：$status"
    else
        test_fail "健康检查返回异常状态：$status"
    fi
}

# 测试 4：备份列表测试
test_backup_list() {
    log "测试 4：备份列表测试..."
    
    if $SCRIPT_DIR/list-backups.sh > /dev/null 2>&1; then
        test_pass "备份列表命令执行成功"
    else
        test_fail "备份列表命令执行失败"
    fi
}

# 测试 5：缓存清理测试
test_cache_cleanup() {
    log "测试 5：缓存清理测试..."
    
    # 创建测试缓存
    mkdir -p $HOME/.openclaw/cache/test
    touch $HOME/.openclaw/cache/test/testfile.tmp
    
    # 执行清理（medium 级别会清理 cache 目录）
    $SCRIPT_DIR/cleanup-cache.sh medium 2>&1
    
    # 验证
    if [ ! -d $HOME/.openclaw/cache/test ]; then
        test_pass "缓存清理成功"
    else
        test_fail "缓存清理失败"
    fi
    
    # 清理测试目录
    rm -rf $HOME/.openclaw/cache/test 2>/dev/null || true
}

# 测试 6：确认命令测试
test_confirm() {
    log "测试 6：确认命令测试..."
    
    if $SCRIPT_DIR/confirm-config.sh > /dev/null 2>&1; then
        test_pass "确认命令执行成功"
    else
        test_fail "确认命令执行失败"
    fi
}

# 主测试流程
main() {
    log "=========================================="
    log "开始 OpenClaw Guardian 测试"
    log "=========================================="
    
    test_syntax
    test_permissions
    test_health_check
    test_backup_list
    test_cache_cleanup
    test_confirm
    
    log "=========================================="
    log "测试完成"
    log "通过：$TEST_PASSED"
    log "失败：$TEST_FAILED"
    log "=========================================="
    
    if [ $TEST_FAILED -gt 0 ]; then
        log "有测试失败，请修复后再部署"
        echo ""
        echo "测试结果：失败 ($TEST_FAILED 个测试未通过)"
        exit 1
    else
        log "所有测试通过，可以部署"
        echo ""
        echo "测试结果：通过 (所有测试完成)"
        exit 0
    fi
}

main "$@"
