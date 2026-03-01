{{/*
Common labels for all resources.
*/}}
{{- define "dragonfly.labels" -}}
app.kubernetes.io/name: dragonfly
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "dragonfly.selectorLabels" -}}
app.kubernetes.io/name: dragonfly
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "dragonfly.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
