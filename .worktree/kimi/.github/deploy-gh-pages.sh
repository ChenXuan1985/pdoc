#!/bin/bash
set -eu

# ============================================
# pdoc 文档部署脚本
# 支持 Staging 和 Production 环境
# ============================================

# 配置
WEBSITE='https://pdoc3.github.io/pdoc'
REPO_URL="https://github.com/${GITHUB_REPOSITORY}.git"
DEPLOY_ENV="${1:-staging}"
BUILD_DIR="doc/build"

die() { echo "ERROR: $*" >&2; exit 2; }

# 检查必要的环境变量
if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${GH_PASSWORD:-}" ]; then
    die "GITHUB_TOKEN or GH_PASSWORD environment variable is required"
fi

# 检查构建目录
if [ ! -d "$BUILD_DIR" ]; then
    die "Build directory '$BUILD_DIR' not found. Run doc/build.sh first."
fi

# 获取认证信息
if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_TOKEN="$GITHUB_TOKEN"
    AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
else
    AUTH_TOKEN="$GH_PASSWORD"
    AUTH_HEADER="Authorization: Basic $(echo -n "kernc:$GH_PASSWORD" | base64)"
fi

# 获取当前提交信息
head=$(git rev-parse HEAD)
short_head=$(git rev-parse --short HEAD)
commit_message=$(git log -1 --pretty=%B)
commit_author=$(git log -1 --pretty=%an)
commit_email=$(git log -1 --pretty=%ae)

# 生成站点地图
sitemap() {
    echo "Generating sitemap..."
    local sitemap_file="$1/sitemap.txt"
    local robots_file="$1/robots.txt"
    
    find "$1" -name '*.html' |
        sed "s|^$1|$WEBSITE/$DEPLOY_ENV|" |
        sed 's/index.html$//' |
        grep -v '/google.*\.html$' |
        sort -u > "$sitemap_file"
    
    echo "Sitemap: $WEBSITE/$DEPLOY_ENV/sitemap.txt" > "$robots_file"
    echo "Generated sitemap with $(wc -l < "$sitemap_file") URLs"
}

# 添加环境标识
add_environment_badge() {
    local target_dir="$1"
    local env="$2"
    
    echo "Adding environment badge for $env..."
    
    local badge_style=""
    local badge_text=""
    
    case "$env" in
        staging)
            badge_style="background-color: #f0ad4e; color: white;"
            badge_text="STAGING"
            ;;
        production)
            badge_style="background-color: #5cb85c; color: white;"
            badge_text="PRODUCTION"
            ;;
        *)
            badge_style="background-color: #777; color: white;"
            badge_text="${env^^}"
            ;;
    esac
    
    local badge_html="<div id=\"env-badge\" style=\"position: fixed; top: 0; right: 0; padding: 5px 15px; font-size: 12px; font-weight: bold; z-index: 9999; $badge_style\">$badge_text</div>"
    
    # 在每个 HTML 文件的 body 开始处添加徽章
    find "$target_dir" -name '*.html' -print0 |
        xargs -0 sed -i "s|<body[^>]*>|&\n    $badge_html|"
}

# 部署到 GitHub Pages
deploy_to_gh_pages() {
    local env="$1"
    local target_branch="gh-pages"
    local deploy_dir=""
    
    case "$env" in
        staging)
            deploy_dir="staging"
            ;;
        production)
            deploy_dir="."
            ;;
        *)
            deploy_dir="$env"
            ;;
    esac
    
    echo "========================================"
    echo "Deploying to GitHub Pages"
    echo "Environment: $env"
    echo "Target directory: $deploy_dir"
    echo "Commit: $head"
    echo "========================================"
    
    # 克隆 gh-pages 分支
    local temp_dir=$(mktemp -d)
    git clone --single-branch --branch "$target_branch" \
        "https://x-access-token:${AUTH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" \
        "$temp_dir/gh-pages" 2>/dev/null || {
        echo "Creating new gh-pages branch..."
        git checkout --orphan "$target_branch"
        git rm -rf .
        git commit --allow-empty -m "Initial gh-pages commit"
        git push origin "$target_branch"
        git clone --single-branch --branch "$target_branch" \
            "https://x-access-token:${AUTH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" \
            "$temp_dir/gh-pages"
    }
    
    cd "$temp_dir/gh-pages"
    
    # 创建目标目录
    if [ "$deploy_dir" != "." ]; then
        mkdir -p "$deploy_dir"
        rm -rf "$deploy_dir"/*
    else
        # 保留 .git 目录和其他特殊文件
        find . -mindepth 1 -maxdepth 1 -not -name '.git' -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # 复制构建文件
    if [ "$deploy_dir" != "." ]; then
        cp -R "$GITHUB_WORKSPACE/$BUILD_DIR"/* "$deploy_dir/"
    else
        cp -R "$GITHUB_WORKSPACE/$BUILD_DIR"/* .
    fi
    
    # 生成站点地图
    sitemap "$deploy_dir"
    
    # 添加环境徽章（仅 staging）
    if [ "$env" == "staging" ]; then
        add_environment_badge "$deploy_dir" "$env"
    fi
    
    # 添加 noindex meta 标签到 staging（防止搜索引擎索引）
    if [ "$env" == "staging" ]; then
        find "$deploy_dir" -name '*.html' -print0 |
            xargs -0 sed -i 's|<head>|<head>\n    <meta name="robots" content="noindex, nofollow">|'
    fi
    
    # 配置 git
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    
    # 提交并推送
    git add -A
    
    if git diff --staged --quiet; then
        echo "No changes to commit."
        exit 0
    fi
    
    local commit_msg="CI: Deploy docs for ${env}"
    if [ -n "${GITHUB_REF_NAME:-}" ]; then
        commit_msg="$commit_msg - ${GITHUB_REF_NAME}"
    fi
    commit_msg="$commit_msg ($short_head)"
    
    git commit -m "$commit_msg" \
               -m "Original commit: $head" \
               -m "Author: $commit_author <$commit_email>" \
               -m "Message: $commit_message"
    
    git push origin "$target_branch"
    
    echo "========================================"
    echo "Deployment completed successfully!"
    echo "URL: $WEBSITE/$deploy_dir"
    echo "========================================"
    
    # 清理
    cd "$GITHUB_WORKSPACE"
    rm -rf "$temp_dir"
}

# 回滚功能
rollback() {
    local env="$1"
    local target_branch="gh-pages"
    local deploy_dir=""
    
    case "$env" in
        staging)
            deploy_dir="staging"
            ;;
        production)
            deploy_dir="."
            ;;
        *)
            deploy_dir="$env"
            ;;
    esac
    
    echo "Rolling back $env deployment..."
    
    local temp_dir=$(mktemp -d)
    git clone --single-branch --branch "$target_branch" \
        "https://x-access-token:${AUTH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" \
        "$temp_dir/gh-pages"
    
    cd "$temp_dir/gh-pages"
    
    # 回滚到上一个提交
    git revert --no-edit HEAD
    git push origin "$target_branch"
    
    echo "Rollback completed for $env"
    
    cd "$GITHUB_WORKSPACE"
    rm -rf "$temp_dir"
}

# 主逻辑
case "${2:-}" in
    rollback)
        rollback "$DEPLOY_ENV"
        ;;
    *)
        deploy_to_gh_pages "$DEPLOY_ENV"
        ;;
esac
