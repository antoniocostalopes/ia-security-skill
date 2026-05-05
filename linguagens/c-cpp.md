# C / C++ — Cartão de Segurança

> Memory safety é a categoria-rei aqui. Buffer overflows, use-after-free, double-free, integer overflows — clássicos. C++ moderno (C++17/20/23) tem ferramentas, mas é preciso usá-las.

## Funções perigosas (C)

| Função | Risco | Substituto |
|---|---|---|
| `gets(buf)` | Buffer overflow garantido | `fgets(buf, n, stdin)` |
| `strcpy`, `strcat` | Buffer overflow se sem check | `strncpy`, `strncat`, `strlcpy` (BSD/Linux) |
| `sprintf(buf, fmt, ...)` | Buffer overflow | `snprintf(buf, n, fmt, ...)` |
| `scanf("%s", buf)` (sem width) | Buffer overflow | `scanf("%99s", buf)` |
| `system(cmd)` | Command injection | `execve` com array |
| `mktemp` | TOCTOU race | `mkstemp` |
| `tmpnam` | Race | `mkstemp` |
| `strtok` | Não thread-safe | `strtok_r` |
| `rand()` | Não criptográfico | `getrandom`/`/dev/urandom` |
| `setuid` em bins SUID | Privilege issues | Drop privileges cedo |
| `printf(userInput)` | Format string injection | `printf("%s", userInput)` |
| `memcpy` com size errado | Buffer overflow | Validar `size <= dst_size` |

## Idiomas inseguros (C)

### Format string sem `%s` literal
```c
// BAD — atacante controla format
printf(user_input);  // %s lê stack, %n escreve

// GOOD
printf("%s", user_input);
```

### Off-by-one
```c
// BAD
char buf[10];
strncpy(buf, src, 10);  // sem null terminator se src >= 10

// GOOD
char buf[10];
strncpy(buf, src, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
// MELHOR: snprintf
snprintf(buf, sizeof(buf), "%s", src);
```

### Integer overflow em allocação
```c
// BAD
size_t total = n_items * item_size;  // overflow → small alloc, big write
void* p = malloc(total);

// GOOD
if (n_items > SIZE_MAX / item_size) return NULL;
size_t total = n_items * item_size;
// ou usar calloc (verifica overflow internamente):
void* p = calloc(n_items, item_size);
```

### Use-after-free
```c
// BAD
free(ptr);
use(ptr);  // UAF

// GOOD
free(ptr);
ptr = NULL;
if (ptr) use(ptr);
```

### Double-free
```c
// BAD
free(ptr);
// ... mais código ...
free(ptr);  // double-free → exploit

// GOOD
free(ptr);
ptr = NULL;
free(ptr);  // free(NULL) é seguro
```

### Race conditions com `access` + `open`
```c
// BAD — TOCTOU
if (access(path, R_OK) == 0) {
    fd = open(path, O_RDONLY);  // atacante substitui ficheiro entre
}

// GOOD — abre e verifica
fd = open(path, O_RDONLY | O_NOFOLLOW);
if (fd < 0) handle_error();
fstat(fd, &st);
// validar st.st_uid, st.st_mode após abrir
```

## Idiomas inseguros (C++)

### Raw pointers + manual delete
```cpp
// BAD
auto* p = new MyClass();
// ... exception thrown ...
delete p;  // leak

// GOOD — RAII
auto p = std::make_unique<MyClass>();
// ou
auto p = std::make_shared<MyClass>();
```

### `std::cin >>` em strings sem limite
```cpp
// BAD — overflow potencial em std::string? não, mas DoS por memória
std::string s;
std::cin >> s;  // sem limite — atacante envia GB

// GOOD
std::string s;
std::cin >> std::setw(1024) >> s;
// ou
std::getline(std::cin, s);
if (s.size() > 1024) reject();
```

