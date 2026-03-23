# ============================================
# pdoc Docker 镜像
# 用于文档生成和部署
# ============================================

# 构建阶段
FROM python:3.11-slim as builder

WORKDIR /app

# 安装构建依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 复制项目文件
COPY setup.py setup.cfg MANIFEST.in ./
COPY pdoc/ ./pdoc/
COPY doc/ ./doc/

# 安装 pdoc
RUN pip install --no-cache-dir -e .

# 构建文档
RUN cd doc && ./build.sh

# 生产阶段
FROM nginx:alpine as production

# 复制构建的文档
COPY --from=builder /app/doc/build /usr/share/nginx/html

# 复制自定义 nginx 配置
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

EXPOSE 80

# 开发阶段（用于本地文档开发）
FROM python:3.11-slim as development

WORKDIR /app

# 安装开发依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

# 复制项目文件
COPY setup.py setup.cfg MANIFEST.in ./
COPY pdoc/ ./pdoc/
COPY doc/ ./doc/

# 安装 pdoc（开发模式）
RUN pip install --no-cache-dir -e .

# 开发服务器脚本
COPY docker/dev-server.sh /usr/local/bin/dev-server
RUN chmod +x /usr/local/bin/dev-server

EXPOSE 8080

CMD ["dev-server"]
