# Policy: resource limits required on every container (issue #4)
# Every container of every workload kind must set BOTH resources.limits.cpu
# and resources.limits.memory. Unbounded containers can starve nodes and
# break bin-packing/autoscaling decisions.
#
# Scope: Deployment, Rollout, and Job — containers AND initContainers,
# bound inside the deny bodies (helper functions crash on multi-container
# workloads: eval_conflict_error).
package main

import rego.v1

workload_kinds := {"Deployment", "Rollout", "Job"}

# conftest --combine presents a list of {contents, path} objects
docs := [d.contents | some d in input]

deny contains msg if {
	some doc in docs
	workload_kinds[doc.kind]
	some container in doc.spec.template.spec.containers
	limits := object.get(object.get(container, "resources", {}), "limits", {})
	not has_both_limits(limits)
	msg := sprintf(
		"%s %s/%s: container %q missing resources.limits (needs both cpu and memory)",
		[doc.kind, object.get(doc.metadata, "namespace", "default"), doc.metadata.name, container.name],
	)
}

deny contains msg if {
	some doc in docs
	workload_kinds[doc.kind]
	some container in object.get(doc.spec.template.spec, "initContainers", [])
	limits := object.get(object.get(container, "resources", {}), "limits", {})
	not has_both_limits(limits)
	msg := sprintf(
		"%s %s/%s: init container %q missing resources.limits (needs both cpu and memory)",
		[doc.kind, object.get(doc.metadata, "namespace", "default"), doc.metadata.name, container.name],
	)
}

has_both_limits(limits) if {
	limits.cpu
	limits.memory
}
