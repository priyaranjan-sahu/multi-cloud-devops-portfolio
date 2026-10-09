package kubernetes.admission

# Test cases for deny rules

test_deny_root_container if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "securityContext": {"runAsUser": 0}},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_missing_runAsNonRoot if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "securityContext": {}},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_privileged if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "securityContext": {"privileged": true}},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_dangerous_capability if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "securityContext": {"capabilities": {"add": ["SYS_ADMIN"]}}},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_hostpath if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"volumes": [{"name": "host", "hostPath": {"path": "/etc"}}],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_host_network if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {"hostNetwork": true},
			},
		},
	}
	deny with input as test_input
}

test_deny_no_memory_limit if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "resources": {"limits": {"cpu": "100m"}}},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_latest_tag if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "image": "nginx:latest"},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_no_tag if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "image": "nginx"},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_missing_probes if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "image": "nginx:1.25"},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_missing_security_context if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "image": "nginx:1.25"},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_default_service_account if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"serviceAccountName": "default",
					"containers": [{"name": "test", "image": "nginx:1.25"}],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_missing_labels if {
	test_input := {
		"request": {
			"kind": {"kind": "Deployment"},
			"object": {
				"metadata": {"labels": {"app": "test"}},
				"spec": {
					"template": {
						"spec": {
							"containers": [{"name": "test", "image": "nginx:1.25"}],
						},
					},
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_allow_privilege_escalation if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "image": "nginx:1.25", "securityContext": {"allowPrivilegeEscalation": true}},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_missing_readonly_rootfs if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "image": "nginx:1.25", "securityContext": {"runAsNonRoot": true}},
					],
				},
			},
		},
	}
	deny with input as test_input
}

test_deny_ingress_no_tls if {
	test_input := {
		"request": {
			"kind": {"kind": "Ingress"},
			"object": {
				"spec": {
					"rules": [{"host": "example.com"}],
				},
			},
		},
	}
	deny with input as test_input
}

# Test cases for allowed (no deny)

test_allow_good_pod if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"serviceAccountName": "my-sa",
					"securityContext": {
						"runAsNonRoot": true,
						"runAsUser": 1000,
						"fsGroup": 1000,
					},
					"containers": [
						{
							"name": "test",
							"image": "nginx:1.25",
							"securityContext": {
								"runAsNonRoot": true,
								"runAsUser": 1000,
								"allowPrivilegeEscalation": false,
								"readOnlyRootFilesystem": true,
								"capabilities": {"drop": ["ALL"]},
							},
							"resources": {
								"limits": {"memory": "256Mi", "cpu": "500m"},
								"requests": {"memory": "128Mi", "cpu": "100m"},
							},
							"livenessProbe": {"httpGet": {"path": "/health", "port": 8080}},
							"readinessProbe": {"httpGet": {"path": "/ready", "port": 8080}},
						},
					],
				},
			},
		},
	}
	count(deny) == 0 with input as test_input
}

test_allow_good_deployment if {
	test_input := {
		"request": {
			"kind": {"kind": "Deployment"},
			"object": {
				"metadata": {
					"labels": {
						"app.kubernetes.io/name": "test",
						"app.kubernetes.io/version": "1.0.0",
						"app.kubernetes.io/managed-by": "helm",
					},
					"annotations": {
						"prometheus.io/scrape": "true",
						"prometheus.io/port": "8080",
						"prometheus.io/path": "/metrics",
					},
				},
				"spec": {
					"replicas": 3,
					"template": {
						"metadata": {
							"labels": {
								"app.kubernetes.io/name": "test",
							},
						},
						"spec": {
							"serviceAccountName": "my-sa",
							"securityContext": {
								"runAsNonRoot": true,
								"runAsUser": 1000,
							},
							"containers": [
								{
									"name": "test",
									"image": "nginx:1.25",
									"securityContext": {
										"runAsNonRoot": true,
										"runAsUser": 1000,
										"allowPrivilegeEscalation": false,
										"readOnlyRootFilesystem": true,
										"capabilities": {"drop": ["ALL"]},
									},
									"resources": {
										"limits": {"memory": "256Mi", "cpu": "500m"},
										"requests": {"memory": "128Mi", "cpu": "100m"},
									},
									"livenessProbe": {"httpGet": {"path": "/health", "port": 8080}},
									"readinessProbe": {"httpGet": {"path": "/ready", "port": 8080}},
								},
							],
						},
					},
				},
			},
		},
	}
	count(deny) == 0 with input as test_input
}

# Test warning rules

test_warn_image_pull_always if {
	test_input := {
		"request": {
			"kind": {"kind": "Pod"},
			"object": {
				"spec": {
					"containers": [
						{"name": "test", "image": "nginx:1.25", "imagePullPolicy": "Always"},
					],
				},
			},
		},
	}
	warn with input as test_input
}

test_warn_single_replica if {
	test_input := {
		"request": {
			"kind": {"kind": "Deployment"},
			"object": {
				"spec": {
					"replicas": 1,
					"template": {
						"spec": {
							"containers": [{"name": "test", "image": "nginx:1.25"}],
						},
					},
				},
			},
		},
	}
	warn with input as test_input
}
