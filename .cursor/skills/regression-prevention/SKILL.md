---
name: regression-prevention
description: Verifies code changes, fixes, and refactors do not break existing behavior. Use before claiming completion, after Flutter/Dart code changes, after refactors, or when regression risk is present.
---

# regression-prevention

MODE: REGRESSION_GATE CURSOR_PORT
SOURCE: regression-prevention|pri:H|deps:[]|flags:[test-creation-strategy,test-interpretation-failure-diagnosis,correctness-validation]|rules:[TQ-3,TQ-1,MF-1,GM-2]
STANDALONE: no external policy-template reads; use this file, project tests, and local verification rules.

SCOPE: activate on code modification, fix, or refactor; detect behavioral regressions and block completion until resolved, scoped out, or own change is reverted.

ENFORCE: identify risk surface; verify coverage and flag test-creation-strategy on meaningful gaps; run tests/analyze against modified and adjacent paths; block on regression; classify test failures before fixing; for manual regressions, fix then add/verify coverage; revert own change if regression fix is out of scope; document CLEAR or REGRESSION_FOUND with evidence.

PROHIBIT: CLEAR without evidence; shipping known regression; silent coverage gaps; reverting without root-cause note; fixing test failure before classification.

ON_VIOLATION: test_failure_regression -> flag test-interpretation-failure-diagnosis -> classify. code_defect -> fix code -> if out_of_scope: revert own change -> document -> flag correctness-validation. test_defect -> flag test-creation-strategy. manual_regression -> fix code -> if out_of_scope: revert own change -> document -> flag correctness-validation + test-creation-strategy. coverage_gap -> flag test-creation-strategy -> block. scope_unclear -> request clarification.

OUTPUT: risk surface, coverage status, checks run, CLEAR/REGRESSION_FOUND, exact failures, residual risk.
