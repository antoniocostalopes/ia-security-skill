# Como Contribuir

Obrigado por considerares contribuir para esta skill! 🎉

A skill é **open source** sob licença MIT. Toda a contribuição construtiva é bem-vinda — desde correções tipográficas até novos módulos completos.

## Tipos de contribuição

### 🐛 Reportar bugs ou falsos positivos
Abre uma **issue** no GitHub descrevendo:
- Categoria afetada (ex.: `analises/sql-injection.md`)
- Comportamento atual vs esperado
- Exemplo de código onde a IA deu falso positivo / falso negativo
- Versão do Claude Code (`claude --version`)

### 💡 Sugerir nova categoria / framework / linguagem
Abre uma **issue** com:
- Nome da categoria/framework/linguagem
- Justificação (popularidade, gap atual, casos de uso)
- Sketch da estrutura proposta (secções principais)
- Disponibilidade para contribuir o conteúdo

### 🔧 Pull Requests

#### Setup
```bash
git clone https://github.com/antoniocostalopes/ia-security-skill
cd ia-security-skill
# Criar branch
git checkout -b feature/nova-analise-X
```

#### Diretrizes de conteúdo

**Para novas análises** (`analises/*.md`):
- Seguir estrutura padrão: `O que procurar` → `Sinais de alarme` → `Quick wins` → `Falsos positivos` → `Severidade típica`
- Code examples com BAD vs GOOD
- Multi-linguagem onde aplicável
- Cross-references para `linguagens/` e `frameworks/`

**Para novos cartões de linguagem** (`linguagens/*.md`):
- Funções perigosas + helpers seguros
- Idioms inseguros (type juggling, etc.)
- Pitfalls específicos do runtime
- Bibliotecas comuns com vulns conhecidas

**Para novos framework profiles** (`frameworks/web/*.md`):
- Setup mínimo seguro
- Auth / authorization patterns
- ORM / queries
- Common antipatterns
- Quick wins

**Para mobile** (`mobile/*.md`):
- Alinhar com OWASP MASVS
- Mindset device-hostil
- Storage, network, biometric, anti-tampering

#### Diretrizes de tom

- **Tom prestável**: direto, honesto, sem alarmismo teatral.
- **Output construtivo**: cada problema tem fix copy-paste
- **Severidade conservadora**: Crítico só para o que é crítico
- **Português pt-PT** por defeito (PRs em outras línguas requerem discussão)

#### Antes de submeter PR

- [ ] Conteúdo segue tom prestável (sem alarmismo)
- [ ] Code examples testados (sintaxe correta)
- [ ] Quick wins com 8-10 itens checkbox
- [ ] Cross-references válidas (sem broken links)
- [ ] Sem secrets/PII em exemplos
- [ ] Markdown lint passa (formatação consistente)
- [ ] Atualiza README/CHANGELOG se adiciona nova categoria

### 📚 Documentação
Correções tipográficas, clarificações, traduções de exemplos — todas bem-vindas via PR direto.

## Processo de review

1. PR aberto → CI corre validações automáticas (links, formatação)
2. Maintainer review (António Lopes ou colaboradores)
3. Discussão construtiva se necessário
4. Merge quando aprovado
5. Próxima release inclui a contribuição com crédito ao autor

## Princípios da skill

Antes de propor alterações grandes, lê estes princípios:

1. **Claude Code-first** — skill nativa do Claude Code, sem adaptadores multi-IA. Para outras IAs, garfa o repo.
2. **Universal stack** — qualquer linguagem/framework/plataforma. WordPress é uma das opções, não a default.
3. **Tom prestável** — colega que ajuda, não inspetor que aponta erros.
4. **Cada achado tem fix copy-paste** — apontar sem corrigir não chega.
5. **Severidade conservadora** — falsos positivos minam confiança.
6. **Loading hierárquico** — só carregar ficheiros relevantes ao stack detetado.

Mudanças que conflitem com estes princípios serão discutidas mais cuidadosamente.

## Code of Conduct

- Sê respeitoso. Discordâncias técnicas são OK; ataques pessoais não.
- Foco em melhorar a skill, não em "ganhar" argumentos.
- Assume boa fé das outras pessoas.

## Reconhecimento

Contribuidores são listados no `CHANGELOG.md` por release. Contribuições significativas mencionadas no README.

## Dúvidas?

- **Discussão de ideias**: GitHub Discussions
- **Bugs/features**: GitHub Issues
- **Privado/Sensível**: ver `SECURITY.md`

Obrigado! 🙏
