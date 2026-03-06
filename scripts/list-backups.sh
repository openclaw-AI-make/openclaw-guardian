#!/bin/bash
# OpenClaw Guardian - 备份列表脚本
# 用法：./list-backups.sh

BACKUP_ROOT="$HOME/.openclaw-full-backups"

echo "=========================================="
echo " OpenClaw 备份列表"
echo "=========================================="
echo ""

if [ ! -d "$BACKUP_ROOT" ]; then
    echo "暂无备份"
    exit 0
fi

cd $BACKUP_ROOT

# 按时间排序显示
for dir in $(ls -dt */ 2>/dev/null); do
    name=$(basename $dir)
    date=$(stat -c %y $dir | cut -d'.' -f1)
    size=$(du -sh $dir | cut -f1)
    
    # 检查是否有 manifest
    if [ -f "$dir/manifest.json" ]; then
        items=$(grep -c '"tar.gz"' $dir/manifest.json 2>/dev/null || echo "0")
        echo " 备份：$name"
        echo "  时间：$date"
        echo "  大小：$size"
        echo "  文件：$items 个"
        echo "  恢复：oc-restore $name"
        echo ""
    fi
done

echo "=========================================="
