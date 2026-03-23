#!/bin/bash
#
# pdoc CI/CD Notification Script
#
# This script handles notifications for CI/CD events including:
# - Deployment status (success/failure)
# - Rollback notifications
# - Security alerts
# - Test failures
#
# Usage:
#   ./notify.sh [OPTIONS]
#
# Options:
#   -t, --type TYPE        Notification type (deploy|rollback|security|test|ci)
#   -s, --status STATUS    Status (success|failure|warning)
#   -e, --environment ENV  Environment (staging|production)
#   -v, --version VERSION  Version string
#   -m, --message MSG      Custom message
#   -h, --help             Show help
#
# Environment Variables:
#   SLACK_WEBHOOK_URL      Slack webhook URL
#   DISCORD_WEBHOOK_URL    Discord webhook URL
#   GITHUB_TOKEN           GitHub token for API calls
#   GITHUB_REPOSITORY      Repository name (owner/repo)
#   GITHUB_SHA             Commit SHA
#   GITHUB_REF             Git reference
#   GITHUB_ACTOR           Actor who triggered the event
#

set -euo pipefail

# Default values
NOTIFICATION_TYPE="${NOTIFICATION_TYPE:-}"
STATUS="${STATUS:-}"
ENVIRONMENT="${ENVIRONMENT:-}"
VERSION="${VERSION:-}"
MESSAGE="${MESSAGE:-}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

# Show help
show_help() {
    cat << EOF
pdoc CI/CD Notification Script

Usage: $(basename "$0") [OPTIONS]

Options:
    -t, --type TYPE        Notification type (deploy|rollback|security|test|ci)
    -s, --status STATUS    Status (success|failure|warning)
    -e, --environment ENV  Environment (staging|production)
    -v, --version VERSION  Version string
    -m, --message MSG      Custom message
    --dry-run              Show what would be sent without sending
    -h, --help             Show this help

Environment Variables:
    SLACK_WEBHOOK_URL      Slack webhook URL (optional)
    DISCORD_WEBHOOK_URL    Discord webhook URL (optional)
    GITHUB_TOKEN           GitHub token (optional)
    GITHUB_REPOSITORY      Repository name (owner/repo)
    GITHUB_SHA             Commit SHA
    GITHUB_REF             Git reference
    GITHUB_ACTOR           Actor who triggered the event

Examples:
    # Deployment success
    $(basename "$0") -t deploy -s success -e production -v 1.0.0

    # Deployment failure
    $(basename "$0") -t deploy -s failure -e staging -m "Build failed"

    # Rollback notification
    $(basename "$0") -t rollback -s warning -e production -v abc123

    # Security alert
    $(basename "$0") -t security -s warning -m "Vulnerability found"

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                NOTIFICATION_TYPE="$2"
                shift 2
                ;;
            -s|--status)
                STATUS="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -m|--message)
                MESSAGE="$2"
                shift 2
                ;;
            --dry-run)
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

# Get emoji for status
get_status_emoji() {
    local status="$1"
    case "$status" in
        success) echo "✅" ;;
        failure) echo "❌" ;;
        warning) echo "⚠️" ;;
        *) echo "ℹ️" ;;
    esac
}

# Get color for status (Slack/Discord)
get_status_color() {
    local status="$1"
    case "$status" in
        success) echo "good" ;;
        failure) echo "danger" ;;
        warning) echo "warning" ;;
        *) echo "#808080" ;;
    esac
}

# Get title for notification type
get_notification_title() {
    local type="$1"
    case "$type" in
        deploy) echo "Deployment" ;;
        rollback) echo "Rollback" ;;
        security) echo "Security Alert" ;;
        test) echo "Test Result" ;;
        ci) echo "CI Status" ;;
        *) echo "Notification" ;;
    esac
}

