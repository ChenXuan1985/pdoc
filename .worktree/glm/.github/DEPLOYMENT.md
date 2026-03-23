# pdoc 自动化文档部署流程说明

## 概述

本文档描述了 pdoc 项目的自动化 CI/CD 流程，包括持续集成、多环境部署、回滚机制等。

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Actions Trigger                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Push to main │  │ Tag Release  │  │ Manual/PR/Scheduled  │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │  CI Workflow │ │Deploy Staging│ │Deploy Prod   │
        │              │ │              │ │              │
        │ • Lint       │ │ • Build Docs │ │ • Build Docs │
        │ • Type Check │ │ • Deploy to  │ │ • Deploy to  │
        │ • Test       │ │   /staging/  │ │   /          │
        │ • Coverage   │ │              │ │ • Release    │
        │ • Security   │ │              │ │              │
        └──────────────┘ └──────────────┘ └──────────────┘
                │               │               │
                └───────────────┼───────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       GitHub Pages                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  https://owner.github.io/repo/        (Production)       │  │
│  │  https://owner.github.io/repo/staging/ (Staging)         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 文件结构

```
.github/
├── workflows/
│   ├── ci.yml           # 持续集成工作流
│   └── deploy.yml       # 部署工作流
├── actions/
│   └── setup/
│       └── action.yml   # 共享的 Python 环境设置
├── deploy-docs.sh       # 文档部署脚本
├── rollback.sh          # 回滚脚本
└── lint-markdown.sh     # Markdown 检查脚本
```

## 工作流详解

### 1. CI 工作流 (ci.yml)

#### 触发条件

| 事件 | 条件 |
|------|------|
| `push` | `master` 或 `main` 分支 |
| `pull_request` | 目标为 `master` 或 `main` |
| `schedule` | 每月 6 日凌晨 2:12 UTC |
| `workflow_dispatch` | 手动触发 |

#### 执行流程

```
detect-changes ──┬── lint ────────┬── test ────────┬── build-docs
                 │                │                │
                 │                └── coverage     │
                 │                                 │
                 └── security-scan                 │
                                                   │
ci-status ◄───────────────────────────────────────┘
```

#### Job 说明

| Job | 功能 | 条件 |
|-----|------|------|
| `detect-changes` | 检测代码变更类型 | 始终运行 |
| `lint` | 代码风格检查 | 代码或 CI 配置变更时 |
| `test` | 多版本测试 | lint 通过后 |
| `coverage` | 测试覆盖率报告 | lint 通过后 |
| `build-docs` | 构建文档 | 测试通过后 |
| `security-scan` | 安全扫描 | 代码变更或定时任务 |
| `ci-status` | 汇总状态 | 始终运行 |

#### 测试矩阵

```yaml
strategy:
  matrix:
    python-version: ['3.9', '3.10', '3.11', '3.12']
    os: [ubuntu-latest]
    include:
      - python-version: '3.11'
        os: macos-latest
      - python-version: '3.11'
        os: windows-latest
```

### 2. 部署工作流 (deploy.yml)

#### 触发条件

| 事件 | 部署环境 |
|------|----------|
| `push` 到 `master/main` | Staging |
| `push` 标签 (如 `1.0.0`) | Production |
| `workflow_dispatch` | 用户指定 |

#### 环境策略

```
┌─────────────────┐     ┌─────────────────┐
│     Staging     │     │   Production    │
├─────────────────┤     ├─────────────────┤
│ • 主分支推送     │     │ • 标签发布       │
│ • PR 预览       │     │ • 手动部署       │
│ • 手动触发      │     │ • 需要审批       │
│ • 无审批要求    │     │                 │
└─────────────────┘     └─────────────────┘
        │                       │
        ▼                       ▼
   /staging/               / (root)
```

#### 部署流程

```
determine-environment
        │
        ▼
   run-tests (可跳过)
        │
        ▼
   build-docs
        │
        ├──► deploy-staging (if staging)
        │
        └──► deploy-production (if production)
                    │
                    ├── 创建 GitHub Release
                    └── 更新部署标签
        │
        ▼
     notify
```

### 3. 回滚机制

#### 方式一：通过 GitHub Actions

```yaml
# 在 workflow_dispatch 中指定 rollback-{SHA}
# 例如: rollback-abc123def456
```

#### 方式二：通过命令行脚本

```bash
# 列出最近部署
.github/rollback.sh --list

# 回滚到指定 commit
.github/rollback.sh -t abc123def456

# 回滚到指定版本
.github/rollback.sh -v 1.0.0

# 强制回滚（跳过确认）
.github/rollback.sh -t abc123def456 --force
```

#### 回滚流程

```
1. 验证目标 commit 存在
2. 显示回滚预览
3. 确认操作
4. Checkout 目标 commit
5. 构建文档
6. 部署到 Production
7. 更新 deployed-production 标签
```

## 缓存策略

