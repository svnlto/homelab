{{/*
Common labels for all resources.
*/}}
{{- define "postgresql.labels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "postgresql.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
