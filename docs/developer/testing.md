# Testing

`make test` runs three tiers for every chart (or `CHARTS=…`); CI runs the
same target. `make check-version` is the fourth check, run on pull requests.

| Tier | Command | Fails when |
|---|---|---|
| lint | `scripts/chart.sh lint <chart>` | chart contract broken (name ≠ directory, version not SemVer, first `sources` entry not this repository, `README.md` or `values.schema.json` missing); `helm lint --strict` reports a warning or error for the default values or any `ci/*-values.yaml` — including values that violate the schema |
| unittest | `scripts/chart.sh unittest <chart>` | no `tests/*_test.yaml`; any helm-unittest assertion fails (`--strict` also rejects unknown keys in suites) |
| kubeconform | `scripts/chart.sh kubeconform <chart>` | a rendered object does not match the Kubernetes schema of any version in `KUBERNETES_VERSIONS` (strict: unknown fields fail), for any values set |
| version | `scripts/chart.sh check-version <chart> <base>` | packaged files changed against `<base>` and the version is not greater, or the tag `<chart>-<version>` exists |

## Values sets

Each chart is linted and rendered with its default `values.yaml` plus every
`charts/<chart>/ci/<name>-values.yaml`. Use them to switch on the optional
features, so templates behind an `if` are rendered at least once:

| galaxy-ng set | Covers |
|---|---|
| default | defaults as published |
| [ci/full-values.yaml](../../charts/galaxy-ng/ci/full-values.yaml) | Ingress, LDAP, S3, PVC with StorageClass, Redis TLS with CA Secret, admin and key Secrets, pull Secret |
| [ci/minimal-values.yaml](../../charts/galaxy-ng/ci/minimal-values.yaml) | inline database credentials, no Redis, no PVC, no NetworkPolicies |

## Unit tests

[helm-unittest](https://github.com/helm-unittest/helm-unittest) suites live in
`charts/<chart>/tests/`. Test behaviour that a reader of the values would rely
on and that would break silently: rendered settings, which Secret is mounted,
selector stability, schema rejections of old keys. Two practical points:

- A template that `include`s another (checksum annotations of a ConfigMap)
  needs that template in the suite's `templates:` list. Name the template on
  each assertion then (`template: deployment-api.yaml`), otherwise the
  assertion runs against every listed template.
- Check a new test against a mutation: break the template on purpose and
  confirm the test fails.

```bash
make unittest CHARTS=galaxy-ng
.tools/helm-unittest-v1.2.1/untt --strict -f 'tests/settings_test.yaml' charts/galaxy-ng   # one suite
```

## What is not tested

- **No installation into a cluster.** CI renders and validates manifests but
  never starts the workloads. Whether galaxy-ng starts with a given image tag
  (settings compatible, migrations succeed) is only seen at deployment.
- **CRD schemas** come from the community [CRDs catalog](https://github.com/datreeio/CRDs-catalog);
  a custom resource whose kind is missing there fails kubeconform. No current
  chart renders custom resources.
- **`KUBERNETES_VERSIONS`** is maintained by hand (`1.34.0` for the wds18
  production cluster, `1.37.0` as the newest schema set published by
  kubeconform's schema repository on 2026-10-28).
