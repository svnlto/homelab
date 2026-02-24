{{/*
Common labels for all resources.
*/}}
{{- define "jellyfin.labels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "jellyfin.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "jellyfin.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
