package kubernetes.admission

# Deny containers running as root
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	container.securityContext.runAsUser == 0
	msg := sprintf("Container %q runs as root (UID 0)", [container.name])
}

deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.securityContext.runAsNonRoot
	msg := sprintf("Container %q does not have runAsNonRoot set to true", [container.name])
}

# Deny privileged containers
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	container.securityContext.privileged == true
	msg := sprintf("Container %q runs in privileged mode", [container.name])
}

# Deny containers with dangerous capabilities
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	caps := container.securityContext.capabilities.add
	dangerous_caps := {"SYS_ADMIN", "NET_ADMIN", "SYS_RESOURCE", "CAP_DAC_OVERRIDE", "CAP_SYS_PTRACE"}
	cap := caps[_]
	cap in dangerous_caps
	msg := sprintf("Container %q has dangerous capability %q", [container.name, cap])
}

# Deny hostPath volumes
deny[msg] if {
	input.request.kind.kind == "Pod"
	volume := input.request.object.spec.volumes[_]
	volume.hostPath
	msg := sprintf("Pod uses hostPath volume %q", [volume.name])
}

# Deny hostNetwork, hostPID, hostIPC
deny[msg] if {
	input.request.kind.kind == "Pod"
	input.request.object.spec.hostNetwork == true
	msg := "Pod uses hostNetwork"
}

deny[msg] if {
	input.request.kind.kind == "Pod"
	input.request.object.spec.hostPID == true
	msg := "Pod uses hostPID"
}

deny[msg] if {
	input.request.kind.kind == "Pod"
	input.request.object.spec.hostIPC == true
	msg := "Pod uses hostIPC"
}

# Deny containers without resource limits
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.resources.limits.memory
	msg := sprintf("Container %q missing memory limit", [container.name])
}

deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.resources.limits.cpu
	msg := sprintf("Container %q missing CPU limit", [container.name])
}

# Deny containers without resource requests
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.resources.requests.memory
	msg := sprintf("Container %q missing memory request", [container.name])
}

deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.resources.requests.cpu
	msg := sprintf("Container %q missing CPU request", [container.name])
}

# Deny latest tag
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	endswith(container.image, ":latest")
	msg := sprintf("Container %q uses :latest tag", [container.name])
}

deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not contains(container.image, ":")
	msg := sprintf("Container %q has no tag", [container.name])
}

# Deny missing liveness/readiness probes
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.livenessProbe
	msg := sprintf("Container %q missing livenessProbe", [container.name])
}

deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.readinessProbe
	msg := sprintf("Container %q missing readinessProbe", [container.name])
}

# Deny missing security context
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.securityContext
	msg := sprintf("Container %q missing securityContext", [container.name])
}

# Deny missing pod security context
deny[msg] if {
	input.request.kind.kind == "Pod"
	not input.request.object.spec.securityContext
	msg := "Pod missing securityContext"
}

# Deny missing service account
deny[msg] if {
	input.request.kind.kind == "Pod"
	not input.request.object.spec.serviceAccountName
	msg := "Pod missing serviceAccountName"
}

# Deny default service account
deny[msg] if {
	input.request.kind.kind == "Pod"
	input.request.object.spec.serviceAccountName == "default"
	msg := "Pod uses default service account"
}

# Require labels on Deployments
deny[msg] if {
	input.request.kind.kind == "Deployment"
	required_labels := {"app.kubernetes.io/name", "app.kubernetes.io/version", "app.kubernetes.io/managed-by"}
	provided := object.keys(input.request.object.metadata.labels)
	missing := required_labels - provided
	count(missing) > 0
	msg := sprintf("Deployment missing required labels: %v", [missing])
}

# Require annotations on Deployments
deny[msg] if {
	input.request.kind.kind == "Deployment"
	required_annotations := {"prometheus.io/scrape", "prometheus.io/port", "prometheus.io/path"}
	provided := object.keys(input.request.object.metadata.annotations)
	missing := required_annotations - provided
	count(missing) > 0
	msg := sprintf("Deployment missing required annotations: %v", [missing])
}

# Deny containers with allowPrivilegeEscalation
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	container.securityContext.allowPrivilegeEscalation == true
	msg := sprintf("Container %q has allowPrivilegeEscalation=true", [container.name])
}

# Deny containers without readOnlyRootFilesystem
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	not container.securityContext.readOnlyRootFilesystem
	msg := sprintf("Container %q missing readOnlyRootFilesystem=true", [container.name])
}

# Deny containers with dangerous volume mounts
deny[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	mount := container.volumeMounts[_]
	mount.mountPath in ["/etc", "/usr", "/bin", "/sbin", "/lib", "/lib64", "/proc", "/sys"]
	msg := sprintf("Container %q mounts sensitive path %q", [container.name, mount.mountPath])
}

# Namespace policies
deny[msg] if {
	input.request.kind.kind == "Namespace"
	input.request.object.metadata.name in {"kube-system", "kube-public", "kube-node-lease", "default"}
	msg := sprintf("Cannot modify protected namespace %q", [input.request.object.metadata.name])
}

# Ingress policies
deny[msg] if {
	input.request.kind.kind == "Ingress"
	not input.request.object.spec.tls
	msg := "Ingress missing TLS configuration"
}

# Service policies
deny[msg] if {
	input.request.kind.kind == "Service"
	input.request.object.spec.type == "LoadBalancer"
	not input.request.object.metadata.annotations["service.beta.kubernetes.io/azure-load-balancer-internal"]
	not input.request.object.metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-internal"]
	msg := "LoadBalancer service missing internal annotation"
}

# ConfigMap policies
deny[msg] if {
	input.request.kind.kind == "ConfigMap"
	input.request.object.data[_] == ""
	msg := "ConfigMap contains empty value"
}

# Secret policies
deny[msg] if {
	input.request.kind.kind == "Secret"
	input.request.object.type == "Opaque"
	value := input.request.object.data[_]
	value != ""
	looks_sensitive(value)
	msg := "Secret may contain sensitive data in plaintext"
}

looks_sensitive(value) if contains(lower(value), "password")
looks_sensitive(value) if contains(lower(value), "secret")
looks_sensitive(value) if contains(lower(value), "token")
looks_sensitive(value) if contains(lower(value), "key")

# Warning rules (non-blocking)
warn[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	container.imagePullPolicy == "Always"
	msg := sprintf("Container %q uses imagePullPolicy: Always", [container.name])
}

warn[msg] if {
	input.request.kind.kind == "Deployment"
	input.request.object.spec.replicas < 2
	msg := "Deployment has less than 2 replicas"
}

warn[msg] if {
	input.request.kind.kind == "Pod"
	container := input.request.object.spec.containers[_]
	container.resources.limits.memory
	container.resources.requests.memory
	msg := sprintf("Container %q memory limit/request ratio may be suboptimal", [container.name])
}
