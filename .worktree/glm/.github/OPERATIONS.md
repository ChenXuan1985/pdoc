# pdoc 部署操作手册

## 目录

1. [概述](#概述)
2. [环境说明](#环境说明)
3. [部署流程](#部署流程)
4. [回滚操作](#回滚操作)
5. [监控告警](#监控告警)
6. [日常维护](#日常维护)

---

## 概述

本文档描述 pdoc 项目的部署操作流程，包括自动化部署、手动部署、回滚操作等。

### 相关文件

| 文件 | 用途 |
|------|------|
| `.github/workflows/ci.yml` | 持续集成配置 |
| `.github/workflows/deploy.yml` | 部署工作流配置 |
| `.github/deploy-docs.sh` | 文档部署脚本 |
| `.github/rollback.sh` | 回滚脚本 |
| `.github/notify.sh` | 监控告警脚本 |

---

## 环境说明

### 环境配置

| 环境 | URL | 触发条件 | 审批 |
|------|-----|----------|------|
| Staging | `https://{owner}.github.io/{repo}/staging/` | 主分支推送 | 无 |
| Production | `https://{owner}.github.io/{repo}/` | 标签发布 | 需要 |

### Secrets 配置

在 GitHub 仓库设置中配置以下 Secrets：

| Secret | 必需 | 用途 |
|--------|------|------|
| `GITHUB_TOKEN` | ✅ 自动 | GitHub API 访问 |
| `CODECOV_TOKEN` | 推荐 | 代码覆盖率上传 |
| `SLACK_WEBHOOK_URL` | 可选 | Slack 通知 |
| `DISCORD_WEBHOOK_URL` | 可选 | Discord 通知 |

### 配置 Slack Webhook

1. 在 Slack 工作区创建 Incoming Webhook
2. 复制 Webhook URL
3. 在 GitHub 仓库 Settings → Secrets 中添加 `SLACK_WEBHOOK_URL`

---

## 部署流程

### 自动部署

#### Staging 部署

```
推送到 master/main 分支 → CI 通过 → 自动部署到 Staging
```

**触发条件：**
- 推送到 `master` 或 `main` 分支
- CI 测试通过

**部署位置：**
- `https://{owner}.github.io/{repo}/staging/`

#### Production 部署

```
创建版本标签 → CI 通过 → 自动部署到 Production → 创建 GitHub Release
```

**触发条件：**
- 创建格式为 `[0-9]+.[0-9]+.*` 的标签（如 `1.0.0`, `2.1.0-beta`）

**操作步骤：**

```bash
# 1. 准备发布
# 更新 CHANGELOG
# 确保所有测试通过

# 2. 创建标签
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0

# 3. 等待自动部署完成
# 检查 GitHub Actions 状态
# 验证文档网站
```

### 手动部署

#### 通过 GitHub Actions UI

1. 进入仓库的 **Actions** 页面
2. 选择 **Deploy** 工作流
3. 点击 **Run workflow**
4. 填写参数：

| 参数 | 说明 | 示例 |
|------|------|------|
| environment | 部署环境 | `staging` 或 `production` |
| version | 版本号 | `1.0.0` 或留空 |
| skip_tests | 跳过测试 | `true` 或 `false` |
| action | 操作类型 | `deploy` 或 `rollback` |

#### 通过命令行

```bash
# 设置环境变量
export GITHUB_TOKEN=your_token
export GITHUB_REPOSITORY=owner/repo

# 部署到 Staging
.github/deploy-docs.sh -e staging

# 部署到 Production
.github/deploy-docs.sh -e production -v 1.0.0

# Dry run（预览）
.github/deploy-docs.sh -e staging --dry-run
```

### 部署验证

部署完成后，验证以下内容：

1. **访问文档网站**
   - Staging: `https://{owner}.github.io/{repo}/staging/`
   - Production: `https://{owner}.github.io/{repo}/`

2. **检查构建信息**
   ```bash
   # 查看部署的版本信息
   curl https://{owner}.github.io/{repo}/build-info.json
   ```

3. **验证文档内容**
   - API 文档是否完整
   - 链接是否正常
   - 样式是否正确

---

## 回滚操作

### 自动化回滚

#### 通过 GitHub Actions UI

1. 进入 **Actions** → **Deploy**
2. 点击 **Run workflow**
3. 选择参数：
   - environment: `production`
   - action: `rollback`
   - version: `rollback-{commit-sha}` 或 `rollback-{tag}`

示例：
```
version: rollback-abc123def456
version: rollback-v1.0.0
```

#### 通过命令行

```bash
# 列出可用版本
.github/rollback.sh --list

# 回滚到指定 commit
.github/rollback.sh -t abc123def456

# 回滚到指定版本标签
.github/rollback.sh -v 1.0.0

# 强制回滚（跳过确认）
.github/rollback.sh -t abc123def456 --force

# 预览回滚
.github/rollback.sh -t abc123def456 --dry-run
```

### 回滚流程图

```
┌─────────────────────────────────────────────────────────────┐
│                     回滚决策流程                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  发现问题 → 确认影响范围 → 决定回滚                          │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────┐                                        │
│  │ 查找目标版本     │                                        │
│  │ .github/rollback.sh --list                              │
│  └────────┬────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │ 验证目标版本     │                                        │
│  │ 确认 commit/tag 存在                                     │
│  └────────┬────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │ 执行回滚         │                                        │
│  │ 通过 Actions 或命令行                                    │
│  └────────┬────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │ 验证回滚结果     │                                        │
│  │ 检查文档网站                                             │
│  └────────┬────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │ 通知相关人员     │                                        │
│  │ 记录回滚原因                                             │
│  └─────────────────┘                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 回滚最佳实践

1. **快速响应**
   - 发现问题后尽快决定是否回滚
   - 不要试图在生产环境调试

2. **记录原因**
   - 记录回滚原因和发现的问题
   - 创建 Issue 跟踪问题

3. **验证回滚**
   - 回滚后验证文档网站
   - 确认功能正常

4. **修复问题**
   - 在开发环境修复问题
   - 通过正常流程重新部署

---

## 监控告警

### 通知类型

| 类型 | 触发条件 | 级别 |
|------|----------|------|
| 部署成功 | 部署完成 | ✅ 成功 |
| 部署失败 | 部署出错 | ❌ 失败 |
| 回滚通知 | 执行回滚 | ⚠️ 警告 |
| 安全告警 | 发现漏洞 | ⚠️ 警告 |
| CI 状态 | 流水线完成 | 成功/失败 |

### 配置通知

#### Slack 通知

```bash
# 测试 Slack 通知
SLACK_WEBHOOK_URL=https://hooks.slack.com/xxx \
.github/notify.sh -t deploy -s success -e staging
```

#### Discord 通知

```bash
# 测试 Discord 通知
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/xxx \
.github/notify.sh -t deploy -s success -e staging
```

### 告警处理流程

```
收到告警 → 确认严重程度 → 决定处理方式
    │
    ├── 严重（生产故障）→ 立即响应 → 可能回滚
    │
    ├── 中等（测试失败）→ 记录问题 → 安排修复
    │
    └── 轻微（警告信息）→ 记录日志 → 定期处理
```

---

## 日常维护

### 定期检查项

#### 每周检查

- [ ] 检查 CI/CD 运行状态
- [ ] 查看安全扫描报告
- [ ] 检查依赖更新

#### 每月检查

- [ ] 清理旧的部署记录
- [ ] 更新 Actions 版本
- [ ] 审查 Secrets 有效期
- [ ] 验证回滚流程

#### 每季度检查

- [ ] 审查部署流程
- [ ] 更新文档
- [ ] 检查环境配置

### 维护命令

```bash
# 查看最近部署状态
gh run list --workflow=deploy.yml --limit 10

# 查看部署日志
gh run view --log

# 手动触发 CI
gh workflow run ci.yml

# 列出所有标签
git tag -l

# 删除旧标签
git tag -d old-tag
git push origin :refs/tags/old-tag
```

### 清理操作

```bash
# 清理本地构建
rm -rf doc/build/

# 清理远程分支
git push origin --delete stale-branch

# 清理 Actions 缓存
gh cache delete --all
```

---

## 附录

### A. 常用命令速查

```bash
# 部署
.github/deploy-docs.sh -e staging
.github/deploy-docs.sh -e production -v 1.0.0

# 回滚
.github/rollback.sh --list
.github/rollback.sh -t abc123def456

# 通知测试
.github/notify.sh -t deploy -s success -e staging

# GitHub CLI
gh workflow run deploy.yml -f environment=staging
gh run list --workflow=deploy.yml
gh run view
```

### B. 环境变量参考

| 变量 | 说明 |
|------|------|
| `GITHUB_TOKEN` | GitHub API 访问令牌 |
| `GITHUB_REPOSITORY` | 仓库名 (owner/repo) |
| `GITHUB_SHA` | 当前 commit SHA |
| `GITHUB_REF` | Git 引用 |
| `GITHUB_ACTOR` | 触发用户 |
| `SLACK_WEBHOOK_URL` | Slack Webhook URL |
| `DISCORD_WEBHOOK_URL` | Discord Webhook URL |

### C. 联系方式

- **问题反馈**: GitHub Issues
- **紧急联系**: 查看 CODEOWNERS 文件
