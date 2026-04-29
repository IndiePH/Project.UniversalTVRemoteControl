---
name: modularity
description: Designs cohesive, loosely coupled modules with explicit interfaces and domain-aligned boundaries. Use for Flutter feature boundaries, DI/module wiring, app decomposition, dependency direction, or module ownership decisions.
---

# modularity

MODE: MODULARITY_GUIDANCE CURSOR_PORT
SOURCE: modularity|pri:H|deps:[system-design]|flags:[dependency-management,refactoring,abstraction-domain-modeling,api-design,technical-debt-management]|rules:[DA-1,DA-2,DA-4,DA-5,DA-7,DT-1,GM-2,GM-4]
STANDALONE: no external policy-template reads; use this file, project rules, and local architecture.

SCOPE: decompose system into cohesive, loosely coupled modules with explicit interfaces and domain-aligned boundaries.

ENFORCE: module boundary must reflect domain concern, not technical convenience; each module responsibility fits one sentence without conjunctions; define explicit public interface; keep symbols private by default; dependency direction must follow UI -> application/domain -> data/infrastructure; assign each domain concern to exactly one module; classify boundary violations by severity; document deliberate boundary tradeoffs with rationale and remediation.

PROHIBIT: modules organized only by technical layer when domain boundary is needed; circular module dependencies; accepting boundary violations without remediation plan; interfaces based on implementation convenience rather than consumer need.

ON_VIOLATION: circular_mod_dep -> block approval -> recommend break strategy -> flag dependency-management. boundary_ambiguity -> flag abstraction-domain-modeling -> halt boundary decisions. blocking_violations -> block new feature work -> escalate. numerous_violations -> flag technical-debt-management -> log debt. complex_api_interface -> flag api-design -> require formal interface design.

OUTPUT: module boundaries, public interfaces, dependency direction check, violations/remediation, deferred debt.
