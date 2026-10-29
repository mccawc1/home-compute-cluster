#!/usr/bin/env bash
# 30-agents.sh : install the agent harnesses and a tmux helper so an agent
# keeps running after you disconnect. Claude does the heavy thinking in the
# cloud; this machine just hosts the harness 24/7.
set -euo pipefail

echo "== Claude Code (native installer, no Node needed)"
# VERIFY: install command current as of 2026-10. Docs: https://docs.claude.com/en/docs/claude-code
curl -4 -fsSL https://claude.ai/install.sh | bash

echo "== OpenCode (optional open-source harness, works with Ollama)"
curl -4 -fsSL https://opencode.ai/install | bash || echo "OpenCode install failed, skipping"

echo "== tmux helper: 'agent' opens or re-attaches a persistent session"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/agent" <<'SH'
#!/usr/bin/env bash
# agent [name]  : attach to a persistent tmux session (default "main").
# Detach with Ctrl-b then d. The session keeps running after you log out.
name="${1:-main}"
if tmux has-session -t "$name" 2>/dev/null; then
  exec tmux attach -t "$name"
else
  exec tmux new -s "$name"
fi
SH
chmod +x "$HOME/.local/bin/agent"

grep -q '.local/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

echo
echo "Done. Log out and back in, then:"
echo "   agent            # persistent shell"
echo "   claude           # sign in once with your Anthropic account"
echo "Detach with Ctrl-b d; the agent keeps working. 'agent' again re-attaches."
