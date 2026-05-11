---
name: abstraction-domain-modeling
description: Models domain concepts into coherent code structures with clear ownership and vocabulary. Use for Flutter/Dart domain models, capability modeling, adapters, value objects, app concepts, and business-boundary decisions.
---

# abstraction-domain-modeling

MODE: DOMAIN_MODELING_GUIDANCE CURSOR_PORT
SOURCE: abstraction-domain-modeling|pri:M|deps:[correctness-validation,clean-code-solid]|flags:[design-pattern-selection,clean-code-solid,api-design,system-design]|rules:[DA-2,DA-4,DA-5,PS-1,GM-2]
STANDALONE: no external policy-template reads; use this file, project rules, and local domain language.

SCOPE: model business concepts into coherent code structures aligned with domain language and logical boundaries.

ENFORCE: choose abstraction level by business meaning, not technical convenience; align code vocabulary with domain language; keep boundaries aligned to real domain separations; class changes only when business responsibility changes; reject abstractions without real domain concept; validate model against requirements; explain modeling decisions before implementation; map entities, value objects, aggregates, and capabilities to business concepts when relevant.

PROHIBIT: abstractions named after technical concerns in business layers; splitting one domain concept across classes without ownership; anemic domain models where behavior belongs on entity/value object; technical jargon in business-layer code; multiple domains in one class; ignoring domain vocabulary; over-abstracting simple concepts; choosing convenience over meaning.

ON_VIOLATION: domain_unclear -> request clarification. domain_reveals_service_boundaries -> flag system-design. abstraction_level_unclear -> verify with domain intent. vocab_mismatch -> update to domain language. domain_pattern_opportunity -> flag design-pattern-selection. model_needs_solid_validation -> flag clean-code-solid. domain_boundaries_define_apis -> flag api-design.

OUTPUT: domain concepts, ownership, vocabulary decisions, rejected abstractions, API/pattern follow-ups, residual risk.
