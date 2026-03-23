#!/bin/bash
# pdoc Documentation Deployment Script
# Usage: ./deploy-docs.sh [staging|production|rollback]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
DOCS_OUTPUT_DIR="${PROJECT_ROOT}/docs_build"
GITHUB_PAGES_BRANCH="gh-pages"
REMOTE_NAME="origin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Parse command line arguments
DEPLOY_ENV="${1:-staging}"
ROLLBACK_VERSION="${2:-}"

validate_environment() {
    if [[ ! "$DEPLOY_ENV" =~ ^(staging|production|rollback)$ ]]; then
        error "Invalid environment: $DEPLOY_ENV. Use 'staging', 'production', or 'rollback'"
    fi
}

check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v pdoc &> /dev/null; then
        error "pdoc is not installed. Please install it first: pip install -e ."
    fi
    
    if ! command -v git &> /dev/null; then
        error "git is not installed"
    fi
    
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        error "Not inside a git repository"
    fi
    
    info "All prerequisites satisfied"
}

get_version() {
    git describe --tags --abbrev=0 2>/dev/null || git rev-parse --short HEAD
}

build_documentation() {
    local version="$1"
    local output_dir="$2"
    
    info "Building documentation for version: $version"
    
    rm -rf "${output_dir}"
    mkdir -p "${output_dir}"
    
    # Build main documentation
    info "Generating main API documentation..."
    pdoc --html --output-dir "${output_dir}" pdoc
    
    # Move html output to root if needed
    if [ -d "${output_dir}/pdoc" ]; then
        mv "${output_dir}/pdoc"/* "${output_dir}/"
        rmdir "${output_dir}/pdoc"
    fi
    
    # Copy additional assets
    if [ -d "${PROJECT_ROOT}/doc" ]; then
        cp -r "${PROJECT_ROOT}/doc"/* "${output_dir}/" 2>/dev/null || true
    fi
    
    # Create version file
    echo "${version}" > "${output_dir}/version.txt"
    
    # Create index.html redirect if needed
    if [ ! -f "${output_dir}/index.html" ] && [ -f "${output_dir}/pdoc.html" ]; then
        cat > "${output_dir}/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="refresh" content="0; url=pdoc.html" />
    <title>Redirecting to pdoc documentation</title>
</head>
<body>
    Redirecting to <a href="pdoc.html">pdoc documentation</a>...
</body>
</html>
EOF
    fi
    
    info "Documentation built successfully in: ${output_dir}"
}

deploy_to_gh_pages() {
    local source_dir="$1"
    local target_subdir="$2"
    
    info "Deploying to GitHub Pages (subdir: ${target_subdir:-root})..."
    
    # Create a temporary directory for gh-pages work
    local temp_dir=$(mktemp -d -t pdoc-gh-pages-XXXXXX)
    trap 'rm -rf "${temp_dir}"' EXIT
    
    # Clone gh-pages branch
    info "Cloning ${GITHUB_PAGES_BRANCH} branch..."
    if ! git clone --depth 1 --branch "${GITHUB_PAGES_BRANCH}" \
        "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" \
        "${temp_dir}" 2>/dev/null; then
        warn "gh-pages branch does not exist yet, creating new one..."
        git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "${temp_dir}"
        cd "${temp_dir}"
        git checkout --orphan "${GITHUB_PAGES_BRANCH}"
        git rm -rf .
        cd "${PROJECT_ROOT}"
    fi
    
    # Prepare target directory
    local target_dir="${temp_dir}/${target_subdir}"
    rm -rf "${target_dir}"
    mkdir -p "$(dirname "${target_dir}")"
    cp -r "${source_dir}/"* "${target_dir}/"
    
    # Create/update versions.json for version navigation
    local versions_file="${temp_dir}/versions.json"
    if [ ! -f "${versions_file}" ]; then
        echo '[]' > "${versions_file}"
    fi
    
    # Update versions list
    local version_name="$(get_version)"
    if [ "${DEPLOY_ENV}" = "staging" ]; then
        version_name="staging (${version_name})"
    fi
    
    python3 <<EOF
import json
from datetime import datetime

versions_file = "${versions_file}"
with open(versions_file, 'r') as f:
    versions = json.load(f)

new_version = {
    "name": "${version_name}",
    "path": "${target_subdir}",
    "environment": "${DEPLOY_ENV}",
    "timestamp": datetime.utcnow().isoformat() + "Z"
}

# Remove existing entry with same path
versions = [v for v in versions if v["path"] != "${target_subdir}"]
versions.insert(0, new_version)

# Keep only last 10 versions
versions = versions[:10]

with open(versions_file, 'w') as f:
    json.dump(versions, f, indent=2)
EOF
    
    # Commit and push
    cd "${temp_dir}"
    git config user.name "GitHub Actions"
    git config user.email "actions@github.com"
    git add -A .
    
    local commit_msg="Deploy ${DEPLOY_ENV} documentation - $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    if ! git commit -m "${commit_msg}"; then
        info "No changes to commit"
        cd "${PROJECT_ROOT}"
        return 0
    fi
    
    git push origin "${GITHUB_PAGES_BRANCH}"
    cd "${PROJECT_ROOT}"
    
    info "Successfully deployed to GitHub Pages!"
}

rollback() {
    local target_version="$1"
    info "Rolling back to version: ${target_version}"
    
    # In a real scenario, this would revert to a previous version
    # For simplicity, we'll redeploy the previous commit or tag
    if [ -n "${target_version}" ]; then
        git checkout "${target_version}"
        build_documentation "${target_version}" "${DOCS_OUTPUT_DIR}"
        deploy_to_gh_pages "${DOCS_OUTPUT_DIR}" ""
    else
        error "Rollback requires a target version/tag"
    fi
}

main() {
    validate_environment
    check_prerequisites
    
    local version="$(get_version)"
    info "Current version: ${version}"
    
    if [ "${DEPLOY_ENV}" = "rollback" ]; then
        rollback "${ROLLBACK_VERSION}"
        return 0
    fi
    
    # Build documentation
    build_documentation "${version}" "${DOCS_OUTPUT_DIR}"
    
    # Determine deployment target
    local deploy_target=""
    if [ "${DEPLOY_ENV}" = "staging" ]; then
        deploy_target="staging"
    elif [ "${DEPLOY_ENV}" = "production" ]; then
        # Production deploys to root and to versioned directory
        deploy_target=""
        deploy_to_gh_pages "${DOCS_OUTPUT_DIR}" "v/${version}"
    fi
    
    deploy_to_gh_pages "${DOCS_OUTPUT_DIR}" "${deploy_target}"
    
    info "Deployment completed successfully!"
}

main "$@"
