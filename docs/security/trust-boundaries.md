# Trust boundaries

What decides which bytes end up at `ghcr.io/guided-traffic/helm-charts/<chart>`.

```
 contributor / fork ──PR──▶ Chart CI (contents: read, no secrets)
                                │ lint-test
 Renovate (App token) ──PR──────┤
                                ▼
 maintainer ── merge / push ──▶ main ──▶ Release Charts, release job
                                          GITHUB_TOKEN: contents/packages write
                                          OIDC token ──▶ Fulcio cert ──▶ cosign signature
                                          │
                                          ▼
                              ghcr.io/guided-traffic/helm-charts/<chart>
                                          │  verify identity release.yml@refs/heads/main
                                          ▼
                              consumers (helm, Flux OCIRepository)
```

## Roles

| Role | Can | Cannot |
|---|---|---|
| Contributor, also from a fork | open a PR; its code runs in Chart CI on a GitHub-hosted runner with `contents: read` and no secrets | publish, read secrets, run on infrastructure of the organisation |
| Renovate (GitHub App `guided-traffic-automation`, installation token) | open, update and automerge PRs in this repository; the token lives for the job only | bypass required checks, if they are configured (see H-1) |
| Maintainer (write access) | merge, push to `main`, start workflows by hand | — a push to `main` releases every new chart version |
| Release job | push packages, sign, attest, create tags and releases | run for anything but `main`: pushes trigger on `main` only, and the `plan` job skips manual runs on any other ref (`if: github.ref == 'refs/heads/main'`) |
| Consumer | pull and verify | — |

## Tokens and permissions

| Workflow / job | Token | Permissions | Secrets |
|---|---|---|---|
| Chart CI / `lint-test` | `GITHUB_TOKEN` | `contents: read` | none |
| Release Charts / `plan` | `GITHUB_TOKEN` | `contents: read` | none |
| Release Charts / `release` | `GITHUB_TOKEN` + OIDC | `contents: write`, `packages: write`, `id-token: write`, `attestations: write` | none besides `GITHUB_TOKEN` |
| Renovate Dependencies | App installation token | workflow: `contents: read`; Renovate: the App's permissions on this repository | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` (organisation secrets) |

Write permissions are declared on the release job only; every workflow sets
`contents: read` at the top. Third-party actions are pinned to commit digests
and kept current by Renovate. The runners are GitHub-hosted: the repository
is public, and a self-hosted runner would execute code from fork pull
requests on the organisation's machines.

## Tools in CI

helm, kubeconform and helm-unittest are downloaded by
[install-tool.sh](../../scripts/install-tool.sh) from their GitHub releases
(helm from `get.helm.sh`) and checked against the SHA-256 in the checksum
file of the same release, at the version pinned in the
[Makefile](../../Makefile). cosign comes from `sigstore/cosign-installer`,
which verifies the cosign binary itself.

## What this does not cover

### H-1: `main` has no required status check

Checked on 2026-10-28: `main` is not protected. With `platformAutomerge`, a
Renovate PR is merged by GitHub as soon as auto-merge is enabled, without
waiting for `lint-test`, and the release job then publishes it. The release
job runs `make test` itself, so a chart failing lint, unit tests or schema
validation is not published — but a missing version bump or a failing
`check-version` is not caught there. Closed by the required check in
[release.md](../developer/release.md#one-time-setup), step 2.

### H-2: upstream images are taken unreviewed

Renovate automerges image updates, including the weekly galaxy-ng digest of
upstream's main branch. The chart's defaults therefore contain upstream code
no one here has read. The boundary is the consumer: pin an image tag in the
values (wds18 does) or pin the chart version and review the update.

### H-3: checksums prove integrity, not origin

`install-tool.sh` compares against a checksum file from the same release as
the archive. It detects a corrupted or truncated download, not a release
replaced by someone with write access to the tool's repository. No tool
signature is verified.

### H-4: the App's permission scope is not documented here

Which repository permissions `guided-traffic-automation` holds, and on which
repositories it is installed, is configured in the organisation settings and
was not checked for this page.
