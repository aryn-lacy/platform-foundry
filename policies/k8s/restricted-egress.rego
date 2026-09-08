# Policy: restricted egress / NetworkPolicy posture (issue #4)
#
# Interpretation of "egress restricted to declared destinations" as two
# enforceable checks on the rendered bundle:
#
#  1. COVERAGE — every long-running server workload must be selected by
#     at least one NetworkPolicy in its namespace. An unselected pod
#     escapes the default-deny posture entirely (Kubernetes allows all
#     traffic to pods with no selecting policy).
#
#     Workload resolution handles BOTH Rollout shapes:
#       - inline template: labels from spec.template.metadata.labels
#       - workloadRef: the Rollout adopts the referenced Deployment's
#         pods, so labels resolve from that Deployment in the same
#         bundle (name + namespace match). A workloadRef pointing at a
#         Deployment that is not in the bundle is itself a coverage
#         failure.
#
#     Jobs are deliberately EXEMPT: the estate's one Job is a break-glass
#     bootstrap that talks to RDS directly, and requiring policy coverage
#     for one-shot jobs would push policy authoring into P3's reviewed
#     scope. AnalysisTemplates are not workloads at all.
#
#  2. NO ALLOW-ALL — no NetworkPolicy may contain an empty egress rule
#     ("egress: - {}"), which permits ALL destinations. Egress must be
#     enumerated.
#
# Selector matching implements empty-selector (matches everything in the
# namespace) and matchLabels subset semantics. matchExpressions is not
# evaluated — the estate uses plain labels; extending this is a follow-up
# if expressions ever appear.
package main

import rego.v1

server_kinds := {"Deployment", "Rollout"}

# conftest --combine presents a list of {contents, path} objects
docs := [d.contents | some d in input]

# --- Check 1: coverage ---

deny contains msg if {
	some wl in docs
	server_kinds[wl.kind]
	not covered_by_any_policy(wl)
	msg := sprintf(
		"%s %s/%s: no NetworkPolicy selects this workload — pods escape the default-deny posture",
		[wl.kind, workload_namespace(wl), wl.metadata.name],
	)
}

covered_by_any_policy(wl) if {
	some np in docs
	np.kind == "NetworkPolicy"
	selects(np, wl)
}

selects(np, wl) if {
	np_namespace(np) == workload_namespace(wl)
	not np.spec.podSelector.matchLabels
}

selects(np, wl) if {
	np_namespace(np) == workload_namespace(wl)
	sel := np.spec.podSelector.matchLabels
	labels := workload_labels(wl)
	every k, v in sel {
		labels[k] == v
	}
}

# Pod labels of a workload, resolving workloadRef Rollouts to their
# referenced Deployment.
workload_labels(wl) := wl.spec.template.metadata.labels

workload_labels(wl) := ref_labels if {
	ref := wl.spec.workloadRef
	some d in docs
	d.kind == "Deployment"
	d.metadata.name == ref.name
	deployment_namespace(d) == workload_namespace(wl)
	ref_labels := d.spec.template.metadata.labels
}

deployment_namespace(d) := object.get(d.metadata, "namespace", "default")

# --- Check 2: no allow-all egress rules ---

deny contains msg if {
	some np in docs
	np.kind == "NetworkPolicy"
	some rule in object.get(np.spec, "egress", [])
	count(rule) == 0
	msg := sprintf(
		"NetworkPolicy %s/%s: egress contains an empty rule (allow-all) — enumerate destinations",
		[np_namespace(np), np.metadata.name],
	)
}

workload_namespace(wl) := object.get(wl.metadata, "namespace", "default")

np_namespace(np) := object.get(np.metadata, "namespace", "default")
