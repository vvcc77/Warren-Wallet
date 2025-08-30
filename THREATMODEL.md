# THREATMODEL.md

- Actores:
  - Usuario final, Admin (DEFAULT_ADMIN_ROLE), Risk Admin (RISK_ADMIN_ROLE).
  - Atacante web (XSS/CSRF), phishing de seed (fuera de alcance del dApp).

- Suposiciones:
  - On-chain: ERC-20 válidos; Aave provider aprobado.
  - Off-chain: FHE Zama para agregados; IPFS/Filecoin para recibos; relayer FTSO confiable.

- Riesgos y mitigaciones:
  - Reentrancy → `nonReentrant` + CEI.
  - Manipulación de parámetros → checks y límites, roles.
  - Pérdida de CIDs → pinning/deals en Filecoin.
  - Datos sensibles → No PII; FHE para montos/fechas; sólo agregados públicos.
  - Oráculos → Relayer firmado; verificación de firmas (pendiente si se requiere on-chain).

- Futuro:
  - Integrar oráculos de precio para mínimos en USD reales.
  - Auditoría externa antes de producción.
