# Adding a chart

1. **Create the directory** `charts/<chart>/` — the name is the OCI path
   (`oci://ghcr.io/guided-traffic/helm-charts/<chart>`) and must equal
   `name` in `Chart.yaml`. Copy [charts/galaxy-ng/.helmignore](../../charts/galaxy-ng/.helmignore).
2. **Write `Chart.yaml`**: `apiVersion: v2`, a SemVer `version` (start at
   `0.1.0`, or continue the numbering of a chart moved here), and
   `https://github.com/guided-traffic/helm-charts` as the **first** entry of
   `sources`. Template: [charts/galaxy-ng/Chart.yaml](../../charts/galaxy-ng/Chart.yaml).
3. **Write `values.yaml`** with images as `<component>.image.repository` and
   `<component>.image.tag` (see [conventions.md](conventions.md)). Defaults must
   not contain anything specific to one installation.
4. **Write `values.schema.json`** with `additionalProperties: false` on every
   object you define.
5. **Add values sets** `ci/<name>-values.yaml` that switch on every optional
   feature at least once.
6. **Add test suites** `tests/<name>_test.yaml` (helm-unittest).
7. **Write `README.md`**: what it deploys, prerequisites, every value with
   default and meaning, security notes where a value has a security effect.
8. **Add the chart** to the chart table in the root [README.md](../../README.md#charts).
9. **Run** `make test CHARTS=<chart>`.
10. **After the first release**: make the package public — [release.md](release.md#one-time-setup),
    step 3 (irreversible), and add the chart's images to
    [renovate.json](../../renovate.json) only if they need a rule of their own
    (grouping, schedule); the default rules already cover them.
