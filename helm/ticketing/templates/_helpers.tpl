{{/* Chart fullname, used as the resource name prefix. */}}
{{- define "ticketing.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ticketing.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- include "ticketing.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Common labels. */}}
{{- define "ticketing.labels" -}}
app.kubernetes.io/part-of: ticketing
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/* Per-component selector labels. Usage: include "ticketing.selectorLabels" (dict "ctx" . "component" "api") */}}
{{- define "ticketing.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- end -}}

{{/* Resolve an app image: registry/repository/<name>:<tag|global tag>. */}}
{{- define "ticketing.image" -}}
{{- $reg := .ctx.Values.image.registry -}}
{{- $repo := .ctx.Values.image.repository -}}
{{- $tag := .tag | default .ctx.Values.image.tag -}}
{{- printf "%s/%s/%s:%s" $reg $repo .name $tag -}}
{{- end -}}