# Build notification payload
build_payload() {
    local type="$1"
    local status="$2"
    local environment="$3"
    local version="$4"
    local message="$5"
    
    local emoji
    emoji=$(get_status_emoji "$status")
    local title
    title=$(get_notification_title "$type")
    local color
    color=$(get_status_color "$status")
    
    local repo="${GITHUB_REPOSITORY:-unknown/unknown}"
    local sha="${GITHUB_SHA:-unknown}"
    local short_sha="${sha:0:7}"
    local ref="${GITHUB_REF:-unknown}"
    local actor="${GITHUB_ACTOR:-unknown}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local github_url="https://github.com/$repo"
    local commit_url="$github_url/commit/$sha"
    local workflow_url="$github_url/actions"
    
    # Build fields
    local fields=""
    if [[ -n "$environment" ]]; then
        fields+="\"Environment\": \"$environment\","
    fi
    if [[ -n "$version" ]]; then
        fields+="\"Version\": \"$version\","
    fi
    fields+="\"Commit\": \"<$commit_url|$short_sha>\","
    fields+="\"Branch/Tag\": \"$ref\","
    fields+="\"Triggered by\": \"$actor\""
    
    # Build main message
    local main_message
    if [[ -n "$message" ]]; then
        main_message="$message"
    else
        main_message="$emoji **$title $status**"
        if [[ -n "$environment" ]]; then
            main_message+=" to **$environment**"
        fi
        if [[ -n "$version" ]]; then
            main_message+=" (v$version)"
        fi
    fi
    
    # JSON payload for Slack
    cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": "$emoji $title $status",
                        "emoji": true
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "$main_message"
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": "*Repository:*\n<$github_url|$repo>"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*Environment:*\n${environment:-N/A}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*Version:*\n${version:-N/A}"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*Commit:*\n<$commit_url|$short_sha>"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*Branch/Tag:*\n$ref"
                        },
                        {
                            "type": "mrkdwn",
                            "text": "*Triggered by:*\n$actor"
                        }
                    ]
                },
                {
                    "type": "actions",
                    "elements": [
                        {
                            "type": "button",
                            "text": {
                                "type": "plain_text",
                                "text": "View Workflow",
                                "emoji": true
                            },
                            "url": "$workflow_url"
                        },
                        {
                            "type": "button",
                            "text": {
                                "type": "plain_text",
                                "text": "View Commit",
                                "emoji": true
                            },
                            "url": "$commit_url"
                        }
                    ]
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "mrkdwn",
                            "text": "📅 $timestamp"
                        }
                    ]
                }
            ]
        }
    ]
}
EOF
}

# Send Slack notification
send_slack() {
    local payload="$1"
    
    if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
        log_warning "SLACK_WEBHOOK_URL not set, skipping Slack notification"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would send to Slack:"
        echo "$payload" | jq . 2>/dev/null || echo "$payload"
        return 0
    fi
    
    log_info "Sending notification to Slack..."
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H 'Content-type: application/json' \
        --data "$payload" \
        "$SLACK_WEBHOOK_URL" 2>&1)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "200" ]]; then
        log_success "Slack notification sent successfully"
    else
        log_warning "Failed to send Slack notification (HTTP $http_code)"
    fi
}

# Send Discord notification
send_discord() {
    local payload="$1"
    
    if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
        log_warning "DISCORD_WEBHOOK_URL not set, skipping Discord notification"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would send to Discord:"
        echo "$payload" | jq . 2>/dev/null || echo "$payload"
        return 0
    fi
    
    log_info "Sending notification to Discord..."
    
    # Convert Slack payload to Discord format
    local discord_payload
    discord_payload=$(echo "$payload" | jq '{
        embeds: [.attachments[] | {
            title: .blocks[0].text.text,
            description: .blocks[1].text.text,
            color: (if .color == "good" then 3066993 
                   elif .color == "danger" then 15158332 
                   elif .color == "warning" then 16776960 
                   else 8421504 end),
            fields: [.blocks[2].fields[] | {
                name: .text | split(":")[0] | gsub("\\*"; ""),
                value: .text | split(":")[1:] | join(":") | gsub("\\*"; "") | gsub("<[^>]+>"; "") | trim,
                inline: true
            }],
            footer: {
                text: .blocks[4].elements[0].text
            }
        }]
    }')
    
    local response
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H 'Content-type: application/json' \
        --data "$discord_payload" \
        "$DISCORD_WEBHOOK_URL" 2>&1)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "204" ]]; then
        log_success "Discord notification sent successfully"
    else
        log_warning "Failed to send Discord notification (HTTP $http_code)"
    fi
}

