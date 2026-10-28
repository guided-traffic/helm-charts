# galaxy-ng

Helm chart for [Galaxy NG](https://github.com/ansible/galaxy_ng), the server
behind Ansible Galaxy and Automation Hub. It runs the API, the content app,
the task worker and the web UI. PostgreSQL is external; Redis/Valkey (cache)
is optional.

```bash
helm install galaxy-ng oci://ghcr.io/guided-traffic/helm-charts/galaxy-ng \
  --version 2.0.0 --namespace galaxy --values my-values.yaml
```

## Components

| Deployment | Image | Port | Role |
|---|---|---|---|
| `galaxy-ng-api` | `api.image` | 8000 (`galaxy-ng-api-svc`) | REST API; init containers run `pulpcore-manager migrate` and reset the admin password |
| `galaxy-ng-content` | `content.image` | 24816 (`galaxy-ng-content-svc`) | serves collection artifacts (`/pulp/content/`) |
| `galaxy-ng-worker` | `worker.image` | — | background tasks (sync, import); also runs the migrations in an init container |
| `galaxy-ng-web` | `web.image` | 8080 (`galaxy-ng-web-svc`) | nginx with the UI, proxies `/api/`, `/pulp/` to api and content |

All Deployments use the `Recreate` strategy and select pods by
`app: galaxy-ng-<component>`. The selectors are the same as in chart 1.x, so an
upgrade from 1.x keeps the Deployments.

## Prerequisites

| What | Why |
|---|---|
| PostgreSQL database | `database.*`; credentials in a Secret with the keys `username` and `password` |
| Secret `galaxy-ng-db-fields-encryption-sec`, key `database_fields.symmetric.key` | encrypts secret fields in the database; or set `db_fields_encryption_key` |
| Secret `galaxy-ng-admin-password`, keys `user`, `password` | the api resets the `admin` password to this value on every start; or set `adminPassword` |
| Secret `galaxy-ng-secrets` (may be empty) | loaded with `envFrom` into every Galaxy container; the pods do not start without it |
| `ReadWriteMany` storage or S3 | collection artifacts, shared by api, content and worker (`pvcBackend` or `s3_backend`) |
| Redis or Valkey (optional) | cache (`redis.*`) |

> **Security:** the database fields key (Fernet) is the only way to read the
> encrypted columns (remote tokens, passwords). Back it up together with the
> database. Replacing the Secret alone makes the stored values unreadable; to
> rotate, put the new key as the first line above the old one, then run
> `pulpcore-manager rotate-db-key`.

## Images and updates

Upstream publishes only builds of the `main` branch of galaxy_ng: 8-character
commit tags (`71e98059`) and `latest`, no release tags. The chart default is
`latest` pinned by digest (`latest@sha256:…`); Renovate moves the digest once
a week and releases a new chart patch version. Updating `latest` means
running upstream's newest database migrations, so **pin a commit tag in
production** and update on purpose:

```yaml
api:
  image:
    repository: quay.io/ansible/galaxy-ng  # example
    tag: "71e98059"                        # example
```

Use the same galaxy-ng tag for `api`, `content` and `worker`. The worker's
migration init container uses `api.image`.

## Values

Unknown keys are rejected by [`values.schema.json`](values.schema.json), so a
misspelled or 1.x-style key fails the install instead of being ignored.

| Key | Default | Description |
|---|---|---|
| `adminPassword` | unset | Creates `galaxy-ng-admin-password`. **Security:** the value is stored in the Helm release Secret; prefer an existing Secret. |
| `db_fields_encryption_key` | unset | Creates `galaxy-ng-db-fields-encryption-sec` with this content as the key file (one Fernet key per line). **Security:** stored in the Helm release Secret; prefer an existing Secret. |
| `api.image.repository` | `quay.io/ansible/galaxy-ng` | |
| `api.image.tag` | `latest@sha256:3954…91b3` | Tag, optionally with digest |
| `api.replicas` | `1` | |
| `api.podExtraLabels` | `{}` | Extra pod labels, e.g. for network policy selectors |
| `api.resources` | requests `50m`/`3000Mi`, limit `4000Mi` | |
| `content.image.repository` | `quay.io/ansible/galaxy-ng` | |
| `content.image.tag` | `latest@sha256:3954…91b3` | |
| `content.replicas` | `1` | |
| `content.podExtraLabels` | `{}` | |
| `content.resources` | requests `50m`/`500Mi`, limit `750Mi` | |
| `web.image.repository` | `quay.io/ansible/galaxy-ui` | |
| `web.image.tag` | `latest@sha256:f627…d66a` | |
| `web.replicas` | `1` | |
| `web.podExtraLabels` | `{}` | |
| `web.resources` | requests `25m`/`100Mi`, limit `200Mi` | |
| `worker.image.repository` | `quay.io/ansible/galaxy-ng` | |
| `worker.image.tag` | `latest@sha256:3954…91b3` | |
| `worker.replicas` | `1` | |
| `worker.podExtraLabels` | `{}` | |
| `worker.resources` | requests `200m`/`5000Mi`, limit `7000Mi` | |
| `imagePullPolicy` | `IfNotPresent` | |
| `imagePullSecretName` | `""` | Existing pull Secret for all pods |
| `ingress.enabled` | `false` | Ingress `galaxy-ng-internal` to `galaxy-ng-web-svc:8080` |
| `ingress.className` | `""` | |
| `ingress.domain` | `""` | Public hostname. Also renders `CONTENT_ORIGIN`, `ANSIBLE_API_HOSTNAME`, `CSRF_TRUSTED_ORIGINS` and `CORS_ORIGIN_WHITELIST` (`https://<domain>`), so set it even without the Ingress |
| `ingress.tlsSecret` | `galaxy-ng-tls` | TLS Secret; empty disables the `tls` block |
| `ingress.extraAnnotations` | `{}` | e.g. `cert-manager.io/cluster-issuer` |
| `ingress.extraLabels` | `{}` | |
| `ldap.enabled` | `false` | Adds `django_auth_ldap.backend.LDAPBackend` in front of the local user backend |
| `ldap.settings` | `""` | Python appended to `settings.py` (`AUTH_LDAP_SERVER_URI`, `AUTH_LDAP_USER_SEARCH`, …). `ldap`, `LDAPSearch` and `NestedGroupOfNamesType` are imported. **Security:** rendered into a ConfigMap — never put the bind password here; it is read from the environment variable `AUTH_LDAP_BIND_PASSWORD`, set it in `galaxy-ng-secrets`. Use `ldaps://` or StartTLS, otherwise passwords cross the network in clear text. |
| `s3_backend.enabled` | `false` | Store artifacts in S3 (`storages.backends.s3boto3`) |
| `s3_backend.endpoint` | `""` | |
| `s3_backend.region` | `""` | |
| `s3_backend.bucket_name` | `""` | |
| `s3_backend.secret_name` | `s3-secret` | Secret with `access-key-id` and `secret-access-key` |
| `pvcBackend.enabled` | `true` | PVC `galaxy-ng-pvc` (`ReadWriteMany`) at `/var/lib/pulp/media` |
| `pvcBackend.storageClassName` | `""` | Empty: the cluster's default StorageClass. Immutable after creation |
| `pvcBackend.size` | `20Gi` | |
| `database.host` | `galaxy-ng-postgres` | |
| `database.name` | `galaxy` | |
| `database.port` | `"5432"` | |
| `database.secret_name` | `galaxy-ng-postgres-credentials` | Secret with `username` and `password`, mounted at `/etc/pulp/db-credentials` |
| `database.username` | unset | Only when `secret_name` is empty |
| `database.password` | unset | Only when `secret_name` is empty. **Security:** rendered in clear text into the ConfigMap `galaxy-ng-cm`; use `secret_name` |
| `redis.enabled` | `true` | Enables the cache (`CACHE_ENABLED = True`) |
| `redis.host` | `galaxy-ng-valkey` | |
| `redis.port` | `6379` | |
| `redis.db` | `0` | |
| `redis.secret.name` | `galaxy-ng-valkey` | Secret with the password (env `REDIS_PASSWORD`); empty: no password |
| `redis.secret.key` | `password` | |
| `redis.tls.enabled` | `false` | `REDIS_SSL = True`. **Security:** without TLS the password and cached data cross the network in clear text |
| `redis.tls.caSecretName` | `""` | Secret whose key `ca.crt` is mounted at `/etc/pulp/redis-ca/ca.crt` and used as `REDIS_SSL_CA_CERTS` |
| `redis.tls.caCertsPath` | `""` | CA bundle path already in the pod (ignored when `caSecretName` is set). Both empty: the image's default store (`/etc/pki/tls/cert.pem` in `71e98059`), which holds public CAs only |
| `networkPolicy.enabled` | `true` | NetworkPolicies `api-from-web` and `content-from-web` |
| `additionalSettings` | `""` | Python appended verbatim to the end of `settings.py`; overrides anything above |

`settings.py` also contains these fixed assignments: `TOKEN_AUTH_DISABLED = True`,
`GALAXY_REQUIRE_CONTENT_APPROVAL = False`,
`AUTHENTICATION_BACKEND_PRESET = 'custom'`, database `sslmode` `prefer`.
Override them with `additionalSettings`.

### NetworkPolicies

With `networkPolicy.enabled` the api and content pods accept connections only
from the web pods. Everything else that talks to them needs its own policy
in the release namespace — jobs calling the API directly, monitoring, a
`kubectl port-forward` to the api. The web pods are not selected by these
policies; whether the ingress controller reaches them depends on the
cluster's other policies.

## Upgrading from 1.x

Chart 1.x was published privately as `oci://ghcr.io/guided-traffic/galaxy-ng`.
2.0.0 is the first version under `oci://ghcr.io/guided-traffic/helm-charts/galaxy-ng`.
The Deployment selectors are unchanged, so `helm upgrade` replaces the pods
and keeps the Deployments, Services, PVC and Ingress.

| 1.x | 2.0.0 |
|---|---|
| `api.image: <repo>` + `api.tag: <tag>` (same for content, web, worker) | `api.image.repository` + `api.image.tag` |
| `authLdapSettings`, default pointing at a fixed company directory, always enabled | `ldap.enabled` (default `false`) + `ldap.settings` |
| `redis.tls.enabled: "True"` / `"False"` (strings) | `true` / `false` |
| TLS wrote `REDIS_TLS_CA_CERTS`, which pulpcore does not read | `REDIS_SSL_CA_CERTS` |
| CA from `redis.tls.secretName` in api, hard-coded Secret `valkey-tls` in content and worker | `redis.tls.caSecretName` in all three, or `redis.tls.caCertsPath` |
| pod label `valkey: "true"` | removed |
| NetworkPolicy `db-from-api-worker-content` (selects Zalando/Spilo pods) | removed — admit the database clients in your database's policy |
| `database.port` ignored | rendered as `PORT` |
| `adminPassword` produced an invalid Secret (`data.user` not base64) | fixed (`stringData`) |
| web pod without `imagePullSecrets` | all four pods |
| defaults: Ingress on, S3 on, PVC off (`nfs-client`), issuer `cluster-ca`, network-policy labels on pods, organisation-specific host names | Ingress off, S3 off, PVC on (default StorageClass), no annotations or labels, neutral host names |

The schema rejects the 1.x keys (`api.tag`, `authLdapSettings`, string
`redis.tls.enabled`), so a values file that was not migrated fails at
`helm upgrade` instead of falling back to the defaults.

## Development

`make test CHARTS=galaxy-ng` from the repository root runs lint, the unit tests
in [`tests/`](tests/) and the schema validation for the values sets in
[`ci/`](ci/). See [docs/developer/](../../docs/developer/README.md).
