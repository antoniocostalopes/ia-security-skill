---
name: 🐛 Bug ou falso positivo
about: Reporta um problema na skill (falso positivo, instrução incorreta, comportamento inesperado da IA)
title: '[BUG] '
labels: bug
assignees: ''
---

## Tipo de problema

- [ ] Falso positivo (IA reportou vuln que não existe)
- [ ] Falso negativo (IA não detetou vuln óbvia)
- [ ] Instrução incorreta na skill (ex.: snippet GOOD na verdade é mau)
- [ ] Comportamento inesperado da IA (não seguiu o workflow / formato)
- [ ] Outro

## Categoria afetada

Qual ficheiro da skill?
- Ex.: `analises/sql-injection.md`, `frameworks/web/node-express.md`, `mobile/ios-native.md`

## Comportamento atual

O que a skill (ou a IA usando a skill) está a fazer?

```
(cola output ou descreve)
```

## Comportamento esperado

O que **deveria** estar a fazer?

## Como reproduzir

1. IA usada: (Claude Code / Claude.ai / ChatGPT / Cursor / Copilot / Gemini / outro)
2. Versão da IA / modelo: (ex.: Claude 3.5 Sonnet, GPT-4o)
3. Versão da skill: (ex.: v1.0.0)
4. Como instalei: (git clone / copiar ficheiros / bundle)
5. Comando/pergunta usada:
   ```
   (ex.: "audita este projeto")
   ```
6. Código auditado (mínimo viável que reproduz):
   ```
   (snippet relevante, anonimizado se necessário)
   ```

## Contexto adicional

- Stack do projeto: (ex.: Node + Express + MySQL)
- Algo único do setup?

## Sugestão de correção (opcional)

Se já tens ideia de como corrigir, descreve aqui ou abre PR.
