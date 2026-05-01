{{/*
Common labels for all resources.
*/}}
{{- define "aurral.labels" -}}
app.kubernetes.io/name: aurral
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "aurral.selectorLabels" -}}
app.kubernetes.io/name: aurral
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "aurral.annotations" -}}
  {{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
  {{- end }}
{{- end -}}
