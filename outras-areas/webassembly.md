# WebAssembly — Segurança

> Wasm corre em sandbox mas a fronteira Wasm↔JS, memory exposure, e supply chain dos módulos têm pegadas próprias.

## Quando carregar

- Ficheiros `.wasm` no projeto
- `Cargo.toml` com `wasm-bindgen`, `wasm-pack`, `wasm32-unknown-unknown` target
- `package.json` com `assemblyscript`, `@wasmer/wasi`, `wasmtime`
- `pkg/*.wasm` típico de wasm-pack
- `go.mod` com `syscall/js` (Go-Wasm)

## Mindset

- **Sandbox forte** — Wasm não pode aceder DOM, filesystem, network diretamente; tudo via host
- **Memory linear exposed** — JS pode ler/escrever a memória Wasm completa via `WebAssembly.Memory.buffer`
- **Side-channel** (Spectre, timing) — Wasm não está imune a microarchitectural attacks
- **Supply chain** dupla — npm package + binário .wasm compilado de Rust/C/C++/Go
- **No bound checks** em alguns idiomas (C/C++ unsafe Wasm)

## 6 categorias

### 1. Imports/exports demasiado largos

**BAD** — JS expõe APIs do host sem restrição:
```javascript
const importObject = {
  env: {
    fetch: (urlPtr, urlLen) => {
      const url = readString(memory, urlPtr, urlLen);
      return fetch(url);  // Wasm pode chamar qualquer URL
    },
    eval_js: (codePtr, codeLen) => {
      const code = readString(memory, codePtr, codeLen);
      return eval(code);  // RCE
    }
  }
};
WebAssembly.instantiateStreaming(fetch('app.wasm'), importObject);
```

**GOOD** — APIs específicas, validadas:
```javascript
const importObject = {
  env: {
    api_call: (endpointId, payloadPtr, payloadLen) => {
      const payload = readString(memory, payloadPtr, payloadLen);
      const endpoint = ENDPOINTS[endpointId];
      if (!endpoint) return -1;
      return fetch(endpoint, { method: 'POST', body: payload });
    }
    // Sem eval, sem fetch arbitrário
  }
};
```

### 2. Memory exposure / sensitive data leakage

JS tem acesso total à memória do Wasm:
```javascript
const memory = new Uint8Array(wasmInstance.exports.memory.buffer);
// memory contém TUDO o que o Wasm tem em RAM, incluindo passwords, keys
```

**Mitigação:**
- Não armazenar secrets na memória Wasm (apenas processar e limpar)
- Após operação cripto, fazer `wipe_memory(ptr, len)` no Wasm — embora não garante 100%
- Para crypto crítico, considerar rodar fora do Wasm

### 3. Buffer overflow no Wasm (C/C++)

Wasm com `unsafe` C/C++ não tem stack canaries automáticos. Buffer overflow pode corromper estruturas Wasm internamente.

**BAD** — `app.c`:
```c
void process(const char *input) {
    char buf[16];
    strcpy(buf, input);  // sem bounds check
}
```

**GOOD:**
- Compilar com `-fstack-protector-all` (Emscripten suporta)
- Preferir `strncpy` / `snprintf`
- Migrar para Rust (memory-safe)

### 4. wasm-bindgen / wasm-pack supply chain

```toml
# Cargo.toml
[dependencies]
sketchy-crypto-lib = "0.1.0"  # crate sem auditoria
```

Wasm binário publicado em npm package herda riscos do npm + crates.io.

**Mitigação:**
- `cargo audit` antes de cada release
- Pin de versões exatas
- Usar `wasm-snip` para remover dead code (reduz superfície)
- Reproducible builds — `cargo build --release` com hashes verificáveis

### 5. WASI capabilities over-broad

WASI (WebAssembly System Interface) é o "POSIX para Wasm". Por design, sandbox por capabilities:

**BAD** — `wasmtime --dir=/` (mapeia tudo):
```bash
wasmtime --dir=/ app.wasm
```

**GOOD** — só os dirs necessários:
```bash
wasmtime --dir=/var/data --env API_KEY=xxx app.wasm
```

Ou em código (Wasmer/Wasmtime SDK):
```rust
let wasi = WasiCtxBuilder::new()
    .preopened_dir(Dir::open_ambient_dir("/var/data", ambient_authority())?, "/data")?
    .env("API_KEY", &key)?
    .build();
```

### 6. Side-channel mitigation

Spectre / Meltdown afetam Wasm. Browsers ativaram mitigations (process isolation, COOP/COEP) mas:
- **High-resolution timers** podem leak timing info — Wasm usa `performance.now()` capado em ~5ms em browsers modernos
- **SharedArrayBuffer** requer Cross-Origin Isolation (COOP: same-origin + COEP: require-corp)
- Para crypto, usar **constant-time** algorithms — mesmo em Wasm

## Quick wins

- [ ] Imports do host minimalistas (sem `eval`, `exec`, `fetch` arbitrário)
- [ ] Validação de pointers/lengths em todos imports JS→Wasm
- [ ] Memory limits configurados (`--initial-memory`, `--maximum-memory`)
- [ ] Para WASI: `--dir` específico, sem `/`
- [ ] `cargo audit` / `npm audit` no pipeline
- [ ] Compile flags: `-fstack-protector-all` (C/C++), `--release` (Rust)
- [ ] Sem secrets persistentes na memória Wasm
- [ ] COOP/COEP headers se usar SharedArrayBuffer
- [ ] Source maps NÃO em produção (revelam structure)
- [ ] Reproducible build verificável

## Falsos positivos

- `import { fetch } from 'env'` — pode ser legítimo se o Wasm SÓ chama fetch para endpoints internos
- `wasm-pack build --target web` produz JS shim — esperado
- `Memory.grow()` chamado pelo Wasm — comportamento normal

## Severidade típica

- **Crítico** — `eval` ou exec exposto via imports
- **Alto** — buffer overflow em C/C++ Wasm, WASI com `--dir=/`
- **Médio** — secrets em memória Wasm, source maps em prod
- **Baixo** — falta de COOP/COEP se não usa SAB

## Cross-references

- [`../linguagens/c-cpp.md`](../linguagens/c-cpp.md) — buffer overflows
- [`../linguagens/rust.md`](../linguagens/rust.md) — Rust→Wasm
- [`../analises/13-criptografia.md`](../analises/13-criptografia.md) — constant-time
- [`../analises/17-dependencias.md`](../analises/17-dependencias.md) — supply chain

## Recursos

- [WebAssembly Security](https://webassembly.org/docs/security/)
- [WASI Capabilities](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md)
- [Wasm Side-channel](https://www.usenix.org/conference/usenixsecurity20/presentation/koppelmann)
