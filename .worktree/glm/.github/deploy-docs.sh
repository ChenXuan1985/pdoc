#!/bin/bash
#
# pdoc Documentation Deployment Script
# 
# This script handles documentation deployment to GitHub Pages
# with support for multiple environments (staging/production),
# version tracking, and rollback capabilities.
#
# Usage:
#   ./deploy-docs.sh [OPTIONS]
#
# Options:
#   -e, --environment    Environment (staging|production) [default: staging]
#   -v, --version        Version string [default: git commit SHA]
#   -r, --rollback       Rollback to specified commit SHA
#   -d, --dry-run        Show what would be done without making changes
#   -h, --help           Show this help message
#
# Environment Variables:
#   GITHUB_TOKEN         GitHub personal access token (required)
#   GITHUB_REPOSITORY    Repository name (e.g., owner/repo)
#   GITHUB_SHA           Current commit SHA
#   GITHUB_REF           Git reference (branch or tag)
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/doc/build"
DEPLOY_BRANCH="gh-pages"
TEMP_DIR=""

# Default values
ENVIRONMENT="${ENVIRONMENT:-staging}"
VERSION="${VERSION:-}"
DRY_RUN="${DRY_RUN:-false}"
ROLLBACK_TARGET="${ROLLBACK_TARGET:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        log_info "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Show help message
show_help() {
    cat << EOF
pdoc Documentation Deployment Script

Usage: $(basename "$0") [OPTIONS]

Options:
    -e, --environment ENV    Deployment environment (staging|production)
                             Default: staging
    -v, --version VERSION    Version string for this deployment
                             Default: git commit SHA or tag
    -r, --rollback SHA       Rollback to specified commit SHA
    -d, --dry-run            Show what would be done without making changes
    -h, --help               Show this help message

Environment Variables:
    GITHUB_TOKEN             GitHub personal access token (required)
    GITHUB_REPOSITORY        Repository name (e.g., owner/repo)
    GITHUB_SHA               Current commit SHA
    GITHUB_REF               Git reference (branch or tag)

Examples:
    # Deploy to staging
    $(basename "$0") -e staging

    # Deploy to production with version
    $(basename "$0") -e production -v 1.0.0

    # Rollback to a previous commit
    $(basename "$0") -r abc123def456

    # Dry run to see what would happen
    $(basename "$0") -e staging --dry-run

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -r|--rollback)
                ROLLBACK_TARGET="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be 'staging' or 'production'."
        exit 1
    fi
}

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in git pdoc3; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Install missing dependencies with: pip install ${missing_deps[*]}"
        exit 1
    fi
}

# Check required environment variables
check_env_vars() {
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is required"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        log_error "GITHUB_REPOSITORY environment variable is required"
        exit 1
    fi
}

