# Claude Unchained

Run Claude Code in an isolated Docker container with network firewall.

**Why use this?** Run Claude with full permissions in a completely isolated environment, allowing it to work efficiently without the dangers of damaging your system or leaking information to malicious websites.

- **Domain-based firewall** - SNI proxy filters HTTPS traffic by domain name (not IP)
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

- **SNI proxy firewall** - All HTTPS traffic goes through nginx SNI proxy that filters by domain name
- **Filesystem isolation** - Claude only sees current project directory
- **Docker-in-Docker** - Run isolated Docker stacks with no port conflicts
- **SSH git push** - Seamless git operations with deploy keys
- **No prompts** - YOLO mode enabled automatically
- **Shared sessions** - Same Claude session across regular and isolated modes

## How the Firewall Works

Claude Unchained uses an **SNI (Server Name Indication) proxy** instead of IP-based whitelisting:

1. All outbound HTTPS traffic is redirected to a local nginx proxy
2. The proxy inspects the TLS handshake's SNI field (the domain name)
3. If the domain is whitelisted, traffic is forwarded; otherwise, blocked
4. TLS certificate validation still happens, ensuring you're talking to the real server

**Why SNI proxy instead of IP whitelisting?**

- **No IP rotation issues** - CDNs like Cloudflare change IPs frequently, breaking IP-based rules
- **Reliable** - Domain names don't change; IPs do
- **Transparent** - No certificate tampering, just domain filtering

**Security model:**

- Claude cannot bypass this (uses standard TLS)
- A developer who spoofs SNI AND disables cert validation is intentionally circumventing security

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

**Connection refused or blocked:**
- Check if the domain is in your whitelist config
- View SNI proxy logs: `docker exec <container> cat /var/log/nginx/sni-proxy.log`
- The log shows which domains were allowed/blocked

**MCP server not connecting:**
- Add the MCP server's domain to your config (e.g., `mcp.linear.app` for Linear)
- Restart the container to apply changes

## License

MIT
