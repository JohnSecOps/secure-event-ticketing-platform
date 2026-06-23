# Secure Event Ticketing Platform — DevSecOps projekt

Sigurna višeslojna aplikacija za prodaju ulaznica, isporučena kroz cijeli DevOps/DevSecOps ciklus:
lokalni razvoj (Docker Compose), CI/CD s sigurnosnim provjerama (GitHub Actions + Trivy) i
produkcijska orkestracija na Kubernetesu (Helm chart).

## Arhitektura

| Servis     | Tehnologija        | Uloga                                            | Port |
|------------|--------------------|--------------------------------------------------|------|
| `frontend` | Node.js / Express  | Web UI za pregled evenata i kupnju ulaznica      | 3000 |
| `api`      | Node.js / Express  | REST API: eventi, narudžbe, health/readiness     | 8080 |
| `worker`   | Node.js            | Pozadinska obrada narudžbi iz reda (Redis → DB)  | —    |
| `postgres` | PostgreSQL 16      | Trajna pohrana narudžbi                          | 5432 |
| `redis`    | Redis 7            | Red/cache za asinkronu obradu narudžbi           | 6379 |

Tok narudžbe: `frontend → api` (validacija) `→ redis` (red) `→ worker` (obrada) `→ postgres` (trajna pohrana).

```
        ┌──────────┐      ┌────────┐      ┌─────────┐
 user → │ frontend │ ───▶ │  api   │ ───▶ │  redis  │
        └──────────┘      └────────┘      └─────────┘
                              │                 │
                              ▼                 ▼
                          ┌────────┐        ┌────────┐
                          │postgres│ ◀───── │ worker │
                          └────────┘        └────────┘
```

## Struktura repozitorija

```
.
├── app/                       # izvorni kod aplikacije (frontend, api, worker, postgres init)
│   └── <servis>/Dockerfile    # multi-stage, non-root Containerfile po servisu
├── compose.yaml               # Dio 1: lokalni stack (jedna naredba)
├── compose.dev.yaml           # hot-reload overlay za razvoj
├── .env.example               # primjer environment varijabli / lokalnih tajni
├── helm/ticketing/            # Dio 2: produkcijski Helm chart za Kubernetes
├── .github/workflows/ci.yaml  # CI/CD pipeline s DevSecOps kontrolama
└── docs/
    ├── deployment.md          # upute za lokalni i produkcijski deployment
    ├── runbook.md             # troubleshooting runbook za incidente
    ├── evidence/              # dokazi o pokretanju (logovi, ispisi)
    └── security/image-scan-report.md   # izvješće skeniranja slika (Trivy)
```

## Dio 1 — Lokalni razvoj (Docker Compose)

```bash
cp .env.example .env          # lokalne tajne (git-ignored)
docker compose up --build     # podigni cijeli stack jednom naredbom
```

Validacija funkcionalnosti:

```bash
curl http://localhost:8080/healthz       # {"status":"ok","service":"api"}
curl http://localhost:8080/readyz        # {"status":"ready"}  (DB + Redis spremni)
curl http://localhost:8080/events        # lista evenata
curl -X POST http://localhost:8080/tickets/purchase \
  -H "Content-Type: application/json" \
  -d '{"eventId":"evt-1001","customerEmail":"student@example.com","quantity":2}'
curl http://localhost:8080/tickets/orders   # obrađena narudžba (worker → postgres)
# UI: http://localhost:3000
```

Hot-reload razvojni način (nodemon, bind-mount izvora):

```bash
docker compose -f compose.yaml -f compose.dev.yaml up --build
```

Zaustavljanje:

```bash
docker compose down            # zaustavi i ukloni kontejnere
docker compose down -v         # + obriši volume s podacima (čisti reset)
```

Detaljne upute: [`docs/deployment.md`](docs/deployment.md).

## Dio 2 — Produkcija (Kubernetes / Helm)

```bash
kubectl create namespace ticketing
helm upgrade --install ticketing helm/ticketing -n ticketing \
  --set image.tag=<git-sha> \
  --set secret.POSTGRES_PASSWORD=<jaka-lozinka>
kubectl -n ticketing rollout status deploy/ticketing-api
```

Rolling update i rollback:

```bash
helm upgrade ticketing helm/ticketing -n ticketing --set image.tag=<novi-sha>
helm rollback ticketing -n ticketing       # vrati na prethodnu reviziju
```

Detaljne upute, sigurnosne postavke i runbook: [`docs/deployment.md`](docs/deployment.md),
[`docs/runbook.md`](docs/runbook.md).

## Sigurnosni elementi (DevSecOps)

- Multi-stage build, minimalna `alpine` runtime slika, **non-root** korisnik (UID 10001)
- Razdvojena konfiguracija: `ConfigMap` (ne-tajno) + `Secret` (tajne), bez hardkodiranih lozinki
- `liveness`/`readiness` probe za sve ključne servise
- `resources` requests/limits za sve servise
- `ServiceAccount` + minimalni RBAC, bez automatskog mountanja tokena (least privilege)
- `NetworkPolicy` segmentacija (default-deny + eksplicitni dozvoljeni tokovi)
- Trivy skeniranje slika i IaC konfiguracije u CI-u kao **quality gate** prije objave
- `readOnlyRootFilesystem`, drop svih Linux capabilities, `seccomp: RuntimeDefault`

Izvješće skeniranja: [`docs/security/image-scan-report.md`](docs/security/image-scan-report.md).
