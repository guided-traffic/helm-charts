# Renovate

Self-hosted Renovate ([workflow](../../.github/workflows/renovate.yml)) runs on
weekdays at 05:00 UTC, after every push to `main` and on demand, with a GitHub
App installation token. Pull requests opened and merged with that token start
CI and release workflows; pull requests from `GITHUB_TOKEN` would not.
Configuration: [renovate.json](../../renovate.json).

## What is updated

| Manager | Files | Dependencies |
|---|---|---|
| `helm-values` | `charts/*/values.yaml` only | every map under a key ending in `image` that has `repository` and `tag` (Renovate's heuristic). `ci/` values are not touched. |
| `regex` (custom) | `Makefile` | `*_VERSION := …` with a `# renovate: datasource=… depName=…` comment on the line above |
| `github-actions` | `.github/workflows/*.yml` | actions (pinned to digests by `helpers:pinGitHubActionDigests`) and `cosign-release` of the cosign installer |

Checked with Renovate 44.190.2 in `--platform=local --dry-run=lookup` mode on
2026-10-28: 4 image dependencies in `charts/galaxy-ng/values.yaml`, 3 tools in
the `Makefile`, all actions; an outdated galaxy-ng digest was proposed as a
`digest` update on branch `renovate/galaxy-ng-galaxy-ng-images`.

## Chart version bump

An image update changes the chart, so it needs a release. The `helm-values`
package rule carries a `bumpVersions` entry that raises `version` in the
`Chart.yaml` next to the updated `values.yaml`: minor for a major image
update, patch otherwise (digest, patch, minor).

`bumpVersions` resolves `{{packageFileDir}}` from the first update of a branch
only. `additionalBranchPrefix: "{{parentDir}}-"` keeps every branch to one
chart, so the bump always lands in the right chart. Keep that prefix when you
add group rules.

If a bump is missing anyway, `make check-version` fails the PR and the
automerge does not happen. `bumpVersions` is marked experimental by Renovate;
its effect on a real branch has not been observed in this repository yet.

## galaxy-ng images

`quay.io/ansible/galaxy-ng` and `quay.io/ansible/galaxy-ui` publish only
builds of the upstream main branch (commit tags plus `latest`), so the chart
tracks `latest@sha256:…` and Renovate moves the digest. These digest updates
are grouped (`galaxy-ng images`) and scheduled for Monday morning
(`* 0-8 * * 1`, Europe/Berlin), which gives at most one galaxy-ng patch
release per week.

## Automerge

All updates automerge (`platformAutomerge`, squash) once required checks pass.
That relies on `lint-test` being a required status check on `main` —
[release.md](release.md#one-time-setup), step 2. Without it, GitHub merges
immediately.

## Adding a tool to the Makefile

```make
# renovate: datasource=github-releases depName=<owner>/<repo>
MYTOOL_VERSION := v1.2.3
```

The variable must end in `_VERSION` and follow the comment directly.
