# pdoc 自动化文档部署流程指南

## 概览

本文档描述了 pdoc 项目的完整自动化文档部署流程，包括 CI/CD 流水线配置、GitHub Pages 部署、Docker 容器化方案等。

## 📋 目录

1. [架构设计](#架构设计)
2. [快速开始](#快速开始)
3. [CI/CD 流水线](#cicd-流水线)
4. [部署策略](#部署策略)
5. [Docker 容器化部署](#docker-容器化部署)
6. [环境配置](#环境配置)
7. [监控与告警](#监控与告警)
8. [故障排除](#故障排除)
9. [安全最佳实践](#安全最佳实践)

---

## 🏗️ 架构设计

### 系统架构图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            pdoc 文档部署架构                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  开发者推送代码 ─────► GitHub ─────► CI/CD 流水线 ─────► 文档构建 ─────► 部署 │
│                        │                         │                          │
│                        │                         ├─────────────────────────►│
│                        │                         │  代码质量检查             │
│                        │                         │  自动化测试               │
│                        │                         │  覆盖率报告               │
│                        │                         │                          │
│                        ▼                         ▼                          │
│                    GitHub Pages            测试报告/覆盖率                   │
│                    ┌─────────────┐       ┌─────────────┐                    │
│                    │  Production │       │   Codecov   │                    │
│                    │   (根目录)   │       └─────────────┘                    │
│                    ├─────────────┤                                        │
│                    │   Staging   │       ┌─────────────┐                    │
│                    │  (/staging)  │       │ PDF 制品包   │                    │
│                    ├─────────────┤       └─────────────┘                    │
│                    │ Versioned   │                                        │
│                    │  (/v/x.y.z) │                                        │
│                    └─────────────┘                                        │
│                                                                             │
│  Docker 容器化 ───────────────────────────────────────────────────────────►│
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │ 静态文档服务     │  │ 实时文档服务     │  │ PDF 生成服务    │            │
│  │ (nginx:alpine)  │  │ (pdoc --http)   │  │ (TeX Live)      │            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 核心组件

| 组件 | 职责 | 技术栈 |
|------|------|--------|
| **CI 流水线** | 代码质量检查、自动化测试、覆盖率报告 | GitHub Actions |
| **CD 流水线** | 文档构建、GitHub Pages 部署 | GitHub Actions + peaceiris/actions-gh-pages |
| **文档生成** | API 文档静态构建 | pdoc + Mako + Markdown |
| **容器化** | 可移植部署方案 | Docker + Nginx + Compose |
| **多版本管理** | 历史版本文档访问 | GitHub Pages + versions.json |

---

## 🚀 快速开始

### 前置条件

1. GitHub 仓库已启用 GitHub Pages（Settings > Pages）
2. 仓库 Secrets 已配置必要的 token（`GITHUB_TOKEN` 自动提供）
3. Python 3.9+ 环境

### 手动部署步骤

```bash
# 1. 安装依赖
pip install -e .

# 2. 本地构建文档
pdoc --html --output-dir docs_build pdoc

# 3. 本地预览
pdoc --http :8080 pdoc

# 4. 使用部署脚本（需配置 GITHUB_TOKEN）
chmod +x deploy-docs.sh
GITHUB_TOKEN=your_token GITHUB_REPOSITORY=owner/repo ./deploy-docs.sh staging
```

---

## 🔄 CI/CD 流水线

### 流水线触发条件

| 事件 | 触发条件 | 执行作业 |
|------|----------|----------|
| **Push 到 master/main** | 代码变更（非文档文件） | 完整 CI + 构建 staging 文档 |
| **Pull Request** | 针对 master/main 的 PR | 代码检查 + 测试 |
| **Tag 推送 (v\*)** | 语义化版本标签 | 完整 CI + 生产环境部署 |
| **Release 发布** | GitHub Release | 生产环境部署 |
| **定时任务** | 每周日 2AM UTC | 完整 CI 流水线 |
| **手动触发** | workflow_dispatch | 自定义选项 |

### CI 作业详情

#### 1. 代码质量检查 (`lint`)

```yaml
执行检查:
  - flake8: Python 代码风格检查
    - 最大行长度: 100
    - 忽略规则: F824, W503, W504
    - 检查项: 语法错误、未定义名称、未使用导入
  
  - mypy: 静态类型检查
    - 模块: pdoc
    - 选项: show-error-codes
  
  - markdownlint: Markdown 文件检查
    - 范围: 非测试、非 Git 目录
```

#### 2. 多版本测试 (`test`)

```yaml
测试矩阵:
  Python 版本: 3.9, 3.10, 3.11
  操作系统: Ubuntu, Windows, macOS (仅 3.11)
  
测试内容:
  - unittest: 完整测试套件
  - doctest: README.md 中的文档测试
  
缓存优化:
  - pip: 依赖缓存
  - 策略: fail-fast: false（即使一个失败，其他继续）
```

#### 3. 覆盖率报告 (`coverage`)

```yaml
覆盖率工具: coverage.py + Codecov
报告格式:
  - 控制台报告（含缺失行）
  - XML 报告（上传 Codecov）
  
忽略路径: pdoc/test/example_pkg/*
Codecov 集成:
  - Flag: unittests
  - 失败不阻止流水线
```

#### 4. PDF 生成测试 (`pdf-test`)

```yaml
依赖安装:
  - TeX Live (texlive-xetex, lmodern, texlive-fonts-recommended)
  - Pandoc 3.1.12.2
  
缓存优化:
  - Pandoc deb 包（key: $OS-pandoc-texlive）
  - TeX Live deb 包
  
测试: CliTest.test_pdf_pandoc
制品: /tmp/pdoc.pdf（保留 30 天）
```

#### 5. 文档构建 (`build-docs`)

```yaml
触发条件: 仅 master/main 分支的 Push 事件
输出结构:
  docs_build/
  ├── pdoc.html       # pdoc 模块文档
  ├── index.html      # 重定向到 pdoc.html
  └── ...             # 其他资源
  
制品保留: 7 天
```

---

## 📦 部署策略

### 环境划分

| 环境 | URL 路径 | 触发条件 | 说明 |
|------|----------|----------|------|
| **Staging** | `/staging` | master/main 分支 Push | 预发布验证 |
| **Production** | `/` (根目录) | v* 标签 / Release | 生产环境 |
| **Versioned** | `/v/x.y.z` | v* 标签 / Release | 历史版本归档 |

### 部署流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        部署决策流程                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  事件触发: Push / Tag / Release                                 │
│         │                                                       │
│         ▼                                                       │
│  设置环境变量:                                                  │
│  ├── Tag/Release → Production                                   │
│  ├── Push master → Staging                                      │
│  └── 手动触发 → 用户选择                                        │
│         │                                                       │
│         ▼                                                       │
│  构建文档:                                                      │
│  ├── 执行 pdoc --html                                           │
│  ├── 生成 index.html 重定向                                     │
│  ├── 创建 DEPLOY_ENV / VERSION / BUILD_TIME 标记                │
│  └── 生成 versions.json 版本清单                                │
│         │                                                       │
│         ▼                                                       │
│  部署到 GitHub Pages:                                           │
│  ├── Staging: peaceiris/actions-gh-pages → destination_dir: staging │
│  ├── Production: 部署到根目录 + 版本目录                         │
│  └── Versioned: 部署到 /v/{version} 目录                        │
│         │                                                       │
│         ▼                                                       │
│  更新版本索引:                                                  │
│  ├── 克隆 gh-pages 分支                                         │
│  ├── 更新 versions.json（保留最近 10 个版本）                    │
│  ├── 生成 version-selector.html.inc                             │
│  └── 推送变更                                                   │
│         │                                                       │
│         ▼                                                       │
│  通知:                                                          │
│  ├── 步骤总结到 GitHub Summary                                  │
│  └── 打印部署 URL                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 版本管理

`versions.json` 格式示例：

```json
[
  {
    "name": "v1.2.3",
    "path": "v/v1.2.3",
    "environment": "production",
    "timestamp": "2024-01-15T10:30:00Z"
  },
  {
    "name": "v1.2.2",
    "path": "v/v1.2.2",
    "environment": "production",
    "timestamp": "2024-01-10T09:00:00Z"
  }
]
```

### 回滚机制

```bash
# 回滚到指定版本
./deploy-docs.sh rollback v1.2.2

# 或使用 GitHub Actions 手动触发
# 1. 进入 Actions > Deploy Documentation
# 2. 选择 "Run workflow"
# 3. Environment: production
# 4. Version: v1.2.2（要回滚的版本）
```

---

## 🐳 Docker 容器化部署

### 镜像结构

```
pdoc3/pdoc:latest
├── Builder 阶段 (python:3.11-slim)
│   ├── 安装依赖 (git, build-essential)
│   ├── 安装 pdoc
│   └── 构建文档到 /output
│
└── Final 阶段 (nginx:alpine)
    ├── 静态文档: /usr/share/nginx/html/docs
    ├── 源代码: /pdoc-source
    ├── Nginx 配置: /etc/nginx/conf.d/default.conf
    ├── 健康检查: /health → 返回 200 "healthy"
    ├── 暴露端口: 80 (静态), 8080 (实时)
    └── 启动脚本: /usr/local/bin/start-live.sh
```

### 使用方式

#### 1. 静态文档服务（生产环境）

```bash
# 构建并启动
docker-compose up -d docs-static

# 或直接使用 Docker
docker build -t pdoc3/pdoc .
docker run -d -p 8080:80 --name pdoc-docs pdoc3/pdoc:latest

# 访问: http://localhost:8080/docs
```

#### 2. 实时文档服务（开发环境）

```bash
# 启动实时模式（监听代码变更）
docker-compose up -d docs-live

# 为您自己的项目
# 编辑 docker-compose.yml 挂载您的项目目录:
# volumes:
#   - ../your-project:/app:ro
# environment:
#   - PDOC_MODULE=your_module

# 访问: http://localhost:8081
```

#### 3. 多环境启动

```bash
# 启动所有服务
docker-compose up -d

# 仅启动 staging 环境
docker-compose up -d docs-staging

# 生成 PDF
docker-compose run --rm docs-pdf
# 输出: ./output/pdoc-documentation.pdf
```

#### 4. 服务端点

| 服务 | 端点 | 说明 |
|------|------|------|
| Static | http://localhost:8080/docs | 静态文档 |
| Live | http://localhost:8081 | 实时文档服务 |
| Staging | http://localhost:8082/docs | staging 环境 |
| Health | http://localhost:8080/health | 健康检查 |

---

## ⚙️ 环境配置

### GitHub 环境配置

建议在 GitHub Settings > Environments 中配置：

| 环境名称 | 保护规则 |
|----------|----------|
| `staging` | 无（自动部署） |
| `production` | 需审查、仅特定标签 |

### 流水线变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `DEFAULT_PYTHON` | 默认 Python 版本 | `3.11` |
| `GH_PAGES_BRANCH` | GitHub Pages 分支 | `gh-pages` |
| `run_lint` | 手动触发时是否运行 lint | `true` |
| `run_tests` | 手动触发时是否运行测试 | `true` |
| `run_coverage` | 手动触发时是否运行覆盖率 | `true` |

---

## 📊 监控与告警

### 内置监控

1. **部署状态检查**
   - CI/CD 作业状态可视化
   - 每个步骤的日志输出
   - 步骤总结（Summary）

2. **健康检查端点**
   ```
   GET /health
   响应: 200 "healthy"
   ```

3. **Docker 健康检查**
   ```yaml
   HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3
   ```

### 告警配置建议

1. **GitHub Actions 通知**
   - 配置 Email 通知
   - Slack/Teams 集成（使用 Actions）

2. **示例：Slack 通知步骤**

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  if: always()
  with:
    payload: |
      {
        "text": "部署 ${{ needs.pre-deploy-check.outputs.environment }}: ${{ job.status }}",
        "attachments": [
          {
            "title": "pdoc 文档部署",
            "title_link": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}",
            "color": "${{ job.status == 'success' && 'good' || 'danger' }}",
            "fields": [
              { "title": "版本", "value": "${{ needs.pre-deploy-check.outputs.version }}", "short": true },
              { "title": "环境", "value": "${{ needs.pre-deploy-check.outputs.environment }}", "short": true }
            ]
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## 🔧 故障排除

### 常见问题

#### 1. 构建失败：权限错误

```
症状: "Permission denied" 或 "Error 403: Resource not accessible by integration"

解决方案:
  1. 检查仓库 Settings > Actions > General > Workflow permissions
  2. 确保 "Read and write permissions" 已启用
  3. 确保 "Allow GitHub Actions to create and approve pull requests" 已启用
```

#### 2. 依赖安装缓慢

```
症状: pip install 步骤耗时很长

解决方案:
  - 流水线已配置 pip 缓存（通过 actions/setup-python）
  - Pandoc 和 TeX Live 已配置缓存（通过 actions/cache）
  - 验证缓存命中: 查看步骤日志中的 "Cache hit"
```

#### 3. GitHub Pages 部署未生效

```
症状: 流水线成功，但页面没有更新

检查:
  1. 确认 gh-pages 分支有新提交
  2. 确认 GitHub Pages 源分支是 gh-pages (Settings > Pages)
  3. 等待几分钟（CDN 缓存）
  4. 检查是否有自定义域名冲突
```

#### 4. PDF 生成失败

```
症状: PDF 测试步骤失败

检查:
  - Pandoc 是否已正确安装（缓存可能损坏）
  - TeX Live 包是否完整
  - 尝试清除缓存重新运行
  - 本地测试: PDOC_TEST_PANDOC=1 python -m unittest -v pdoc.test.CliTest.test_pdf_pandoc
```

### 调试技巧

1. **启用调试日志**
   ```yaml
   env:
     ACTIONS_RUNNER_DEBUG: true
     ACTIONS_STEP_DEBUG: true
   ```

2. **本地复现 CI 环境**
   ```bash
   # 使用 act 工具（需安装 act）
   act -j test
   ```

3. **查看部署内容**
   ```bash
   # 克隆 gh-pages 分支
   git clone --branch gh-pages https://github.com/owner/repo.git
   
   # 或直接访问
   https://github.com/owner/repo/tree/gh-pages
   ```

---

## 🔒 安全最佳实践

### 1. Secrets 管理

```yaml
✅ 正确: 使用 GitHub Secrets
- GITHUB_TOKEN (自动提供)
- SLACK_WEBHOOK_URL (如配置)

❌ 错误: 硬编码敏感信息
- 不要在工作流文件中放入任何密钥
- 不要在日志中打印敏感数据
```

### 2. 权限最小化

```yaml
每个作业按需配置权限:
permissions:
  contents: write      # 仅需要写入的作业
  pages: write        # 仅部署作业需要
  pull-requests: read # 按需读取

注意: GITHUB_TOKEN 默认权限已限制
```

### 3. 依赖安全

```
✅ 已实施:
  - pip 安装使用 --upgrade pip setuptools wheel
  - 依赖版本通过 setup.py 管理
  - 可复用的 action 使用固定 hash 引用

建议补充:
  - 启用 Dependabot 进行依赖更新
  - 定期扫描依赖漏洞
```

### 4. 输入验证

```
工作流输入验证:
  - environment: choice 类型（仅允许 staging/production）
  - boolean 类型有默认值
  - 可选输入有合理默认值

脚本验证:
  - deploy-docs.sh 验证 DEPLOY_ENV 值
  - set -euo pipefail 确保错误时退出
```

---

## 📈 性能优化

### 1. 缓存策略

| 缓存对象 | 键 | 路径 | 节省时间 |
|----------|----|------|----------|
| Pip 依赖 | setup.py hash | pip cache | ~30s |
| Pandoc | $OS-pandoc-texlive | /tmp/pandoc.deb | ~10s |
| TeX Live | $OS-pandoc-texlive | /var/cache/apt/archives | ~2min |

### 2. 并行执行

```
作业依赖关系（并行执行优化）:
┌─────────┐
│   lint  │
└────┬────┘
     │
     ▼
┌─────────┐    ┌─────────┐    ┌─────────┐
│  test   │    │coverage │    │ pdf-test│
└─────────┘    └─────────┘    └─────────┘
     │
     ▼
┌─────────┐
│build-docs│
└─────────┘

注意: 三个测试相关作业可并行（needs: test, if: always()）
```

### 3. 路径过滤

```yaml
paths-ignore:  # 非代码变更不触发流水线
  - '**.md'
  - 'docs/**'
  - '**.rst'
```

---

## 📚 附录

### 参考链接

- [pdoc 官方文档](https://pdoc3.github.io/pdoc/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [peaceiris/actions-gh-pages](https://github.com/peaceiris/actions-gh-pages)

### 文件结构

```
.github/workflows/
├── ci.yml          # CI 流水线（检查、测试、构建）
└── deploy.yml      # 部署流水线（GitHub Pages 部署）

deploy-docs.sh      # Shell 部署脚本（备用）
Dockerfile          # 容器化配置
docker-compose.yml  # Compose 多服务配置
.dockerignore       # Docker 构建忽略
DEPLOYMENT_GUIDE.md # 本文档
```

### 命令速查

```bash
# 本地测试
python -m unittest discover -v -s pdoc/test
python -m coverage run -m unittest discover -s pdoc/test
python -m coverage report -m

# Docker
docker-compose up -d docs-static  # 静态服务
docker-compose up -d docs-live    # 实时服务
docker-compose run --rm docs-pdf  # 生成 PDF

# 手动部署
GITHUB_TOKEN=your_token GITHUB_REPOSITORY=owner/repo ./deploy-docs.sh staging
```

---

**文档维护者**: pdoc Community
**最后更新**: 2024-01
**版本**: 1.0
