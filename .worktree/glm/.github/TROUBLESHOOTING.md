# pdoc CI/CD 故障排查指南

## 目录

1. [快速诊断](#快速诊断)
2. [CI 故障排查](#ci-故障排查)
3. [部署故障排查](#部署故障排查)
4. [回滚故障排查](#回滚故障排查)
5. [日志分析](#日志分析)
6. [应急处理](#应急处理)

---

## 快速诊断

### 诊断检查清单

```
□ GitHub Actions 是否正常运行？
□ Secrets 是否正确配置？
□ 分支保护规则是否正确？
□ 依赖是否安装成功？
□ 测试是否通过？
□ 文档是否构建成功？
□ 部署是否完成？
```

### 快速诊断命令

```bash
# 检查最近的工作流运行状态
gh run list --limit 5

# 查看特定工作流的运行状态
gh run list --workflow=ci.yml --limit 10
gh run list --workflow=deploy.yml --limit 10

# 查看失败的运行
gh run list --status=failure --limit 10

# 查看运行详情
gh run view <run-id>

# 查看运行日志
gh run view <run-id> --log
```

---

## CI 故障排查

### Lint 失败

**症状：** flake8 或 mypy 检查失败

**诊断步骤：**

```bash
# 本地运行 lint 检查
pip install flake8 mypy types-Markdown
flake8 pdoc setup.py
mypy -p pdoc
```

**常见错误及解决方案：**

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| E501 行过长 | 行超过 100 字符 | 重构代码或忽略 |
| F401 未使用导入 | 导入未使用 | 删除导入 |
| mypy 类型错误 | 类型注解问题 | 添加类型注解 |

**修复命令：**

```bash
# 自动修复部分问题
pip install autopep8
autopep8 --in-place --aggressive pdoc/*.py

# 忽略特定规则（在 setup.cfg 中）
[flake8]
ignore = E501, W503
```

### 测试失败

**症状：** 单元测试失败

**诊断步骤：**

```bash
# 本地运行测试
python -m unittest -v pdoc.test

# 运行特定测试
python -m unittest pdoc.test.ModuleTest.test_something

# 查看测试覆盖率
pip install coverage
coverage run -m unittest pdoc.test
coverage report
```

**常见问题：**

1. **导入错误**
   ```bash
   # 确保安装了包
   pip install -e .
   ```

2. **依赖缺失**
   ```bash
   # 检查依赖
   pip list
   pip install -e .  # 重新安装
   ```

3. **环境差异**
   ```bash
   # 检查 Python 版本
   python --version
   
   # 使用正确版本
   pyenv local 3.11
   ```

### 测试矩阵失败

**症状：** 特定 Python 版本或操作系统测试失败

**诊断步骤：**

1. 查看 Actions 日志确定失败环境
2. 本地模拟失败环境

```bash
# 切换 Python 版本
pyenv install 3.9
pyenv local 3.9

# 运行测试
python -m unittest -v pdoc.test
```

---

## 部署故障排查

### 权限错误

**症状：** `Permission denied` 或 `Resource not accessible`

**诊断步骤：**

```bash
# 检查 GITHUB_TOKEN 权限
gh auth status

# 检查仓库权限
gh repo view --json permissions
```

**解决方案：**

1. 检查工作流权限配置
   ```yaml
   permissions:
     contents: write
     pages: write
   ```

2. 检查 Secrets 配置
   - Settings → Secrets and variables → Actions

### GitHub Pages 部署失败

**症状：** `peaceiris/actions-gh-pages` 失败

**诊断步骤：**

```bash
# 检查 gh-pages 分支
git fetch origin
git branch -r | grep gh-pages

# 检查构建产物
ls -la doc/build/
```

**解决方案：**

1. 确保 `doc/build/` 目录存在且有内容
2. 检查 GitHub Pages 设置
   - Settings → Pages → Source: `gh-pages` branch
3. 验证 `GITHUB_TOKEN` 是否有效

### 文档构建失败

**症状：** `pdoc3` 命令失败

**诊断步骤：**

```bash
# 本地测试文档构建
pip install -e .
pdoc3 --html --output-dir doc/build pdoc

# 检查模板
ls -la doc/pdoc_template/

# 检查模块导入
python -c "import pdoc; print(pdoc.__file__)"
```

**常见错误：**

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `ModuleNotFoundError` | 模块未安装 | `pip install -e .` |
| `TemplateNotFound` | 模板文件缺失 | 检查模板目录 |
| `SyntaxError` | 源码语法错误 | 修复代码 |

---

## 回滚故障排查

### 回滚目标不存在

**症状：** `Invalid commit SHA` 或 `Tag not found`

**诊断步骤：**

```bash
# 列出可用标签
git tag -l

# 列出最近提交
git log --oneline -20

# 验证 commit 存在
git rev-parse <commit-sha>
```

**解决方案：**

1. 确保使用正确的 commit SHA 或标签名
2. 检查远程分支是否同步
   ```bash
   git fetch --all --tags
   ```

### 回滚后验证失败

**症状：** 回滚后文档显示异常

**诊断步骤：**

```bash
# 检查部署的版本信息
curl https://owner.github.io/repo/build-info.json

# 对比本地构建
cat doc/build/build-info.json
```

**解决方案：**

1. 清除浏览器缓存
2. 等待 CDN 刷新（通常 1-5 分钟）
3. 检查 GitHub Pages 构建状态

---

## 日志分析

### 查看 Actions 日志

```bash
# 使用 GitHub CLI
gh run view <run-id> --log

# 查看特定 job
gh run view <run-id> --job <job-id> --log

# 下载日志文件
gh run download <run-id>
```

### 日志分析技巧

```bash
# 搜索错误关键词
gh run view <run-id> --log | grep -i "error\|failed\|exception"

# 查看特定步骤
gh run view <run-id> --log | grep -A 20 "Run tests"

# 分析失败原因
gh run view <run-id> --log | grep -B 5 "exit code: 1"
```

### 常见错误代码

| 代码 | 含义 | 可能原因 |
|------|------|----------|
| 1 | 一般错误 | 命令执行失败 |
| 2 | 误用命令 | 参数错误 |
| 126 | 无法执行 | 权限问题 |
| 127 | 命令未找到 | 未安装依赖 |
| 128 | 退出参数 | 无效参数 |

---

## 应急处理

### 紧急回滚流程

```
发现问题 → 确认严重程度 → 决定回滚
    │
    ├── 严重（生产故障）→ 立即回滚
    │
    └── 中等 → 评估影响 → 计划修复
```

### 紧急回滚步骤

1. **确认问题**
   ```bash
   # 访问文档网站确认问题
   curl -I https://owner.github.io/repo/
   ```

2. **查找回滚目标**
   ```bash
   .github/rollback.sh --list
   ```

3. **执行回滚**
   ```bash
   # 通过 GitHub Actions UI
   # 或命令行
   .github/rollback.sh -t <commit-sha> --force
   ```

4. **验证回滚**
   ```bash
   curl https://owner.github.io/repo/build-info.json
   ```

5. **通知团队**
   ```bash
   .github/notify.sh -t rollback -s warning -e production -v <version>
   ```

### 紧急联系

- **GitHub 支持**: https://support.github.com/
- **社区支持**: GitHub Community Forum
- **问题跟踪**: GitHub Issues

---

## 附录

### A. 常用诊断脚本

```bash
#!/bin/bash
# diagnose.sh - CI/CD 诊断脚本

echo "=== Git Status ==="
git status

echo "=== Recent Commits ==="
git log --oneline -5

echo "=== Python Version ==="
python --version

echo "=== Installed Packages ==="
pip list | grep -E "pdoc|mako|markdown"

echo "=== Test Status ==="
python -m unittest -v pdoc.test 2>&1 | tail -20

echo "=== Build Status ==="
pdoc3 --html --output-dir /tmp/doc-build pdoc 2>&1 | tail -10
```

### B. 问题报告模板

```markdown
## 问题描述
[简要描述问题]

## 环境信息
- Python 版本:
- 操作系统:
- pdoc 版本:

## 复现步骤
1. 
2. 
3. 

## 预期结果
[描述预期结果]

## 实际结果
[描述实际结果]

## 日志/截图
```
[粘贴相关日志]
```

## 已尝试的解决方案
- [ ] 方案 1
- [ ] 方案 2
```

### C. 相关资源

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [GitHub Pages 故障排查](https://docs.github.com/en/pages/troubleshooting)
- [pdoc 文档](https://pdoc3.github.io/pdoc/)
