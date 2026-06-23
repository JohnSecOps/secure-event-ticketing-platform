# Troubleshooting runbook — Secure Event Ticketing Platform

Sistematičan postupak za incidente isporuke. Za svaki scenarij: **simptom → dijagnostika →
uzrok → korektivna mjera → validacija**.

## Općeniti prvi koraci (triage)
```bash
kubectl -n ticketing get pods -o wide          # status, restartovi, čvor
kubectl -n ticketing get events --sort-by=.lastTimestamp | tail -20
kubectl -n ticketing describe pod <pod>        # zašto pod nije Ready / razlog restarta
kubectl -n ticketing logs <pod> --tail=100     # logovi aplikacije
```
`api` i `frontend` izlažu `/healthz` (liveness) i `api` dodatno `/readyz` (provjera DB+Redis).

---

## Scenarij 1 — Pad baze podataka (PostgreSQL nedostupan)

**Simptom:** `api` `/readyz` vraća `503 not-ready`; nove narudžbe se ne pojavljuju u
`/tickets/orders`; `worker` logira `Redis/PG error`.

**Dijagnostika:**
```bash
kubectl -n ticketing get pods -l app.kubernetes.io/name=postgres
kubectl -n ticketing logs ticketing-postgres-0 --tail=50
kubectl -n ticketing describe pod ticketing-postgres-0   # PVC, OOMKilled, probe failure
```

**Mogući uzroci i mjere:**
- Pod restartan / na novom čvoru → StatefulSet ga sam ponovno pokreće; pričekaj da prođe
  `readinessProbe` (`pg_isready`). Podaci preživljavaju jer su na PVC-u.
- `OOMKilled` → povećaj `postgres.resources.limits.memory` i `helm upgrade`.
- PVC se ne montira → provjeri `kubectl get pvc -n ticketing` i StorageClass.

**Ključno:** narudžbe poslane tijekom pada **ostaju u Redis redu** i `worker` ih obradi
čim baza ponovno postane dostupna (red djeluje kao buffer). Nema gubitka narudžbi.

**Validacija:** `/readyz` → `200`; `curl /tickets/orders` prikazuje zaostale narudžbe.

---

## Scenarij 2 — Loš image tag (deployment ne kreće)

**Simptom:** novi podovi u `ImagePullBackOff` / `ErrImagePull`; rollout zapne.

**Dijagnostika:**
```bash
kubectl -n ticketing get pods
kubectl -n ticketing describe pod <api-pod> | grep -A5 Events   # "manifest unknown"
kubectl -n ticketing rollout status deploy/ticketing-api --timeout=60s
```

**Uzrok:** `image.tag` pokazuje na nepostojeću/nepotpisanu sliku (npr. krivi SHA).

**Korektivna mjera (rollback):**
```bash
helm history ticketing -n ticketing
helm rollback ticketing <zadnja-ispravna-revizija> -n ticketing
kubectl -n ticketing rollout status deploy/ticketing-api
```
Zahvaljujući `maxUnavailable: 0`, stari podovi se ne gase dok novi ne postanu Ready —
pa loš tag **ne ruši uslugu**, rollout samo zapne i lako se vrati.

**Validacija:** svi podovi `Running`/`Ready`; `helm history` pokazuje uspješnu reviziju.

---

## Scenarij 3 — Neispravan secret (kriva lozinka baze)

**Simptom:** `api`/`worker` u `CrashLoopBackOff` ili stalno `not-ready`; logovi:
`password authentication failed for user "ticketing_user"`.

**Dijagnostika:**
```bash
kubectl -n ticketing logs deploy/ticketing-api --tail=30
kubectl -n ticketing get secret ticketing-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
# usporedi s lozinkom kojom je inicijaliziran PostgreSQL data volume
```

**Uzrok:** `Secret` promijenjen nakon što je PostgreSQL volume već inicijaliziran starom
lozinkom (Postgres lozinku postavlja samo pri prvoj inicijalizaciji praznog volumena).

**Korektivne mjere:**
- Uskladi `secret.POSTGRES_PASSWORD` s postojećom lozinkom baze, ili
- (test okruženje) presetaj bazu: `helm uninstall` + obriši PVC + ponovno instaliraj s
  novim secretom, ili promijeni lozinku unutar baze (`ALTER USER ... PASSWORD ...`).
- Nakon promjene secreta restartaj potrošače: `kubectl rollout restart deploy/ticketing-api deploy/ticketing-worker -n ticketing`.

**Validacija:** `/readyz` → `200`; `worker` logira `Order processed`.

---

## Scenarij 4 — Lokalno (Compose): stack se ne diže

```bash
docker compose ps                 # koji servis nije healthy
docker compose logs api --tail=50
docker compose logs postgres --tail=50
```
- `api`/`worker` ne mogu na bazu → provjeri `.env` (`POSTGRES_*`) i da je `postgres` healthy.
- Port zauzet (8080/3000/5432) → promijeni `API_PORT`/`FRONTEND_PORT` u `.env`.
- Čisti reset: `docker compose down -v && docker compose up --build`.

---

## Eskalacija
Ako nakon korektivnih mjera usluga nije obnovljena, snimi `kubectl get events`,
`kubectl logs` i `helm history` te eskaliraj uz priložene dokaze. Svaki incident
zabilježi (vrijeme, simptom, uzrok, mjera) radi blameless post-mortema.
