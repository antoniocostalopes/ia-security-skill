# Exemplo de Auditoria — Smart Contract Solidity

> Few-shot para IAs auditarem smart contracts. **Aviso:** auditoria por IA é primeiro filtro — contracts em mainnet exigem audit profissional adicional.

## Input

### `contracts/SimpleVault.sol`
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract SimpleVault {
    mapping(address => uint256) public balances;
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient");
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        balances[msg.sender] -= amount;
    }

    function changeOwner(address newOwner) public {
        require(tx.origin == owner);
        owner = newOwner;
    }

    function emergencyWithdraw() public {
        require(msg.sender == owner);
        msg.sender.transfer(address(this).balance);
    }

    function getRandom() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
    }
}
```

---

## Output esperado

```markdown
# Relatório de Segurança — SimpleVault.sol

**Data:** 2026-05-06
**Stack:** Solidity 0.6.x · Ethereum/EVM
**Tipo:** Vault (custodia de fundos) — alto risco
**Ficheiros analisados:** 1 contract

## 1. Score: 0/100 — **Crítico — NÃO DEPLOY**

| Severidade | Qtd | Subtotal |
|---|---:|---:|
| Crítico | 5 | -100 |
| Alto    | 2 | -20 |
| Médio   | 1 | -4 |
| **Total** | 8 | **0 (cap)** |

## 2. Resumo Cliente
Este contract tem 5 vulnerabilidades críticas que permitem **drenagem total dos fundos** depositados. **Não fazer deploy em mainnet sob nenhuma circunstância.** Mesmo após correções, contract com custodia de fundos requer audit profissional (Trail of Bits, OpenZeppelin, Code4rena) antes de mainnet.

## 3. Resumo Técnico
Solidity 0.6 (sem checked arithmetic — needs SafeMath). Reentrancy clássica no withdraw (Checks-Effects-Interactions violado). tx.origin para auth (phishable). Random previsível. Owner sem multi-sig nem timelock. Falta pause mechanism. Refactor obrigatório: Solidity 0.8+, OpenZeppelin (ReentrancyGuard, Ownable, Pausable), Chainlink VRF para random, multi-sig + timelock para owner ops, NatSpec docs.

## 4. Superfícies de Ataque

| # | Função | Visibility | Risco |
|---|---|---|---|
| 1 | withdraw() | public | Crítico (reentrancy) |
| 2 | changeOwner() | public | Crítico (tx.origin auth) |
| 3 | emergencyWithdraw() | public | Crítico (owner único) |
| 4 | getRandom() | public view | Alto (previsível) |

## 5. Attack Chains

### Vetor 1 — Drain total via Reentrancy (Crítico, 100%)
- C1 (reentrancy)
- Atacante deploya contract malicioso com `receive()` que chama `withdraw()` recursivamente. Drena todo o vault numa transação.

### Vetor 2 — Tornar-se owner via tx.origin (Crítico, 100%)
- C2 (tx.origin) + phishing
- Atacante cria dApp atrativa. Owner usa-a (assina tx). dApp atacante chama `changeOwner(attacker_addr)` durante a tx. `tx.origin` é o owner → check passa.

### Vetor 3 — Random manipulation (Alto, 90%)
- C5 (random previsível) — se este vault for usado num jogo com getRandom, miner manipula timestamp.

## 6. Achados

### Críticos

#### C1. Reentrancy em withdraw
- **Categoria:** Web3 / Reentrancy (clássico)
- **Confiança:** 100%
- **Localização:** `SimpleVault.sol:18-22`
- **Código:**
  ```solidity
  function withdraw(uint256 amount) public {
      require(balances[msg.sender] >= amount, "Insufficient");
      (bool success, ) = msg.sender.call{value: amount}("");  // <-- external call ANTES
      require(success, "Transfer failed");
      balances[msg.sender] -= amount;                          // <-- estado depois
  }
  ```
- **Exploração:** Atacante deploya:
  ```solidity
  contract Attacker {
      SimpleVault vault;
      function attack() external payable {
          vault.deposit{value: 1 ether}();
          vault.withdraw(1 ether);
      }
      receive() external payable {
          if (address(vault).balance >= 1 ether) {
              vault.withdraw(1 ether);  // recursivo até drenar
          }
      }
  }
  ```
- **Correção:** Checks-Effects-Interactions + ReentrancyGuard:
  ```solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;
  import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

  contract SimpleVault is ReentrancyGuard {
      mapping(address => uint256) public balances;

      function withdraw(uint256 amount) public nonReentrant {
          require(balances[msg.sender] >= amount, "Insufficient");
          balances[msg.sender] -= amount;  // <-- estado PRIMEIRO
          (bool success, ) = payable(msg.sender).call{value: amount}("");
          require(success, "Transfer failed");
      }
  }
  ```

#### C2. tx.origin para autenticação
- **Categoria:** Web3 / Auth
- **Confiança:** 100%
- **Localização:** `SimpleVault.sol:25`
- **Código:** `require(tx.origin == owner);`
- **Explicação:** `tx.origin` é o originador da tx, **não** o caller direto. Phishable: owner usa contract malicioso → contract malicioso chama `changeOwner` → `tx.origin` é owner → passa.
- **Correção:** `require(msg.sender == owner);` (sempre `msg.sender` para auth).
- **Recomendação adicional:** usar OpenZeppelin Ownable + multi-sig.

#### C3. Owner único sem multi-sig nem timelock
- **Categoria:** Web3 / Access control
- **Confiança:** 95%
- **Localização:** Toda a estrutura `owner`
- **Explicação:** Single point of failure. Owner comprometido (private key roubada) → drena tudo via `emergencyWithdraw`. Para vault com fundos reais, multi-sig + timelock são obrigatórios.
- **Correção:**
  ```solidity
  // 1. Owner = Gnosis Safe (multi-sig 3/5)
  // 2. Mudanças críticas via TimelockController:
  import "@openzeppelin/contracts/governance/TimelockController.sol";

  // emergencyWithdraw só executável após 48h de delay público
  // Permite users sair se mudança suspeita
  ```

