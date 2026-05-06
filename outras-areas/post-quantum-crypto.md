# Post-Quantum Crypto — Migração

> Quantum computers irão quebrar RSA e ECC quando ficarem práticos (estimativa: 2030-2040). Para dados que precisam confidencialidade ≥10 anos, migração começa agora — atacantes "harvest now, decrypt later".

## Quando carregar

- Apps que armazenam segredos de longo prazo (medical records, government, financial archives)
- Banking, defense, healthcare, legal
- Apps que usam crypto signing para validade longa (legal documents, code signing certs)
- Migrações para TLS 1.3 + híbridos
- Auditorias de criptografia em sistemas críticos

## Mindset

- **"Quantum is decades away"** é falso para cenários sensíveis — capture-now-decrypt-later é real
- **NIST padronizou em 2024:** ML-KEM (Kyber), ML-DSA (Dilithium), SLH-DSA (SPHINCS+)
- **Híbridos** (clássico + PQ) são o caminho de transição — falha de um não compromete tudo
- **Performance trade-offs:** PQ keys/signatures muito maiores (KB vs bytes)
- **Side-channels** continuam relevantes — implementação importa tanto como algoritmo

## 6 categorias

### 1. Identificar crypto vulnerável

Atualmente vulnerável a quantum:
- **RSA** (qualquer tamanho)
- **DH / ECDH** (key exchange)
- **DSA / ECDSA** (signing)
- **EdDSA / Ed25519** (também elliptic curve, vulnerável)

Resistente até agora:
- **AES-256** (precisa de 256-bit keys, AES-128 fica em ~64-bit security)
- **SHA-256, SHA-3** (hash, Grover algoritmo dá half security)
- **HMAC** (depende de hash subjacente)
- **ChaCha20** (symmetric)

**Audit pattern:**
```bash
grep -rn "RSA\|RSAES\|ECDSA\|secp256\|prime256\|ed25519\|x25519\|DH\|DiffieHellman" --include="*.{py,js,ts,go,rs,java,c}"
```

### 2. NIST PQ algorithms (2024 padronizados)

#### ML-KEM (Module Lattice Key Encapsulation Mechanism, ex-Kyber)
- **Key exchange / KEM**
- Substitui RSA encryption, ECDH, DH
- Levels: ML-KEM-512 (~AES-128), ML-KEM-768 (~AES-192), ML-KEM-1024 (~AES-256)
- Public key: ~800 bytes (768), Ciphertext: ~1088 bytes
- Performance: rápida (~10x mais rápido que RSA-2048)

#### ML-DSA (Module Lattice Digital Signature Algorithm, ex-Dilithium)
- **Digital signatures**
- Substitui RSA signing, ECDSA, EdDSA
- Levels: 44 (~128-bit), 65 (~192-bit), 87 (~256-bit)
- Public key: ~1300 bytes (level 44), Signature: ~2400 bytes
- Performance: rápida em verify, signing meio lento

#### SLH-DSA (Stateless Hash-based Digital Signature Algorithm, ex-SPHINCS+)
- **Hash-based signatures** — stateless, baseado só em hash
- Backup if lattice-based broken
- Signatures gigantes (~17-50 KB)
- Útil para: code signing, root certificates (low frequency, high stakes)

### 3. Padrão híbrido (recomendado durante transição)

Combinar clássico + PQ — atacante precisa quebrar AMBOS:

**TLS 1.3 hybrid (RFC draft, OpenSSL 3.2+ suporta):**
```
X25519MLKEM768  =  X25519 ⊕ ML-KEM-768
```

OpenSSL config:
```
SSL_CTX_set_groups(ctx, "X25519MLKEM768:X25519:secp256r1");
```

Cloudflare, Google, Apple já em produção com hybrid TLS.

**Signing híbrido:**
```python
# Conceitual
classical_sig = ed25519_sign(message, ed25519_key)
pq_sig = ml_dsa_sign(message, ml_dsa_key)
hybrid_signature = b"|".join([classical_sig, pq_sig])
```

Verifier deve validar AMBOS (não OR).

### 4. Bibliotecas disponíveis

| Linguagem | Biblioteca | Status |
|---|---|---|
| OpenSSL | OpenSSL 3.2+ | Hybrid TLS suportado |
| Python | `pyOQS` (Open Quantum Safe), `kyber-py` | Beta |
| Go | `cloudflare/circl` | Production-ready |
| Rust | `pqcrypto`, `ml-kem` (rust-crypto) | Beta |
| Java | Bouncy Castle 1.78+ | Production |
| Node.js | `node-pqcrypto` (wrapper liboqs) | Beta |
| AWS | KMS support PQ via TLS hybrid | Behind feature flag |

