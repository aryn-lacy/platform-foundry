# Policy: no :latest image tags (issue #4)
# Immutable digests or versioned tags only — a :latest tag makes rollouts
# non-reproducible and rollbacks impossible.
#
# Scope: every container (incl. initContainers) of every workload kind —
# Deployment, Rollout (Argo Rollouts CRD), and Job. A Deployment-only rule
# would silently pass the whole backend/frontend fleet, which deploys as
# Rollouts.
#
# Interpretation note: tagless images (e.g. "nginx") are ALSO mutable in
# spirit, but distinguishing a tagless image from a registry host with a
# port (registry:5000/app) requires fragile parsing; this rule enforces
# the explicit :latest case, which is what the issue text names.
package main

import rego.v1

workload_kinds := {"Deployment", "Rollout", "Job"}

# conftest --combine presents a list of {contents, path} objects
docs := [d.contents | some d in input]

deny contains msg if {
	some doc in docs
	workload_kinds[doc.kind]
	container := pick_container(doc)
	endswith(lower(container.image), ":latest")
	msg := sprintf(
		"%s %s/%s: container %q uses :latest tag (%s) — pin an immutable digest or versioned tag",
		[doc.kind, object.get(doc.metadata, "namespace", "default"), doc.metadata.name, container.name, container.image],
	)
}

pick_container(doc) := c if {
	some c in doc.spec.template.spec.containers
}

pick_container(doc) := c if {
	some c in object.get(doc.spec.template.spec, "initContainers", [])
}
