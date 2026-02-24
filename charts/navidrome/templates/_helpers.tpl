{{/*
Common labels for all resources.
*/}}
{{- define "navidrome.labels" -}}
app.kubernetes.io/name: navidrome
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "navidrome.selectorLabels" -}}
app.kubernetes.io/name: navidrome
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "navidrome.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
