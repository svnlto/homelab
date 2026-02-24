{{/*
Common labels for all resources.
*/}}
{{- define "infrastructure.labels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "infrastructure.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
