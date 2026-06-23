# Sažetak validacije artefakata

Sve provjere izvedene 2026-06-22 na Docker Desktop hostu (osim gdje je navedeno).

| Provjera | Alat | Rezultat |
|----------|------|----------|
| Sintaksa aplikacijskog koda (api/frontend/worker) | `node --check` | PASS (sve 3) |
| Dockerfile best-practices (api/frontend/worker) | hadolint | PASS — exit 0, bez upozorenja |
| Helm chart lint | `helm lint` | PASS — 1 chart, 0 failed (samo INFO: icon preporučen) |
| Helm render | `helm template` | PASS — 21 objekata renderirano ([`rendered-manifests.yaml`](rendered-manifests.yaml)) |
| Renderirani manifesti — parsiranje i sanity | PyYAML | PASS — svi Deployment/StatefulSet imaju `runAsNonRoot` i `resources` |
| compose.yaml / ci.yaml — well-formedness | PyYAML | PASS |
| Skeniranje ranjivosti slika | Trivy image | Izvedeno — nalazi u [`../security/image-scan-report.md`](../security/image-scan-report.md) |
| IaC misconfig skeniranje | Trivy config | Izvodi se u CI-u (`.github/workflows/ci.yaml`); lokalno preskočeno (spor dohvat policy bundle-a) |

## Renderirani Kubernetes objekti (iz `helm template`)

```
2x ConfigMap        4x Deployment       1x Ingress
5x NetworkPolicy    1x Role             1x RoleBinding
1x Secret           4x Service          1x ServiceAccount
1x StatefulSet
```
Ukupno 21 objekt. Svi radni objekti (Deployment/StatefulSet) imaju definiran
`securityContext.runAsNonRoot: true` i `resources` (requests/limits).

## Napomena o hadolint i helm lint

`hadolint` je prošao bez i jednog upozorenja na sve tri slike — potvrđuje da
Dockerfile-ovi slijede preporuke (pinned bazna slika, `npm ci` iz lockfilea,
nema `latest` taga, definiran `USER`, `HEALTHCHECK` i `WORKDIR`).
`helm lint` potvrđuje strukturnu ispravnost charta.
