#!/bin/bash
#
# pdoc Documentation Rollback Script
#
# This script provides rollback functionality for documentation deployments.
# It can list deployment history, verify rollback targets, and perform rollbacks.
#
# Usage:
#   ./rollback.sh [OPTIONS]
#
# Options:
#   -l, --list            List recent deployments
#   -t, --target SHA      Target commit SHA to rollback to
#   -v, --version VER     Target version/tag to rollback to
#   -e, --environment ENV Environment (staging|production) [default: production]
#   -f, --force           Skip confirmation prompt
#   -d, --dry-run         Show what would be done without making changes
#   -h, --help            Show this help message
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOYMENTS_DIR="$REPO_ROOT/deployments"
DEPLOY_TAG="deployed-production"

# Default values
ENVIRONMENT="production"
TARGET_SHA=""
TARGET_VERSION=""
FORCE="false"
DRY_RUN="false"
LIST_ONLY="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Show help message
show_help() {
    cat << EOF
pdoc Documentation Rollback Script

Usage: $(basename "$0") [OPTIONS]

Options:
    -l, --list              List recent deployments
    -t, --target SHA        Target commit SHA to rollback to
    -v, --version VERSION   Target version/tag to rollback to
    -e, --environment ENV   Environment (staging|production)
                            Default: production
    -f, --force             Skip confirmation prompt
    -d, --dry-run           Show what would be done without making changes
    -h, --help              Show this help message

Examples:
    # List recent deployments
    $(basename "$0") --list

    # Rollback to specific commit
    $(basename "$0") -t abc123def456

    # Rollback to specific version
    $(basename "$0") -v 1.0.0

    # Force rollback without confirmation
    $(basename "$0") -t abc123def456 --force

    # Dry run to see what would happen
    $(basename "$0") -t abc123def456 --dry-run

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--list)
                LIST_ONLY="true"
                shift
                ;;
            -t|--target)
                TARGET_SHA="$2"
                shift 2
                ;;
            -v|--version)
                TARGET_VERSION="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
                shift
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

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in git; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# List recent deployments
list_deployments() {
    log_info "Listing recent deployments..."
    echo ""
    
    # Get deployment history from git log
    echo -e "${CYAN}Recent Production Deployments:${NC}"
    echo "----------------------------------------"
    
    # Check if deploy tag exists
    if git rev-parse "$DEPLOY_TAG" &>/dev/null; then
        local current_deploy
        current_deploy=$(git rev-parse "$DEPLOY_TAG")
        echo -e "Current deployed: ${GREEN}$current_deploy${NC}"
        echo ""
    fi
    
    # List recent commits on gh-pages branch
    echo -e "${CYAN}Recent gh-pages commits:${NC}"
    git log --oneline -20 origin/gh-pages 2>/dev/null || {
        log_warning "Could not fetch gh-pages branch history"
    }
    
    echo ""
    echo -e "${CYAN}Recent tags (potential rollback targets):${NC}"
    git tag -l '[0-9]*' | sort -Vr | head -10
    
    echo ""
    echo -e "${CYAN}Recent commits on master:${NC}"
    git log --oneline -10 master 2>/dev/null || git log --oneline -10 main 2>/dev/null || {
        log_warning "Could not fetch master/main branch history"
    }
}

# Resolve target to commit SHA
resolve_target() {
    if [[ -n "$TARGET_VERSION" ]]; then
        log_info "Resolving version $TARGET_VERSION to commit..."
        
        if git rev-parse "$TARGET_VERSION" &>/dev/null; then
            TARGET_SHA=$(git rev-parse "$TARGET_VERSION")
            log_info "Version $TARGET_VERSION resolves to $TARGET_SHA"
        else
            log_error "Version $TARGET_VERSION not found"
            exit 1
        fi
    fi
    
    if [[ -z "$TARGET_SHA" ]]; then
        log_error "No rollback target specified. Use -t SHA or -v VERSION"
        exit 1
    fi
    
    # Verify the commit exists
    if ! git rev-parse --verify "$TARGET_SHA" &>/dev/null; then
        log_error "Invalid commit SHA: $TARGET_SHA"
        exit 1
    fi
    
    # Get full SHA
    TARGET_SHA=$(git rev-parse "$TARGET_SHA")
}

