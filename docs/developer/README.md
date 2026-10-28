# Developer guide

Everything needed to change, test and release a chart in this repository.

## What has to be in your head first

1. **`version` in `Chart.yaml` is the release trigger.** On `main`, every chart
   whose version has no git tag `<chart>-<version>` is released. There is no
   other release switch.
2. **Every change to a packaged file needs a higher version.** CI fails the
   pull request otherwise. Files under `tests/` and `ci/` are not packaged
   (`.helmignore`) and need no bump.
3. **A released version is final.** OCI tags can be overwritten, so the
   release workflow refuses to push a version that already exists; fix forward
   with a new version.
4. **Tools come from the `Makefile` pins.** `make tools` puts helm, kubeconform
   and helm-unittest into `.tools/`; CI runs the same targets. Do not test with
   a helm from `PATH` — it may be a different major.
5. **Images follow `<component>.image.{repository,tag}`.** That is the layout
   Renovate's helm-values manager detects; anything else is not updated.

## Pages

| Page | Content |
|---|---|
| [layout.md](layout.md) | Repository tree, what each file is responsible for |
| [testing.md](testing.md) | Test tiers, values sets, what is not tested |
| [release.md](release.md) | Release workflow, one-time setup, recovery |
| [renovate.md](renovate.md) | What Renovate updates, branches, version bumps, automerge |
| [adding-a-chart.md](adding-a-chart.md) | Checklist for a new chart |
| [conventions.md](conventions.md) | Values, schema, versioning, defaults, docs |

## Core flows

- **Pull request** → [Chart CI](../../.github/workflows/ci.yml) runs `make test` and
  `make check-version BASE_REF=origin/main` → job `lint-test` must pass.
- **Merge to `main`** → [Release Charts](../../.github/workflows/release.yml) runs
  `scripts/chart.sh release-plan` → one matrix job per unreleased version:
  test, package, push to `ghcr.io/guided-traffic/helm-charts/<chart>`, sign,
  attest, tag and GitHub release.
- **Renovate** ([workflow](../../.github/workflows/renovate.yml),
  [config](../../renovate.json)) → PR with the update and the chart version bump →
  same CI → automerge → release.
