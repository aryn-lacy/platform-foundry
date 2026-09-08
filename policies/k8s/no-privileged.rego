# Policy: no privileged containers, no hostNetwork, no hostPath (issue #4)
# Workload hardening floor: containers must not run privileged, must not
# share the host network namespace, and must not mount host paths.
#
# Scope: Deployment, Rollout, and Job.
package main

import rego.v1

workload_kinds := {"Deployment", "Rollout", "Job"}

# conftest --combine presents a list of {contents, path} objects
docs := [d.contents | some d in input]

deny contains msg if {
	some doc in docs
	workload_kinds[doc.kind]
	container := pick_container(doc)
	object.get(object.get(container, "securityContext", {}), "privileged", false)
	msg := sprintf(
		"%s %s/%s: container %q runs privileged",
		[doc.kind, object.get(doc.metadata, "namespace", "default"), doc.metadata.name, container.name],
	)
}

deny contains msg if {
	some doc in docs
	workload_kinds[doc.kind]
	doc.spec.template.spec.hostNetwork
	msg := sprintf(
		"%s %s/%s: hostNetwork is set",
		[doc.kind, object.get(doc.metadata, "namespace", "default"), doc.metadata.name],
	)
}

deny contains msg if {
	some doc in docs
	workload_kinds[doc.kind]
	some vol in doc.spec.template.spec.volumes
	vol.hostPath
	msg := sprintf(
		"%s %s/%s: volume %q mounts a hostPath",
		[doc.kind, object.get(doc.metadata, "namespace", "default"), doc.metadata.name, vol.name],
	)
}

pick_container(doc) := c if {
	some c in doc.spec.template.spec.containers
}

pick_container(doc) := c if {
	some c in object.get(doc.spec.template.spec, "initContainers", [])
}
