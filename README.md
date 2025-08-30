# Warren-Wallet
Buffett called Bitcoin rat poison. We call it the fuel for the next paradigm. Warren Wallet locks micro-savings for 10 years, adds DeFi yield, ENS identity, Filecoin receipts, Zama privacy, and Flare oracles — proving Web3 can beat old-school finance at its own game.”

# Warren Wallet – Hackathon Build (Base + Zama + Filecoin + ENS)

**Modo DEMO**: testnet (Base Sepolia). Sin oferta pública. Sin APY.  
Seguridad: OWASP ASVS (CSP/HSTS/validación), CI con SAST/DAST/SBOM.  
Contrato: lock 10 años, AUM 0.5% (exentos primeros 1000), withdraw 3%, rebalance 50% a Aave cada 6m, beneficiario ENS, rollover +10y.  
Multi-asset (USDC/WETH/WBTC y más vía `listAsset`).

---

## Estructura
```
contracts/
  WarrenWalletMulti.sol
  aux/CreditLineMock.sol
  mocks/MockERC20.sol
  mocks/MockPool.sol
  mocks/MockPoolAddressesProvider.sol
script/
  Deploy.s.sol
test/
  WarrenWalletMulti.t.sol
  WarrenWalletMulti_Ext.t.sol
front/
  .env.example
SECURITY.md
THREATMODEL.md
```

## Requisitos
- Foundry (`forge`, `cast`), Node 20, pnpm 9
- `forge install`:
  ```bash
  forge install foundry-rs/forge-std@v1.9.6 --no-commit
  forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
  ```

## Variables de entorno (Foundry / Deploy)
Crea `.env` en la raíz:

```
# Deployer
DEPLOYER_ADDRESS=0xYourEOA
DEPLOYER_PRIVATE_KEY=0xYourPrivateKey

# DAO Treasury (EVM)
DAO_TREASURY=0xc2bb63Dc8f0e456F3bD13C3ce1D2F730CA1bE8Fc

# Aave Provider (Base Sepolia) - si vacío, se usará un mock
AAVE_PROVIDER=0x0000000000000000000000000000000000000000

# Assets (opcional; si se setean se listan)
USDC=0x0000000000000000000000000000000000000000
WETH=0x0000000000000000000000000000000000000000
WBTC=0x0000000000000000000000000000000000000000

# Mínimos (si no, defaults: USDC 3e6, WETH 1e15, WBTC 1e6)
MIN_USDC=3000000
MIN_WETH=1000000000000000
MIN_WBTC=1000000
```

> **Nota**: en producción, usa el `PoolAddressesProvider` real de Aave en Base / Base Sepolia.
> Para demo sin dependencias externas, deja `AAVE_PROVIDER` vacío para desplegar `MockPoolAddressesProvider`.

## Deploy en Base Sepolia
```bash
source .env
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_BASE_SEPOLIA --broadcast --verify --verifier blockscout
```

- `RPC_BASE_SEPOLIA` debe apuntar a tu RPC (Alchemy/Ankr/etc.).
- Al finalizar, verás en consola la dirección de `WarrenWalletMulti`.

## Tests
```bash
forge build
forge test -vv
```

## Front (Vercel v0 / Next.js)
`front/.env.example`:
```
NEXT_PUBLIC_CHAIN_ID=84532
NEXT_PUBLIC_RPC_URL=https://sepolia.base.org
NEXT_PUBLIC_MODE=DEMO
NEXT_PUBLIC_IPFS_GATEWAY=https://ipfs.io/ipfs/
NEXT_PUBLIC_FTSO_RELAYER_URL=https://ftso-relayer.example.com
```

- UI: conectar wallet → aportar (front hace swap a WETH) → confirmar.
- Recibos: JSON en IPFS/Filecoin y evento on-chain (CID).
- Privacidad: FHE off-chain (Zama) con JSON firmado (CID).
- ENS/Basenames: resolución en front (normalizar UTS-46).

## Seguridad / Compliance
- **OWASP ASVS**: V1/V2/V3/V5/V9/V14 aplicados en pipeline y GUI.
- **CNV/UIF (Argentina)**: DEMO/testnet, sin oferta pública ni promesas de renta.
- **Supply chain**: Dependabot, SBOM (CycloneDX), firmas (`cosign`) recomendadas.

## Créditos / Mock de Crédito
`aux/CreditLineMock.sol` simula una línea de crédito con LTV y umbral. No transfiere fondos; sólo registra y emite eventos.

## Operativa de Rollover / Beneficiarios
- `setBeneficiary(id, addr, ensHash)`
- `rolloverPosition(id)` (+10 años post-vencimiento)

---

**Mantra demo**: *Disciplina > Especulación*. Todo firme, nada de APY mágico. 🍋
