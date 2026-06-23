# Dokazi o pokretanju infrastrukture (evidence)

Ovi dokazi prikupljeni su pokretanjem cijelog stacka na Docker Desktopu
(Docker Engine 29.5.3, Docker Desktop 4.78.0) dana 2026-06-22, naredbom
`docker compose up --build -d`, te izvođenjem funkcionalnog workflowa i
sigurnosnog skeniranja slika.

## Datoteke
- [`workflow.txt`](workflow.txt) — `docker compose ps`, popis slika, provjera non-root
  korisnika i cijeli funkcionalni tok (health, readiness, events, purchase, orders).
- [`trivy-scan.txt`](trivy-scan.txt) — potpuni izlaz Trivy skeniranja triju slika.
- [`environment.txt`](environment.txt) — verzije Dockera/Engine-a korištene pri pokretanju.

## Što je dokazano

**1. Svih 5 servisa radi i zdravo je (`docker compose ps`):**
```
ticketing-api-1        ticketing-api          Up (healthy)   0.0.0.0:8080->8080/tcp
ticketing-frontend-1   ticketing-frontend     Up (healthy)   0.0.0.0:3000->3000/tcp
ticketing-postgres-1   postgres:16.4-alpine   Up (healthy)   5432/tcp
ticketing-redis-1      redis:7.4-alpine       Up (healthy)   6379/tcp
ticketing-worker-1     ticketing-worker       Up (healthy)
```

**2. Kontejneri rade kao non-root (hardening):**
```
api      -> uid=10001(app) gid=10001(app)
frontend -> uid=10001(app) gid=10001(app)
worker   -> uid=10001(app) gid=10001(app)
```

**3. Funkcionalni tok od kraja do kraja:**
```
GET  /healthz            -> {"status":"ok","service":"api"}
GET  /readyz             -> {"status":"ready"}            (Postgres + Redis dostupni)
GET  /events             -> 3 eventa
POST /tickets/purchase   -> {"message":"Order queued","orderId":"afc67b7f-..."}
GET  /tickets/orders     -> narudžba status:"processed"  (worker -> Postgres)
frontend /               -> HTTP 200
worker logs              -> "Worker started..." / "Order processed"
```
Narudžba prolazi puni put `api -> redis -> worker -> postgres`, a u listi narudžbi
vidljive su narudžbe iz dva odvojena pokretanja — dokaz **perzistencije** podataka
preko Postgres volumena.

**4. Sigurnosno skeniranje slika (Trivy):** vidi
[`../security/image-scan-report.md`](../security/image-scan-report.md).
