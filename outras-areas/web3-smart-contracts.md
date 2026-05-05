# Web3 / Smart Contracts — Segurança

> Já existe `linguagens/solidity.md` (cheat-sheet). Este foca no **ecosistema** Web3: deployment, oráculos, DeFi patterns, ferramentas, processo de audit.

## Mindset Web3

- **Imutabilidade** = bugs são para sempre (a menos que upgradeable)
- **Adversarial** = atacante tem acesso ao bytecode + bytecode de todas as outras contracts
- **Composabilidade** = contract usa outras contracts maliciosas via flash loan
- **Public** = todas as transactions visíveis em mempool
- **Real money** = bug = $$$ perdidos

## Top 10 vulnerabilities

### 1. Reentrancy — coberto em `linguagens/solidity.md`
### 2. Integer overflow/underflow — Solidity 0.8+ resolve
### 3. Access control — `onlyOwner`, multi-sig
### 4. Oracle manipulation — flash loans + AMM spot price
### 5. Front-running / MEV — commit-reveal, batch auctions
### 6. Storage layout corruption (proxies)
### 7. Logic errors — divisão por zero, off-by-one
### 8. Unchecked external calls
### 9. Denial of Service via gas
### 10. Tx ordering dependence

## DeFi-specific patterns

### Flash loans
- Atacante toma loan gigante, manipula price em DEX, executa exploit, devolve loan no mesmo bloco.
- Gas cost coberto pelos profits.
- **Mitigações:**
  - TWAP (time-weighted) prices em vez de spot
  - Multiple oracle sources (Chainlink, Uniswap V3 oracle)
  - Reentrancy guards
  - Slippage limits

### Arbitrage / Sandwich attacks
- Atacante vê tx grande na mempool, frente-corre comprando, vende após.
- **Mitigações:**
  - Slippage limits no contract
  - Submission via Flashbots / private mempool
  - Commit-reveal schemes

## Upgradeable contracts

```solidity
// OpenZeppelin Upgrades (UUPS)
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyContract is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImpl) internal override onlyOwner {}
}
```

### Riscos
- Storage layout corruption se nova versão muda ordem de variáveis
- Initialization race conditions
- Owner com poder total (comprometer owner = comprometer contract)

### Mitigações
- Storage gaps em base contracts
- Multi-sig + timelock para upgrades
- Audit de cada upgrade

## Multi-sig + Timelock

```solidity
// Operações críticas via multi-sig
// Proposed → 7 day timelock → executable
// Permite usuários sair se mudança suspeita
```

Frameworks:
- **Gnosis Safe** — multi-sig padrão
- **OpenZeppelin Defender** — operations + monitoring
- **OpenZeppelin Governor** — DAO governance

## Ferramentas

### Static analysis
- **Slither** (Trail of Bits) — gratuito, robusto
- **Mythril** — symbolic execution
- **Securify**
- **Manticore** — symbolic execution avançado

### Fuzzing
- **Echidna** (Trail of Bits) — property-based fuzzing
- **Foundry's `forge fuzz`** — built-in
- **Harvey** — coverage-guided

### Testing
- **Foundry** — fast, Solidity tests, ótimo
- **Hardhat** — JS tests
- **Truffle** — legacy

### Monitoring
- **Tenderly** — debug, simulação
- **OpenZeppelin Defender** — alertas, autotask
- **Forta** — runtime monitoring + alerting

### Verification
- **Etherscan verify** — código fonte público (obrigatório)
- **Sourcify** — alternative

## Audit checklist (pré-deploy)

```
- [ ] Solidity 0.8+
- [ ] OpenZeppelin contracts onde aplicável
- [ ] Slither sem warnings críticos
- [ ] Mythril sem high-severity
- [ ] Test coverage ≥ 95%
- [ ] Fuzzing extensivo (Echidna ou forge fuzz)
- [ ] Audit profissional (mínimo 1, idealmente 2)
- [ ] Code4rena / Sherlock / etc. contest
- [ ] Bug bounty no Immunefi
- [ ] Multi-sig (3/5, 5/9) + timelock para owner ops
- [ ] Pause mechanism (emergency stop)
- [ ] Upgrade mechanism com timelock + multi-sig
- [ ] Etherscan verified
- [ ] Documentação completa
- [ ] Deploy script revisto
- [ ] Plano de incident response
```

## Operacional pós-deploy

```
- [ ] OpenZeppelin Defender Autotasks para monitoring
- [ ] Forta agents para anomaly detection
- [ ] Slack/Discord alerts para events críticos
- [ ] Multi-sig para ops dia-a-dia (não EOA)
- [ ] Hardware wallets para signers
- [ ] Bug bounty ativo
- [ ] Política de disclosure
- [ ] War room procedure
```

## Cross-chain — additional risks

- **Bridges** são alvo principal (>$2B perdidos historicamente)
- Validar mensagens cross-chain com signatures threshold
- Múltiplos validators independentes
- Audit específico para bridges

## Frontend (dApp) security

- Transactions assinadas no wallet (não no servidor)
- Verificar transaction details no UI **e** no wallet (anti UI deception)
- Domain pinning para wallet connections (anti phishing)
- Limit allowances (anti unlimited approve attacks)

## Common antipatterns

### `tx.origin` para auth
- Phishable.

### `msg.value` em loops
- Reentrancy.

### `balances[from] -= amount` antes de `external call`
- Já coberto.

### Random com `block.timestamp`
- Manipulável.

### `delegatecall` com address controllable
- RCE no contract.

### Oracle único / centralizado
- Single point of failure.

### Sem timelock em upgrades / mudanças críticas
- Atacante com owner comprometido drena tudo.

### Hardcoded admin EOA
- Owner único = compromise único = catástrofe.

## Quick wins

- [ ] Solidity 0.8+
- [ ] OpenZeppelin contracts (não roll-your-own)
- [ ] Slither + Mythril sem warnings críticos
- [ ] Test coverage ≥ 95% via Foundry
- [ ] Fuzzing extensivo
- [ ] Audit profissional para mainnet
- [ ] Multi-sig + timelock para ops críticos
- [ ] Pause mechanism
- [ ] Chainlink oracles (não DEX spot price)
- [ ] Etherscan verified
- [ ] Bug bounty no Immunefi
- [ ] Monitoring (OZ Defender, Forta)
- [ ] Hardware wallets para signers
- [ ] Plano de incident response documentado
- [ ] Frontend com transaction simulation antes de assinar
