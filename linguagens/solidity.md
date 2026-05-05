# Solidity — Cartão de Segurança (Smart Contracts)

> Categoria à parte: contratos correm em blockchain pública, são imutáveis após deploy, e cada bug pode custar milhões. Este cartão é primer; auditoria a sério usa Slither, Mythril, Foundry fuzzing, e revisão humana.

## Vulnerabilidades clássicas

### 1. Reentrancy
```solidity
// BAD
function withdraw(uint amount) public {
    require(balances[msg.sender] >= amount);
    (bool ok, ) = msg.sender.call{value: amount}("");
    require(ok);
    balances[msg.sender] -= amount;  // estado atualizado DEPOIS da call
}
// Atacante reentra via fallback → drena balance

// GOOD — Checks-Effects-Interactions
function withdraw(uint amount) public {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;  // estado primeiro
    (bool ok, ) = msg.sender.call{value: amount}("");
    require(ok);
}

// MELHOR — ReentrancyGuard
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
contract X is ReentrancyGuard {
    function withdraw(uint amount) public nonReentrant { ... }
}
```

### 2. Integer overflow / underflow
- **Solidity 0.8+** tem checked arithmetic por default. Pre-0.8 era unchecked.
```solidity
// PRE 0.8 — SafeMath obrigatório
using SafeMath for uint256;
balance = balance.sub(amount);  // throws em underflow

// 0.8+ — automático, mas:
unchecked { balance -= amount; }  // EXPLÍCITO se quiseres bypass
```

### 3. Access control
```solidity
// BAD — sem modifier
function setOwner(address newOwner) public {
    owner = newOwner;  // qualquer um!
}

// GOOD
modifier onlyOwner() {
    require(msg.sender == owner, "not owner");
    _;
}
function setOwner(address newOwner) public onlyOwner {
    owner = newOwner;
}

// MELHOR — OpenZeppelin Ownable / AccessControl
import "@openzeppelin/contracts/access/Ownable.sol";
contract X is Ownable {
    function setX() public onlyOwner { ... }
}
```

### 4. `tx.origin` para auth
```solidity
// BAD — phishable via contract intermediário
require(tx.origin == owner);

// GOOD
require(msg.sender == owner);
```

### 5. Front-running / MEV
- Mempool é público — atacante vê tx pendente, submete a sua com gas mais alto.
- **Proteções:**
  - Commit-reveal (compromete-se com hash, depois revela)
  - Off-chain orderbook + on-chain settlement
  - Submarine sends
  - Flashbots / private mempool

### 6. Oracle manipulation
```solidity
// BAD — usar price de uma DEX num único bloco (flash loan attack)
uint price = getDEXPrice(token);  // manipulável dentro do mesmo bloco
liquidate(user, price);

// GOOD — usar TWAP (time-weighted average) ou oracle confiável
uint price = chainlinkOracle.latestAnswer();  // Chainlink price feed
```

### 7. `delegatecall` perigoso
```solidity
// BAD — delegatecall para endereço controlável
function execute(address target, bytes memory data) public {
    target.delegatecall(data);  // executa código de target NO CONTEXTO deste contract → roubo
}
```

### 8. Uninitialized storage pointers (pre 0.5.0)
- Versões antigas tinham bug onde local variables apontavam para slot 0.
- Solidity 0.5+ exige inicialização explícita.

### 9. Random na blockchain
```solidity
// BAD — block.timestamp, blockhash são previsíveis
function lottery() public {
    uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
    // miner pode manipular
}

// GOOD — Chainlink VRF (Verifiable Random Function)
```

### 10. Denial of Service via gas
```solidity
// BAD — loop sobre array unbounded
function payAll() public {
    for (uint i = 0; i < users.length; i++) {
        users[i].transfer(amount);
    }
}
// Se users.length cresce → tx fica acima do gas limit → contract bloqueado

// GOOD — pull pattern
mapping(address => uint) public pendingWithdrawals;
function withdraw() public {
    uint amount = pendingWithdrawals[msg.sender];
    pendingWithdrawals[msg.sender] = 0;
    payable(msg.sender).transfer(amount);
}
```

### 11. Unchecked external call return
```solidity
// BAD
recipient.call{value: amount}("");  // ignora se falhou

// GOOD
(bool ok, ) = recipient.call{value: amount}("");
require(ok, "call failed");
```

### 12. Storage layout em proxies
- Upgrades via proxy precisam de manter storage layout idêntico.
- Adicionar variável no meio → corrupção de storage.
- Usar OpenZeppelin Upgrades + storage gaps.

## Padrões obrigatórios

### Checks-Effects-Interactions
1. Verificar pré-condições (`require`).
2. Atualizar estado.
3. Interagir com contracts externos.

### Pull over Push
- Em vez de "push" de pagamentos (loop a transferir), guardar valores e users sacam.

### Circuit breakers
```solidity
bool public stopped = false;
modifier stopInEmergency { require(!stopped); _; }
function pause() public onlyOwner { stopped = true; }
function withdraw() stopInEmergency public { ... }
```

### Use OpenZeppelin
- `@openzeppelin/contracts` é audited e battle-tested.
- ERC20, ERC721, AccessControl, ReentrancyGuard, etc.

## Ferramentas obrigatórias

| Tool | Para |
|---|---|
| **Slither** | Static analysis (Trail of Bits) |
| **Mythril** | Symbolic execution |
| **Echidna** | Property-based fuzzing |
| **Foundry** (`forge test`) | Testes + fuzzing nativos |
| **Hardhat** + plugins | Testing/deploy framework |
| **Tenderly** | Simulation, debug |
| **OpenZeppelin Defender** | Operations, monitoring |

## Audit obrigatório antes de deploy mainnet

- Para qualquer contract com TVL > $0, **audit profissional** (Trail of Bits, OpenZeppelin, ConsenSys Diligence, Code4rena contest).
- Múltiplos auditors > um único.
- Bug bounty pós-deploy (Immunefi).

## Quick wins (faz isto antes de deploy)

- [ ] Solidity 0.8+ (checked arithmetic)
- [ ] OpenZeppelin para ERC20/721/AccessControl/ReentrancyGuard
- [ ] `nonReentrant` em todas as funções com external calls + state changes
- [ ] Checks-Effects-Interactions sempre
- [ ] Pull over Push para pagamentos múltiplos
- [ ] `msg.sender`, nunca `tx.origin` para auth
- [ ] Chainlink ou similar para oracles (não DEX spot price)
- [ ] Chainlink VRF para randomness
- [ ] Slither sem warnings críticos
- [ ] Mythril sem high-severity findings
- [ ] Test coverage ≥ 95% via Foundry/Hardhat
- [ ] Fuzzing com Echidna ou Foundry
- [ ] Audit profissional para mainnet
- [ ] Pause/upgrade mechanism (com timelock + multisig)
- [ ] Monitoring pós-deploy (Tenderly, OpenZeppelin Defender)
- [ ] Bug bounty no Immunefi
- [ ] Storage layout documentado e versionado
- [ ] `unchecked { }` blocks comentados com justificação
- [ ] Eventos emitidos para todas as state changes críticas
- [ ] License explícita (`SPDX-License-Identifier`)
- [ ] Verificar contract no Etherscan/Polygonscan/etc após deploy
