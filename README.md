# OpenClaw Guardian 🦞

> OpenClaw 守护技能 - 自动健康检查、配置回滚、服务恢复

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-Skill-blue.svg)](https://docs.openclaw.ai)

---

## 📋 功能特性

| 功能 | 说明 | 状态 |
|------|------|------|
| **健康检查** | 4 层检查（进程 + 端口+API+ 功能） | ✅ |
| **自动回滚** | 配置修改前自动备份，5 分钟超时回滚 | ✅ |
| **服务恢复** | 服务崩溃自动重启/回滚 | ✅ |
| **多通道通知** | 钉钉 + Telegram 故障通知 | ✅ |
| **缓存清理** | 智能分级清理（light/medium/full） | ✅ |
| **完整备份** | 系统完整备份与恢复 | ✅ |

---

## 🚀 快速开始

### 安装

```bash
# 克隆仓库
git clone https://github.com/openclaw-AI-make/openclaw-guardian.git
cd openclaw-guardian

# 复制配置模板
cp notify.conf.example notify.conf
cp nas.conf.example nas.conf

# 编辑配置
nano notify.conf
nano nas.conf
```

### 配置

**编辑 `notify.conf`**：
```bash
# Telegram 通知配置
BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
CHAT_ID="YOUR_CHAT_ID_HERE"
```

**编辑 `nas.conf`**：
```bash
# NAS 配置
NAS_HOST="192.168.10.6"
NAS_USER="openclaw"
NAS_PASS="YOUR_NAS_PASSWORD_HERE"
NAS_DIR="/openclaw"
```

### 使用

```bash
# 备份配置（带 5 分钟回滚保护）
oc-config-backup

# 完整备份
oc-backup

# 查看备份列表
oc-list

# 恢复系统
oc-restore <备份名称>

# 确认配置（取消回滚）
oc-confirm <时间戳>

# 手动回滚
oc-rollback <时间戳>

# 清理缓存
oc-cache-clean [light|medium|full]

# 查看服务状态
oc-status

# 查看日志
oc-logs
```

---

## 📁 文件结构

```
openclaw-guardian/
├── scripts/                    # 核心脚本
│   ├── watchdog.sh             # 服务监控
│   ├── config-backup.sh        # 配置备份
│   ├── confirm-config.sh       # 确认口令
│   ├── config-rollback.sh      # 手动回滚
│   ├── cleanup-cache.sh        # 缓存清理
│   ├── full-backup.sh          # 完整备份
│   ├── restore.sh              # 系统恢复
│   ├── verify-backup.sh        # 备份验证
│   ├── list-backups.sh         # 备份列表
│   └── test-all.sh             # 完整测试
│
├── .github/
│   └── workflows/
│       └── ci.yml              # CI/CD 工作流
│
├── notify.conf.example         # 通知配置模板
├── nas.conf.example            # NAS 配置模板
├── .gitignore                  # Git 忽略规则
├── LICENSE                     # MIT 许可
└── README.md                   # 本文件
```

---

## 🔒 安全说明

**敏感信息处理**：

| 信息 | 处理方式 |
|------|---------|
| Telegram Token | 使用占位符 + GitHub Secrets |
| NAS 密码 | 使用占位符 + GitHub Secrets |
| 凭证文件 | 加入 .gitignore，不提交 |
| 日志文件 | 加入 .gitignore，不提交 |

**配置 Secrets**：

在 GitHub 仓库设置中添加：
```
Settings → Secrets and variables → Actions

添加：
- BOT_TOKEN
- NAS_PASS
```

---

## 📊 监控流程

```
健康检查（每 1 分钟）
    ↓
发现异常
    ↓
轻量重启 → 成功 → 发送通知
    ↓ 失败
强制恢复 → 成功 → 发送通知
    ↓ 失败
配置回滚 → 成功 → 发送通知
    ↓ 失败
发送告警 → 等待人工干预
```

---

## 🧪 测试

```bash
# 运行完整测试
./scripts/test-all.sh

# 测试结果
测试结果：通过 (所有测试完成)
通过：17
失败：0
```

---

## 📝 变更日志

### v1.0.0 (2026-03-07)

- ✅ 初始发布
- ✅ 10 个核心脚本
- ✅ 4 层健康检查
- ✅ 3 级恢复流程
- ✅ 多通道通知
- ✅ 智能缓存清理

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📄 许可

MIT License - 详见 [LICENSE](LICENSE) 文件

---

## 🔗 相关链接

| 项目 | 地址 |
|------|------|
| OpenClaw 官方 | https://openclaw.ai |
| 文档 | https://docs.openclaw.ai |
| 灾备系统 | https://github.com/openclaw-AI-make/openclaw-disaster-recovery |
| 组织主页 | https://github.com/openclaw-AI-make |

---

<p align="center">
  <strong>🦞 OpenClaw Guardian - 你的 AI 助手守护神</strong>
</p>
