# Policy: no :latest image tags, no tagless images (issue #4)
# Immutable digests or versioned tags only — :latest makes rollouts
# non-reproducible and rollbacks impossible; a tagless image (e.g.
# "nginx") resolves to :latest implicitly.
#
# Scope: every container (incl. initContainers) of every workload kind —
# Deployment, Rollout (Argo Rollouts CRD), and Job. A Deployment-only rule
# would silently pass the whole backend/frontend fleet, which deploys as
# Rollouts. Containers are bound inside the deny body (NOT via a helper
# function — a function producing multiple outputs for one input crashes
# conftest with eval_conflict_error on any multi-container workload).
#
# Tagless heuristic: an image is tagless iff its final path segment lacks
# BOTH a digest marker (@sha256:) and a ':' after any registry host.
# Registry hosts with ports (registry:5000/app) are handled by only
# treating ':' as a tag separator when it appears in the last path
# segment.
package main

import rego.v1

workload_kinds := {"Deployment", "Rollout", "Job"}

# conftest --combine presents a list of {contents, path} objects
docs := [d.contents | some d in input]

deny contains msg if {
	some doc in docs
	workload_kinds[doc.kind]
	some container in doc.spec.template.spec.containers
	bad_image(container.image)
	msg := sprintf(
		"%s %s/%s: container %q uses a mutable image reference (%s) — pin a digest or versioned tag",
		[doc.kind, object.get(doc.metadata, "namespace", "default"), doc.metadata.name, container.name, container.image],
	)
}

deny contains msg if {
	some doc in docs
	workload_kinds[doc.kind]
	some container in object.get(doc.spec.template.spec, "initContainers", [])
	bad_image(container.image)
	msg := sprintf(
		"%s %s/%s: init container %q uses a mutable image reference (%s) — pin a digest or versioned tag",
		[doc.kind, object.get(doc.metadata, "namespace", "default"), doc.metadata.name, container.name, container.image],
	)
}

# explicit :latest
bad_image(image) if endswith(lower(image), ":latest")

# tagless and digestless: last path segment contains no ':' or '@'
bad_image(image) if {
	not contains(image, "@")
	last := array.reverse(split(image, "/"))[0]
	not contains(last, ":")
}
