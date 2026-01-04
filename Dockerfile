# Claude Code Isolated Container
# Based on Anthropic's DevContainer reference
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages including iptables for firewall
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    gnupg \
    ripgrep \
    sudo \
    iptables \
    iproute2 \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 (required for Claude Code)
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Claude Code using official installer (installs latest version as root)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    # Copy claude binary to /usr/local/bin so it's accessible to all users
    cp /root/.local/bin/claude /usr/local/bin/claude && \
    cp -r /root/.local/share/claude /usr/local/share/claude && \
    chmod 755 /usr/local/bin/claude

# Copy entrypoint script for firewall setup
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create non-root user matching typical host UID (or use existing ubuntu user)
# Ubuntu 24.04 creates 'ubuntu' user with UID 1000 by default
RUN if id 1000 > /dev/null 2>&1; then \
        usermod -l claude -d /home/claude $(id -nu 1000) && \
        groupmod -n claude $(id -gn 1000) || true; \
    else \
        useradd -m -u 1000 -s /bin/bash claude; \
    fi && \
    echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Don't switch to claude user yet - entrypoint needs root for iptables
# The entrypoint will switch to claude after setting up firewall

# The installer puts claude in /root/.local/bin, make it accessible to claude user
ENV PATH="/root/.local/bin:${PATH}"

# Set up Claude Code config directory
RUN mkdir -p /home/claude/.claude

WORKDIR /workspace

# Set entrypoint to configure firewall before running Claude
ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "/usr/local/bin/claude"]
CMD ["--help"]
