#!/bin/bash
# Entrypoint script for Claude Code isolated container
# Sets up iptables firewall with domain whitelist before starting Claude

set -e

# Configuration constants
readonly DNS_PORT=53
readonly HTTP_PORT=80
readonly HTTPS_PORT=443
readonly SSH_PORT=22
readonly DOCKER_STARTUP_TIMEOUT=30
readonly DOCKER_POLL_INTERVAL=0.5
readonly FIREWALL_LOG_PREFIX="BLOCKED: "
readonly FIREWALL_LOG_LEVEL=4

# Hardcoded whitelist of allowed domains (minimal set)
WHITELISTED_DOMAINS=(
    # Claude Code
    "code.claude.com"
    "api.anthropic.com"
    "platform.claude.com"
    "claude.ai"
    # GitHub
    "github.com"
    "ssh.github.com"
    "raw.githubusercontent.com"
    "api.github.com"
    # Docker Hub - Official allowlist from https://docs.docker.com/desktop/setup/allow-list/
    "auth.docker.io"
    "login.docker.com"
    "auth.docker.com"
    "hub.docker.com"
    "registry-1.docker.io"
    "production.cloudflare.docker.com"
    "docker-images-prod.6aa30f8b08e16409b46e0173d6de2f56.r2.cloudflarestorage.com"
    "desktop.docker.com"
    "api.docker.com"
)

# Add extra domains from environment variable if set
add_extra_whitelisted_domains() {
    [ -z "$CLAUDE_UNCHAINED_WHITELIST_DOMAINS" ] && return 0

    local -a extra_domains=($CLAUDE_UNCHAINED_WHITELIST_DOMAINS)
    WHITELISTED_DOMAINS+=("${extra_domains[@]}")

    echo "Added ${#extra_domains[@]} extra domain(s) from CLAUDE_UNCHAINED_WHITELIST_DOMAINS"
}

# Check if domain requires SSH access (for git operations)
is_github_domain() {
    local domain="$1"
    [ "$domain" = "github.com" ] || [ "$domain" = "ssh.github.com" ]
}

# Add a single iptables rule for IPv4 or IPv6
add_iptables_rule() {
    local ip_version="$1"  # "4" or "6"
    local ip="$2"
    local port="$3"

    local cmd="iptables"
    [ "$ip_version" = "6" ] && cmd="ip6tables"

    $cmd -A OUTPUT -d "$ip" -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
}

# Allow HTTP, HTTPS, and optionally SSH for a given IP
allow_http_https_ssh_for_ip() {
    local ip_version="$1"
    local ip="$2"
    local domain="$3"

    add_iptables_rule "$ip_version" "$ip" "$HTTP_PORT"
    add_iptables_rule "$ip_version" "$ip" "$HTTPS_PORT"

    if is_github_domain "$domain"; then
        add_iptables_rule "$ip_version" "$ip" "$SSH_PORT"
    fi
}

# Process a batch of resolved IPs (either IPv4 or IPv6)
process_resolved_ips() {
    local domain="$1"
    local ip_version="$2"  # "4" or "6"
    local ips="$3"

    while IFS= read -r ip; do
        [ -n "$ip" ] && allow_http_https_ssh_for_ip "$ip_version" "$ip" "$domain"
    done <<< "$ips"
}

# Resolve domain to IPv4 addresses
resolve_domain_ipv4() {
    local domain="$1"
    dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true
}

# Resolve domain to IPv6 addresses
resolve_domain_ipv6() {
    local domain="$1"
    dig +short "$domain" AAAA 2>/dev/null | grep -E '^[0-9a-fA-F:]+$' || true
}

# Whitelist a single domain (resolve and add firewall rules)
whitelist_domain() {
    local domain="$1"
    echo "  Whitelisting: $domain"

    local ipv4s=$(resolve_domain_ipv4 "$domain")
    local ipv6s=$(resolve_domain_ipv6 "$domain")

    [ -n "$ipv4s" ] && process_resolved_ips "$domain" "4" "$ipv4s"
    [ -n "$ipv6s" ] && process_resolved_ips "$domain" "6" "$ipv6s"

    if [ -z "$ipv4s" ] && [ -z "$ipv6s" ]; then
        echo "  Warning: Could not resolve $domain"
    fi
}

