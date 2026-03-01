{{/*
Common labels for all resources.
*/}}
{{- define "immich.labels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "immich.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "immich.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
