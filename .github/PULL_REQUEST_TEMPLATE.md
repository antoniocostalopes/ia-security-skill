## Descrição

(Resume o que este PR faz)

## Tipo de mudança

- [ ] 🐛 Bug fix (correção que não quebra nada existente)
- [ ] ✨ Nova categoria / linguagem / framework
- [ ] 📝 Documentação (correções, clarificações, traduções)
- [ ] 🎨 Melhoria de tom / formatação
- [ ] 🔧 Refactor (sem mudança de comportamento)
- [ ] ⚠️ Breaking change (requer atualização de quem usa a skill)

## Ficheiros afetados

- [ ] `analises/*.md`
- [ ] `linguagens/*.md`
- [ ] `frameworks/*.md`
- [ ] `mobile/*.md`
- [ ] `outras-areas/*.md`
- [ ] Entry points (SKILL.md, PROMPT.md, AGENTS.md, etc.)
- [ ] CI / configs
- [ ] Outro: ____

## Checklist

### Conteúdo
- [ ] Segue tom **hacker amigável** (prestável, direto, sem alarmismo)
- [ ] Code examples têm BAD vs GOOD claramente marcados
- [ ] Sintaxe dos snippets testada (não inventei API calls)
- [ ] Multi-linguagem onde aplicável
- [ ] Cross-references válidas (links para outros .md desta skill)

### Estrutura (para análises)
- [ ] Tem secção "O que procurar"
- [ ] Tem secção "Sinais de alarme" com exemplos
- [ ] Tem secção "Quick wins" com checkbox de 8-10 itens
- [ ] Tem secção "Falsos positivos"
- [ ] Tem secção "Severidade típica" / "Severidade — em linguagem honesta"

### Estrutura (para frameworks)
- [ ] Tem "Deteção" (manifests/files que identificam o framework)
- [ ] Tem auth/authorization patterns nativos
- [ ] Tem ORM/query patterns
- [ ] Tem common antipatterns
- [ ] Tem "Quick wins" no fim

### Qualidade
- [ ] Sem secrets/PII em exemplos
- [ ] Sem TODOs/FIXMEs/placeholders deixados
- [ ] Versão consistente (v1.0.0 ou superior)
- [ ] Atualizei `CHANGELOG.md` se aplicável
- [ ] Atualizei `README.md` se adiciono nova categoria/framework

### CI
- [ ] CI passou localmente (cross-refs, lint, sizes)
- [ ] PROMPT-COMPACTO.md continua < 8000 chars (se editado)

## Como testar

(Se mudaste conteúdo de análises, descreve como validar que a IA aplica corretamente)

## Issue relacionada

Closes #(número)

## Notas adicionais

(Anything else reviewers should know)
