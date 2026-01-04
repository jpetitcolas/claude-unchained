#!/bin/bash
# Entrypoint script for Claude Code isolated container
# Sets up iptables firewall with domain whitelist before starting Claude

set -e

# Hardcoded whitelist of allowed domains
WHITELISTED_DOMAINS=(
    "code.claude.com"
    "api.anthropic.com"
    "platform.claude.com"
    "claude.ai"
    "github.com"
    "raw.githubusercontent.com"
    "api.github.com"
    "npmjs.com"
    "registry.npmjs.org"
    "pypi.org"
    "files.pythonhosted.org"
)

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
echo "Whitelisted domains:"
printf '  - %s\n' "${WHITELISTED_DOMAINS[@]}"
echo ""

# Switch to claude user and execute the command passed to the container (Claude Code)
# We need to run as root for iptables setup, then drop to claude user
cd /workspace
exec su claude -c "$*"
