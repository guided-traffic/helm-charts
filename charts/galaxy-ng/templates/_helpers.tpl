{{/*
Image reference of a component: repository:tag. The tag may carry a digest
(latest@sha256:...), which then decides what is pulled.
Usage: {{ include "galaxy-ng.image" .Values.api.image }}
*/}}
{{- define "galaxy-ng.image" -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}

{{/*
CA bundle for the Redis TLS connection, or empty for the image default.
*/}}
{{- define "galaxy-ng.redisCaCerts" -}}
{{- if .Values.redis.tls.caSecretName -}}
/etc/pulp/redis-ca/ca.crt
{{- else -}}
{{- .Values.redis.tls.caCertsPath -}}
{{- end -}}
{{- end -}}

{{/*
True when the pods mount the Redis CA Secret.
*/}}
{{- define "galaxy-ng.redisCaMounted" -}}
{{- if and .Values.redis.enabled .Values.redis.tls.enabled .Values.redis.tls.caSecretName -}}
true
{{- end -}}
{{- end -}}
