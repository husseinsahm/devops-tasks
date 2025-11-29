{{- define "library.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "library.fullname" -}}
{{ printf "%s-%s" .Release.Name .Chart.Name }}
{{- end }}
