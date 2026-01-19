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

Configure via JSON files. Use `.local.json` suffix for secrets (gitignored).

**Config files** (priority order, later overrides earlier):
1. `~/.claude-unchained.config.json` - Global base config
2. `~/.claude-unchained.config.local.json` - Global secrets
3. `./.claude-unchained.config.json` - Project config (committable)
4. `./.claude-unchained.config.local.json` - Project secrets (gitignored)

**Default whitelist** (always enabled):
- **Claude**: `code.claude.com`, `api.anthropic.com`, `platform.claude.com`, `claude.ai`
- **GitHub**: `github.com`, `raw.githubusercontent.com`, `api.github.com`
- **Docker Hub**: `auth.docker.io`, `login.docker.com`, `hub.docker.com`, `registry-1.docker.io`, etc.

**Example: `.claude-unchained.config.json` (committable):**
```json
{
  "networking": {
    "whitelisted_domains": [
      "npmjs.com",
      "registry.npmjs.org"
    ]
  }
}
```

**Example: `.claude-unchained.config.local.json` (secrets, gitignored):**
```json
{
  "ssh": {
    "keyPath": "~/.ssh/my-repo-deploy"
  },
  "github": {
    "token": "github_pat_YOUR_FINE_GRAINED_TOKEN"
  }
}
```

**Protect secrets:** Add deny rules to `~/.claude/settings.local.json`:
```json
{
  "permissions": {
    "deny": [
      "Read(.env)",
      "Read(**/*.key)",
      "Read(**/*.local.json)"
    ]
  }
}
```

## GitHub CLI Support

The `gh` CLI is available in the container. For security, use a repo-specific fine-grained token instead of your global OAuth token.

**Setup:**
```bash
# 1. Create fine-grained token at https://github.com/settings/tokens?type=beta
#    - Select only the repository you want to grant access to
#    - Grant permissions: Contents (Read/Write), Pull Requests (Read/Write), Issues (Read/Write)

# 2. Add github token to .claude-unchained.config.local.json (gitignored)
{
  "github": {
    "token": "github_pat_YOUR_FINE_GRAINED_TOKEN"
  }
}
```

**Note:** The fine-grained token is ONLY used for `gh` API commands (like `gh pr list`, `gh issue create`). Git operations (push/pull) still use the SSH deploy key.

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

# 4. Add SSH key path to .claude-unchained.config.local.json (gitignored)
echo '{
  "ssh": {
    "keyPath": "~/.ssh/my-repo-deploy"
  }
}' > .claude-unchained.config.local.json
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
