# Docker 部署指南

## 概述

本指南介绍如何使用 Docker 容器化部署 pdoc 文档生成服务。

## 快速开始

### 1. 使用预构建镜像

```bash
# 拉取镜像
docker pull ghcr.io/pdoc3/pdoc:latest

# 运行文档服务器
docker run -p 8080:8080 ghcr.io/pdoc3/pdoc:latest

# 为特定项目生成文档
docker run -v $(pwd):/workspace ghcr.io/pdoc3/pdoc:latest \
  pdoc --html --output-dir /workspace/docs /workspace/myproject
```

### 2. 使用 Docker Compose

```bash
# 启动开发服务器
docker-compose --profile dev up

# 构建文档
docker-compose --profile build up

# 生产部署
docker-compose up -d
```

## Dockerfile 说明

### 多阶段构建

```dockerfile
# 阶段 1: 构建环境
FROM python:3.11-slim-bookworm AS builder
WORKDIR /app
COPY setup.py setup.cfg ./
RUN pip install --user -e .

# 阶段 2: 运行环境
FROM python:3.11-slim-bookworm
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
```

### 优化要点

1. **使用 slim 基础镜像**：减小镜像体积
2. **清理缓存**：`pip cache purge`
3. **多阶段构建**：分离构建和运行环境
4. **健康检查**：确保服务可用性

## Docker Compose 配置

### 服务说明

| 服务 | 用途 | 命令 |
|------|------|------|
| `pdoc` | 标准文档服务器 | `pdoc --http :8080 pdoc` |
| `pdoc-builder` | 静态文档构建 | `pdoc --html --output-dir /output pdoc` |
| `pdoc-dev` | 开发模式（挂载源码） | 同 pdoc，但支持热重载 |

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PYTHONUNBUFFERED` | `1` | Python 输出无缓冲 |
| `DOC_PORT` | `8080` | 文档服务端口 |
| `PDOC_CONFIG` | - | pdoc 配置文件路径 |

## CI/CD 集成

### Docker 工作流

```yaml
name: Docker

on:
  push:
    tags: ['[0-9]+.[0-9]+.*']
  pull_request:
    branches: [master, main]
```

### 构建流程

```
Checkout → Setup Buildx → Login → Build & Push → Scan → Deploy
```

### 镜像标签策略

| 事件 | 标签格式 | 示例 |
|------|----------|------|
| 主分支推送 | `master` | `pdoc:master` |
| PR 推送 | `pr-{number}` | `pdoc:pr-123` |
| 标签发布 | `v{version}` | `pdoc:v1.0.0` |
| 语义化版本 | `{major}.{minor}` | `pdoc:1.0` |
| SHA | `{sha}` | `pdoc:abc123` |

## 安全扫描

### Trivy 扫描

```bash
# 本地扫描
trivy image ghcr.io/pdoc3/pdoc:latest

# CI 集成
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/pdoc3/pdoc:latest
    format: 'sarif'
```

### 安全最佳实践

1. **使用非 root 用户运行**
   ```dockerfile
   RUN useradd -m -u 1000 pdoc
   USER pdoc
   ```

2. **只读文件系统**
   ```yaml
   security_opt:
     - no-new-privileges:true
   read_only: true
   ```

3. **资源限制**
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '0.5'
         memory: 512M
   ```

## 部署场景

### 场景 1: 本地开发

```bash
# 挂载源码目录
docker run -v $(pwd):/workspace -p 8080:8080 \
  ghcr.io/pdoc3/pdoc:latest \
  pdoc --http :8080 /workspace
```

### 场景 2: CI/CD 构建

```yaml
- name: Build documentation
  run: |
    docker run --rm \
      -v ${{ github.workspace }}:/workspace \
      ghcr.io/pdoc3/pdoc:latest \
      pdoc --html --output-dir /workspace/docs /workspace
```

### 场景 3: Kubernetes 部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pdoc
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pdoc
  template:
    metadata:
      labels:
        app: pdoc
    spec:
      containers:
      - name: pdoc
        image: ghcr.io/pdoc3/pdoc:latest
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

### 场景 4: 多环境配置

```yaml
# docker-compose.override.yml (开发)
services:
  pdoc:
    volumes:
      - ./pdoc:/app/pdoc:ro
    environment:
      - DEBUG=true

# docker-compose.prod.yml (生产)
services:
  pdoc:
    deploy:
      replicas: 3
    environment:
      - DEBUG=false
      - LOG_LEVEL=info
```

## 性能优化

### 1. 层缓存

```dockerfile
# 先复制依赖文件
COPY setup.py setup.cfg ./
RUN pip install -e .

# 再复制源码
COPY pdoc/ ./pdoc/
```

### 2. 构建缓存

```yaml
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### 3. 多架构构建

```yaml
platforms: linux/amd64,linux/arm64
```

## 监控与日志

### 健康检查

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1
```

### 日志收集

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 指标导出

```dockerfile
# 添加 Prometheus exporter
RUN pip install prometheus-fastapi-instrumentator
```

## 故障排查

### 常见问题

#### 1. 权限问题

```bash
# 检查文件权限
docker run --rm -v $(pwd):/workspace \
  ghcr.io/pdoc3/pdoc:latest ls -la /workspace
```

#### 2. 网络问题

```bash
# 测试网络连接
docker run --rm ghcr.io/pdoc3/pdoc:latest curl -I https://pypi.org
```

#### 3. 内存不足

```bash
# 增加内存限制
docker run -m 1g --memory-swap 2g ghcr.io/pdoc3/pdoc:latest
```

### 调试技巧

```bash
# 进入容器
docker exec -it <container-id> /bin/bash

# 查看日志
docker logs -f <container-id>

# 检查健康状态
docker inspect --format='{{.State.Health.Status}}' <container-id>
```

## 最佳实践

### 1. 版本管理

```bash
# 使用特定版本
docker pull ghcr.io/pdoc3/pdoc:v1.0.0

# 使用语义化版本
docker pull ghcr.io/pdoc3/pdoc:1.0
```

### 2. 安全更新

```bash
# 定期更新基础镜像
FROM python:3.11-slim-bookworm
RUN apt-get update && apt-get upgrade -y
```

### 3. 资源清理

```bash
# 清理未使用的镜像
docker image prune -a

# 清理未使用的卷
docker volume prune
```

## 附录

### A. Docker 命令速查

```bash
# 构建镜像
docker build -t pdoc:latest .

# 运行容器
docker run -p 8080:8080 pdoc:latest

# 查看日志
docker logs -f <container-id>

# 停止容器
docker stop <container-id>

# 删除容器
docker rm <container-id>

# 删除镜像
docker rmi pdoc:latest
```

### B. Compose 命令速查

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看日志
docker-compose logs -f

# 重新构建
docker-compose build

# 扩展服务
docker-compose up -d --scale pdoc=3
```

### C. 相关资源

- [Docker 文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [GitHub Container Registry](https://ghcr.io/)
- [Trivy 安全扫描](https://aquasecurity.github.io/trivy/)
