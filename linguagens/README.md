# Linguagens — Cartões de Referência

> Cada cartão é um cheat-sheet de **funções perigosas, idiomas inseguros e helpers seguros** específicos da linguagem. A IA carrega o(s) cartão(ões) da(s) linguagem(ns) detetada(s) no projeto.

## Princípio

Os módulos em `../analises/` cobrem vulnerabilidades **universais** (XSS, SQLi, etc.). Estes cartões adicionam o **delta específico da linguagem**:

- Funções da stdlib que devem ser evitadas
- Sintaxe que traiçoa (type juggling, prototype pollution, etc.)
- Helpers seguros equivalentes
- Pitfalls do compilador / runtime

A IA já conhece a sintaxe das linguagens. Estes cartões são **prompt boost**, não tutorial.

## Linguagens cobertas

| Linguagem | Cartão | Quando carregar |
|---|---|---|
| JavaScript / TypeScript | `javascript-typescript.md` | `package.json`, `.js`/`.ts`/`.jsx`/`.tsx` |
| Python | `python.md` | `requirements.txt`/`pyproject.toml`/`Pipfile`, `.py` |
| PHP | `php.md` | `composer.json`, `.php` |
| Java | `java.md` | `pom.xml`/`build.gradle`, `.java` |
| C# / .NET | `csharp-dotnet.md` | `.csproj`/`.sln`, `.cs` |
| Go | `go.md` | `go.mod`, `.go` |
| Ruby | `ruby.md` | `Gemfile`, `.rb` |
| Rust | `rust.md` | `Cargo.toml`, `.rs` |
| Kotlin | `kotlin.md` | `.kt`, Gradle Kotlin |
| Swift | `swift.md` | `Package.swift`, `.swift` |
| Dart | `dart.md` | `pubspec.yaml`, `.dart` |
| C / C++ | `c-cpp.md` | `Makefile`/`CMakeLists.txt`, `.c`/`.cpp`/`.h` |
| Scala | `scala.md` | `build.sbt`, `.scala` |
| Elixir | `elixir.md` | `mix.exs`, `.ex`/`.exs` |
| Shell / Bash | `shell-bash.md` | `.sh`, `Dockerfile` RUN |
| SQL (dialetos) | `sql.md` | `.sql`, migrations |
| GraphQL | `graphql.md` | `.graphql`, Apollo/relay configs |
| Solidity | `solidity.md` | `.sol`, Hardhat/Foundry |

## Estrutura de cada cartão

Cada cartão segue a mesma estrutura:

1. **Funções perigosas** — table de funções a evitar/cuidar
2. **Idiomas inseguros** — padrões da linguagem que enganam
3. **Helpers seguros da stdlib** — equivalentes seguros recomendados
4. **Pitfalls específicos** — quirks do runtime/compilador
5. **Bibliotecas comuns com vulns conhecidas** — libs a verificar com cuidado
