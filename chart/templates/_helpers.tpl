{{- define "mobula.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mobula.labels" -}}
app.kubernetes.io/name: {{ include "mobula.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Distinct name label for the UI so its Deployment/Service selectors never
     overlap the control plane's. */}}
{{- define "mobula.ui.name" -}}
{{ include "mobula.name" . }}-ui
{{- end -}}

{{- define "mobula.ui.labels" -}}
app.kubernetes.io/name: {{ include "mobula.ui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mobula.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ default (include "mobula.name" .) .Values.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/* The namespace RayClusters are provisioned into. */}}
{{- define "mobula.kuberayNamespace" -}}
{{ .Values.kuberay.namespace | default .Release.Namespace }}
{{- end -}}

{{/* Validate the auth values once; included from deployment.yaml. */}}
{{- define "mobula.validateAuth" -}}
{{- if not (has .Values.auth.mode (list "oidc" "local" "none")) -}}
{{- fail (printf "auth.mode must be one of oidc|local|none, got %q" .Values.auth.mode) -}}
{{- end -}}
{{- if eq .Values.auth.mode "oidc" -}}
{{- if not .Values.auth.oidc.issuer -}}
{{- fail "auth.oidc.issuer is required when auth.mode=oidc" -}}
{{- end -}}
{{- if not .Values.auth.oidc.audience -}}
{{- fail "auth.oidc.audience is required when auth.mode=oidc" -}}
{{- end -}}
{{- end -}}
{{- if and (eq .Values.auth.mode "none") (not .Values.auth.dangerousDevAllowUnauthenticated) -}}
{{- fail "auth.mode=none serves WITHOUT authentication; set auth.dangerousDevAllowUnauthenticated=true to confirm" -}}
{{- end -}}
{{- end -}}
