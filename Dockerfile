# Claude Code Isolated Container
# Based on Anthropic's DevContainer reference
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages including iptables for firewall and gosu for user switching
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
    gosu \
    jq \
    make \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 (required for Claude Code)
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm globally
RUN npm install -g pnpm

# Install Docker Engine (full daemon) and Docker Compose for Docker-in-Docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install Playwright/Chromium system dependencies
# These libraries are required for running Chromium browser in headless mode
RUN apt-get update && apt-get install -y \
    fonts-liberation \
    libasound2t64 \
    libatk-bridge2.0-0t64 \
    libatk1.0-0t64 \
    libatspi2.0-0t64 \
    libcairo2 \
    libcups2t64 \
    libdbus-1-3 \
    libdrm2 \
    libegl1 \
    libgbm1 \
    libglib2.0-0t64 \
    libgtk-3-0t64 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code using official installer (installs latest version as root)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    # Copy claude binary to /usr/local/bin so it's accessible to all users
    cp /root/.local/bin/claude /usr/local/bin/claude && \
    cp -r /root/.local/share/claude /usr/local/share/claude && \
    chmod 755 /usr/local/bin/claude

# Pre-install Playwright Chrome browser (before firewall is active)
# This downloads ~280MB and avoids runtime network dependency
# Note: We install as root but will chown to claude user later
RUN export PLAYWRIGHT_BROWSERS_PATH=/ms-playwright && \
    npx --yes @playwright/test@latest install chrome

# Copy entrypoint script for firewall setup
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create non-root user matching typical host UID (or use existing ubuntu user)
# Ubuntu 24.04 creates 'ubuntu' user with UID 1000 by default
# Add claude user to docker group for Docker socket access
RUN if id 1000 > /dev/null 2>&1; then \
        usermod -l claude -d /home/claude $(id -nu 1000) && \
        groupmod -n claude $(id -gn 1000) || true; \
    else \
        useradd -m -u 1000 -s /bin/bash claude; \
    fi && \
    groupadd -f docker && \
    usermod -aG docker claude && \
    echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Don't switch to claude user yet - entrypoint needs root for iptables
# The entrypoint will switch to claude after setting up firewall

# Add both root and claude user bin paths
ENV PATH="/home/claude/.local/bin:/root/.local/bin:${PATH}"

# Set Playwright to use pre-installed browsers
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Set up Claude Code config directory and .local/bin for claude user
# Also transfer ownership of Playwright browsers to claude user
RUN mkdir -p /home/claude/.claude /home/claude/.local/bin /home/claude/.local/share && \
    ln -s /usr/local/bin/claude /home/claude/.local/bin/claude && \
    ln -s /usr/local/share/claude /home/claude/.local/share/claude && \
    chown -R claude:claude /home/claude /ms-playwright

WORKDIR /workspace

# Set entrypoint to configure firewall before running Claude
ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "/usr/local/bin/claude"]
CMD []
