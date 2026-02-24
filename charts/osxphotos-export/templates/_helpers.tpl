{{/*
Common labels for all resources.
*/}}
{{- define "osxphotos-export.labels" -}}
app.kubernetes.io/name: osxphotos-export
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "osxphotos-export.selectorLabels" -}}
app.kubernetes.io/name: osxphotos-export
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "osxphotos-export.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
