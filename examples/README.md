# Examples — Auditorias-exemplo (few-shot)

> Relatórios reais que servem de **few-shot reference** para alinhar o output da skill. A IA lê 1 destes ficheiros antes de gerar relatório, escolhendo o que melhor casa com o stack do projeto.

## Quando ler

Antes da Fase 7 (Geração do relatório) do workflow. **Lê 1 example, não vários** — basta um para alinhar formato, tom e estrutura.

| Stack do projeto | Example a ler |
|---|---|
| Node / Express / Next / Nuxt / Remix / SvelteKit / NestJS / etc. | `audit-example-node.md` |
| PHP / Laravel / Symfony / WordPress | `audit-example-php-laravel.md` |
| Python / Django / Flask / FastAPI | `audit-example-python-django.md` |
| Mobile (iOS / Android / RN / Flutter / MAUI) | `audit-example-mobile-flutter.md` |
| Web3 / Solidity / smart contracts | `audit-example-web3-solidity.md` |

Para stacks não cobertos diretamente (Go, Rust, Java, .NET, Ruby, Elixir, etc.):
- App web → usa `audit-example-node.md` (estrutura genérica)
- API só → usa `audit-example-node.md` ou `audit-example-python-django.md`
- App mobile híbrida → usa `audit-example-mobile-flutter.md`

## O que cada example contém

Estrutura completa de um relatório de auditoria:
1. Header (projeto fictício, data, stack)
2. Score 0-100 + nível de blindagem
3. Resumo executivo (cliente)
4. Resumo técnico (devs)
5. Mapa de superfícies de ataque
6. Attack chains (3+)
7. Achados detalhados com confidence + fix copy-paste
8. Plano de correção em 4 fases
9. Checklist pré-produção
10. Notas e limitações

Não copies o conteúdo — usa apenas como **referência de formato**. Os achados, scores e fixes do projeto real serão diferentes.

## Cross-references

- Template canónico do relatório: [`../relatorio/template.md`](../relatorio/template.md)
- Fórmula de score: [`../relatorio/score-blindagem.md`](../relatorio/score-blindagem.md)
- Checklist final: [`../relatorio/checklist-producao.md`](../relatorio/checklist-producao.md)