### `reinterpret_cast` / `static_cast` errado
```cpp
// BAD
auto* derived = reinterpret_cast<Derived*>(base);  // se base não é Derived → UB

// GOOD
auto* derived = dynamic_cast<Derived*>(base);
if (derived) { use(derived); }
```

### Exception não capturada em destrutor
```cpp
// BAD
~MyClass() {
    delete resource;  // se throw → terminate
}

// GOOD
~MyClass() {
    try { delete resource; }
    catch (...) { /* log, swallow */ }
}
// ou usar smart pointers que não throw em destrutor
```

### Comparação de buffers de auth
```cpp
// BAD
if (memcmp(expected, received, len) == 0) ...  // timing!

// GOOD — constant-time
int constant_time_compare(const uint8_t* a, const uint8_t* b, size_t n) {
    uint8_t result = 0;
    for (size_t i = 0; i < n; i++) result |= a[i] ^ b[i];
    return result == 0;
}
```

## Helpers seguros

| Necessidade | Use |
|---|---|
| Strings | `std::string`, `std::string_view` (C++17) |
| Containers | STL (`std::vector`, `std::array`, `std::span`) |
| Smart pointers | `std::unique_ptr`, `std::shared_ptr` |
| Random | `<random>` (C++11) ou `getrandom`/`/dev/urandom` para crypto |
| Crypto | OpenSSL, libsodium (preferir libsodium para APIs simples) |
| Format | `std::format` (C++20), `fmt` lib |
| Concurrency | `std::mutex`, `std::lock_guard`, `std::atomic` |
| File I/O seguro | `std::filesystem` (C++17) com `std::filesystem::canonical` |

## Defesas em profundidade

### Compilador
```bash
# GCC/Clang flags recomendadas
-Wall -Wextra -Wpedantic -Werror
-fstack-protector-strong       # stack canary
-D_FORTIFY_SOURCE=2            # runtime checks
-fPIE -pie                     # ASLR
-Wl,-z,relro,-z,now            # RELRO + immediate binding
-fsanitize=address             # AddressSanitizer (dev/CI)
-fsanitize=undefined           # UBSan (dev/CI)
-fsanitize=thread              # ThreadSanitizer (dev/CI)
```

### Sandboxing
- `seccomp` para limitar syscalls.
- AppArmor/SELinux profiles.
- Containers/namespaces.
- Capabilities Linux (drop CAP_*).

### Static analysis
- `clang-tidy`
- `cppcheck`
- `Coverity`
- `PVS-Studio`
- `CodeQL`

### Fuzzing
- AFL++, libFuzzer, Honggfuzz.
- Especialmente para parsers e código que recebe input externo.

## Bibliotecas comuns com vulns

- **OpenSSL** — várias CVEs históricas, manter atualizado
- **libcurl** — manter atualizado
- **zlib** — pré-1.2.13 tinha vulns
- **libxml2** — XXE if mal configurado
- **Boost** — manter atualizado
- **Qt** — manter atualizado

## Quick wins

- [ ] Compilar com hardening flags (`-fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -pie`)
- [ ] AddressSanitizer + UBSan na CI
- [ ] `clang-tidy` na CI sem warnings novos
- [ ] Banir `gets`, `strcpy`, `sprintf`, `system` (substituir)
- [ ] Sempre `snprintf` em vez de `sprintf`
- [ ] Sempre `printf("%s", x)` para strings, não `printf(x)`
- [ ] `std::unique_ptr`/`std::shared_ptr` em C++ (não `new`/`delete` manual)
- [ ] Smart pointers em loops/branches que podem throw
- [ ] `getrandom()` (Linux) ou `BCryptGenRandom` (Windows) para crypto random
- [ ] Constant-time compare em auth/MAC
- [ ] Drop privileges cedo em SUID binaries
- [ ] Containers/seccomp para sandboxing de processos não-confiáveis
- [ ] Fuzzing em parsers de input externo
- [ ] Code review obrigatório para qualquer `unsafe`/`reinterpret_cast`/`raw pointer`
