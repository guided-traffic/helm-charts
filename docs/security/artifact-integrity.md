# Artifact integrity

What a consumer of `oci://ghcr.io/guided-traffic/helm-charts/<chart>` can
check, and against what.

## What is published per version

| Object | Where | Bound to |
|---|---|---|
| Chart (OCI artifact) | `ghcr.io/guided-traffic/helm-charts/<chart>:<version>` | manifest digest from `helm push` |
| cosign signature (keyless, cosign v3.1.4) | same repository, attached to the digest | Fulcio certificate for the workflow identity, logged in Rekor |
| SLSA build provenance | same repository (`push-to-registry`) and the repository's attestations | the digest, the workflow run, the commit |
| `.tgz` + git tag `<chart>-<version>` | GitHub release | the commit (`--target $GITHUB_SHA`) |

The signature and the provenance cover the **digest**. A tag can be moved in
an OCI registry; the digest cannot.

## Identity to verify

| Field | Value |
|---|---|
| Certificate identity (SAN) | `https://github.com/guided-traffic/helm-charts/.github/workflows/release.yml@refs/heads/main` |
| OIDC issuer | `https://token.actions.githubusercontent.com` |

```bash
cosign verify ghcr.io/guided-traffic/helm-charts/<chart>:<version> \
  --certificate-identity https://github.com/guided-traffic/helm-charts/.github/workflows/release.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/guided-traffic/helm-charts/<chart>:<version> \
  --repo guided-traffic/helm-charts
```

Flux: `spec.verify` with `provider: cosign` and `matchOIDCIdentity` (example in
the [README](../../README.md#-tldr)). Flux source-controller verifies cosign v2
and v3 signatures since v1.8.0. An OCIRepository whose verification fails is
not Ready, and no HelmRelease gets the new chart.

Matching the exact workflow file and `refs/heads/main` is what makes the
signature meaningful: any workflow in any public repository can obtain a
Fulcio certificate, but only this file on this branch gets this identity.

## Immutability

Released versions are not overwritten: the release job fails if the version
already exists in the registry
([release.yml](../../.github/workflows/release.yml), step "Refuse to overwrite
a pushed version"), and a version with a git tag is never planned again.

## Visibility

A new package on ghcr.io starts **private**. Making it public is a manual,
irreversible step per chart ([release.md](../developer/release.md#one-time-setup)).
Everything in a packaged chart becomes public with it: templates, defaults,
README. The chart contract keeps `tests/` and `ci/` out of the package; the
[conventions](../developer/conventions.md#defaults) keep installation-specific
values out of the defaults.

## What this does not cover

### H-5: the chart's signature does not cover the images

The signature proves who published the chart, not what the images in it
contain. galaxy-ng's defaults pin images by digest, so the default render
pulls exactly the bytes Renovate resolved; a consumer that overrides
`image.tag` with a tag only gets whatever the tag points to at pull time.
Upstream image signatures are not checked by this repository.

### H-6: a run that fails after the push leaves an unsigned version

If signing or attestation fails after `helm push`, the version exists in the
registry without signature and without git tag. It is not re-released (the
overwrite guard stops the rerun), but it stays pullable until someone deletes
it ([release.md](../developer/release.md#recovery)). Consumers that verify
signatures reject it; consumers that do not, can install it.
