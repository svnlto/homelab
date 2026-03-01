{{/*
Common labels for all resources.
*/}}
{{- define "immich.labels" -}}
helm.sh/chart: {{ .context.Chart.Name }}-{{ .context.Chart.Version }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
app.kubernetes.io/version: {{ .context.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .context.Release.Service }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "immich.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "immich.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}
