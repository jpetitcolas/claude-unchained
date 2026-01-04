# Claude Code Isolated Container

Run Claude Code in a secure Docker container with filesystem and network isolation.

## What is this?

A containerized Claude Code setup that:

- **Limits filesystem access** to the current project directory only
- **Restricts network access** to approved domains via iptables firewall
- **Isolates credentials and configuration** from the host system
- **Runs with full permissions** within the isolated environment (autonomous operation)

Perfect for letting AI assistants work freely within a controlled, throwaway sandbox.

## Quick Start

### 1. Install

```bash
make install
```

This will build the Docker image and install the `claude-isolated` command to `/usr/local/bin`.

### 2. Run from Any Directory

```bash
cd /path/to/your/project
claude-isolated
```

That's it! Claude Code will run in an isolated container with access only to the current directory.

### First-Time Setup

You need Claude Code credentials on your host system:

```bash
claude login
```

The containerized version will reuse these credentials (read-only).

## What's Allowed

### Network Access (Hardcoded Whitelist)

**Anthropic Services:**
- code.claude.com, api.anthropic.com, platform.claude.com, claude.ai

**Development Tools:**
- github.com, raw.githubusercontent.com, api.github.com
- npmjs.com, registry.npmjs.org
- pypi.org, files.pythonhosted.org

To modify: Edit `WHITELISTED_DOMAINS` in `entrypoint.sh` and rebuild.

### Filesystem Access

- ✅ Current workspace (read/write)
- ✅ Credentials from `~/.claude/.credentials.json` (read-only)
- ✅ Isolated config in Docker volumes
- ❌ Host system files
- ❌ Other project directories

## Architecture

```
┌──────────────────────────────────────────┐
│  Docker Container (Ubuntu 24.04 LTS)     │
│  ┌────────────────────────────────────┐  │
│  │ iptables Firewall (runs as root)  │  │
│  │ ├─ Allow: whitelisted domains     │  │
│  │ └─ Block: everything else         │  │
│  ├────────────────────────────────────┤  │
│  │ Claude Code 2.0.76 (user: claude) │  │
│  │ └─ Access: /workspace only        │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
           │                    │
      (mounted)            (mounted)
           │                    │
     Current Dir         ~/.claude/.credentials.json
     (read-write)             (read-only)
```

## Requirements

- Docker with CAP_NET_ADMIN capability support
- Existing Claude Code credentials on host (`~/.claude/.credentials.json`)

## Troubleshooting

**"Credentials not found":**
```bash
claude login
```

**Uninstall:**
```bash
make uninstall  # Prompts to remove Docker volumes
```