# Show rollback preview
show_rollback_preview() {
    local current_sha
    current_sha=$(git rev-parse "$DEPLOY_TAG" 2>/dev/null || echo "unknown")
    
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}ROLLBACK PREVIEW${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo -e "Environment:    ${CYAN}$ENVIRONMENT${NC}"
    echo -e "Current commit: ${GREEN}$current_sha${NC}"
    echo -e "Target commit:  ${RED}$TARGET_SHA${NC}"
    echo ""
    
    # Show commit info
    echo -e "${CYAN}Target commit details:${NC}"
    git log -1 --format="Author: %an <%ae>%nDate:   %ad%nMessage: %s" "$TARGET_SHA"
    echo ""
    
    # Show diff stats
    if [[ "$current_sha" != "unknown" ]]; then
        echo -e "${CYAN}Changes since deployment:${NC}"
        git log --oneline "$current_sha..$TARGET_SHA" 2>/dev/null || echo "No commits between current and target"
        echo ""
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}DRY RUN: No changes will be made${NC}"
    fi
}

# Confirm rollback
confirm_rollback() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo ""
    read -p "$(echo -e ${RED}Are you sure you want to proceed with this rollback? [y/N]:${NC} )" -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rollback cancelled"
        exit 0
    fi
}

# Perform rollback
perform_rollback() {
    log_warning "Initiating rollback to: $TARGET_SHA"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN: Would perform the following actions:"
        echo "  1. Checkout commit $TARGET_SHA"
        echo "  2. Build documentation"
        echo "  3. Deploy to $ENVIRONMENT environment"
        echo "  4. Update deployment tag"
        return
    fi
    
    # Store original branch
    local original_branch
    original_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")
    
    # Checkout target commit
    log_info "Checking out target commit..."
    git checkout "$TARGET_SHA"
    
    # Build documentation
    log_info "Building documentation from target commit..."
    cd "$REPO_ROOT"
    
    if [[ -f "doc/build.sh" ]]; then
        bash doc/build.sh
    else
        pip install -e . 2>/dev/null || pip install -e .
        pdoc3 --html --output-dir doc/build pdoc
    fi
    
    # Deploy using the deploy script
    log_info "Deploying documentation..."
    if [[ -f "$SCRIPT_DIR/deploy-docs.sh" ]]; then
        ENVIRONMENT="$ENVIRONMENT" VERSION="rollback-$TARGET_SHA" \
            bash "$SCRIPT_DIR/deploy-docs.sh" -e "$ENVIRONMENT"
    else
        log_warning "deploy-docs.sh not found, manual deployment required"
    fi
    
    # Return to original branch
    git checkout "$original_branch" 2>/dev/null || git checkout -
    
    # Update deployment tag
    log_info "Updating deployment tag..."
    git tag -f "$DEPLOY_TAG" "$TARGET_SHA"
    git push origin "$DEPLOY_TAG" --force 2>/dev/null || {
        log_warning "Could not push tag. You may need to push manually:"
        log_warning "  git push origin $DEPLOY_TAG --force"
    }
    
    log_success "Rollback completed successfully!"
    log_info "Documentation should be updated shortly"
}

# Main function
main() {
    parse_args "$@"
    
    cd "$REPO_ROOT"
    check_dependencies
    
    if [[ "$LIST_ONLY" == "true" ]]; then
        list_deployments
        exit 0
    fi
    
    resolve_target
    show_rollback_preview
    confirm_rollback
    perform_rollback
}

# Run main function
main "$@"