# Create GitHub issue for critical failures
create_github_issue() {
    local type="$1"
    local status="$2"
    local environment="$3"
    local version="$4"
    local message="$5"
    
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_warning "GITHUB_TOKEN not set, skipping GitHub issue creation"
        return 0
    fi
    
    if [[ "$status" != "failure" ]]; then
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would create GitHub issue for failure"
        return 0
    fi
    
    local repo="${GITHUB_REPOSITORY:-}"
    if [[ -z "$repo" ]]; then
        log_warning "GITHUB_REPOSITORY not set, skipping GitHub issue creation"
        return 0
    fi
    
    local title
    title=$(get_notification_title "$type")
    local emoji
    emoji=$(get_status_emoji "$status")
    
    local issue_title="[$type] $title failed in $environment"
    local issue_body="## $emoji $title Failure\n\n**Environment:** $environment\n**Version:** ${version:-N/A}\n**Commit:** ${GITHUB_SHA:-unknown}\n**Branch/Tag:** ${GITHUB_REF:-unknown}\n**Triggered by:** ${GITHUB_ACTOR:-unknown}\n\n### Details\n\n$message\n\n### Links\n\n- [Workflow Run](https://github.com/$repo/actions)\n- [Commit](https://github.com/$repo/commit/${GITHUB_SHA:-})\n\n---\n*This issue was automatically created by the CI/CD system.*"
    
    log_info "Creating GitHub issue for $type failure..."
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$repo/issues" \
        -d "{\"title\":\"$issue_title\",\"body\":\"$issue_body\",\"labels\":[\"ci-failure\",\"automated\"]}" 2>&1)
    
    if echo "$response" | jq -e '.number' &>/dev/null; then
        local issue_number
        issue_number=$(echo "$response" | jq -r '.number')
        log_success "Created GitHub issue #$issue_number"
    else
        log_warning "Failed to create GitHub issue"
    fi
}

# Print terminal notification
print_terminal() {
    local type="$1"
    local status="$2"
    local environment="$3"
    local version="$4"
    local message="$5"
    
    local emoji
    emoji=$(get_status_emoji "$status")
    local title
    title=$(get_notification_title "$type")
    
    echo ""
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $emoji $title $status${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    
    if [[ -n "$message" ]]; then
        echo -e "  ${YELLOW}Message:${NC} $message"
    fi
    
    echo -e "  ${BLUE}Environment:${NC} ${environment:-N/A}"
    echo -e "  ${BLUE}Version:${NC} ${version:-N/A}"
    echo -e "  ${BLUE}Commit:${NC} ${GITHUB_SHA:-unknown}"
    echo -e "  ${BLUE}Branch/Tag:${NC} ${GITHUB_REF:-unknown}"
    echo -e "  ${BLUE}Triggered by:${NC} ${GITHUB_ACTOR:-unknown}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Main function
main() {
    parse_args "$@"
    
    if [[ -z "$NOTIFICATION_TYPE" ]]; then
        log_error "Notification type is required. Use -t or --type"
        exit 1
    fi
    
    if [[ -z "$STATUS" ]]; then
        log_error "Status is required. Use -s or --status"
        exit 1
    fi
    
    # Build payload
    local payload
    payload=$(build_payload "$NOTIFICATION_TYPE" "$STATUS" "$ENVIRONMENT" "$VERSION" "$MESSAGE")
    
    # Print to terminal
    print_terminal "$NOTIFICATION_TYPE" "$STATUS" "$ENVIRONMENT" "$VERSION" "$MESSAGE"
    
    # Send notifications
    send_slack "$payload"
    send_discord "$payload"
    
    # Create GitHub issue for failures
    create_github_issue "$NOTIFICATION_TYPE" "$STATUS" "$ENVIRONMENT" "$VERSION" "$MESSAGE"
    
    log_success "Notification process completed"
}

# Run main
main "$@"
