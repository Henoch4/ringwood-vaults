# Ringwood Vaults — Yield Autocompounder

> Ringwood Vaults compound external yield automatically: deposit once, the vault scans rewards every epoch, harvests and restakes them into the position - everyone pays gas for themselves.

## What it does

Ringwood Vaults compound external yield automatically: deposit once, the vault scans rewards every epoch, harvests and restakes them into the position - everyone pays gas for themselves. The entire lifecycle lives in one contract, every button in the UI calls a real function on it — there is no mock backend.

## Contract

| | |
|---|---|
| File | `contracts/YieldAutoCompounder.sol` |
| Contract name | `YieldAutoCompounder` (inherits `ReentrancyGuard, Ownable`) |
| Solidity | `^0.8.20` |
| State functions | 8 (of which 0 payable) |
| Deployed (mainnet 677) | not yet deployed — placeholder `0x000…000` |

### Function surface

| Function | Type | Returns |
|---|---|---|
| `owner` | view | address |
| `createVault` | write | uint256 |
| `deposit` | write | result / revert |
| `compound` | write | result / revert |
| `withdraw` | write | result / revert |
| `pauseVault` | write | result / revert |
| `resumeVault` | write | result / revert |
| `getVault` | view | address owner, address token, uint256 balance, uint256 interval, uint256 lastCompound, uint256 totalCompounded, bool active |

### Events

| Event | Signature |
|---|---|
| `OwnershipTransferred` | (address indexed previousOwner, address indexed newOwner) |
| `VaultCreated` | (uint256 indexed vid, address indexed owner, address token, uint256 interval) |
| `Compounded` | (uint256 indexed vid, address indexed owner, uint256 amount) |
| `VaultPaused` | (uint256 indexed vid, address indexed owner) |
| `VaultResumed` | (uint256 indexed vid, address indexed owner) |

## Network

| | |
|---|---|
| Chain | BOT Chain Mainnet (chainId `677`) |
| RPC | `https://rpc.botchain.ai` |
| Explorer | `https://scan.botchain.ai` |
| Native currency | BOT (18 decimals) |
| Testnet | BOT Chain Testnet (chainId `968`) - `https://rpc.bohr.life` |

## Frontend

- **Wallet connection** - [Reown/AppKit](https://reown.com) (Web3Modal v2, inline modal, `subscribeAccount` / `subscribeNetwork`)
- **Web3 library** - ethers.js v6 (`BrowserProvider`, `Contract`, `parseEther`)
- **Animation** - GSAP 3 + ScrollTrigger (`expo.out` entrances, `prefers-reduced-motion` fallback renders content instantly)
- **Zero build step** - single `index.html`, CDN imports via ESM import map; no bundler, no framework runtime
- **Accessibility** - auto-generated `aria-label`s on all binary and form controls, focus-visible styles, button busy states

## Run it locally

```bash
git clone https://github.com/Henoch4/yield-autocompounder.git
cd yield-autocompounder
# open the frontend directly (no build step)
start frontend/index.html   # Windows
# or serve it if your browser blocks file:// modules:
npx serve frontend
```

> **Note** — contract addresses: the UI reads its deploy target from the `CA` constant at the top of the inline script. Until the contract is deployed to mainnet 677, the demo runs against the deterministic sample data built into the page; after deployment, set `CA['677']` to the real address and every button goes live.