**Cuidado:** muitas libs ainda em beta. Para produção prepara-te para upgrades frequentes.

### 5. Migration roadmap

#### Fase 1 (2025-2026) — Inventário
- Audit completo de algoritmos crypto usados (Crypto Bill of Materials, CBOM)
- Identificar dados de longo prazo (>10 anos confidentiality)
- Identificar TLS endpoints, signing keys, encryption keys

#### Fase 2 (2026-2028) — Híbridos para greenfield
- Novos sistemas usam hybrid (clássico+PQ)
- Cripto agility no código (substitutable algorithms)
- Test ambiente PQ separado

#### Fase 3 (2028-2030) — Migration sistemas críticos
- VPNs, banking, healthcare em hybrid TLS
- Code signing certs com SLH-DSA
- Encryption-at-rest com PQ KEM

#### Fase 4 (2030+) — Pure PQ
- Phase out classical algorithms
- Continuar híbrido onde performance permite

### 6. Crypto agility

Código deve ser fácil de trocar de algoritmo:

**BAD:**
```python
def sign(message, key):
    return rsa.sign(message, key, "SHA-256")
```

**GOOD:**
```python
class Signer(Protocol):
    def sign(self, message: bytes) -> bytes: ...
    def verify(self, message: bytes, sig: bytes) -> bool: ...

class RSASigner(Signer): ...
class MLDSASigner(Signer): ...
class HybridSigner(Signer):
    def __init__(self, classical: Signer, pq: Signer): ...

# Config-driven
signer = SignerFactory.create(config.algorithm)
```

## Quick wins

- [ ] Crypto Bill of Materials (CBOM) gerada para o repo
- [ ] Inventário de dados com classification de retention (anos)
- [ ] Para novos sistemas: planejar hybrid TLS desde dia 1
- [ ] Avaliar OpenSSL/BoringSSL/wolfSSL versão para hybrid support
- [ ] Crypto agility no código — algoritmos via interface, não hardcoded
- [ ] Roadmap PQ documentado (research, beta, production phases)
- [ ] Acompanhar NIST recomendações + transition timelines
- [ ] Vendors críticos: perguntar PQ roadmap (cloud, HSM, certificate authorities)
- [ ] Para code signing certs com validade >5 anos: considerar SLH-DSA híbrido
- [ ] AES-256 (não AES-128) para dados longo prazo — Grover dá ~½ security
- [ ] SHA-3 ou SHA-256 (256-bit output) para hashes longo prazo
- [ ] Testing em staging com hybrid TLS antes de prod
- [ ] Monitor performance impact (PQ é mais lento + bigger payloads)
- [ ] Plan B se PQ algorithm escolhido for broken: ter fallback

## Falsos positivos

- App ephemeral (TLS sessions curtas, dados deletados em 30 dias) — quantum threat menor
- AES-256 já em uso (apenas verificar key size 256, não 128)
- Para signing curto prazo (auth tokens, JWT 1h TTL) — não urgente

## Severidade típica

- **Crítico** — sistema com confidentiality requirement ≥10 anos sem roadmap PQ (medical records, government, defense)
- **Alto** — code signing certs ou root CAs sem PQ planning, AES-128 para long-term data
- **Médio** — falta de crypto agility no código, sem CBOM
- **Baixo** — TLS 1.2 quando 1.3+hybrid possível

## Cross-references

- [`../analises/13-criptografia.md`](../analises/13-criptografia.md) — base crypto
- [`../analises/16-headers-http.md`](../analises/16-headers-http.md) — TLS configuration
- [`dns-security.md`](dns-security.md) — DNSSEC algorithms
- [`email-infrastructure.md`](email-infrastructure.md) — DKIM key types

## Recursos

- [NIST Post-Quantum Cryptography](https://csrc.nist.gov/projects/post-quantum-cryptography)
- [Open Quantum Safe (liboqs)](https://openquantumsafe.org/)
- [Cloudflare PQ research](https://research.cloudflare.com/projects/post-quantum/)
- [Apple iMessage PQ3](https://security.apple.com/blog/imessage-pq3/)
- [PQC Migration Handbook (BSI)](https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Informationen-und-Empfehlungen/Quantentechnologien-und-Post-Quanten-Kryptografie/Migration-zu-Post-Quanten-Kryptografie/migration-zu-post-quanten-kryptografie_node.html)
