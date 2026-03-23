# pdoc 自动化文档部署流程

本文档详细说明了 pdoc 项目的 CI/CD 流程设计，包括代码质量检查、自动化测试、文档生成和多环境部署策略。

## 目录

- [架构概览](#架构概览)
- [工作流说明](#工作流说明)
- [环境配置](#环境配置)
- [部署策略](#部署策略)
- [安全考虑](#安全考虑)
- [故障排查](#故障排查)
- [扩展指南](#扩展指南)

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GitHub Actions                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   CI Workflow   │    │  Deploy Workflow │    │  Security Scan   │    │  Cleanup Job   │
│  │   (ci.yml)      │    │  (deploy.yml)    │    │  (security)      │    │  (cleanup)     │
│  └──────┬──────┘    └──────┬──────┘    └─────────────┘    └─────────────┘  │
│         │                  │                                               │
│         ▼                  ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                        触发条件                                       │  │
│  │  • Push to master/main/develop                                       │  │
│  │  • Pull Request to master/main                                       │  │
│  │  • Tag release (v*.*.*)                                              │  │
│  │  • Manual trigger (workflow_dispatch)                                │  │
│  │  • Scheduled (cron)                                                  │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              部署目标                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Staging Environment              Production Environment                   │
│   ┌─────────────────┐              ┌─────────────────┐                       │
│   │ GitHub Pages    │              │ GitHub Pages    │                       │
│   │ /staging/       │              │ / (root)        │                       │
│   │                 │              │                 │                       │
│   │ • Auto-deploy   │              │ • Tag-triggered │                       │
│   │ • Noindex meta  │              │ • SEO optimized │                       │
│   │ • Staging badge │              │ • Analytics     │                       │
│   └─────────────────┘              └─────────────────┘                       │
│                                                                             │
│   PyPI (Optional)                                                           │
│   ┌─────────────────┐                                                       │
│   │ pdoc3 package   │                                                       │
│   │ Auto-publish    │                                                       │
│   │ on release tag  │                                                       │
│   └─────────────────┘                                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 工作流说明

### 1. CI 工作流 ([ci.yml](workflows/ci.yml))

#### 触发条件

| 事件 | 分支/条件 | 说明 |
|------|----------|------|
| `push` | master, main, develop | 代码推送时触发 |
| `pull_request` | master, main | PR 创建/更新时触发 |
| `workflow_dispatch` | - | 手动触发，支持跳过测试选项 |
| `schedule` | cron: '12 2 6 * *' | 每月6号定时运行 |

#### 任务矩阵

```yaml
任务: lint
├── 代码风格检查 (flake8)
├── 类型检查 (mypy)
├── 代码格式化检查 (black)
├── 导入排序检查 (isort)
└── Markdown 文件检查

任务: test
├── 操作系统: [ubuntu-latest, windows-latest, macos-latest]
├── Python 版本: [3.9, 3.10, 3.11, 3.12]
└── 代码覆盖率上传 (Codecov)

任务: test-pdf
├── LaTeX 环境安装
├── Pandoc 安装
└── PDF 生成测试

任务: build-docs
├── 文档构建
├── 链接检查
└── 构建产物上传

任务: security
├── Bandit (安全漏洞扫描)
└── Safety (依赖安全检查)
```

### 2. 部署工作流 ([deploy.yml](workflows/deploy.yml))

#### 环境策略

| 环境 | 触发条件 | URL | 特性 |
|------|---------|-----|------|
| **Staging** | Push to master/main | `/staging/` | 自动部署、环境徽章、noindex |
| **Production** | Tag release (v*.*.*) | `/` | 手动确认、SEO优化、Analytics |

#### 部署流程

```
1. 确定部署环境
   ├── 检查触发事件类型
   ├── 解析版本标签
   └── 设置部署标志

2. 构建文档
   ├── 安装依赖
   ├── 运行 doc/build.sh
   ├── 生成版本元数据
   └── 上传构建产物

3. 部署到目标环境
   ├── Staging: 自动部署到 /staging/
   └── Production: 需要环境批准

4. 发布到 PyPI (仅 Production)
   ├── 构建 wheel/sdist
   └── 使用 API Token 发布

5. 清理旧版本
   └── 删除超过30天的构建产物
```

---

## 环境配置

### GitHub Environments

需要在仓库设置中配置以下环境：

#### 1. Staging 环境

```yaml
名称: staging
URL: https://pdoc3.github.io/pdoc/staging/
保护规则:
  - 无（自动部署）
```

#### 2. Production 环境

```yaml
名称: production
URL: https://pdoc3.github.io/pdoc/
保护规则:
  - 需要审查（指定维护者）
  - 等待时间: 无
  - 部署分支: tags
```

#### 3. PyPI 环境

```yaml
名称: pypi
URL: https://pypi.org/p/pdoc3
保护规则:
  - 需要审查
Secrets:
  - PYPI_API_TOKEN
```

### Secrets 配置

| Secret | 用途 | 设置位置 |
|--------|------|----------|
| `GITHUB_TOKEN` | GitHub API 访问、Pages 部署 | 自动生成 |
| `PYPI_API_TOKEN` | PyPI 包发布 | Repository Secrets |
| `CODECOV_TOKEN` | 代码覆盖率上传 | Repository Secrets |

---

## 部署策略

### 分支策略

```
main/master (生产分支)
    │
    ├─── 推送 ───► Staging 自动部署
    │
    └─── 标签 ───► Production 部署
         v1.0.0

develop (开发分支)
    │
    └─── 推送 ───► CI 测试（不部署）

feature/* (功能分支)
    │
    └─── PR ─────► CI 测试
```

### 回滚机制

#### 自动回滚

- 部署失败时自动阻止发布
- 健康检查失败触发告警

#### 手动回滚

```bash
# 回滚 Staging
.github/deploy-gh-pages.sh staging rollback

# 回滚 Production
.github/deploy-gh-pages.sh production rollback
```

#### Git 回滚

```bash
# 查看 gh-pages 提交历史
git log gh-pages --oneline

# 回滚到指定版本
git revert <commit-hash>
git push origin gh-pages
```

---

## 安全考虑

### 1. Secrets 管理

```yaml
# ✅ 正确: 使用 GitHub Secrets
- name: Deploy
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: .github/deploy-gh-pages.sh

# ❌ 错误: 硬编码凭证
env:
  GH_TOKEN: "ghp_xxxxxxxxxxxx"
```

### 2. 权限控制

```yaml
# 最小权限原则
permissions:
  contents: read      # 读取代码
  pages: write        # 写入 Pages
  id-token: write     # OIDC 令牌
```

### 3. 依赖安全

- **Bandit**: Python 代码安全扫描
- **Safety**: 依赖包漏洞检查
- **Dependabot**: 自动依赖更新

### 4. 代码审查

- 所有 PR 需要至少 1 个审查
- 生产部署需要额外批准
- 敏感文件变更需要管理员审查

---

## 故障排查

### 常见问题

#### 1. 部署失败

```bash
# 检查构建产物
ls -la doc/build/

# 验证 GitHub Token 权限
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/user

# 查看部署日志
gh run view <run-id> --log
```

#### 2. 缓存问题

```yaml
# 手动清除缓存
- name: Clear cache
  run: |
    pip cache purge
    rm -rf ~/.cache/pip
```

#### 3. 权限错误

```bash
# 检查文件权限
chmod +x .github/deploy-gh-pages.sh
chmod +x doc/build.sh

# 检查 Git 配置
git config user.name
git config user.email
```

### 调试模式

```yaml
# 启用调试日志
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

---

## 扩展指南

### 1. 添加新的部署目标

```yaml
# deploy.yml
jobs:
  deploy-custom:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to custom server
        run: |
          rsync -avz doc/build/ user@server:/var/www/docs/
```

### 2. 集成通知系统

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Deployment ${{ job.status }}: ${{ github.ref }}"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### 3. 添加性能监控

```yaml
- name: Performance check
  run: |
    pip install lighthouse-ci
    lhci autorun --config=lighthouserc.js
```

### 4. Docker 化部署

```dockerfile
# Dockerfile.docs
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -e .
RUN doc/build.sh
FROM nginx:alpine
COPY --from=0 /app/doc/build /usr/share/nginx/html
```

---

## 性能优化

### 构建缓存策略

| 缓存类型 | 路径 | 键 |
|----------|------|-----|
| pip 缓存 | `~/.cache/pip` | `${{ runner.os }}-pip-${{ hashFiles('**/setup.py') }}` |
| pandoc | `/tmp/pandoc.deb` | `pandoc-3.1.12.2` |
| 构建产物 | `doc/build/` | `docs-${{ github.run_id }}` |

### 并行化策略

```yaml
strategy:
  fail-fast: false
  matrix:
    job: [lint, test, security]
```

### 资源使用优化

- 使用 `ubuntu-latest` 运行器（最快）
- 条件执行避免不必要任务
- 产物保留策略（7-30天）

---

## 监控与告警

### 部署状态监控

```yaml
- name: Monitor deployment
  uses: actions/github-script@v7
  with:
    script: |
      const deployments = await github.rest.repos.listDeployments({
        owner: context.repo.owner,
        repo: context.repo.repo,
        environment: 'production'
      });
      console.log(deployments.data);
```

### 健康检查

```yaml
- name: Health check
  run: |
    curl -f https://pdoc3.github.io/pdoc/ || exit 1
    curl -f https://pdoc3.github.io/pdoc/staging/ || exit 1
```

---

## 贡献指南

### 修改 CI/CD 流程

1. 在功能分支修改工作流文件
2. 测试更改（使用 `workflow_dispatch`）
3. 提交 PR 并等待审查
4. 合并后观察生产部署

### 最佳实践

- 保持工作流文件简洁
- 使用可复用的 Action
- 添加适当的注释
- 定期审查和更新依赖

---

## 参考资源

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [GitHub Pages 文档](https://docs.github.com/en/pages)
- [pdoc 官方文档](https://pdoc3.github.io/pdoc/)
- [PyPI 发布指南](https://packaging.python.org/)
