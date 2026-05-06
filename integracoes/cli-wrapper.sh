#!/usr/bin/env bash
#
# IA Security Skill — CLI Wrapper
#
# Uso:
#   iass <ficheiro_ou_diretorio>            # auditoria standard
#   iass --quick <ficheiro>                  # triagem rápida (só Críticos/Altos)
#   iass --diff                              # auditar git diff (staged + unstaged)
#   iass --pr                                # auditar contra origin/main
#   iass --output report.md <ficheiro>       # gravar relatório em ficheiro
#
# Setup:
#   ln -s ~/.iass/integracoes/cli-wrapper.sh /usr/local/bin/iass
#   export ANTHROPIC_API_KEY="sk-ant-..."

set -euo pipefail

IASS_PATH="${IASS_PATH:-$HOME/.iass}"
IASS_MODEL="${IASS_MODEL:-claude-3-5-sonnet-20241022}"
MODE="standard"
TARGET=""
OUTPUT=""

# ── Parse args ──────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)   MODE="quick"; shift ;;
    --diff)    MODE="diff"; shift ;;
    --pr)      MODE="pr"; shift ;;
    --output)  OUTPUT="$2"; shift 2 ;;
    --help|-h)
      sed -n '3,12p' "$0" | sed 's/^# //;s/^#//'
      exit 0
      ;;
    *)         TARGET="$1"; shift ;;
  esac
done

# ── Validações ──────────────────────────────────────
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "❌ ANTHROPIC_API_KEY não definida"
  echo "   export ANTHROPIC_API_KEY=\"sk-ant-...\""
  exit 1
fi

if [[ ! -f "$IASS_PATH/PROMPT.md" ]]; then
  echo "❌ Skill não encontrada em $IASS_PATH"
  echo "   git clone https://github.com/antoniocostalopes/ia-security-skill $IASS_PATH"
  exit 1
fi

# ── Construir code payload ──────────────────────────
CODE=""
case "$MODE" in
  diff)
    CODE=$(git diff HEAD)
    [[ -z "$CODE" ]] && CODE=$(git diff --cached)
    [[ -z "$CODE" ]] && { echo "ℹ️  Sem diff para auditar"; exit 0; }
    ;;
  pr)
    BASE="${IASS_BASE_BRANCH:-origin/main}"
    CODE=$(git diff "$BASE"...HEAD)
    [[ -z "$CODE" ]] && { echo "ℹ️  Sem diff vs $BASE"; exit 0; }
    ;;
  quick|standard)
    if [[ -z "$TARGET" ]]; then
      echo "❌ Especifica ficheiro ou diretório"
      echo "   iass <path>"
      exit 1
    fi
    if [[ -f "$TARGET" ]]; then
      CODE=$'=== '"$TARGET"$' ===\n'$(cat "$TARGET")
    elif [[ -d "$TARGET" ]]; then
      while IFS= read -r f; do
        CODE+=$'\n\n=== '"$f"$' ===\n'
        CODE+=$(cat "$f")
      done < <(find "$TARGET" -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rb" -o -name "*.cs" -o -name "*.kt" -o -name "*.swift" -o -name "*.dart" -o -name "*.sol" \) -size -100k 2>/dev/null)
    else
      echo "❌ Path não encontrado: $TARGET"
      exit 1
    fi
    ;;
esac

# ── Construir prompt ────────────────────────────────
SKILL_PROMPT=$(cat "$IASS_PATH/PROMPT.md")

case "$MODE" in
  quick)
    USER_PROMPT="Triagem rápida do código abaixo. APENAS Críticos e Altos. Output curto: 1 linha por achado com [Severidade] ficheiro:linha — descrição + fix em 1 linha.\n\n$CODE"
    MAX_TOKENS=2048
    ;;
  *)
    USER_PROMPT="Aplica a IA Security Skill ao código abaixo. Workflow completo: recon → 24 análises universais → análise específica de linguagem/framework → attack chains (MIN 3) → self-review com confidence → relatório no formato fixo (Header, Score, Resumo Cliente, Resumo Técnico, Mapa de superfícies, Vetores com chains, Achados detalhados, Plano em 4 fases, Checklist final, Recomendações).\n\n$CODE"
    MAX_TOKENS=8192
    ;;
esac

# ── Chamar API ──────────────────────────────────────
echo "🛡️  IA Security Skill — analisando..." >&2

RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$(jq -n \
    --arg model "$IASS_MODEL" \
    --arg system "$SKILL_PROMPT" \
    --arg user "$USER_PROMPT" \
    --argjson max "$MAX_TOKENS" \
    '{
      model: $model,
      max_tokens: $max,
      system: $system,
      messages: [{role: "user", content: $user}]
    }')") || {
  echo "❌ Erro a chamar API"
  exit 1
}

# ── Extrair texto ───────────────────────────────────
TEXT=$(echo "$RESPONSE" | jq -r '.content[0].text' 2>/dev/null)

if [[ -z "$TEXT" ]] || [[ "$TEXT" == "null" ]]; then
  echo "❌ Resposta da API inválida:"
  echo "$RESPONSE" | jq .
  exit 1
fi

# ── Output ──────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  echo "$TEXT" > "$OUTPUT"
  echo "✓ Relatório gravado em $OUTPUT" >&2
else
  echo "$TEXT"
fi
