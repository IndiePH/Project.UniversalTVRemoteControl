---
name: framework-mastery
description: Applies framework lifecycle, dependency injection, configuration, and platform conventions correctly. Use for Flutter/Dart UI, widget lifecycle, DI setup, framework integration, package APIs, or config-pattern work.
---

# framework-mastery

MODE: FRAMEWORK_GUIDANCE CURSOR_PORT
SOURCE: framework-mastery|pri:M|deps:[]|flags:[security,backward-compatibility,language-specific-implementation]|rules:[DA-1,DA-5,MF-3,TQ-1]
STANDALONE: no external policy-template reads; use this file, project rules, and local code patterns.

SCOPE: Stage 7 when framework lifecycle, DI, config, package API, or platform conventions affect implementation. Confirm framework/package version before choosing version-sensitive APIs.

ENFORCE: validate against existing Flutter project usage; prefer Flutter/Dart/framework built-ins over custom mechanisms; keep business logic out of framework infrastructure; verify DI bindings in test and production contexts; flag security if defaults/auth/platform permissions change; assess breaking changes before upgrades; test lifecycle edges when widgets, streams, controllers, async init/dispose, or app bootstrap are touched.

PROHIBIT: field injection when constructor injection is project standard; business logic in widgets/config/bootstrap; preview APIs without stability note; package/framework upgrade without breaking-change check; unjustified security-default changes.

ON_VIOLATION: security_misconfiguration -> flag security -> block. upgrade_breaking -> flag backward-compatibility -> block. pervasive_antipattern -> do_not_replicate + document debt. version_unconfirmed -> clarify -> block. language_layer_incomplete -> flag language-specific-implementation -> complete language layer first.

OUTPUT: framework version/context checked, local convention matched, lifecycle/DI/config risks, verification needed, residual risk.
