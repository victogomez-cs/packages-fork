# Objective-C → Swift migration rollout plan

This document describes the repeatable **process** for rolling out the
[`objc-to-swift-migration`](./SKILL.md) skill across the repository — it is
package-agnostic and applies to any flutter/packages Darwin
(`_ios`/`_macos`/`_darwin`) plugin implementation, not a specific one. The
skill defines *how* to migrate a single package (the mechanics, phases,
non-negotiables); this document defines *how the initiative as a whole is
sequenced, validated, and kept honest* across however many packages end up
being migrated. Read the skill first — this plan assumes it and does not
repeat its phase-by-phase mechanics.

## 1. Goal and scope

Eliminate hand-written Objective-C from flutter/packages' Darwin plugin
implementations, one package at a time, with **zero change to Dart-facing
behavior**. Each package is migrated independently, on its own branch — as a
single PR by default, or as a short sequence of PRs for large packages using
the skill's incremental rollout strategy (see
[§6](#6-per-pr-safety-and-rollback)); nothing in this plan changes the
Dart-facing API of any plugin — app authors should see no difference other
than a CHANGELOG entry and a patch version bump per migrated package.

This plan does not hardcode which package is migrated next — that's decided
each time using the criteria in [§2](#2-choosing-and-sequencing-packages)
below, based on what Discovery (skill Step 0) finds for the candidates under
consideration.

## 2. Choosing and sequencing packages

Before starting a package, run the skill's Step 0 (Discovery) against it to
gather the facts needed to size and sequence the work:

- Hand-written Obj-C line count (`.h`/`.m`, excluding Pigeon-generated files).
- OCMock density: how many distinct system classes/methods are mocked, and of
  what kind (class/static method vs. instance vs. `alloc`/`init`
  interception) — more distinct mocked system APIs means more new Phase 3
  protocol seams to design.
- Whether the package is already in the **"tests-first" partial-migration
  shape** described in the skill (protocol seams and/or Swift tests already
  exist, only the plugin class itself remains Obj-C) — these are lower-risk
  and faster.
- Whether the package shares a system framework, permission model, or a
  `_darwin` target with another package already migrated (or being migrated
  in the same wave) — shared patterns mean the protocol-seam design and Swift
  fakes from one package can often be reused or closely mirrored in the next.

Sequencing guidance:

- **Prefer smaller, lower-OCMock-density, and/or already-partially-migrated
  packages first.** They validate the Pigeon `swiftOut` step, the prefix-drop
  + `pubspec.yaml` update, and the Xcode-project cleanup mechanics
  (deleted-file references, and — if present — OCMock removal from
  `project.pbxproj`) at lower risk before tackling a package that needs
  substantial new Phase 3 protocol-seam design.
- **Batch related packages together** when it's efficient to do so (e.g. two
  plugins wrapping the same system framework, or two plugins that already
  share a `_darwin` target) so the protocol-seam/test-double patterns
  developed for one directly inform the other — but still land them as
  separate PRs (see [§6](#6-per-pr-safety-and-rollback)).
- **Default to big-bang rollout** (single PR covering all Sources + all
  tests) for any package under the skill's ~3-4k-line hand-written-Obj-C
  threshold; use the skill's incremental multi-PR pattern only above that
  threshold.
- After each package, feed concrete learnings back into `SKILL.md` (new
  protocol-seam patterns, gaps in the phase instructions, etc.) before
  starting the next one, so the playbook keeps improving.

## 3. Non-negotiables (acceptance bar for every package)

Restated from the skill — a package isn't "done" until all of these hold:

- No behavior change: every validation rule, error code/message, and edge
  case (nil handling, rounding, clamping, "0 means unlimited", etc.) is
  preserved exactly. Bugs found along the way are flagged, not silently
  fixed.
- Every existing native test method has a passing Swift equivalent — counts
  must match or exceed the pre-migration baseline.
- Every existing Dart-side test (`test/*.dart`) still passes unchanged, and
  `git diff` on generated Dart Pigeon output (`lib/src/messages.g.dart` or
  equivalent) is empty.
- CHANGELOG updated and version bumped (patch-level, per this repo's
  precedent that a pure Obj-C→Swift rewrite is non-breaking, since the Dart
  API is untouched).
- `format`, `analyze`, `dart-test`, and `native-test` all pass — not just the
  native suite.
- Dropping the package's vendor Obj-C prefix on Swift class names is in
  scope and expected: it only touches internal Swift symbol names and
  `pubspec.yaml`'s `pluginClass:` string, never `dartPluginClass` or any
  Dart-visible type, so it is not a breaking change.
- Test-count parity means porting *existing* tests 1:1 — it does not mean
  achieving full coverage. Whether a package's native code is already at
  100% coverage isn't something to assume either way: this repo's
  `coverage-check` tool only measures **Dart** coverage (for packages
  opted into `script/configs/custom_coverage_minimums.yaml`), never native,
  so it varies per package and must be checked directly (Discovery /
  Coverage-only mode), not assumed. Closing any gaps found is an explicit,
  separate, opt-in follow-up regardless (see
  [§10](#10-optional-backfilling-missing-coverage)), not part of what makes
  the core migration "done".

## 4. Discovery output: what to capture per package

Before writing any Swift, turn the skill's Step 0 findings into two concrete
artifacts for the target package (keep these in the PR description or an
issue, not committed as permanent docs):

**File inventory** — one row per hand-written `.h`/`.m` file:

- File path.
- Hand-written or Pigeon-generated (generated files are handled by Phase 1's
  `swiftOut` change, not hand-ported).
- Planned Swift replacement file/class name (prefix dropped, per the
  Non-negotiables).
- Which migration phase it belongs to (leaf utility class = Phase 2; core
  plugin class = Phase 4; etc.).

**OCMock inventory** (skip if the package has no OCMock usage) — one row per
distinct system class being mocked:

- System class name.
- Method(s) mocked, and the mock kind (class/static method, instance method,
  or `alloc`/`init` construction interception).
- Planned protocol name for the new seam (named for what it *does*, not for
  the system class it wraps, per the skill's Phase 3 guidance).
- Existing test methods that exercise it (these become the coverage checklist
  for Phase 5 — see [§5.4](#54-edge-case-coverage-methodology)).

Also record the **pre-migration native test count** (Phase 0 baseline) —
this is the single number that Phase 8 must match or exceed.

## 5. Test strategy and tech stack

### 5.1 Dart side (unchanged)

`flutter_test` + `mockito`/`build_runner`-generated mocks, exactly as before
migration. `dart-test` must stay green with **zero diff** in generated
Pigeon Dart output — any diff there means Phase 1 introduced an unintended
API change and must be fixed before continuing, not worked around.

### 5.2 Native side: Swift Testing, not XCTest

Per the skill's "Native test framework: Swift Testing, not XCTest" section,
all newly-written or newly-ported native Swift tests use the **Swift
Testing** framework (`import Testing`), matching current repo convention:

- `@Suite`/`@Test` structs mirroring the old Obj-C `- (void)testXxx` methods
  1:1, grouped to mirror the original test file's logical sections.
- `#expect(...)`/`#require(...)` instead of `XCTAssert*`.
- `await confirmation("...") { confirmed in ... }` instead of
  `XCTestExpectation`/`waitForExpectations` for async completion-handler
  APIs.
- `@Test(arguments: [...])` for parameterized cases, instead of copy-pasted
  near-duplicate test functions that only differ in input/expected-output —
  but only collapse tests this way if every original case is preserved with
  equal or better clarity.

### 5.3 Test doubles

Hand-rolled Swift structs/classes conforming to the Phase-3 protocols — **no
third-party Swift mocking library** (no Cuckoo, Mockingbird, etc.). Fakes
should be simple: stored properties for stubbed return values, and simple
counters/argument-capturing properties for recording calls, matching this
repo's established convention for already-migrated packages.

### 5.4 Edge-case coverage methodology

Rather than a fixed list (edge cases are specific to each package's domain),
use the OCMock inventory from [§4](#4-discovery-output-what-to-capture-per-package)
as a checklist generator. For each mocked system API found, check whether it
falls into one of these recurring categories, and if so, confirm the ported
test suite still exercises every value/branch called out:

- **Permission/authorization state matrices** — every distinct
  authorization/status enum case the original tests covered (e.g.
  authorized/denied/restricted/not-determined, plus any "limited" or
  provisional variant), not just the happy path.
- **Capability/availability checks** — every "is this feature available"
  branch (true and false), and for both/all variants if the check is
  parameterized (e.g. per-device, per-source-type).
- **Object construction interception** — if OCMock intercepted `alloc`/`init`
  to inject a mock instance, confirm the replacement factory-based seam is
  exercised with the same inputs the original test constructed.
- **"Duplicate/concurrent call while one is in-flight" semantics** — any test
  verifying that a second call while the first hasn't completed either
  cancels, replaces, or no-ops relative to the first.
- **"Verify NOT called" assertions** (`OCMReject` equivalents) — confirm the
  Swift fake would observably register a call if made, and the test asserts
  the count is zero, not just that the test didn't crash.
- **Multi-item/batch flows with partial failures** — any flow operating over
  a list/collection where some items succeed and others fail.
- **Sentinel/default values** — `0`, `nil`, or another sentinel meaning
  "unlimited", "unset", or "use default" rather than a literal value; these
  are exactly the kind of edge case the Non-negotiables warn about silently
  "fixing".
- **Exception/error translation** — every distinct native
  exception-to-error or error-domain/error-code mapping table the plugin
  defines, including the fallback/unknown-code case.
- **Configuration precedence/defaulting logic** — if the plugin merges
  runtime parameters with a config file, bundle resource, or other default
  source, confirm every precedence combination the original tests covered
  is still covered.

### 5.5 Avoiding false positives

A mechanically-ported test can compile and pass while testing nothing. Before
considering any test "ported", verify:

1. **Test-count parity.** The Phase 8 native test count must match or exceed
   the Phase 0 baseline recorded during Discovery. A drop means a test was
   silently dropped or merged away.
2. **Run twice.** Run the full ported native suite at least twice
   consecutively after porting, to catch order-dependent or shared-state
   flakiness (long-lived mutable state — caches, dictionaries keyed by
   session/user identifiers, override queues used for deterministic testing,
   etc. — must be correctly isolated per test).
3. **Verify assertions have teeth.** For every ported "verify called N
   times" or "expect called" assertion, confirm the Swift fake actually
   records a call count or the arguments it was called with, and that the
   test asserts on that recorded state — not just that a stubbed return
   value came back. This is the single most common way a "passing"
   mechanical port silently stops verifying the behavior it used to verify.
4. **Verify "not called" assertions still work.** For every ported "reject"/
   "must not be called" assertion, confirm the fake's method would be
   observably recorded if invoked, and the test asserts that count is `0`.
5. **Prefer real objects over new fakes** wherever the skill's Phase 3
   guidance says to (simple data-holder objects returned by system APIs) —
   fewer seams means fewer places a fake's behavior can quietly diverge from
   the real SDK object's.
6. **Diff generated Pigeon output** (Dart and Swift) field-by-field against
   what existed before, both immediately after Phase 1 and again at the end,
   to catch drift introduced by any manual touch-ups made afterward.

## 6. Per-PR safety and rollback

- **Never combine multiple packages' migrations in one PR**, so a revert of
  one never touches another. This holds regardless of rollout strategy
  ([§2](#2-choosing-and-sequencing-packages)):
  - **Big-bang** (the default, for packages under the skill's ~3-4k-line
    threshold): one PR covers that package's entire migration.
  - **Incremental** (large packages only): that *same* package's migration
    spans a short, sequential *series* of PRs instead of one (e.g. utils →
    individual features → plugin core → tests, per
    `camera_avfoundation`'s precedent) — still only ever touching that one
    package. Each PR in the series must leave the package in a buildable,
    passing state (temporary Obj-C/Swift interop is expected mid-series),
    and be independently revertable without stranding a later PR in the
    same series that depends on it.
- Review the Xcode project (`.pbxproj`) diff line-by-line for every example
  project touched — deleted-file reference cleanup, and (if applicable)
  OCMock package-dependency removal — since `.pbxproj` is not designed to be
  hand-diffed and stray entries are easy to miss.
- Verify both dependency paths resolve post-migration: CocoaPods
  (`example/<platform>/Podfile`) and Swift Package Manager (the repo's SPM
  example variant / Xcode "Add Package" flow), per the skill's Phase 8.
- If a native-test regression surfaces after merge, treat it as the port not
  matching the original behavior (the "no logic change" non-negotiable) and
  fix it with priority. A plain `git revert` on `main` is rarely sufficient
  by itself once the package is already published to pub.dev, which is
  usually the case within minutes of merge — see
  [§7](#7-after-merge-release-and-deployment) for what "reverting" actually
  requires at that point.

## 7. After merge: release and deployment

Landing the PR is normally the **entire** deployment step — nothing beyond
the PR itself is required, because this repo's [release
process](https://github.com/flutter/flutter/blob/master/docs/ecosystem/release/README.md)
is automatic:

- Once the PR merges to `main`, a GitHub Actions workflow ("release")
  detects the version bump made by `update-release-info`, publishes the new
  version to pub.dev, and tags the commit — no further action needed from
  whoever landed the PR.
- This only runs post-submit and waits for all other CI to pass first, so a
  merged PR isn't actually live on pub.dev until "release" CI finishes —
  check that job, not just the merge, to confirm the migration shipped.
- This migration never changes a package's `name:` in `pubspec.yaml` (only
  internal Swift class names and, if applicable, `pluginClass:`), so it's
  always an existing, already-verified-publisher package — the release
  docs' one-time "transfer a brand-new package to the verified publisher"
  step never applies here.

Two things can change that default, and are worth checking for the target
package during Discovery rather than assuming a plain PR is always enough:

1. **Batch release.** If the package has a `ci_config.yaml` with
   `release: batch: true`, don't expect an immediate release:
   `update-release-info` already detects batch mode and writes a
   `pending_changelogs/` entry instead of editing `CHANGELOG.md`/
   `pubspec.yaml` directly — no extra step needed from the migration
   itself — but the actual release only happens on that package's own
   periodic cadence, via a separate auto-generated PR that a package owner
   reviews and merges. Flag this in the end-of-migration summary
   ([§9](#9-end-of-migration-summary-mandatory)) so the user doesn't expect
   it published right away.
2. **Post-release regressions.** Because release is fast and automatic, a
   regression noticed after merge almost always means the version is
   already live — and **published versions can never be un-published or
   reverted** (publishing is forever). Landing a new version that reverts
   the code (with its own CHANGELOG entry and version bump), or a
   fix-forward, is required either way — see [§6](#6-per-pr-safety-and-rollback).
   Retraction (pub.dev's Admin tab, within 7 days of release) is available
   as an additional stop-gap alongside that fix, not a replacement for it.

No manual `dart pub publish` or manual tagging is expected as part of this
migration under normal circumstances — the fully-manual release path exists
only for infra-level failures unrelated to the migration itself.

## 8. Validation matrix

For each package, run the skill's Phase 8 command list
(`format`/`analyze`/`dart-test`/`native-test`/`podspec-check`/`validate`/
`publish-check`/`license-check`). Two things are worth checking on whatever
machine is doing the work, since they fail in easy-to-misdiagnose ways rather
than obviously:

- `format`, `analyze`, and `dart-test` only need a working Flutter/Dart SDK
  (see [`AGENTS.md`](../../../AGENTS.md) for environment setup) — no Xcode
  required.
- `native-test`, the build step inside `podspec-check`, and any simulator
  smoke testing require a **full Xcode install with at least one iOS
  Simulator runtime**, not just the Command Line Tools. Self-check with
  `xcode-select -p` / `xcodebuild -showsdks` (per the skill's "Requires
  macOS + Xcode" section) before starting, and if only Command Line Tools
  are available, produce the code changes but flag those specific validation
  steps as pending manual verification rather than attempting to run them.

## 9. End-of-migration summary (mandatory)

Every package migration ends with an explicit summary — this is not optional,
even if some validation steps had to be skipped for environment reasons.
Report, at minimum:

- What changed (deleted `.h`/`.m` files and Swift replacements, renamed
  classes, `pubspec.yaml` updates, CHANGELOG/version bump).
- Test-count parity: pre-migration baseline vs. final count, stated
  explicitly.
- Which [§8](#8-validation-matrix) commands actually ran and passed versus
  which are pending manual verification, and why — never imply a step passed
  if it was never run.
- Any pre-existing bug or surprising edge case that was flagged rather than
  silently fixed, per the Non-negotiables.
- Concrete next steps for the user: commands to run on a full-Xcode machine,
  manual permission-flow smoke testing, reviewing the `.pbxproj` diff by
  hand, and confirming both CocoaPods and SPM examples build. The summary
  itself should stay focused on the port that was just done — don't
  presuppose the coverage-backfill decision here, ask it separately next
  (see [§10](#10-optional-backfilling-missing-coverage)).

## 10. Optional: backfilling missing coverage

Native coverage isn't tracked repo-wide (this repo's `coverage-check` tool
only measures Dart coverage), so any given package may or may not already
be at 100% — check per package rather than assuming. Where a gap exists,
closing it is a distinct activity from the zero-behavior-change port —
mixing "new tests for previously-uncovered code" into the same PR as
"mechanical Obj-C→Swift translation" makes both harder to review and to
revert independently. Per the skill, this is opt-in, and by default the
opt-in **question itself** is asked only *after* the pure port is fully validated
and summarized ([§9](#9-end-of-migration-summary-mandatory)) — not up front
alongside the initial plan — and the backfill work never starts before that
point either way:

The opt-in doesn't have to happen at the end, though: the skill's
**Coverage-only mode** lets this decision be made *up front*, before any
migration work starts, by first reporting the package's current coverage
(a real or approximate percentage, what's covered, and what's missing) with
no code changes, then asking whether to fold closing those gaps into the
same migration effort. Prefer offering this when sequencing a package that's
suspected to have low coverage (per [§2](#2-choosing-and-sequencing-packages)),
so the coverage/scope discussion happens before committing to an order.

- Land it as its own follow-up commit/PR.
- Prefer objectively identifying gaps (e.g. `xcodebuild ... -enableCodeCoverage
  YES` + `xcrun xccov view --report ...`) over guessing.
- New tests follow the same Swift Testing + hand-rolled-fake conventions as
  the rest of the port ([§5](#5-test-strategy-and-tech-stack)).
- If a new test fails against the plugin's *current* behavior, treat that as
  a discovered pre-existing bug to flag to the user, not something to fix
  silently while "just adding a test".

## 11. Definition of done (per package)

A package is done when all of the following are true:

- [ ] Zero `.h`/`.m` files remain in the package (outside vendored
      third-party code, if any) — including Pigeon-generated ones, now
      produced via `swiftOut`.
- [ ] Native test method count matches or exceeds the pre-migration
      baseline; all pass on a full-Xcode machine, run at least twice
      consecutively.
- [ ] `dart-test` passes unchanged; zero diff in generated Dart Pigeon
      output.
- [ ] `format`, `analyze`, `podspec-check`, `validate`, `publish-check`, and
      `license-check` all pass.
- [ ] `pubspec.yaml`'s `pluginClass` updated for every changed platform
      entry; `dartPluginClass` untouched.
- [ ] CHANGELOG updated and version bumped (patch-level) via
      `update-release-info` or by hand.
- [ ] README/architecture docs checked for stale Objective-C references.
- [ ] Both CocoaPods and SPM dependency paths verified to still resolve.
- [ ] Every edge-case category from [§5.4](#54-edge-case-coverage-methodology)
      that applies to this package (per its Discovery output) is traceable
      to a specific passing test.
- [ ] The [§9](#9-end-of-migration-summary-mandatory) end-of-migration summary
      has been delivered, and the user has been asked (or already answered,
      per Coverage-only mode) whether they want the optional
      coverage-backfill follow-up ([§10](#10-optional-backfilling-missing-coverage)).
- [ ] The release ([§7](#7-after-merge-release-and-deployment)) is understood
      to be automatic once the PR merges — no manual publish step — except
      for a batch-release package, where that's been flagged as such.
