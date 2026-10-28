# Security policy

## Reporting a vulnerability

Please do **not** open a public issue for a vulnerability in a chart or in the
release pipeline.

- Use GitHub private vulnerability reporting:
  <https://github.com/guided-traffic/helm-charts/security/advisories/new>.
  It was switched off when this file was written (2026-10-28); if the form is
  not offered, contact the maintainer organisation
  <https://github.com/guided-traffic> instead.
- Name the chart and version (`helm list`, or the OCI tag) and the values that
  matter for the finding. Leave out passwords, keys and any other Secret
  content.

No response time or disclosure window is promised.

## Supported versions

Only the newest version of each chart receives fixes. A fix is released as a
new chart version; released versions are never changed.

| Chart | Supported |
|---|---|
| galaxy-ng | 2.x, newest version only |

## What is already known

The security architecture and its open gaps (`H-<n>`) are documented in
[docs/security/](docs/security/README.md). A report that adds an exploit, a
consequence or a case missing there is still welcome.
