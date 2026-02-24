{{/*
Common labels for all resources.
*/}}
{{- define "dumper.labels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "dumper.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "dumper.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
