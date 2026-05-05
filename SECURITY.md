# Política de Segurança

A skill em si é uma ferramenta de segurança — por isso levamos a sério vulnerabilidades reportadas no seu próprio conteúdo.

## Versões suportadas

| Versão | Suportada |
|---|---|
| 1.0.x | ✅ |
| < 1.0 | ❌ (pré-release) |

## Reportar uma vulnerabilidade

Se descobrires um problema de segurança **na própria skill** (ex.: instruções que causam IA a gerar código inseguro, falso positivo crítico que oculta vuln real, ou conteúdo que possa ser usado para fins maliciosos), reporta de forma responsável.

### Como reportar

**Preferencial:** GitHub Security Advisories
- Vai a `https://github.com/antoniocostalopes/ia-security-skill/security/advisories/new`
- Privado por defeito até resolução
- Permite discussão coordenada

**Alternativo:** email
- Cria issue **público** apenas para problemas não-sensíveis (ex.: docs, falsos positivos de baixo impacto)
- Para sensíveis, usa GitHub Security Advisories

### O que esperar

- **Confirmação de receção**: até 72h
- **Avaliação inicial**: até 7 dias
- **Resolução ou plano de mitigação**: até 30 dias (depende da complexidade)
- **Disclosure coordenado**: após fix ser publicado

### Reconhecimento

Reportadores responsáveis são creditados no `CHANGELOG.md` (com permissão).

## Tipos de issues que **não** são vulnerabilidades

- A skill não detetou um bug específico no teu código → abre issue normal sugerindo melhoria de regra
- A IA seguiu a skill mas falhou um padrão → ajuda a melhorar via PR
- Falso positivo recorrente → issue normal

## Tipos que **são** vulnerabilidades a reportar

- Conteúdo que faria a IA gerar código inseguro como "GOOD"
- Instruções que possam ser usadas para criar/explorar (não defender)
- Vazamento de segredos/PII em exemplos
- Cross-site scripting em renderização do conteúdo (improvável mas)

## Limitações claras

Esta skill é para **auditoria defensiva pré-entrega de código próprio ou autorizado**. Se descobrires que alguém está a usar a skill para:
- Pentest de sistemas sem autorização
- Engenharia social
- Outros fins maliciosos

Não é vulnerabilidade da skill — é uso indevido. A skill rejeita explicitamente esses casos no `SKILL.md`.

## Disclosure responsável

Pedimos que **não publiques publicamente** detalhes de vulnerabilidades antes de:
1. Reportar via canal apropriado
2. Aguardar resposta razoável (mín. 30 dias)
3. Coordenar disclosure com mantedor

Em troca, comprometemo-nos a:
1. Resposta rápida e profissional
2. Crédito público (se quiseres)
3. Fix transparente em release subsequente

Obrigado por ajudares a manter a skill segura. 🛡️
