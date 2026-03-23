#!/bin/bash
set -e

# ============================================
# pdoc 开发服务器脚本
# 支持实时重载
# ============================================

DOC_DIR="/app/doc"
PDOC_MODULE="pdoc"
PORT=${PORT:-8080}

echo "========================================"
echo "pdoc Development Server"
echo "Port: $PORT"
echo "Module: $PDOC_MODULE"
echo "========================================"

# 初始构建
echo "Building documentation..."
pdoc3 --html --output-dir "$DOC_DIR/build" "$PDOC_MODULE"

# 启动 HTTP 服务器
cd "$DOC_DIR/build"
python3 -m http.server "$PORT" &
SERVER_PID=$!

echo "Server started at http://localhost:$PORT"
echo "Press Ctrl+C to stop"

# 监控文件变化并自动重建
if command -v inotifywait &> /dev/null; then
    echo "Watching for changes..."
    while true; do
        inotifywait -r -e modify,create,delete /app/pdoc 2>/dev/null || true
        echo "Changes detected, rebuilding..."
        pdoc3 --html --output-dir "$DOC_DIR/build" "$PDOC_MODULE"
        echo "Rebuild complete"
    done
else
    echo "inotifywait not available, watching disabled"
    wait $SERVER_PID
fi
