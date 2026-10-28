# Conventions

## Values

- **Images**: `<component>.image.repository` and `<component>.image.tag`.
  Renovate's helm-values manager detects this layout without extra
  configuration. A tag may carry a digest (`latest@sha256:…`); templates render
  `repository:tag` (galaxy-ng: helper `galaxy-ng.image` in
  [_helpers.tpl](../../charts/galaxy-ng/templates/_helpers.tpl)).
- **Booleans are booleans.** No `"True"`/`"False"` strings; translate in the
  template when an application needs a literal.
- **Schema**: every chart has `values.schema.json`; objects the chart defines
  use `additionalProperties: false`. A renamed key then fails loudly instead
  of falling back to a default. Allow `global` at the top level.
- **Secrets**: prefer the name of an existing Secret over a value the chart
  turns into a Secret. A value given to Helm ends up in the release Secret
  `sh.helm.release.v1.<release>.v<n>`. Never render a credential into a
  ConfigMap; document it where a value does.

## Defaults

The charts are public. Defaults must work in any cluster or fail clearly:
no host names, issuers, StorageClasses, network-policy labels or directory
settings of one installation. Installation-specific values belong in the
consumer's values (for wds18: the HelmRelease in `wds18-flux-apps`).

## Versioning

SemVer for the chart, independent of the application version:

| Change | Bump |
|---|---|
| values key renamed or removed, default with a different effect, selector change | major |
| new optional value or feature, image major update (Renovate) | minor |
| fix, image digest/patch/minor update (Renovate), docs in the packaged README | patch |

Breaking changes are listed in the chart README under an upgrade section.

## Templates

- Deployment selectors never change within a major version — they are
  immutable in Kubernetes, and a change forces delete-and-recreate.
- Comments and documentation in English.

## Documentation

When a change touches documented behaviour, update the chart README, this
guide or `docs/security/` in the same pull request.
