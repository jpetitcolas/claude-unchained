# Claude Code Isolated Container

Run Claude Code in a secure Docker container with filesystem and network isolation.

## What is this?

A containerized Claude Code setup that:

- **Limits filesystem access** to the current project directory only
- **Restricts network access** to approved domains via iptables firewall
- **Shares authentication and settings** from host `~/.claude` directory
- **Runs with full permissions** within the isolated environment (autonomous operation)
- **Maintains separate sessions per project** (works like local `claude`)

Perfect for letting AI assistants work freely within a controlled, network-restricted sandbox.

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

The containerized version shares your `~/.claude` directory (auth, theme, config, and sessions).

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

- ✅ Current workspace (read/write, mounted at actual host path)
- ✅ Host `~/.claude` directory (read/write, for auth, config, and sessions)
- ❌ All other host system files
- ❌ Other project directories

**Session Isolation:** Sessions are automatically filtered by workspace path (just like local `claude`), so each project maintains its own session history.

## Architecture

```
┌───────────────────────────────────────────────────┐
│  Docker Container (Ubuntu 24.04 LTS)              │
│  ┌─────────────────────────────────────────────┐  │
│  │ iptables Firewall (runs as root)            │  │
│  │ ├─ Allow: whitelisted domains               │  │
│  │ └─ Block: everything else                   │  │
│  ├─────────────────────────────────────────────┤  │
│  │ Claude Code 2.0.76 (user: claude)           │  │
│  │ ├─ Working dir: /path/to/project            │  │
│  │ └─ Config: /home/claude/.claude             │  │
│  └─────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────┘
              │                       │
         (mounted)               (mounted)
              │                       │
      /path/to/project          ~/.claude
       (read-write)            (read-write)
     [current workspace]    [auth, config, sessions]
```

**Key Design Choices:**
- Workspace mounted at same path as host for session continuity
- Sessions filtered by workspace path (automatic per-project isolation)
- Network restricted to essential domains only

## Requirements

- Docker with CAP_NET_ADMIN capability support
- Existing Claude Code authentication on host (`~/.claude/`)

## Troubleshooting

**"Credentials not found" or setup wizard appears:**
```bash
# Login with regular claude on host first
claude login
```

**Uninstall:**
```bash
make uninstall
```

**Rebuild after changes:**
```bash
make install  # Rebuilds image and reinstalls script
```