# Determine version
determine_version() {
    if [[ -z "$VERSION" ]]; then
        if [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
            VERSION="${GITHUB_REF#refs/tags/}"
        elif [[ -n "${GITHUB_SHA:-}" ]]; then
            VERSION="${GITHUB_SHA:0:7}"
        else
            VERSION="$(git rev-parse --short HEAD)"
        fi
    fi
    
    log_info "Deployment version: $VERSION"
}

# Build documentation
build_docs() {
    log_info "Building documentation..."
    
    cd "$REPO_ROOT"
    
    # Clean previous build
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
    mkdir -p "$BUILD_DIR"
    
    # Determine if this is a release build
    local is_release="false"
    if [[ "$ENVIRONMENT" == "production" ]] || [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
        is_release="true"
    fi
    
    # Build with appropriate template
    local template_args=()
    if [[ "$is_release" == "true" && -d "$REPO_ROOT/doc/pdoc_template" ]]; then
        template_args=(--template-dir "$REPO_ROOT/doc/pdoc_template")
    fi
    
    pdoc3 --html \
        "${template_args[@]}" \
        --output-dir "$BUILD_DIR" \
        pdoc
    
    # Add analytics for production
    if [[ "$is_release" == "true" ]]; then
        add_analytics
    fi
    
    # Create build info file
    create_build_info
    
    log_success "Documentation built successfully"
}

# Add analytics code for production
add_analytics() {
    log_info "Adding analytics code..."
    
    local ga_script='<script async src="https://www.googletagmanager.com/gtag/js?id=G-BKZPJPR558"></script>
<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag("js",new Date());gtag("config","G-BKZPJPR558");</script>'
    
    find "$BUILD_DIR" -name '*.html' -print0 | xargs -0 -- sed -i "s#</head>#$ga_script</head>#i"
}

# Create build info JSON file
create_build_info() {
    local build_time
    build_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local commit_sha
    commit_sha="${GITHUB_SHA:-$(git rev-parse HEAD)}"
    
    cat > "$BUILD_DIR/build-info.json" << EOF
{
    "version": "$VERSION",
    "environment": "$ENVIRONMENT",
    "build_time": "$build_time",
    "commit": "$commit_sha",
    "ref": "${GITHUB_REF:-$(git symbolic-ref -q HEAD || git describe --tags --exact-match 2>/dev/null || echo 'unknown')}",
    "deployed_by": "${GITHUB_ACTOR:-local}"
}
EOF
    
    log_info "Build info saved to build-info.json"
}

# Generate sitemap
generate_sitemap() {
    log_info "Generating sitemap..."
    
    local website="https://${GITHUB_REPOSITORY_OWNER:-owner}.github.io/${GITHUB_REPOSITORY_NAME:-repo}"
    
    if [[ "$ENVIRONMENT" == "staging" ]]; then
        website="$website/staging"
    fi
    
    find "$BUILD_DIR" -name '*.html' |
        sed "s|^$BUILD_DIR|$website|" |
        sed 's/index.html$//' |
        grep -v '/google.*\.html$' |
        sort -u > "$BUILD_DIR/sitemap.txt"
    
    echo "Sitemap: $website/sitemap.txt" > "$BUILD_DIR/robots.txt"
    
    log_success "Sitemap generated"
}

# Deploy to GitHub Pages
deploy_to_github_pages() {
    log_info "Deploying to GitHub Pages ($ENVIRONMENT)..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would deploy to $ENVIRONMENT environment"
        log_info "Files to deploy:"
        find "$BUILD_DIR" -type f | head -20
        return
    fi
    
    TEMP_DIR=$(mktemp -d)
    local deploy_dir="$TEMP_DIR/gh-pages"
    
    # Clone gh-pages branch
    git clone \
        --branch "$DEPLOY_BRANCH" \
        --single-branch \
        "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" \
        "$deploy_dir" 2>/dev/null || {
        log_warning "gh-pages branch doesn't exist, creating it"
        mkdir -p "$deploy_dir"
        cd "$deploy_dir"
        git init
        git checkout -b "$DEPLOY_BRANCH"
    }
    
    cd "$deploy_dir"
    
    # Determine target directory
    local target_dir="."
    if [[ "$ENVIRONMENT" == "staging" ]]; then
        target_dir="staging"
        mkdir -p "$target_dir"
    fi
    
    # Copy new documentation
    cp -r "$BUILD_DIR"/* "$target_dir/"
    
    # Configure git
    git config user.name 'github-actions[bot]'
    git config user.email 'github-actions[bot]@users.noreply.github.com'
    
    # Stage changes
    git add -A
    
    # Check if there are changes
    if git diff --staged --quiet; then
        log_info "No changes to deploy"
        return
    fi
    
    # Commit and push
    git commit -m "Deploy docs: $ENVIRONMENT v$VERSION (${GITHUB_SHA:-local})"
    git push origin "$DEPLOY_BRANCH" --force
    
    log_success "Deployed to $ENVIRONMENT environment"
    log_info "URL: https://${GITHUB_REPOSITORY_OWNER:-owner}.github.io/${GITHUB_REPOSITORY_NAME:-repo}/${ENVIRONMENT}/"
}

# Perform rollback
perform_rollback() {
    log_warning "Initiating rollback to: $ROLLBACK_TARGET"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would rollback to commit $ROLLBACK_TARGET"
        return
    fi
    
    # Verify the commit exists
    if ! git rev-parse --verify "$ROLLBACK_TARGET" &>/dev/null; then
        log_error "Invalid commit SHA: $ROLLBACK_TARGET"
        exit 1
    fi
    
    # Checkout the target commit
    local original_branch
    original_branch=$(git rev-parse --abbrev-ref HEAD)
    
    git checkout "$ROLLBACK_TARGET"
    
    # Build docs from that commit
    build_docs
    
    # Deploy
    ENVIRONMENT="production"
    deploy_to_github_pages
    
    # Return to original branch
    git checkout "$original_branch"
    
    # Update rollback tag
    git tag -f "deployed-production" "$ROLLBACK_TARGET"
    git push origin "deployed-production" --force || true
    
    log_success "Rollback completed successfully"
}

# Main function
main() {
    parse_args "$@"
    
    log_info "=========================================="
    log_info "pdoc Documentation Deployment"
    log_info "=========================================="
    log_info "Environment: $ENVIRONMENT"
    
    check_dependencies
    
    if [[ -n "$ROLLBACK_TARGET" ]]; then
        check_env_vars
        perform_rollback
        exit 0
    fi
    
    validate_environment
    check_env_vars
    determine_version
    build_docs
    generate_sitemap
    deploy_to_github_pages
    
    log_success "=========================================="
    log_success "Deployment completed successfully!"
    log_success "=========================================="
}

# Run main function
main "$@"
