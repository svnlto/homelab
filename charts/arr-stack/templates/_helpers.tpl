{{/*
Common labels for all resources.
*/}}
{{- define "arr-stack.labels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "arr-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}

{{/*
Global annotations from values.
*/}}
{{- define "arr-stack.annotations" -}}
{{- range $key, $val := .Values.global.annotations }}
{{ $key }}: {{ $val | quote -}}
{{- end }}
{{- end -}}

{{/*
Media + scratch volume mounts (shared across arr apps and downloaders).
*/}}
{{- define "arr-stack.mediaVolumeMounts" -}}
- name: media-movies
  mountPath: /data/media/movies
- name: media-tv
  mountPath: /data/media/tv
- name: media-music
  mountPath: /data/media/music
- name: media-books
  mountPath: /data/media/books
- name: scratch
  mountPath: /data-scratch
{{- end -}}

{{/*
Media + scratch volumes (PVC references).
*/}}
{{- define "arr-stack.mediaVolumes" -}}
- name: media-movies
  persistentVolumeClaim:
    claimName: nfs-media-movies
- name: media-tv
  persistentVolumeClaim:
    claimName: nfs-media-tv
- name: media-music
  persistentVolumeClaim:
    claimName: nfs-media-music
- name: media-books
  persistentVolumeClaim:
    claimName: nfs-media-books
- name: scratch
  persistentVolumeClaim:
    claimName: nfs-scratch
{{- end -}}

{{/*
Arr app deployment template.
Usage: {{ include "arr-stack.arrDeployment" (dict "name" "radarr" "app" .Values.radarr "Values" .Values "Release" .Release) }}
*/}}
{{- define "arr-stack.arrDeployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name }}
  labels:
    {{- include "arr-stack.labels" . | nindent 4 }}
  annotations:
    {{- range $key, $val := .Values.global.annotations }}
    {{ $key }}: {{ $val | quote }}
    {{- end }}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      {{- include "arr-stack.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "arr-stack.selectorLabels" . | nindent 8 }}
      annotations:
        {{- range $key, $val := .Values.global.annotations }}
        {{ $key }}: {{ $val | quote }}
        {{- end }}
    spec:
      containers:
        - name: {{ .name }}
          image: {{ .app.image }}
          ports:
            - containerPort: {{ .app.port }}
              name: http
          env:
            - name: PUID
              value: "1000"
            - name: PGID
              value: "1000"
            - name: TZ
              value: {{ .Values.timezone }}
          startupProbe:
            httpGet:
              path: {{ .app.probePath }}
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 12
            timeoutSeconds: 5
          livenessProbe:
            httpGet:
              path: {{ .app.probePath }}
              port: http
            periodSeconds: 30
            timeoutSeconds: 10
            failureThreshold: 5
          readinessProbe:
            httpGet:
              path: {{ .app.probePath }}
              port: http
            periodSeconds: 10
            timeoutSeconds: 10
          resources:
            {{- toYaml .app.resources | nindent 12 }}
          volumeMounts:
            - name: config
              mountPath: /config
            {{- include "arr-stack.mediaVolumeMounts" . | nindent 12 }}
      volumes:
        - name: config
          persistentVolumeClaim:
            claimName: {{ .name }}-config
        {{- include "arr-stack.mediaVolumes" . | nindent 8 }}
{{- end -}}

{{/*
Arr app service template.
Usage: {{ include "arr-stack.arrService" (dict "name" "radarr" "app" .Values.radarr "Values" .Values) }}
*/}}
{{- define "arr-stack.arrService" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
  annotations:
    {{- range $key, $val := .Values.global.annotations }}
    {{ $key }}: {{ $val | quote }}
    {{- end }}
spec:
  ports:
    - port: {{ .app.port }}
      targetPort: {{ .app.port }}
      protocol: TCP
      name: http
  selector:
    {{- include "arr-stack.selectorLabels" . | nindent 4 }}
{{- end -}}
