# Claude Unchained

Run Claude Code in an isolated Docker container with network firewall.

**Why use this?** Run Claude with full permissions in a completely isolated environment, allowing it to work efficiently without the dangers of damaging your system or leaking information to malicious websites.

- **Network firewall** - Only whitelisted domains accessible via iptables
- **Filesystem isolation** - Claude only sees the current project directory
- **Scoped GitHub access** - Fine-grained token limited to specific repositories
- **SSH key isolation** - Only repository-specific deploy keys mounted

## Quick Start

```bash
make install        # Build image and install wrapper
claude-unchained    # Launch isolated Claude in current project
```

## Setup

### 1. Create GitHub Token

[Create a fine-grained token](https://github.com/settings/tokens?type=beta) restricted to your repository. Claude Unchained cannot commit to any repository outside this scope.

- **Repository access**: Select only the repository you want Claude to access
- **Permissions**: Contents (Read/Write), Pull Requests (Read/Write), Issues (Read/Write)

This token is only used for `gh` CLI commands.

### 2. Create SSH Deploy Key

Generate a repository-specific deploy key:

```bash
REPO_NAME="my-repo-deploy"  # Change this to your repository name

ssh-keygen -t ed25519 -f ~/.ssh/$REPO_NAME -C "$REPO_NAME"
gh repo deploy-key add ~/.ssh/$REPO_NAME.pub --title "$REPO_NAME" --allow-write
git config core.sshCommand "ssh -i ~/.ssh/$REPO_NAME -o IdentitiesOnly=yes"
```

This deploy key allows git to push/pull only in the current repository. Only this key is mounted in the container - Claude cannot access other SSH keys.

### 3. Configure Project

**Sensitive data** (`.claude-unchained.config.local.json`, gitignored):

```json
{
  "github": {
    "token": "github_pat_YOUR_FINE_GRAINED_TOKEN"
  },
  "ssh": {
    "keyPath": "~/.ssh/my-repo-deploy"
  }
}
```

**Project configuration** (`.claude-unchained.config.json`, committable):

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

### 4. Protect Secrets in Claude Settings

Add to `~/.claude/settings.local.json` to prevent Claude from leaking your GitHub token to Anthropic servers:

```json
{
  "permissions": {
    "deny": [
      "Read(**/*.local.json)"
    ]
  }
}
```

You can now run `claude-unchained` in your project.

## What Does This Do?

- **Network firewall** - Only whitelisted domains accessible (Claude, GitHub, Docker Hub always allowed)
- **Filesystem isolation** - Claude only sees current project directory
- **Docker-in-Docker** - Run isolated Docker stacks with no port conflicts
- **SSH git push** - Seamless git operations with deploy keys
- **No prompts** - YOLO mode enabled automatically
- **Shared sessions** - Same Claude session across regular and isolated modes

## Configuration Files

Priority order (later overrides earlier):
1. `~/.claude-unchained.config.json` - Global base config
2. `~/.claude-unchained.config.local.json` - Global secrets
3. `./.claude-unchained.config.json` - Project config (committable)
4. `./.claude-unchained.config.local.json` - Project secrets (gitignored)

Use `.local.json` suffix for secrets - they're automatically gitignored.

## Default Whitelist

These domains are always accessible:
- **Claude**: `code.claude.com`, `api.anthropic.com`, `platform.claude.com`, `claude.ai`
- **GitHub**: `github.com`, `raw.githubusercontent.com`, `api.github.com`
- **Docker Hub**: `auth.docker.io`, `registry-1.docker.io`, `hub.docker.com`, etc.

## Requirements

- Docker with `--privileged` support
- Claude credentials (`~/.claude/.credentials.json`)
- `jq` (for parsing config files)

## Troubleshooting

**"Credentials not found":**

Run `claude login` on your host machine first. Credentials are shared between regular Claude and Claude Unchained.

**"Permission denied (publickey)" when pushing:**
- Ensure deploy key is added to GitHub with write access
- Check: `git config core.sshCommand`

## License

MIT
