# Claude Unchained

Run Claude Code in an isolated Docker container with network firewall.

## What is this?

A containerized Claude Code setup that:
- **Blocks network access** except whitelisted domains (iptables firewall)
- **Restricts filesystem** to current project only
- **Docker-in-Docker support** - isolated Docker stacks with no port conflicts
- **SSH git push support** - your SSH keys and git config work seamlessly
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

Configure via `.claude-unchained.config.json` (project-specific) or `~/.claude-unchained.config.json` (global).

**Default whitelist** (always enabled):
- **Claude**: `code.claude.com`, `api.anthropic.com`, `platform.claude.com`, `claude.ai`
- **GitHub**: `github.com`, `raw.githubusercontent.com`, `api.github.com`
- **Docker Hub**: `auth.docker.io`, `login.docker.com`, `hub.docker.com`, `registry-1.docker.io`, etc.

**Example config:**
```json
{
  "networking": {
    "whitelisted_domains": [
      "npmjs.com",
      "registry.npmjs.org",
      "pypi.org",
      "files.pythonhosted.org"
    ]
  },
  "ssh": {
    "keyPath": "~/.ssh/my-repo-deploy"
  },
  "volumes": [
    {
      "host": "~/dev/claude-config",
      "container": "~/dev/claude-config",
      "readonly": true
    }
  ]
}
```

**Config priority:** Local config > Global config

**Protect files:** Add deny rules to `~/.claude/settings.local.json`:
```json
{
  "permissions": {
    "deny": ["Read(.env)", "Read(**/*.key)"]
  }
}
```

## Git Push Support

For security, use repository-specific deploy keys instead of your main SSH key.

**Setup:**
```bash
# 1. Generate a deploy key for this repo
ssh-keygen -t ed25519 -f ~/.ssh/my-repo-deploy -C "my-repo-deploy"

# 2. Add to GitHub as a deploy key with write access
gh repo deploy-key add ~/.ssh/my-repo-deploy.pub --title "my-repo-deploy" --allow-write

# 3. Configure git to use this key for this repo only
git config core.sshCommand "ssh -i ~/.ssh/my-repo-deploy -o IdentitiesOnly=yes"

# 4. Add SSH key path to .claude-unchained.config.json
echo '{
  "ssh": {
    "keyPath": "~/.ssh/my-repo-deploy"
  }
}' > .claude-unchained.config.json
```

Only the specified deploy key is mounted in the container, preventing access to other repos.

## Requirements

- Docker with `--privileged` support
- Claude credentials (`~/.claude/.credentials.json`)
- `jq` (for parsing config files)

## Troubleshooting

**"Credentials not found":**
```bash
claude login    # Login on host first
```

**"Permission denied (publickey)" when pushing:**
- Ensure deploy key is added to GitHub with write access
- Check git config: `git config core.sshCommand`
