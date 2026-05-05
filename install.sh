#!/usr/bin/env bash
# Instalador da skill de segurança para Claude Code.
# Uso:
#   curl -sSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | bash
# ou:
#   ./install.sh [--project]
#
# Por defeito instala em ~/.claude/skills/seguranca (global, todos os projetos).
# Com --project instala em ./.claude/skills/seguranca (só este projeto).

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/antoniocostalopes/ia-security-skill}"
SKILL_NAME="seguranca"
MODE="${1:-}"

if [[ "$MODE" == "--project" ]]; then
    DEST="./.claude/skills/${SKILL_NAME}"
else
    DEST="${HOME}/.claude/skills/${SKILL_NAME}"
fi

echo "→ Destino: $DEST"

mkdir -p "$(dirname "$DEST")"

if [[ -d "$DEST" ]]; then
    echo "⚠  Skill já instalada. Atualizando..."
    cd "$DEST" && git pull --ff-only
else
    git clone --depth=1 "$REPO_URL" "$DEST"
fi

echo ""
echo "✓ Skill de segurança instalada em $DEST"
echo ""
echo "Para usar:"
echo "  - Claude Code: dentro de qualquer projeto, pede 'audita este projeto'"
echo "  - Outras IAs: ver INSTALL.md"
