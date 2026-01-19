#!/bin/bash
# Entrypoint script for Claude Code isolated container
# Sets up iptables firewall with domain whitelist before starting Claude

set -e

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
if [ -n "$CLAUDE_UNCHAINED_WHITELIST_DOMAINS" ]; then
    EXTRA_COUNT=0
    for domain in $CLAUDE_UNCHAINED_WHITELIST_DOMAINS; do
        WHITELISTED_DOMAINS+=("$domain")
        EXTRA_COUNT=$((EXTRA_COUNT + 1))
    done
    echo "Added $EXTRA_COUNT extra domain(s) from CLAUDE_UNCHAINED_WHITELIST_DOMAINS"
fi

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
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow established connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Resolve domains and allow HTTP/HTTPS to their IPs
for domain in "${WHITELISTED_DOMAINS[@]}"; do
    echo "  Whitelisting: $domain"

    # Resolve IPv4 addresses (A records)
    IPV4S=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)

    if [ -n "$IPV4S" ]; then
        while IFS= read -r ip; do
            if [ -n "$ip" ]; then
                # Allow HTTP and HTTPS to this IPv4
                iptables -A OUTPUT -d "$ip" -p tcp --dport 80 -j ACCEPT
                iptables -A OUTPUT -d "$ip" -p tcp --dport 443 -j ACCEPT
                # Allow SSH for GitHub (git push/pull over SSH)
                if [ "$domain" = "github.com" ] || [ "$domain" = "ssh.github.com" ]; then
                    iptables -A OUTPUT -d "$ip" -p tcp --dport 22 -j ACCEPT
                fi
            fi
        done <<< "$IPV4S"
    fi

    # Resolve IPv6 addresses (AAAA records)
    IPV6S=$(dig +short "$domain" AAAA 2>/dev/null | grep -E '^[0-9a-fA-F:]+$' || true)

    if [ -n "$IPV6S" ]; then
        while IFS= read -r ip; do
            if [ -n "$ip" ]; then
                # Allow HTTP and HTTPS to this IPv6
                ip6tables -A OUTPUT -d "$ip" -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
                ip6tables -A OUTPUT -d "$ip" -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
                # Allow SSH for GitHub (git push/pull over SSH)
                if [ "$domain" = "github.com" ] || [ "$domain" = "ssh.github.com" ]; then
                    ip6tables -A OUTPUT -d "$ip" -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
                fi
            fi
        done <<< "$IPV6S"
    fi

    if [ -z "$IPV4S" ] && [ -z "$IPV6S" ]; then
        echo "  Warning: Could not resolve $domain"
    fi
done

# Log dropped packets (for debugging)
iptables -A OUTPUT -j LOG --log-prefix "BLOCKED: " --log-level 4

echo "Firewall configured successfully!"
echo ""

# Ensure .claude directory is writable by claude user
chown -R claude:claude /home/claude/.claude 2>/dev/null || true

# Fix SSH permissions (SSH requires strict permissions)
# Only set up if SSH key exists
# Note: Files are mounted read-only, so we only create the directory
if [ -f /home/claude/.ssh/id_ed25519 ]; then
    mkdir -p /home/claude/.ssh
    chown claude:claude /home/claude/.ssh 2>/dev/null || true
    chmod 700 /home/claude/.ssh 2>/dev/null || true
fi

# Start Docker daemon in background for Docker-in-Docker support
# Use vfs storage driver to avoid overlayfs whiteout issues in WSL2
echo "Starting Docker daemon..."
dockerd --storage-driver=vfs > /var/log/docker.log 2>&1 &
DOCKER_PID=$!

# Wait for Docker to be ready
echo "Waiting for Docker to be ready..."
timeout 30 bash -c 'until docker info > /dev/null 2>&1; do sleep 0.5; done' || {
    echo "ERROR: Docker daemon failed to start"
    exit 1
}
echo "Docker daemon ready!"
echo ""

# Switch to claude user and execute the command passed to the container (Claude Code)
# We need to run as root for iptables setup and Docker daemon, then drop to claude user
# Using gosu instead of su for better signal handling and proper stdin/stdout/stderr
# Set HOME explicitly since gosu doesn't update environment variables
# Working directory is set by docker -w flag
exec gosu claude env HOME=/home/claude "$@"