# Initialize iptables firewall with default policies and base rules
initialize_firewall() {
    echo "Setting up network firewall..."

    # Flush existing rules
    iptables -F OUTPUT 2>/dev/null || true
    iptables -F INPUT 2>/dev/null || true

    # Set default policies
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP

    # Allow loopback
    iptables -A OUTPUT -o lo -j ACCEPT

    # Allow DNS (required for domain resolution)
    iptables -A OUTPUT -p udp --dport "$DNS_PORT" -j ACCEPT
    iptables -A OUTPUT -p tcp --dport "$DNS_PORT" -j ACCEPT

    # Allow established connections
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
}

# Start Docker daemon in background
start_docker_daemon() {
    echo "Starting Docker daemon..."
    dockerd --storage-driver=vfs > /var/log/docker.log 2>&1 &
    echo $!
}

# Wait for Docker daemon to become ready
wait_for_docker() {
    local timeout="$1"
    echo "Waiting for Docker to be ready..."

    if ! timeout "$timeout" bash -c "until docker info > /dev/null 2>&1; do sleep $DOCKER_POLL_INTERVAL; done"; then
        echo "ERROR: Docker daemon failed to start within ${timeout}s" >&2
        return 1
    fi

    echo "Docker daemon ready!"
}

# Set up SSH directory with correct permissions
setup_ssh_directory() {
    local ssh_key_path="$1"
    local ssh_dir="$2"

    [ ! -f "$ssh_key_path" ] && return 0

    mkdir -p "$ssh_dir"
    chown claude:claude "$ssh_dir" 2>/dev/null || true
    chmod 700 "$ssh_dir" 2>/dev/null || true
}

# Create symlink from host's .claude path to /home/claude/.claude
#
# Problem: Plugins installed on the host store absolute paths in installed_plugins.json
# (e.g., /home/jpetitcolas/.claude/plugins/...). These paths don't exist in the container
# where the home directory is /home/claude.
#
# Solution: Symlink the host's .claude directory to the container's .claude directory.
# We only symlink .claude (not the entire home directory) to respect least privilege.
setup_host_home_symlink() {
    [ -z "$HOST_HOME" ] && return 0
    [ "$HOST_HOME" = "/home/claude" ] && return 0

    local host_claude_dir="$HOST_HOME/.claude"
    echo "Creating symlink: $host_claude_dir -> /home/claude/.claude"
    mkdir -p "$HOST_HOME" 2>/dev/null || true
    ln -sf /home/claude/.claude "$host_claude_dir" 2>/dev/null || true
}

# Main execution
add_extra_whitelisted_domains

initialize_firewall

# Resolve domains and allow HTTP/HTTPS (and SSH for GitHub) to their IPs
for domain in "${WHITELISTED_DOMAINS[@]}"; do
    whitelist_domain "$domain"
done

# Log dropped packets (for debugging)
iptables -A OUTPUT -j LOG --log-prefix "$FIREWALL_LOG_PREFIX" --log-level "$FIREWALL_LOG_LEVEL"

echo "Firewall configured successfully!"
echo ""

# Ensure .claude directory is writable by claude user
chown -R claude:claude /home/claude/.claude 2>/dev/null || true

# Fix SSH permissions (SSH requires strict permissions)
# Only set up if SSH key exists
# Note: Files are mounted read-only, so we only create the directory
setup_ssh_directory "/home/claude/.ssh/id_ed25519" "/home/claude/.ssh"

# Create symlink from host home path to allow plugin paths to resolve
setup_host_home_symlink

# Start Docker daemon in background for Docker-in-Docker support
# Use vfs storage driver to avoid overlayfs whiteout issues in WSL2
DOCKER_PID=$(start_docker_daemon)
wait_for_docker "$DOCKER_STARTUP_TIMEOUT" || exit 1

echo ""

# Switch to claude user and execute the command passed to the container (Claude Code)
# We need to run as root for iptables setup and Docker daemon, then drop to claude user
# Using gosu instead of su for better signal handling and proper stdin/stdout/stderr
# Set HOME explicitly since gosu doesn't update environment variables
# Working directory is set by docker -w flag
exec gosu claude env HOME=/home/claude "$@"