### pip 缓存

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cache/pip
      ~\AppData\Local\pip\Cache
      ~/Library/Caches/pip
    key: ${{ runner.os }}-py${{ matrix.python-version }}-${{ hashFiles('setup.py', 'setup.cfg') }}
```

### Pandoc 缓存

```yaml
- uses: actions/cache@v4
  with:
    path: /tmp/pandoc.deb
    key: pandoc
```

## Secrets 管理

### 必需的 Secrets

| Secret | 用途 | 配置位置 |
|--------|------|----------|
| `GITHUB_TOKEN` | GitHub API 访问 | 自动提供 |
| `CODECOV_TOKEN` | Codecov 上传 | Repository Secrets |

### 可选的 Secrets

| Secret | 用途 |
|--------|------|
| `SLACK_WEBHOOK_URL` | Slack 通知 |
| `DISCORD_WEBHOOK_URL` | Discord 通知 |

## 安全最佳实践

### 1. 最小权限原则

```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

### 2. 环境保护规则

Production 环境建议配置：
- 需要审批者确认
- 限制部署分支
- 设置部署超时

### 3. Secret 轮换

定期轮换以下 secrets：
- `CODECOV_TOKEN`
- 任何自定义 webhook URLs

## 性能优化

### 并行执行

```yaml
strategy:
  fail-fast: false  # 允许其他 job 继续运行
```

### 条件执行

```yaml
if: needs.detect-changes.outputs.code_changed == 'true'
```

### 缓存利用

- pip 依赖缓存
- Pandoc 二进制缓存
- actions/setup-python 内置缓存

## 监控与告警

### 部署状态通知

```yaml
- name: Send notification
  if: github.event_name != 'pull_request'
  run: |
    echo "::notice::✅ Deployment to ${{ env.ENVIRONMENT }} successful"
```

### 可选：Slack/Discord 集成

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## 故障排查

### 常见问题

#### 1. 文档构建失败

```bash
# 本地测试
pip install -e .
pdoc3 --html --output-dir doc/build pdoc
```

#### 2. 部署权限错误

检查 `GITHUB_TOKEN` 权限：
```yaml
permissions:
  contents: write
  pages: write
```

#### 3. 缓存问题

清除缓存：
```bash
# 在 Actions 页面手动清除缓存
# 或使用 cache: 'no-cache' 选项
```

### 调试模式

```yaml
- name: Debug
  run: |
    echo "Environment: ${{ needs.determine-environment.outputs.environment }}"
    echo "Version: ${{ needs.determine-environment.outputs.version }}"
    ls -la doc/build/
```

## 版本发布流程

### 1. 准备发布

```bash
# 更新 CHANGELOG
# 更新版本号
git add .
git commit -m "chore: prepare release 1.0.0"
```

### 2. 创建标签

```bash
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

### 3. 自动化流程

```
Tag Push → Deploy Workflow → Production Deploy → GitHub Release
```

## 维护指南

### 定期检查项

- [ ] 更新 Actions 版本
- [ ] 检查 Python 版本支持
- [ ] 审查安全扫描结果
- [ ] 清理旧的部署记录
- [ ] 验证回滚流程

### 升级 Actions

```yaml
# 定期更新到最新稳定版本
- uses: actions/checkout@v4
- uses: actions/setup-python@v5
- uses: actions/cache@v4
```

## 附录

### A. 完整的工作流图

```
┌────────────────────────────────────────────────────────────────────┐
│                         CI/CD Pipeline                              │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Push/PR ─────► detect-changes ─────► lint ─────► test            │
│                      │                   │           │              │
│                      │                   │           ├─► py3.9     │
│                      │                   │           ├─► py3.10    │
│                      │                   │           ├─► py3.11    │
│                      │                   │           └─► py3.12    │
│                      │                   │                          │
│                      │                   └─► coverage               │
│                      │                                              │
│                      └─► security-scan                              │
│                                                                     │
│  Tag Push ─────► determine-env ─────► build-docs ─────► deploy    │
│                         │                   │              │        │
│                         │                   │              ├─► stag │
│                         │                   │              └─► prod │
│                         │                   │                       │
│                         └─► run-tests ──────┘                       │
│                                                                     │
│  Manual ───────► determine-env ─────► [same as above]              │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### B. 环境变量参考

| 变量 | 描述 | 来源 |
|------|------|------|
| `GITHUB_TOKEN` | GitHub API token | 自动提供 |
| `GITHUB_SHA` | 当前 commit SHA | 自动提供 |
| `GITHUB_REF` | Git 引用 | 自动提供 |
| `GITHUB_REPOSITORY` | 仓库名 | 自动提供 |
| `GITHUB_ACTOR` | 触发用户 | 自动提供 |
| `PYTHONUNBUFFERED` | Python 输出缓冲 | 工作流定义 |
| `PDOC_TEST_PANDOC` | 启用 Pandoc 测试 | 工作流定义 |

### C. 相关链接

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [peaceiris/actions-gh-pages](https://github.com/peaceiris/actions-gh-pages)
- [codecov/codecov-action](https://github.com/codecov/codecov-action)
