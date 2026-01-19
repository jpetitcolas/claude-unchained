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

**Whitelist domains:** Edit `WHITELISTED_DOMAINS` in `entrypoint.sh:8`, then `make install`

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
