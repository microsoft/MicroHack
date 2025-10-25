{{- define "goldengate-da.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "goldengate-da.fullname" -}}
{{- printf "%s" (include "goldengate-da.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "goldengate-da.labels" -}}
app.kubernetes.io/name: {{ include "goldengate-da.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: Helm
{{- end -}}
