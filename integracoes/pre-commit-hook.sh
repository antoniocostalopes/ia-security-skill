#!/usr/bin/env bash
#
# Pre-commit hook — bloqueia commits com vulnerabilidades CRÍTICAS detetadas
# pela IA Security Skill.
#
# Setup:
#   ln -s ~/.iass/integracoes/pre-commit-hook.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Variáveis:
#   ANTHROPIC_API_KEY  (obrigatório)
#   IASS_PATH          (default: ~/.iass)
#   IASS_MODEL         (default: claude-3-5-sonnet-20241022)
#   IASS_BLOCK_ON      (default: critical — bloqueia se Crítico encontrado)
#                      (alternativas: critical_high, none — só warn)

set -euo pipefail

IASS_PATH="${IASS_PATH:-$HOME/.iass}"
IASS_MODEL="${IASS_MODEL:-claude-3-5-sonnet-20241022}"
IASS_BLOCK_ON="${IASS_BLOCK_ON:-critical}"

# ── Validações ──────────────────────────────────────
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "⚠️  ANTHROPIC_API_KEY não definida — skip security audit"
  exit 0
fi

if [[ ! -f "$IASS_PATH/PROMPT-COMPACTO.md" ]]; then
  echo "⚠️  Skill não encontrada em $IASS_PATH — skip security audit"
  echo "    git clone https://github.com/antoniocostalopes/ia-security-skill $IASS_PATH"
  exit 0
fi

# ── Detetar ficheiros staged ────────────────────────
STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(php|js|jsx|ts|tsx|py|java|go|rb|cs|kt|swift|dart|sol)$' || true)

if [[ -z "$STAGED" ]]; then
  exit 0  # nada relevante para auditar
fi

echo "🛡️  IA Security Skill — auditando $(echo "$STAGED" | wc -l) ficheiro(s)..."

# ── Construir payload ───────────────────────────────
SKILL_PROMPT=$(cat "$IASS_PATH/PROMPT-COMPACTO.md")
CODE_PAYLOAD=""
for f in $STAGED; do
  if [[ -f "$f" ]]; then
    CODE_PAYLOAD+=$'\n\n=== '"$f"$' ===\n'
    CODE_PAYLOAD+=$(git diff --cached "$f")
  fi
done

USER_PROMPT="Audita as mudanças staged abaixo. **Triagem rápida** — só Críticos e Altos. Output em JSON: { \"findings\": [ { \"severity\": \"Crítico|Alto\", \"file\": \"...\", \"line\": N, \"category\": \"...\", \"description\": \"...\", \"fix\": \"...\" } ] }. Se zero achados Críticos/Altos, devolve { \"findings\": [] }.

$CODE_PAYLOAD"

# ── Chamar API Anthropic ────────────────────────────
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
      max_tokens: 4096,
      system: $system,
      messages: [{role: "user", content: $user}]
    }')") || {
  echo "⚠️  Erro a chamar API — skip audit"
  exit 0
}

# ── Extrair findings ────────────────────────────────
FINDINGS_TEXT=$(echo "$RESPONSE" | jq -r '.content[0].text' 2>/dev/null || echo "{}")
FINDINGS_JSON=$(echo "$FINDINGS_TEXT" | grep -oE '\{[^}]*"findings"[^}]*\}.*\}' | head -1 || echo '{"findings":[]}')

CRITICAL_COUNT=$(echo "$FINDINGS_JSON" | jq '[.findings[] | select(.severity == "Crítico")] | length' 2>/dev/null || echo "0")
HIGH_COUNT=$(echo "$FINDINGS_JSON" | jq '[.findings[] | select(.severity == "Alto")] | length' 2>/dev/null || echo "0")

# ── Mostrar resultado ───────────────────────────────
echo ""
if [[ "$CRITICAL_COUNT" -gt 0 ]] || [[ "$HIGH_COUNT" -gt 0 ]]; then
  echo "🚨 IA Security Skill encontrou:"
  echo "   • Crítico: $CRITICAL_COUNT"
  echo "   • Alto: $HIGH_COUNT"
  echo ""
  echo "$FINDINGS_JSON" | jq -r '.findings[] | "   [\(.severity)] \(.file):\(.line) — \(.category)\n      \(.description)\n      💡 \(.fix)\n"'
  echo ""

  case "$IASS_BLOCK_ON" in
    critical)
      if [[ "$CRITICAL_COUNT" -gt 0 ]]; then
        echo "❌ Commit bloqueado por $CRITICAL_COUNT achado(s) Crítico(s)."
        echo "   Para forçar (NÃO recomendado): git commit --no-verify"
        exit 1
      fi
      ;;
    critical_high)
      if [[ "$CRITICAL_COUNT" -gt 0 ]] || [[ "$HIGH_COUNT" -gt 0 ]]; then
        echo "❌ Commit bloqueado por $CRITICAL_COUNT Crítico(s) + $HIGH_COUNT Alto(s)."
        exit 1
      fi
      ;;
    none)
      echo "⚠️  Mode 'none' — commit permitido apesar dos achados."
      ;;
  esac
else
  echo "✓ IA Security Skill — sem vulnerabilidades Críticas/Altas detetadas."
fi

exit 0
