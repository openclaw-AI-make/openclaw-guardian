#!/bin/bash
# OpenClaw Guardian - 备份验证脚本
# 用法：./verify-backup.sh [备份名称]

set -e

BACKUP_ROOT="$HOME/.openclaw-full-backups"
BACKUP_NAME="$1"

if [ -z "$BACKUP_NAME" ]; then
    echo "用法：oc-verify [备份名称]"
    echo "运行 oc-list 查看所有备份"
    exit 0
fi

BACKUP_DIR="$BACKUP_ROOT/$BACKUP_NAME"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "备份不存在：$BACKUP_NAME"
    exit 1
fi

echo "=========================================="
echo " 验证备份：$BACKUP_NAME"
echo "=========================================="

# 检查校验和
if [ -f "$BACKUP_DIR/checksum.sha256" ]; then
    echo ""
    echo "校验和验证："
    cd $BACKUP_DIR
    if sha256sum -c checksum.sha256 2>/dev/null; then
        echo "所有文件校验通过"
    else
        echo "校验失败，备份可能已损坏"
        exit 1
    fi
    cd - > /dev/null
else
    echo "无校验和文件"
fi

# 检查备份内容
echo ""
echo "备份内容："
for tarfile in $BACKUP_DIR/*.tar.gz; do
    if [ -f "$tarfile" ]; then
        name=$(basename $tarfile)
        size=$(du -h $tarfile | cut -f1)
        files=$(tar -tzf $tarfile 2>/dev/null | wc -l)
        echo "  $name ($size, $files 个文件)"
    fi
done

# 检查清单
if [ -f "$BACKUP_DIR/manifest.json" ]; then
    echo ""
    echo "备份清单："
    cat $BACKUP_DIR/manifest.json | head -20
fi

echo ""
echo "=========================================="
echo " 备份验证完成"
echo "=========================================="
