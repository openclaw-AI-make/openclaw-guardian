# OpenClaw Guardian Skill

## 技能信息

| 项目 | 内容 |
|------|------|
| **名称** | OpenClaw Guardian |
| **版本** | 1.0.0 |
| **作者** | 瓶子 (20721) |
| **许可** | MIT |
| **组织** | openclaw-AI-make |

---

## 功能特性

- ✅ 自动健康检查（每分钟）
- ✅ 配置修改前自动备份
- ✅ 5 分钟超时回滚保护
- ✅ 服务崩溃自动恢复
- ✅ 多通道故障通知（钉钉 + Telegram）
- ✅ 智能缓存清理
- ✅ 完整系统备份与恢复

---

## 安装

```bash
clawhub install openclaw-guardian
```

或手动安装：

```bash
git clone https://github.com/openclaw-AI-make/openclaw-guardian.git
cd openclaw-guardian
cp scripts/* ~/.openclaw-protection/
chmod +x ~/.openclaw-protection/*.sh
```

---

## 配置

### 1. 通知配置

复制并编辑 `notify.conf`：

```bash
cp notify.conf.example notify.conf
nano notify.conf
```

配置内容：
```bash
BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
CHAT_ID="YOUR_CHAT_ID_HERE"
```

### 2. NAS 配置（可选）

```bash
cp nas.conf.example nas.conf
nano nas.conf
```

配置内容：
```bash
NAS_HOST="192.168.10.6"
NAS_USER="openclaw"
NAS_PASS="YOUR_NAS_PASSWORD_HERE"
NAS_DIR="/openclaw"
```

---

## 命令参考

| 命令 | 说明 |
|------|------|
| `oc-backup` | 完整系统备份 |
| `oc-restore <名称>` | 系统恢复 |
| `oc-verify <名称>` | 备份验证 |
| `oc-list` | 备份列表 |
| `oc-config-backup` | 配置备份（5 分钟回滚） |
| `oc-confirm <时间戳>` | 确认配置 |
| `oc-rollback <时间戳>` | 手动回滚 |
| `oc-cache-clean [级别]` | 清理缓存 |
| `oc-status` | 查看服务状态 |
| `oc-logs` | 查看日志 |

---

## 使用示例

### 修改配置前

```bash
# 1. 备份配置（启动 5 分钟回滚保护）
oc-config-backup

# 2. 修改配置
nano ~/.openclaw/openclaw.json

# 3. 重启服务
systemctl --user restart openclaw-gateway

# 4. 测试正常后确认
oc-confirm <时间戳>
```

### 服务崩溃自动恢复

```
系统自动检测 → 自动重启 → 自动回滚 → 发送通知
```

### 手动恢复系统

```bash
# 1. 查看备份列表
oc-list

# 2. 恢复系统
oc-restore 20260307_020000
```

---

## 系统要求

| 要求 | 说明 |
|------|------|
| **系统** | Ubuntu 22.04 / 24.04 |
| **Node.js** | 22+ |
| **OpenClaw** | 2026.3.2+ |
| **权限** | sudo |

---

## 故障排除

### 问题 1：服务无法启动

```bash
# 检查服务状态
oc-status

# 查看日志
oc-logs

# 清理缓存后重试
oc-cache-clean full
```

### 问题 2：备份失败

```bash
# 验证备份
oc-verify <备份名称>

# 检查磁盘空间
df -h
```

### 问题 3：通知不发送

```bash
# 检查配置
cat notify.conf

# 测试通知
./scripts/notify.sh test
```

---

## 相关项目

| 项目 | 说明 |
|------|------|
| [openclaw-disaster-recovery](https://github.com/openclaw-AI-make/openclaw-disaster-recovery) | 灾备系统 v2.0 |
| [openclaw-memory-isolation](https://github.com/openclaw-AI-make/openclaw-memory-isolation) | 记忆隔离技能 |
| [openclaw-monitor](https://github.com/openclaw-AI-make/openclaw-monitor) | 监控技能 |

---

## 更新日志

### v1.0.0 (2026-03-07)

- 初始发布
- 10 个核心脚本
- 4 层健康检查
- 3 级恢复流程
- 多通道通知
- 智能缓存清理

---

## 许可

MIT License
