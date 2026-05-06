# Relatório — Templates de Output

> Estes 3 ficheiros definem o **formato fixo** do output que a skill devolve. Ler na ordem indicada antes de gerar relatório.

## Loading

| Ficheiro | Quando carregar | Para quê |
|---|---|---|
| `score-blindagem.md` | **Fase 6** do workflow (antes de calcular score) | Fórmula de score 0-100 e mapeamento para nível de blindagem (Crítico → Blindado) |
| `template.md` | **Fase 7** do workflow (antes de escrever relatório) | Estrutura literal do output: headers, ordem, formatação |
| `checklist-producao.md` | **Fase 7** (anexar no fim) | Checklist 80+ itens pré-deploy a copiar para o relatório |

## Ordem de uso

1. Aplicar fórmula de `score-blindagem.md` ao conjunto de achados → obter score numérico + nível
2. Abrir `template.md` e seguir literalmente: substituir `<placeholders>` mas manter títulos, ordem, formatação
3. No fim do relatório, anexar conteúdo de `checklist-producao.md` (o developer marca à medida que aplica fixes)

## Regras críticas

- **Não improvisar formato.** O template é fixo para garantir consistência entre auditorias e permitir comparação entre re-auditorias.
- **Não saltar secções.** Se uma secção do template não tem conteúdo (ex: zero achados Críticos), escreve "Nenhum nesta auditoria" em vez de omitir.
- **Score honesto.** Aplicar a fórmula, não inflacionar nem deflacionar para parecer melhor/pior.

## Cross-references

- Achados detalhados usam o formato definido em [`../SKILL.md`](../SKILL.md) (secção "Para cada achado")
- Confidence scoring guideline em [`../analises/00-falsos-positivos-comuns.md`](../analises/00-falsos-positivos-comuns.md)
- Examples reais de relatórios completos em [`../examples/`](../examples/)
