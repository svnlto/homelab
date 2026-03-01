{{/*
Common labels for all resources.
*/}}
{{- define "dragonfly.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: dragonfly
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "dragonfly.selectorLabels" -}}
app.kubernetes.io/name: dragonfly
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "dragonfly.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
