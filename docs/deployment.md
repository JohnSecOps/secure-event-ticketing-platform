# Deployment upute

## 1. Lokalni razvoj (Docker Compose)

### Preduvjeti
- Docker Engine 24+ s Docker Compose v2 (`docker compose version`)

### Pokretanje
```bash
cp .env.example .env
docker compose up --build -d
docker compose ps            # svi servisi trebaju biti "healthy"
```

Redoslijed pokretanja je kontroliran preko `depends_on` + healthcheckova:
`postgres` i `redis` moraju biti `healthy` prije nego krenu `api` i `worker`,
a `frontend` čeka da `api` postane `healthy`.

### Validacija
```bash
curl -s http://localhost:8080/healthz
curl -s http://localhost:8080/readyz
curl -s http://localhost:8080/events | head
curl -s -X POST http://localhost:8080/tickets/purchase \
  -H "Content-Type: application/json" \
  -d '{"eventId":"evt-1001","customerEmail":"student@example.com","quantity":2}'
sleep 1
curl -s http://localhost:8080/tickets/orders
```
Posljednji poziv mora vratiti narudžbu sa `status: processed` — to dokazuje cijeli tok
`api → redis → worker → postgres`.

### Hot-reload (razvoj)
```bash
docker compose -f compose.yaml -f compose.dev.yaml up --build
```
Izvorni kod je bind-mountan i `nodemon` restarta servis na svaku promjenu.

### Zaustavljanje
```bash
docker compose down       # zaustavi kontejnere, zadrži podatke (volume pgdata)
docker compose down -v    # potpuni reset (briše i podatke)
```

### Perzistencija
PostgreSQL podaci žive u imenovanom volumenu `pgdata`. `docker compose down` ih čuva;
samo `down -v` ih briše. Shema se inicijalizira iz `app/infra/postgres/init.sql`
pri prvom pokretanju praznog volumena.

---

## 2. Produkcija (Kubernetes / Helm)

### Preduvjeti
- Kubernetes 1.27+ klaster s Ingress controllerom (npr. ingress-nginx)
- `kubectl` i `helm` 3.x
- Pristup registru sa skeniranim slikama (GHCR)

### Instalacija
```bash
kubectl create namespace ticketing

helm upgrade --install ticketing helm/ticketing -n ticketing \
  --set image.tag=<git-sha-iz-CI> \
  --set secret.POSTGRES_PASSWORD="$(openssl rand -base64 24)"

kubectl -n ticketing rollout status deploy/ticketing-api
kubectl -n ticketing get pods,svc,ingress
```

### Pristup
Dodaj host u `/etc/hosts` (IP Ingress controllera):
```
<INGRESS_IP>  ticketing.local
```
- UI:        `http://ticketing.local/`
- API health: `http://ticketing.local/api/healthz`

### Rolling update
```bash
helm upgrade ticketing helm/ticketing -n ticketing --set image.tag=<novi-sha>
kubectl -n ticketing rollout status deploy/ticketing-api
```
Strategija `RollingUpdate` (`maxUnavailable: 0`, `maxSurge: 1`) održava puni kapacitet
tijekom nadogradnje; novi pod mora proći readiness probe prije gašenja starog.

### Rollback
```bash
helm history ticketing -n ticketing
helm rollback ticketing <REVIZIJA> -n ticketing
kubectl -n ticketing rollout status deploy/ticketing-api
```

### Sigurnosne postavke (ukratko)
- Tajne se predaju kroz `--set` / secrets manager, nikad u git.
- `Secret` objekt drži `POSTGRES_PASSWORD`; `ConfigMap` drži ne-tajnu konfiguraciju.
- `NetworkPolicy` dozvoljava promet do baze/Redisa samo iz `api` i `worker` podova.
- Svi podovi rade kao non-root (UID 10001), bez privilegija, s read-only root FS
  (osim PostgreSQL koji mora pisati u svoj data direktorij).

Vidi i [`runbook.md`](runbook.md) za incidente.
