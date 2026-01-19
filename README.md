# Claude Unchained

Run Claude Code in an isolated Docker container with network firewall.

## What is this?

A containerized Claude Code setup that:
- **Blocks network access** except whitelisted domains (iptables firewall)
- **Restricts filesystem** to current project only
- **Docker-in-Docker support** - isolated Docker stacks with no port conflicts
- **No permission prompts** - YOLO mode enabled automatically
- **Shares sessions** - same session data across regular and isolated Claude

## Quick Start

```bash
claude login    # First time only - login on host
make install    # Build image and install claude-isolated wrapper
```

## Run

```bash
cd /your/project
claude-isolated
```

## Configuration

**Whitelist domains:** By default, only these domains are whitelisted:
- **Claude**: `code.claude.com`, `api.anthropic.com`, `platform.claude.com`, `claude.ai`
- **GitHub**: `github.com`, `raw.githubusercontent.com`, `api.github.com`
- **Docker Hub**: `auth.docker.io`, `login.docker.com`, `hub.docker.com`, `registry-1.docker.io`, etc.

Add extra domains at runtime with `CLAUDE_UNCHAINED_WHITELIST_DOMAINS`:
```bash
# Temporary (one session):
export CLAUDE_UNCHAINED_WHITELIST_DOMAINS="npmjs.com registry.npmjs.org pypi.org files.pythonhosted.org"
claude-isolated

# Permanent (in ~/.bashrc or ~/.zshrc):
export CLAUDE_UNCHAINED_WHITELIST_DOMAINS="npmjs.com registry.npmjs.org pypi.org files.pythonhosted.org"
```

**Mount extra directories:** Set `CLAUDE_UNCHAINED_EXTRA_MOUNTS` for plugins or other paths:
```bash
# In ~/.bashrc or ~/.zshrc:
export CLAUDE_UNCHAINED_EXTRA_MOUNTS="$HOME/dev/claude-config:$HOME/dev/claude-config:ro"
```

**Protect files:** Add deny rules to `~/.claude/settings.local.json`:
```json
{
  "permissions": {
    "deny": ["Read(.env)", "Read(**/*.key)"]
  }
}
```

## Requirements

- Docker with `--privileged` support
- Claude credentials (`~/.claude/.credentials.json`)

## Troubleshooting

**"Credentials not found":**
```bash
claude login    # Login on host first
```
