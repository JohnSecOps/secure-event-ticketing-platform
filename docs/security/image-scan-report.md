# Sigurnosno izvješće — skeniranje kontejnerskih slika

Alat: **Trivy** (aquasec/trivy:latest, vuln DB osvježen pri skeniranju)
Datum skeniranja: **2026-06-22**
Opseg: tri aplikacijske slike (`ticketing-api`, `ticketing-frontend`, `ticketing-worker`)
Filter: `--severity HIGH,CRITICAL --ignore-unfixed` (prikazani samo popravljivi nalazi)
Sirovi izlaz: [`../evidence/trivy-scan.txt`](../evidence/trivy-scan.txt)

## Sažetak nalaza

Sve tri slike dijele istu baznu sliku (`node:22.14-alpine`) i isti skup paketa, pa su nalazi identični po slici.

| Slika | Cilj | Tip | HIGH | CRITICAL | Ukupno |
|-------|------|-----|-----:|---------:|-------:|
| ticketing-api / frontend / worker | alpine 3.21.3 (OS paketi) | OS | 15 | 2 | 17 |
| ticketing-api / frontend / worker | Node.js (node-pkg) | aplikacija | 22 | 0 | 22 |
| **Po slici** | | | **37** | **2** | **39** |

Veličine slika (multi-stage, alpine runtime): `api` 236 MB, `frontend` 230 MB, `worker` 231 MB
(content size ~56 MB; disk usage uključuje dijeljene slojeve).

## Ključni nalazi

**OS sloj (Alpine — OpenSSL/musl/zlib):**

| CVE | Paket | Severity | Status | Popravak |
|-----|-------|----------|--------|----------|
| CVE-2026-31789 | libcrypto3 / libssl3 | CRITICAL | fixed | openssl 3.3.7-r0 (heap buffer overflow na 32-bit) |
| CVE-2026-28387/28388/28389/28390 | libcrypto3 / libssl3 | HIGH | fixed | openssl 3.3.7-r0 (RCE/DoS) |
| CVE-2025-15467, CVE-2025-69421 | libssl3 | HIGH | fixed | openssl 3.3.6-r0 |
| CVE-2026-40200 | musl / musl-utils | HIGH | fixed | musl 1.2.5-r11 |
| CVE-2026-22184 | zlib | HIGH | fixed | zlib 1.3.2-r0 |

**Node.js sloj (npm-bundlane ovisnosti — glob/minimatch/tar):**

| CVE | Paket | Severity | Popravak |
|-----|-------|----------|----------|
| CVE-2025-64756 | glob | HIGH | 10.5.0 (command injection) |
| CVE-2026-26996/27903/27904 | minimatch | HIGH | 9.0.7 (ReDoS / DoS) |
| CVE-2026-23745/23950/24842/26960/29786/31802 | tar (node-tar) | HIGH | 7.5.11 (path traversal / file overwrite) |

## Analiza i korektivne mjere

Nalazi potječu iz **prikvačene (pinned) bazne slike** `node:22.14-alpine`. Slika je
reproducibilna i deterministička, ali s vremenom „zaostaje" — od trenutka prikvačivanja
do datuma skeniranja objavljeni su sigurnosni popravci za OpenSSL, musl, zlib i npm
alate. **Svi prikazani nalazi su `fixed` (popravljivi) — nema nepopravljenih ranjivosti.**

Korektivne mjere (planirano):

1. **Re-base / rebuild na najnoviji patch** bazne slike `node:22-alpine` (povlači
   OpenSSL 3.3.7-r0, musl 1.2.5-r11, zlib 1.3.2-r0 i osvježeni npm s popravljenim
   glob/minimatch/tar). Ponovno skeniranje treba pokazati 0 HIGH/CRITICAL.
2. **Automatizirano osvježavanje** bazne slike (npr. Dependabot / Renovate na
   `FROM` retke + tjedni rebuild) kako bi se spriječilo ponovno zaostajanje.
3. **Quality gate u CI-u** (`.github/workflows/ci.yaml`) već blokira objavu:
   `trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed` —
   slika se ne push-a u registar dok nalazi nisu riješeni.

## Politika objave slika (image policy)

- Slike se grade **multi-stage** (build alat se ne nalazi u runtime sloju).
- Runtime sloj je **minimalan alpine** i radi kao **non-root** (UID 10001) — potvrđeno
  u izvršnom okruženju (`id` → `uid=10001(app)`), vidi [`../evidence/workflow.txt`](../evidence/workflow.txt).
- **Tagging:** semantička verzija (`type=semver`), kratki git SHA (`type=sha`) i
  `latest` samo na default grani. Deployment u produkciju koristi nepromjenjiv SHA tag.
- Slika se objavljuje **tek nakon** prolaska skeniranja (gate) i dependency audita.
- SARIF izvješće se učitava u GitHub Security tab radi evidencije i praćenja trenda.
