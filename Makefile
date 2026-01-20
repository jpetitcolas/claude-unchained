.PHONY: install uninstall

# Install: build image and install wrapper to /usr/local/bin
install:
	@echo "Building claude-unchained Docker image..."
	@docker build -t claude-unchained .
	@echo "✓ Build complete!"
	@echo ""
	@echo "Installing claude-unchained to /usr/local/bin..."
	@if [ ! -f ~/.claude/.credentials.json ]; then \
		echo "⚠ Warning: Claude credentials not found at ~/.claude/.credentials.json"; \
		echo "Please run 'claude login' first if you haven't already."; \
		echo ""; \
	fi
	@sudo install -m 755 claude-unchained /usr/local/bin/claude-unchained
	@echo "✓ Installation complete!"
	@echo ""
	@echo "You can now run 'claude-unchained' from any directory."

# Uninstall: remove wrapper and optionally Docker volumes
uninstall:
	@echo "Uninstalling claude-unchained..."
	@sudo rm -f /usr/local/bin/claude-unchained
	@echo "✓ Removed from /usr/local/bin"
	@echo ""
	@read -p "Remove Docker volumes (session data)? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker volume rm claude-sessions claude-config 2>/dev/null || true; \
		echo "✓ Docker volumes removed"; \
	fi
	@echo ""
	@echo "Uninstall complete."
