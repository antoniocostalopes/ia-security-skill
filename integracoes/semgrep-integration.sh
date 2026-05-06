#!/usr/bin/env bash
#
# IA Security Skill + Semgrep — análise híbrida
#
# Combina:
#   1. Semgrep (static analysis rápida com regras conhecidas)
#   2. IA Security Skill (análise contextual com IA)
#
# Resultado: recall máximo (Semgrep apanha clássicos) +
#            precision contextual (IA filtra false positives e adiciona business logic)
#
# Uso:
#   ~/.iass/integracoes/semgrep-integration.sh ./src
#
# Requer:
#   - semgrep (pip install semgrep, brew install semgrep, etc.)
#   - jq
#   - ANTHROPIC_API_KEY definida

set -euo pipefail

IASS_PATH="${IASS_PATH:-$HOME/.iass}"
IASS_MODEL="${IASS_MODEL:-claude-3-5-sonnet-20241022}"
TARGET="${1:-.}"

# ── Validações ──────────────────────────────────────
if ! command -v semgrep &> /dev/null; then
  echo "❌ Semgrep não instalado"
  echo "   pip install semgrep   # ou: brew install semgrep"
  exit 1
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "❌ ANTHROPIC_API_KEY não definida"
  exit 1
fi

if [[ ! -f "$IASS_PATH/PROMPT.md" ]]; then
  echo "❌ Skill não encontrada em $IASS_PATH"
  exit 1
fi

# ── Pass 1: Semgrep ─────────────────────────────────
echo "🔍 Pass 1/2 — Semgrep (regras conhecidas)..."
SEMGREP_OUTPUT=$(mktemp)

semgrep \
  --config=auto \
  --json \
  --quiet \
  --severity=ERROR \
  --severity=WARNING \
  "$TARGET" > "$SEMGREP_OUTPUT" 2>/dev/null || true

SEMGREP_FINDINGS=$(jq '.results | length' "$SEMGREP_OUTPUT")
echo "   → Semgrep encontrou $SEMGREP_FINDINGS achado(s)"

# ── Construir summary do Semgrep para passar à IA ───
SEMGREP_SUMMARY=$(jq -r '
  .results[] |
  "- [\(.extra.severity)] \(.path):\(.start.line) — \(.check_id): \(.extra.message[0:120])"
' "$SEMGREP_OUTPUT" | head -50)

# ── Pass 2: IA Security Skill com Semgrep como contexto ──
echo "🛡️  Pass 2/2 — IA Security Skill (análise contextual)..."

SKILL_PROMPT=$(cat "$IASS_PATH/PROMPT.md")

# Coletar código do target
CODE_PAYLOAD=""
if [[ -f "$TARGET" ]]; then
  CODE_PAYLOAD=$'=== '"$TARGET"$' ===\n'$(cat "$TARGET")
elif [[ -d "$TARGET" ]]; then
  while IFS= read -r f; do
    CODE_PAYLOAD+=$'\n\n=== '"$f"$' ===\n'
    CODE_PAYLOAD+=$(cat "$f")
  done < <(find "$TARGET" -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rb" -o -name "*.cs" -o -name "*.sol" \) -size -50k 2>/dev/null | head -30)
fi

USER_PROMPT="Aplica a IA Security Skill com workflow completo. Foi feita uma pré-análise com Semgrep que encontrou estes candidatos:

=== SEMGREP FINDINGS ===
$SEMGREP_SUMMARY

=== CÓDIGO ===
$CODE_PAYLOAD

Tarefa:
1. **Confirma ou descarta** cada finding do Semgrep (muitos podem ser falsos positivos — aplica analises/00-falsos-positivos-comuns.md)
2. **Adiciona findings** que Semgrep não detetou mas que são visíveis no código (business logic, race conditions, attack chains, vulnerabilidades de framework específico)
3. **Output**: relatório no formato fixo da skill com confidence per achado. Marca cada achado com [Semgrep+IA] (confirmado por ambos), [Semgrep apenas] (confidence reduzida), [IA apenas] (descoberto pela IA)."

RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$(jq -n \
    --arg model "$IASS_MODEL" \
    --arg system "$SKILL_PROMPT" \
    --arg user "$USER_PROMPT" \
    '{
      model: $model,
      max_tokens: 8192,
      system: $system,
      messages: [{role: "user", content: $user}]
    }')")

echo ""
echo "════════════════════════════════════════"
echo "  RELATÓRIO HÍBRIDO Semgrep + IA Skill"
echo "════════════════════════════════════════"
echo ""
echo "$RESPONSE" | jq -r '.content[0].text'

# ── Cleanup ─────────────────────────────────────────
rm -f "$SEMGREP_OUTPUT"

echo ""
echo "ℹ️  Análise híbrida completa. Combinação Semgrep + IA dá recall + precision máximas."
