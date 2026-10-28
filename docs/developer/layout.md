# Repository layout

```
helm-charts/
├── charts/
│   └── <chart>/                  # one chart; directory name = Chart.yaml name
│       ├── Chart.yaml            # version = release trigger
│       ├── values.yaml           # defaults; images as <component>.image.{repository,tag}
│       ├── values.schema.json    # rejects unknown keys
│       ├── README.md             # values reference, upgrade notes (packaged)
│       ├── .helmignore           # keeps tests/ and ci/ out of the package
│       ├── templates/
│       ├── ci/*-values.yaml      # extra values sets for lint and kubeconform
│       └── tests/*_test.yaml     # helm-unittest suites
├── scripts/
│   ├── chart.sh                  # lint, unittest, kubeconform, check-version, release-plan
│   └── install-tool.sh           # download + checksum-verify + install one binary
├── .github/workflows/
│   ├── ci.yml                    # Chart CI (job lint-test)
│   ├── release.yml               # Release Charts
│   └── renovate.yml              # Renovate Dependencies
├── docs/
│   ├── developer/                # this guide
│   └── security/                 # security architecture, one page per perspective
├── Makefile                      # tool pins, targets used locally and in CI
├── renovate.json
├── CLAUDE.md                     # guidance for coding agents
├── SECURITY.md
├── .tools/                       # (gitignored) pinned binaries from `make tools`
└── .dist/                        # (gitignored) packages from `make package`
```

## Responsibilities

| File | Responsibility |
|---|---|
| [Makefile](../../Makefile) | Pins `HELM_VERSION`, `KUBECONFORM_VERSION`, `HELM_UNITTEST_VERSION` (Renovate comments above each); `KUBERNETES_VERSIONS`; installs each tool to `.tools/<tool>-<version>/`; targets `lint`, `unittest`, `kubeconform`, `test`, `check-version`, `package`; `print-<VAR>` for workflows |
| [scripts/chart.sh](../../scripts/chart.sh) | `cmd_lint`: chart contract + `helm lint --strict` per values set. `cmd_unittest`: helm-unittest, fails without suites. `cmd_kubeconform`: render per Kubernetes version × values set, `kubeconform -strict` with the default schema location and the datreeio CRD catalog. `cmd_check_version`: version bump against a base ref. `cmd_release_plan`: JSON of versions without tag |
| [scripts/install-tool.sh](../../scripts/install-tool.sh) | Downloads a release archive and its checksum file, compares SHA-256 by file name, installs one member |
| [.github/workflows/ci.yml](../../.github/workflows/ci.yml) | `make tools`, `make test`; on pull requests `make check-version` |
| [.github/workflows/release.yml](../../.github/workflows/release.yml) | `plan` job (release-plan) → `release` matrix: test, package, overwrite guard, `helm push`, `cosign sign`, provenance, `gh release create` |
| [.github/workflows/renovate.yml](../../.github/workflows/renovate.yml) | GitHub App token, self-hosted Renovate with `renovate.json` |
| [renovate.json](../../renovate.json) | helm-values limited to `charts/*/values.yaml`, chart version bump, per-chart branches, weekly galaxy-ng digest group, Makefile regex manager |
