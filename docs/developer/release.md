# Release

[Release Charts](../../.github/workflows/release.yml) runs on every push to
`main` that touches `charts/`, the `Makefile`, `scripts/` or the workflow
itself, and on manual dispatch. It never cancels a running release
(`cancel-in-progress: false`).

## Sequence

1. **plan** — `scripts/chart.sh release-plan` lists every chart whose
   `Chart.yaml` version has no git tag `<chart>-<version>`, as JSON
   (`[{"chart":"galaxy-ng","version":"2.0.0"}]`). Empty list → nothing else runs.
2. **release** — one matrix job per entry, `fail-fast: false`:

| Step | What | Why this order |
|---|---|---|
| Test | `make test CHARTS=<chart>` | the commit on `main` may not have passed CI (direct push) |
| Package | `make package` → `.dist/<chart>-<version>.tgz` | `.helmignore` drops `tests/`, `ci/` |
| Log in | `docker/login-action` (cosign, attestation) and `helm registry login`, both with `GITHUB_TOKEN` | helm and cosign read different credential stores |
| Overwrite guard | `helm show chart oci://…/<chart> --version <version>` succeeds → fail | OCI tags are mutable; the git tag is missing but a failed earlier run may have pushed |
| Push | `helm push` → digest parsed from `Digest: sha256:…` | |
| Sign | `cosign sign --yes <repo>/<chart>@<digest>` (cosign v3.1.4, keyless) | signs the digest, not the tag |
| Attest | `actions/attest-build-provenance`, `push-to-registry: true` | SLSA provenance next to the artifact and in the repository's attestations |
| Tag and release | `gh release create <chart>-<version> <tgz> --target <sha>` | last: the tag is what marks the version as released |

The OCI annotations come from `Chart.yaml`: Helm sets
`org.opencontainers.image.source` from the first `sources` entry, which is
why the chart contract requires this repository there.

## One-time setup

These are manual, outside the repository. None is done by the workflows.

| # | What | How |
|---|---|---|
| 1 | GitHub App `guided-traffic-automation` has access to this repository (Renovate) | Organisation settings → GitHub Apps → guided-traffic-automation → Configure → Repository access. The secrets `APP_CLIENT_ID` and `APP_PRIVATE_KEY` are organisation secrets already visible to this repository (checked 2026-10-28). |
| 2 | `lint-test` is a required status check on `main` | `gh api -X PUT repos/guided-traffic/helm-charts/branches/main/protection --input protection.json` with `{"required_status_checks":{"strict":false,"checks":[{"context":"lint-test","app_id":15368}]},"enforce_admins":false,"required_pull_request_reviews":null,"restrictions":null}` (15368 = GitHub Actions; same as container-images). Without it, GitHub's auto-merge merges Renovate PRs without waiting for CI. |
| 3 | After the first release of a chart: package visibility | The first push creates the package `helm-charts/<chart>` as **private**. Package settings → Change visibility → Public. **Irreversible**: a public package cannot be made private again. Check the package's "Repository" link first (set from the source annotation). |
| 4 | Private vulnerability reporting | `gh api -X PUT repos/guided-traffic/helm-charts/private-vulnerability-reporting` (off on 2026-10-28) |

## Recovery

| Situation | Symptom | Fix |
|---|---|---|
| Push succeeded, a later step failed (sign, attest, release) | rerun stops at the overwrite guard | Fix forward: bump the version and merge. Delete the orphaned version in the package settings so nobody installs an unsigned artifact. |
| Push failed | no artifact, no tag | Rerun the job (Actions → Re-run failed jobs). |
| Release created, but the chart is broken | | Bump and release a fixed version. Never delete and re-push a released version: consumers and Flux may hold the old digest. |
| A chart must be withdrawn | | Delete the package version in ghcr.io and mark the GitHub release; the git tag stays, so the version is not re-released. |
