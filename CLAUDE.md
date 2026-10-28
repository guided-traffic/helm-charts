# helm-charts — guide for coding agents

Public Helm charts of guided-traffic. One directory per chart under `charts/`,
released as signed OCI artifacts to
`oci://ghcr.io/guided-traffic/helm-charts/<chart>`. Read
[docs/developer/README.md](docs/developer/README.md) before changing anything;
this file only holds what an agent gets wrong without it.

## Rules

- **Do not `git add`, `git commit`, `git push` or tag.** Prepare the change, run
  the checks, and ask Hans for review; he commits.
- **Never publish by hand.** No `helm push`, `cosign sign` or package deletion
  against ghcr.io — the [release workflow](.github/workflows/release.yml) is the
  only publisher, and its signing identity depends on that.
- **Never change a released version.** A version with a git tag
  `<chart>-<version>` is final. Fix forward with a new version.
- **Every change to a packaged file of a chart bumps `version` in its
  `Chart.yaml`** (SemVer, rules in [conventions](docs/developer/conventions.md#versioning)).
  `tests/` and `ci/` are not packaged.
- **Defaults are public.** No host names, issuers, StorageClasses, policy
  labels or credentials of one installation in `values.yaml`, `ci/` or docs.
  wds18-specific values live in the consumer (`wds18-flux-apps`).
- **English** for code, comments, docs and commit messages.

## Commands

Always through the Makefile — it uses the pinned tools in `.tools/`, never a
helm from `PATH`:

```bash
make tools                         # once, and after a pin changed
make test                          # lint + unittest + kubeconform (what CI runs)
make test CHARTS=galaxy-ng         # one chart
make check-version                 # version bump against origin/main (CI on PRs)
```

A change is done when `make test` and `make check-version` pass.

## Where things are

| Need | File |
|---|---|
| Tool versions, Kubernetes versions for kubeconform | [Makefile](Makefile) |
| What lint enforces, how kubeconform and the version check run | [scripts/chart.sh](scripts/chart.sh) |
| Release steps and recovery | [docs/developer/release.md](docs/developer/release.md) |
| What Renovate updates and how it bumps chart versions | [docs/developer/renovate.md](docs/developer/renovate.md), [renovate.json](renovate.json) |
| New chart checklist | [docs/developer/adding-a-chart.md](docs/developer/adding-a-chart.md) |
| Security gaps (`H-<n>`) | [docs/security/](docs/security/README.md) |

## Non-obvious behaviour

- **Images must be `<component>.image.{repository,tag}`.** Any other layout is
  invisible to Renovate's helm-values manager.
- **`values.schema.json` rejects unknown keys.** Adding a value means adding it
  to the schema, the chart README and, if optional, a `ci/*-values.yaml`.
- **helm-unittest suites need included templates listed.** A Deployment with a
  `checksum/config` annotation includes the ConfigMap template; list it in
  `templates:` and put `template:` on each assertion.
- **galaxy-ng images have no release tags.** Upstream publishes main-branch
  builds only; the chart defaults to `latest@sha256:…`, Renovate moves the
  digest weekly. Do not "fix" this to a commit tag in the defaults — Renovate
  cannot order commit tags.
- **The first `sources` entry in `Chart.yaml` must be this repository.** Helm
  turns it into `org.opencontainers.image.source`, which links the ghcr.io
  package to the repository; lint enforces it.
- **Docs move with the code.** A change to documented behaviour updates the
  chart README, `docs/developer/` or `docs/security/` in the same change.
