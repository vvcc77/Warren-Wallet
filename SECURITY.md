# SECURITY.md

- OWASP ASVS 5.0 baseline:
  - V1: Security policy visible (este archivo) + banners en UI (MODO DEMO).
  - V2: Secrets en servidor/CI, nunca en cliente.
  - V3: CSP estricta, HSTS, X-Content-Type-Options, Referrer-Policy.
  - V5: Validación de entradas estricta (Zod/DTOs), sin `dangerouslySetInnerHTML`.
  - V9: RBAC deny-by-default para rutas admin.
  - V14: SAST (Slither/Solhint), DAST (ZAP baseline), SBOM (CycloneDX), Dependabot.

- Smart contracts:
  - CEI, nonReentrant, Pausable, límites de parámetros, eventos exhaustivos.
  - Sin early withdraw. Fees explícitos. Mínimo depósito por asset.
  - Multi-asset controlado por lista blanca (`listAsset`).

- Infra:
  - Branch protection, firmas de commits recomendadas.
  - Cosign para contenedores; lock down de tokens CI/CD.