#### C4. Solidity 0.6 sem SafeMath
- **Categoria:** Web3 / Crypto / Math
- **Confiança:** 100%
- **Localização:** `pragma solidity ^0.6.0`
- **Explicação:** Solidity < 0.8 não tem checked arithmetic. `balances[msg.sender] += msg.value` pode dar overflow. `balances[msg.sender] -= amount` pode underflow (apesar do require, pode haver edge cases).
- **Correção:** Migrar para `pragma solidity ^0.8.20;` (checked arithmetic built-in). Se não possível, importar `@openzeppelin/contracts/utils/math/SafeMath.sol`.

#### C5. Random previsível (block.timestamp + block.difficulty)
- **Categoria:** Web3 / Randomness
- **Confiança:** 100%
- **Localização:** `SimpleVault.sol:33`
- **Código:**
  ```solidity
  return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
  ```
- **Explicação:** `block.timestamp` é manipulável por miner (range ~15s). `block.difficulty` foi removido em PoS (post-Merge). Random não é random.
- **Correção:** **Chainlink VRF** (Verifiable Random Function):
  ```solidity
  import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
  import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
  // Configurar Chainlink VRF subscription, callback returns random
  ```

### Altos

#### A1. Sem pause mechanism (circuit breaker)
- **Categoria:** Web3 / Operacional
- **Confiança:** 90%
- **Localização:** Estrutura geral
- **Explicação:** Se vulnerabilidade for descoberta pós-deploy, owner não consegue parar interações.
- **Correção:**
  ```solidity
  import "@openzeppelin/contracts/security/Pausable.sol";

  contract SimpleVault is ReentrancyGuard, Ownable, Pausable {
      function withdraw(uint256 amount) public nonReentrant whenNotPaused { ... }
      function pause() public onlyOwner { _pause(); }
      function unpause() public onlyOwner { _unpause(); }
  }
  ```

#### A2. emergencyWithdraw drena para owner sem cap nem cooldown
- **Categoria:** Web3 / Centralization risk
- **Confiança:** 80%
- **Explicação:** Owner pode drenar tudo numa tx. Confidence dos users é zero.
- **Correção:** Remover ou limitar drasticamente (ex.: max 10% por dia, com timelock).

### Médios

#### M1. Falta de events para audit trail
- **Categoria:** Web3 / Logging
- **Confiança:** 70%
- **Explicação:** Não há events emitidos. Off-chain monitoring é cego.
- **Correção:**
  ```solidity
  event Deposit(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);
  event OwnerChanged(address indexed oldOwner, address indexed newOwner);
  event EmergencyWithdraw(uint256 amount);
  ```

## 7. Plano de Correção

### Fase 1 — Antes de qualquer testnet
- [ ] C4 — Migrar para Solidity 0.8+
- [ ] C1 — Refactor withdraw com Checks-Effects-Interactions + ReentrancyGuard
- [ ] C2 — Substituir tx.origin por msg.sender
- [ ] OpenZeppelin Ownable em vez de custom owner

### Fase 2 — Antes de mainnet
- [ ] C3 — Multi-sig (Gnosis Safe) + TimelockController para owner ops
- [ ] C5 — Chainlink VRF se random for usado em produção
- [ ] A1 — Pause mechanism
- [ ] A2 — Limitar emergencyWithdraw
- [ ] M1 — Events em todas as state changes
- [ ] NatSpec docs completos
- [ ] Test coverage ≥ 95% (Foundry/Hardhat)
- [ ] Fuzzing com Echidna ou forge fuzz
- [ ] Slither sem warnings críticos
- [ ] Mythril sem high-severity

### Fase 3 — Pré-deploy mainnet
- [ ] **Audit profissional** (Trail of Bits, OpenZeppelin, ConsenSys, Code4rena)
- [ ] Bug bounty no Immunefi
- [ ] Etherscan verified
- [ ] Deployment via multi-sig

### Fase 4 — Pós-deploy
- [ ] OpenZeppelin Defender Autotasks para monitoring
- [ ] Forta agents para anomaly detection
- [ ] Alerts em Slack/Discord
- [ ] Plano de incident response documentado
- [ ] War room procedure

## 8. Checklist Pré-Mainnet

- [ ] Solidity 0.8+
- [ ] OpenZeppelin contracts (não roll-your-own)
- [ ] ReentrancyGuard em todas as funções com external calls
- [ ] Checks-Effects-Interactions
- [ ] msg.sender (não tx.origin)
- [ ] Multi-sig + timelock para owner ops
- [ ] Pause mechanism
- [ ] Events em todas as state changes
- [ ] Chainlink oracles (não DEX spot price, não block.timestamp)
- [ ] Test coverage ≥ 95%
- [ ] Fuzzing extensivo
- [ ] Slither + Mythril clean
- [ ] **Audit profissional aprovado**
- [ ] Bug bounty ativo
- [ ] Etherscan verified
- [ ] Plano de incident response documentado

## 9. Recomendações Adicionais

- **NUNCA fazer deploy de contracts financeiros sem audit profissional.** Esta análise é primeiro filtro, não substitui.
- **OpenZeppelin Wizard** para gerar contract base com best practices
- **Foundry** para testing + fuzzing nativos
- **Code4rena/Sherlock contests** para audit competitivo
- **Plano de upgrade** se contract for upgradeable (UUPS proxy)
- **Documentar tudo** — NatSpec é crítico para auditors
```
