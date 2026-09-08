# modules/ — hand-rolled, deliberately (ADR-009)

Every module in this tree is written for this repository. No community
module sources (terraform-aws-modules et al.) are consumed.

**Why (ADR-009, full argument in docs/decisions/):**

- **Full surface knowledge.** A hand-rolled module is code you have read
  line by line; its variables, defaults, and upgrade behavior are known,
  not researched. Community modules ask you to internalize someone else's
  abstraction surface before you can safely change a single line.
- **No upstream churn tax.** Community modules change underneath you —
  version bumps alter defaults, refactor interfaces, and occasionally get
  clever in ways that break in production-interesting ways. The debugging
  time spent inside someone else's abstraction exceeds the time saved by
  not writing the resource blocks yourself.
- **The cost asymmetry has flipped.** With LLM-assisted development, the
  marginal cost of authoring a well-structured module is far below its
  historical cost. Writing is cheap; debugging foreign cleverness is not.

**Contract:** modules stay small, single-domain (one concern per module),
and interface-stable — root files consume outputs, never internals. When a
module grows a second concern, it splits. That discipline is what makes
hand-rolling cheaper than dependency management.
