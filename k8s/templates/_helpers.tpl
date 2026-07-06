{{/*
Expand the target namespace. Defaults to .Release.Namespace so the chart can be
installed with `-n <ns> --create-namespace`, but can be overridden per release.
*/}}
{{- define "backend-stack.namespace" -}}
{{- .Release.Namespace -}}
{{- end -}}
