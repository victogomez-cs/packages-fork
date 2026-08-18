---
name: objc-to-swift-migration
description: >-
  Migrate a flutter/packages iOS/macOS plugin implementation (and its OCMock-based
  native tests) from Objective-C to Swift with zero behavior change, always
  following the repository root AGENTS.md, plus the conventions established by
  camera_avfoundation (incremental mixed-language PRs) and url_launcher_ios /
  file_selector_ios / quick_actions_ios (full cutover).
  Default is incremental: keep Obj-C and Swift compiling together across a series
  of small, independently-green PRs (~500 lines). A single-PR full cutover is
  opt-in only, like coverage-only mode. Use when asked to migrate, convert, or
  rewrite a Darwin plugin package from Objective-C to Swift, or to remove OCMock
  from native tests. Also supports coverage-only (report, no code) and
  full-cutover (one PR, all Sources + tests). Example invocations:
  "/objc-to-swift-migration coverage-only for image_picker_ios",
  "/objc-to-swift-migration plan for google_sign_in_ios",
  "/objc-to-swift-migration migrate google_sign_in_ios" (incremental, default),
  "/objc-to-swift-migration full-cutover url_launcher_ios" (single PR).
compatibility: >-
  Producing the plan/code works on any OS. Running Phase 0/8's native test suite
  and simulator smoke testing requires macOS with Xcode and simulators installed.
disable-model-invocation: true
---

# Objective-C → Swift Migration (flutter/packages Darwin plugins)

Platform- and package-agnostic playbook for converting **any** flutter/packages
federated-plugin Darwin implementation package (iOS, macOS, or a shared
`_darwin` package) from Objective-C to Swift with **no logic changes** — only
language/idiom changes. Ask the user for the target package name if not given.

## Repository agent guide (mandatory)

This skill **specializes** Darwin Obj-C → Swift migration. It does **not**
replace the repository agent guide. **Always** read and follow
[`AGENTS.md`](../../../AGENTS.md) at the repository root **before** producing
a plan or writing any code, and keep following it for the entire session
(coverage-only, plan, incremental PRs, and full-cutover).

That includes, at minimum — `AGENTS.md` is the source of truth, not this
summary:

- Format every change with `flutter_plugin_tools.dart format`.
- Pass analyze, Dart tests, and relevant native/integration tests.
- Update `CHANGELOG.md` and `pubspec.yaml` version for any non-test
  production change (prefer `update-release-info --version=minimal`).
- Run Pigeon after editing `pigeons/` files; run `build_runner` for mockito.
- Follow federated-plugin structure, tooling setup (`REPO_ROOT`,
  `script/tool`), and language style guides.

If this skill and `AGENTS.md` appear to conflict, **`AGENTS.md` wins** for
repo-wide contribution, tooling, formatting, testing, and CHANGELOG rules.
This skill only adds migration procedure (phasing, mixed-language packaging,
OCMock replacement, Swift Testing, PR slicing).

## When to use this skill

Use when the user asks to:
- Migrate, convert, port, or rewrite a Darwin-platform plugin package (any
  `_ios`, `_macos`, or `_darwin`-suffixed federated plugin) from Objective-C to
  Swift.
- Remove/replace OCMock from a plugin's native test suite (even if not framed
  as a full migration — OCMock only exists in Obj-C tests, so this implies
  Phase 3/5 of this workflow).
- Plan such a migration ("make a plan to migrate X to Swift") without
  necessarily implementing it yet.
- Report a package's current native test coverage — what's covered, what's
  missing, and what it would take to reach 100% — **without** migrating or
  changing any code yet (see "Coverage-only mode" below). This is often the
  right first ask before committing to a migration at all.

Not a fit for: migrating Android/Kotlin, Dart-only refactors, or plugins that
are already 100% Swift (check Step 0 first — if no `.h`/`.m` files exist
outside Pigeon output, there's nothing to migrate).

## How to use this skill

Model auto-invocation is disabled (`disable-model-invocation: true`), so
mentioning Swift/migration/OCMock in a normal prompt will not load this skill
in agents that respect that field (e.g. Cursor, where it must be triggered via
`/objc-to-swift-migration` or `@objc-to-swift-migration` in chat). Once
invoked, state the target package and what you want. Modes (like
coverage-only, these are explicit — do not guess):

- `/objc-to-swift-migration coverage-only for image_picker_ios` — report
  coverage, no plan or code changes.
- `/objc-to-swift-migration plan for google_sign_in_ios` — produce a plan,
  no code changes. Default the plan to **incremental** PRs unless they asked
  for a full cutover.
- `/objc-to-swift-migration migrate google_sign_in_ios` — **incremental
  implementation (the default)**: mixed Obj-C/Swift, one small green PR at a
  time (see "Rollout strategy"). Do **not** switch Pigeon to `swiftOut` until
  the last PR. The Swift plugin class and `pluginClass` flip can land
  earlier, still implementing the **Obj-C** generated Host API (camera
  [#9007](https://github.com/flutter/packages/pull/9007)).
- `/objc-to-swift-migration full-cutover url_launcher_ios` (or "big-bang",
  "single PR", "migrate everything at once") — **opt-in only**, same idea as
  coverage-only: one coherent PR covering all Sources + tests (Phases 0→8 in
  one pass). Never do this unless the prompt (or a later explicit message)
  asks for it.
- `/objc-to-swift-migration migrate camera_avfoundation, including
  backfilling missing test coverage` — incremental implementation plus the
  optional Phase 10 coverage backfill (still as follow-up PRs).

1. Read the repository root [`AGENTS.md`](../../../AGENTS.md) in full, then
   this entire file, before writing any plan or code — the phases build on
   each other and the Non-negotiables apply throughout. Follow `AGENTS.md`
   for the rest of the session; do not skip it because this skill already
   mentions format/tests/CHANGELOG.
2. Identify the target package and which Platform variants row applies; ask
   the user if it's ambiguous (e.g. multiple candidate packages).
3. Run Step 0 (Discovery) yourself by reading the target package's source —
   don't assume the file layout or OCMock usage described here, confirm it.
4. If the user asked for a **coverage report only** (or this is naturally the
   first thing to answer before they've decided whether to migrate at all),
   produce the report described in "Coverage-only mode" below and stop there
   — don't write a migration plan or touch any code until they respond to the
   question that mode ends with.
5. If the user only asked for a **plan**, produce one structured around the
   Phases below (tailored with the actual discovered files/classes), **sliced
   into incremental PRs by default**, and stop — do not start editing code
   until asked to implement it.
6. If asked to **implement** without `full-cutover` / "single PR" / "all at
   once": use incremental mode. Set up mixed-language packaging first (see
   Rollout strategy), then port **one class (or a ~500-line slice) per PR**.
   Do not jump to Phase 1 Pigeon `swiftOut` until every hand-written class
   (including the plugin) is already Swift. Do **not** wait to port the
   plugin class until the Pigeon switch — Swift can implement the Obj-C
   Host API. If OCMock mocks system APIs, don't jump ahead of Phase 3 seams.
7. If asked to **full-cutover**: work through Phases 0→8 in one PR, keeping
   the Non-negotiables satisfied at every step.
8. If running on a non-Mac environment, see "Requires macOS + Xcode" at the
   bottom before starting — plan/code changes can still proceed, but flag
   native test/simulator steps as pending manual verification.
9. After **each incremental PR** (or after a full-cutover PR), give a short
   status: what landed, that CI should stay green, and what the next PR is.
   Give **Phase 9's end-of-migration summary** only when the last PR
   (Pigeon `swiftOut`) is done (no remaining hand-written `.m` except an
   ExceptionCatcher-style helper, if still required) — never skip it, even
   if some Phase 8 validation steps had to be skipped for environment reasons.
10. Only **after** that summary, ask whether the user also wants existing
    coverage **gaps backfilled** with new native tests (Phase 10, optional —
    distinct from porting *existing* tests, which is always mandatory).
    Default to **no** unless they opt in. Skip this question if the user
    already stated a preference earlier (e.g. via Coverage-only mode's
    follow-up question, or by asking for it explicitly in their original
    request). If they opt in now, do Phase 10 as its own follow-up, normally
    a separate commit/PR from the port.

## Platform variants

Substitute throughout based on the target:

| Target | Source dir | CLI platform flag | Example dir |
|---|---|---|---|
| iOS-only (`<pkg>_ios`) | `ios/<pkg>_ios/Sources/<pkg>_ios/` | `--ios` | `example/ios/` |
| macOS-only (`<pkg>_macos`) | `macos/<pkg>_macos/Sources/<pkg>_macos/` | `--macos` | `example/macos/` |
| Shared (`<pkg>_darwin`) | `darwin/<pkg>_darwin/Sources/<pkg>_darwin/` | `--ios --macos` | `example/ios/` and `example/macos/` |

Some older plugins predate the `Sources/`-based SPM layout and instead keep
Obj-C directly under `ios/Classes/` (or `macos/Classes/`) with no `Package.swift`.
If so, this migration should also introduce a `Package.swift` and the
`Sources/<pkg>/` layout as part of the move to Swift — check a package that
already did this combined move (grep CHANGELOGs across the repo for "Adds Swift
Package Manager" plus "Migrates ... to Swift" near each other) rather than
assuming the layout shown above already exists.

## Non-negotiables

- **No behavior change.** Every method's parameter validation, error codes/messages,
  edge-case handling (nil checks, rounding, clamping, "0 means unlimited", etc.) must
  be preserved exactly. Do not fix bugs silently while porting — flag them instead.
- **Dropping the vendor Obj-C prefix is safe and expected, not a behavior change.**
  Phase 4 renames the core class off its `FLT`/`FPP`/`FSI`/etc. prefix. This is
  invisible to Dart: `dartOut`/`dartPluginClass` never reference the native class
  name directly, only `pubspec.yaml`'s `pluginClass:` string does (and that gets
  updated in the same commit). Don't preserve the old prefixed name "to be safe" —
  that would just leave the package inconsistent with repo convention.
- **Every existing native test case must have a passing Swift equivalent.** Count
  test methods before and after; they must match (or exceed, if you split a test).
  This is about *porting what already exists* — it is not the same as full
  coverage. Whether a given package's native code is already at 100%
  coverage is not something to assume either way going in: this repo's
  `coverage-check` tool only measures **Dart** coverage (via `flutter test
  --coverage`, for packages opted into
  `script/configs/custom_coverage_minimums.yaml`) — native coverage isn't
  tracked or enforced anywhere, so it varies per package and must be checked
  per package (Step 0 / Coverage-only mode), not assumed. Closing any gaps
  found is out of scope for the core migration regardless (it would mix new
  test-writing risk into an otherwise mechanical, easy-to-review port). Treat
  it as a separate, opt-in follow-up — see Phase 10.
- **All existing Dart-side tests in the package (`test/*.dart`) must still pass
  unchanged**, since Phase 1 only changes Pigeon's output *language*, never the
  Dart API/types (`dartOut` is untouched). If the package generates Dart mocks
  (e.g. `mockito`/`build_runner`, or Pigeon's own `dart_test_out` for a
  `TestHostApi`), regenerate them and confirm they still compile — do not
  hand-edit generated Dart mocks to work around a mismatch; if one doesn't
  compile, the Swift-side Pigeon output has a real drift from before and needs
  fixing instead.
- **CHANGELOG + version bump are mandatory** for any non-test code change (see
  Phase 7 and `AGENTS.md`). This repo's precedent (`url_launcher_ios`
  6.2.0→6.2.1) treats a pure Obj-C→Swift rewrite as a **patch-level,
  non-breaking** change since the Dart API is untouched.
- **Format, analyze, Dart tests, and native tests must all pass** before
  considering any phase done — not just the native suite. Never skip
  `dart-test` just because the changes look native-only. Use the
  `flutter_plugin_tools.dart` commands from `AGENTS.md` (format, analyze,
  dart-test, validate, publish-check, license-check), plus this skill's
  native-test commands.

## Step 0: Discovery

Before planning, inventory the target package. Don't assume file layout — a
quick `find`/glob for `*.h`/`*.m` plus `Package.swift` tells you which case
you're in:

1. Find hand-written Obj-C, wherever it lives (`ios|macos|darwin/<pkg>/Sources/<pkg>/**/*.{h,m}`
   for modern SPM layout, or `ios|macos/Classes/**/*.{h,m}` for legacy layout).
   Exclude any Pigeon-generated file (usually named `messages.g.{h,m}` or
   similar per the package's `pigeons/*.dart` config) — that's regenerated, not
   hand-migrated.
2. Find native tests: `example/<platform>/RunnerTests/**/*.{m,swift}` and
   `RunnerUITests/**/*.m` (macOS example projects may name these differently;
   check the `.xcodeproj`'s test targets if not found at the usual path). Some
   packages already have partially-migrated Swift tests living *outside* that
   conventional folder (e.g. under a package-level `Tests/` or `darwin/Tests/`
   directory, pulled into the `RunnerTests` Xcode target via a relative-path
   file reference in `project.pbxproj` rather than living physically inside
   `example/<platform>/RunnerTests/`) — if the folder glob comes up empty or
   suspiciously small, grep the `.pbxproj`'s `PBXFileReference`/`PBXBuildFile`
   entries for the test target instead of assuming there are no tests yet.
3. Grep tests for OCMock usage: `OCMock|OCMClassMock|OCMPartialMock|OCMStub|OCMVerify|OCMExpect|OCMReject|OCMArg`.
   For every match, note *which class* is being mocked and *which specific
   method* (especially class/static methods — these are the ones OCMock can do
   that plain Swift can't, and need protocol seams; see Phase 3). If OCMock
   usage is minimal or absent, Phase 3/5 shrink accordingly — don't invent
   protocol seams that aren't needed.
4. Check for an existing `Package.swift` (SPM) — many Darwin plugins already
   have one; if not, one must be added as part of this migration (copy
   structure from a migrated sibling on the same platform).
5. Check the podspec(s) for `swift_version`/Swift `source_files` — absence
   confirms pure-Obj-C state. Note there may be one podspec per platform.
6. Read `pubspec.yaml` for the current `pluginClass`/`dartPluginClass` name(s)
   and version. Federated plugins can have separate classes per platform.
7. Read any `*_Test.h`/testing category header — it documents the internal
   test-only surface (usually a class extension/category, sometimes exposed via
   a custom modulemap `Test` submodule) that becomes plain Swift `internal`
   access + `@testable import <pkg>` once migrated (no more custom Obj-C `Test`
   submodule needed).

## Coverage-only mode

Sometimes the useful first question isn't "migrate this" but "how
well-tested is this package's native implementation right now, and what
would it take to get to 100%?" — as a standalone report, with **no code
changes and no commitment to migrate**. Use this mode when the user asks
something like "what's the native test coverage for `<pkg>`", "what's
missing to reach 100% coverage", or "before we migrate, tell me what's
covered and what isn't".

1. Run Step 0 (Discovery) to get the file and test inventories.
2. Measure coverage of the package's **current, pre-migration Objective-C**
   production code (this is a question about today's state, independent of
   whether a migration ever happens):
   - If a full Xcode install is available (see "Requires macOS + Xcode"),
     get a real figure:
     ```bash
     xcodebuild test -scheme RunnerTests -enableCodeCoverage YES \
       -resultBundlePath /tmp/<pkg>-coverage.xcresult ...
     xcrun xccov view --report /tmp/<pkg>-coverage.xcresult
     ```
     (adjust scheme/destination flags to match the package's example
     project).
   - If not available, don't skip the question — produce an approximate,
     manually-derived figure instead: enumerate every public/internal method
     and major branch (permission/authorization states, capability checks,
     error/exception paths, sentinel "0/nil means X" values, configuration-
     precedence logic — the same categories Phase 10 uses) and mark each
     covered/not-covered by cross-referencing the existing test files. State
     the result as "*N* of *M* identified code paths covered" and clearly
     label it as an estimate, not a substitute for real line/branch
     coverage.
3. Report back, without making any code changes:
   - **Overall coverage figure** — the real `xccov` percentage, or the
     approximate count from the manual method — labeled accordingly so the
     user knows which kind of number it is.
   - **What's covered** — a brief summary grouped by class/area.
   - **What's missing** — a concrete, categorized list of untested
     methods/branches/edge cases (use Phase 10's edge-case categories as the
     taxonomy rather than a flat list).
   - **What it would take to reach 100%** — a rough scope estimate: roughly
     how many new tests, and whether any gap is only testable if a *new*
     Phase 3 protocol seam is introduced first (some code paths may be
     fundamentally untestable today without one — surface that as its own
     finding, not just "missing a test").
4. Stop here. Do not produce a migration plan or touch any code yet.
5. Ask the user explicitly: *"Would you like me to proceed with the
   Objective-C → Swift migration (incremental mixed-language PRs by
   default), include writing the tests needed to close these gaps as
   follow-up PRs (so the migrated package ends up at ~100% native test
   coverage), do a single-PR full cutover instead, or neither for now?"*
6. Act on the answer:
   - **Incremental migration + close the gaps:** default path. Work through
     incremental PRs (Rollout strategy), and treat Phase 10's coverage
     backfill as **in scope after the last cutover PR** rather than a
     separately-opted-into follow-up — the Phase 10 opt-in question in
     "How to use this skill" has already been answered, so don't re-ask it.
     Keep new-coverage tests as their own PR(s).
   - **Incremental migration only:** default path through mixed-language
     PRs; ask the Phase 10 opt-in question after the last cutover PR
     (default: no).
   - **Full cutover** (only if they said so): Phases 0→8 in one PR; Phase 10
     still a follow-up unless they also asked to close gaps in the same
     effort.
   - **Neither:** stop — the coverage report was the whole ask.

## Reference templates in this repo

| Package | Demonstrates |
|---|---|
| `camera_avfoundation` | **Default template:** incremental mixed-language PRs. Separate SPM targets (`*_objc` + Swift), CocoaPods globs both into one pod, `#if canImport(*_objc)` in tests. Order: tests → packaging ([#8988](https://github.com/flutter/packages/pull/8988)) → utils/features/wrappers (Obj-C plugin calls Swift) → Swift plugin still on Obj-C Pigeon ([#9007](https://github.com/flutter/packages/pull/9007)) → Pigeon `swiftOut` last ([#10939](https://github.com/flutter/packages/pull/10939) prep, [#10980](https://github.com/flutter/packages/pull/10980) switch). Copy this whenever migrating in parts. |
| `url_launcher/url_launcher_ios` | Full-cutover template only (opt-in): `Package.swift`, podspec, protocol-based DI (`Launcher.swift`/`ViewPresenter.swift`), `pluginClass` renamed off `FLT` prefix, patch-level version bump |
| `file_selector/file_selector_ios` | Same full-cutover pattern, Pigeon `swiftOut` |
| `quick_actions_ios` | Small multi-PR but not mixed-language: plugin class first, then remaining components; dropped custom Obj-C `Test` submodule; also migrated `RunnerUITests` |

These four are starting points, not the only options. Before writing code,
also check the repo for a package **already migrated that shares the target's
problem domain** (e.g. two plugins wrapping the same system framework, two
permission-heavy plugins, or two plugins that already share a `_darwin`
target) — prefer that one's conventions if it's a closer match than the table
above. Always read 1-2 chosen references directly (Sources + example
RunnerTests) before writing new code, to match current formatting/idiom
conventions exactly.

Also watch for the **"tests-first" partial-migration shape**: a package whose
native tests are already Swift (protocol seams + fakes already exist, often
already using Swift Testing) while its core plugin class file(s) are still
`.m`. This happens when a prior effort ported the test-facing protocols and
test doubles but stopped short of the plugin class itself, or when OCMock was
removed as a standalone effort before the rest of the migration. Incremental
mode still applies: set up the mixed-language targets, port remaining Obj-C
types (wrappers, helpers) into the Swift target one PR at a time, then port
the plugin class **still implementing the Obj-C Pigeon Host API**, and only
after that switch Pigeon to `swiftOut`. Do **not** collapse plugin + Pigeon
into one PR, and do **not** collapse the leftover into a single full-cutover
PR, unless asked.

## Native test framework: Swift Testing, not XCTest

Ported native tests should be written using the **Swift Testing** framework
(`import Testing`), **not XCTest** — this is the current repo convention as of
early-to-mid 2026, confirmed by both brand-new ports and dedicated follow-up
migrations of older ones (e.g. "[url_launcher_ios] Migrate XCTest to Swift
Testing", "[quick_actions_ios] Migrate XCTest to Swift Testing",
"[file_selector] Switch to Swift Testing", "[webview_flutter] Convert from
XCTest to Swift Testing"). Some packages' existing native tests are already
written this way even before their plugin class has been ported (see the
"tests-first" partial-migration shape above). Concretely:

- `import Testing` (alongside `@testable import <pkg>`), group related tests
  in `@Suite` structs/nested structs, and mark individual tests `@Test`
  (add `@MainActor` on the suite if the code under test isn't Sendable/expects
  main-thread execution).
- Replace `XCTAssertEqual`/`XCTAssertTrue`/`XCTAssertNil`/etc. with `#expect(...)`
  (or `#require(...)` when the test can't meaningfully continue past a failed
  check, e.g. unwrapping a value needed by the rest of the test).
- Replace `XCTestExpectation`/`waitForExpectations` with
  `await confirmation("description") { confirmed in ... }` for async
  completion-handler-based APIs.
- Parameterized/table-driven tests that used to be hand-rolled loops or
  duplicated near-identical Obj-C test methods can become a single
  `@Test(arguments: [...])` function — but only collapse tests this way if
  every original case is preserved with equal or better clarity; don't lose
  a distinct assertion in the process.

This convention has already shifted once (older reference PRs from 2023 were
originally written in XCTest, then migrated later). Before relying on this
section verbatim, spot-check that it's still current: pick one or two
recently-touched Darwin plugin packages and confirm their newest test files
still `import Testing` (e.g. `git log --all --oneline | grep -i "swift
testing"`, or just open a recently-migrated package's `RunnerTests/*.swift`).

## Rollout strategy: incremental (default) vs full-cutover (opt-in)

**Default is incremental mixed-language PRs.** Obj-C and Swift coexist until
the last PRs. Each PR must leave the package **buildable and tests passing**.
Aim for about **~500 lines of reviewable (hand-written) diff** per PR.
Generated Pigeon output does **not** count toward that budget and belongs in
the **last** PR — that switch is expected to be the largest slice (camera
[#10980](https://github.com/flutter/packages/pull/10980) was +2,103/−2,455;
call the generated portion out as mechanical).

**Full-cutover** (one PR, all Sources + tests, delete Obj-C immediately) is
**opt-in only**, like coverage-only: the user must say `full-cutover`,
"single PR", "big-bang", or "migrate everything at once". Do not choose it
because the plugin is small.

### PRs: stacked branches, after a full local port

The unit of **review/merge** is a **pull request**, not extra commits on one
branch. The unit of **validation** is the **full migration**, which you
implement and test **first**.

**1. Port everything locally (or on a private `…-full` branch).** Translate
only — no behavior changes. Run format/analyze/dart-test/native-test on the
**complete** Swift end state so you know the whole package works before
splitting. Keep that branch as the reference; don’t open it as the review PR
unless the user asked for full-cutover.

**2. Split that known-good tree into a chain of branches** (stacked PRs):

```text
main
  └─ pr1/tests-or-packaging          ← mergeable to main, tests pass
       └─ pr2/first-objc-swift-slice ← contains PR1 + slice 2, tests pass
            └─ pr3/next-slice        ← … until the tip matches the full port
```

- Each branch is PR N; its **base** is PR N−1 (or `main` for PR1).
- **Every prefix must behave like today’s Obj-C** for what is still Obj-C,
  and like the translated Swift for what already moved — CI green at every
  step, not only at the tip.
- Prefer **one commit per branch/PR**. Fixups during review can add commits
  on that branch; don’t use commits on one branch as the split.
- The **tip of the last branch must match the full local port** (same
  package tree). Confirm with `git diff <full-branch> <prN-tip> -- <pkg>`.
- **Keep the stack local.** Create and commit on local branches only. Do
  **not** `git push`, `gh pr create`, or otherwise publish branches unless
  the user explicitly asks. Opening PRs and pushing to a fork/origin is
  their step after they’ve reviewed the local stack.

**3. Merge in order** (after the user has pushed / opened PRs): PR1 → PR2 →
PR3. After PR1 lands, retarget PR2 at `main` (or rebase the stack). Same
for the rest.

Do **not** accumulate slices as commits 1..N on a single PR branch. Do **not**
open independent PRs off `main` that each miss the earlier slices unless they
truly don’t depend on each other (rare).

Camera’s history is the same idea spread over time: tests PRs, then
packaging, then implementation part 1, 2, … — each mergeable. Doing the full
port first, then stacking, is how you get that review shape **without**
waiting to discover a break only at the end.

### Incremental sequence (tests first, then mixed Obj-C/Swift)

Do these as **separate PRs, in order**. Skip a wave if Discovery shows it’s
already done (e.g. tests already Swift).

1. **Tests first** (if native tests are still Obj-C / OCMock) — like
   `camera_avfoundation` “Migrate tests to Swift - part N” and
   `google_sign_in` [#10787](https://github.com/flutter/packages/pull/10787).
   Port tests (and protocol seams/fakes they need) while the **plugin stays
   Obj-C**. Split test files across PRs if needed to stay near ~500 lines.
   The production `.m` plugin class does not move yet.
2. **Packaging for mixed language** — SPM `<pkg>` + `<pkg>_objc` targets,
   CocoaPods glob (details below). Plugin still Obj-C.
3. **Implementation slices** — one class / ~500-line group per PR; remaining
   Obj-C **calls** the new Swift; delete that class’s `.m/.h` in the same PR.
4. **Plugin class** — port it to Swift, flip `pluginClass`, keep
   `objcHeaderOut` / `SetUpF*Api` / `FlutterError` completions. Tests stay
   on the Obj-C Pigeon call sites. See "Swift plugin on Obj-C Pigeon" below.
5. **Pigeon `swiftOut` last** — switch generated Host API language, rewrite
   plugin methods + tests to the Swift `Result` / `PigeonError` API, delete
   `messages.g.{h,m}`. Remove leftover Obj-C except ExceptionCatcher if
   needed. This PR is allowed to be large because of generated code.

### Incremental packaging (first mixed-language PR, after tests if needed)

Swift Package Manager **cannot mix Swift and Obj-C in one target**. CocoaPods
can mix them in one pod. Follow `camera_avfoundation` implementation PR #8988:

1. Move remaining Obj-C into `Sources/<pkg>_objc/` (keep `publicHeadersPath`
   / `include/` there).
2. Add a Swift target `Sources/<pkg>/` that **depends on** `<pkg>_objc`.
3. `Package.swift` product lists **both** targets. The Swift target depends
   on the Obj-C target.
4. Podspec **combines** both trees into one module:
   ```ruby
   s.source_files = '<pkg>/Sources/<pkg>*/**/*.{h,m,swift}'
   s.public_header_files = '<pkg>/Sources/<pkg>_objc/include/**/*.h'
   s.swift_version = '5.0'
   ```
   plus the usual Swift `LIBRARY_SEARCH_PATHS` / `LD_RUNPATH_SEARCH_PATHS`
   `xcconfig`.
5. Tests import both, with a SwiftPM-only extra module:
   ```swift
   @testable import <pkg>
   #if canImport(<pkg>_objc)
     @testable import <pkg>_objc
   #endif
   ```
6. Keep `pubspec.yaml` `pluginClass` pointing at the **Obj-C plugin class**
   until the **plugin-class PR** (step 4), not until the Pigeon switch.
7. **Do not** switch Pigeon to `swiftOut` in this PR — production code still
   implements the Obj-C generated API.

This packaging-only PR can be small; it is allowed to be mostly moves +
Package.swift/podspec.

### Implementation slices (after tests + packaging)

Port **bottom-up, one class (or one tight group) per PR**:

1. Leaf utils / parsers (Phase 2).
2. View/window providers, SDK wrappers (Phase 2/3). Expose Swift types the
   remaining Obj-C needs as `@objc` (or keep a thin Obj-C header that Swift
   implements) so the Obj-C plugin **calls into** the new Swift — do not
   leave unused Swift sitting next to a duplicate Obj-C copy.
3. Feature/helper classes, same pattern: delete the `.m/.h` in the **same**
   PR that adds the Swift replacement and updates call sites.
4. Protocol seams for OCMock'd system APIs (Phase 3) when tests still need
   them — often already done in a tests-first package.
5. **Plugin class (still on Obj-C Pigeon).** Port the plugin to Swift and
   flip `pluginClass`. It must conform to the **existing Obj-C** Host API
   (`FSIGoogleSignInApi`, `FCPCameraApi`, …) and register with
   `SetUpF*Api(...)`. Native tests keep `FlutterError` / Obj-C Pigeon types.
   Camera: [#9007](https://github.com/flutter/packages/pull/9007).
6. **Pigeon `swiftOut` last, its own PR.** Replace `objcHeaderOut`/
   `objcSourceOut` with `swiftOut`, regenerate, delete `messages.g.{h,m}`,
   rewrite plugin methods and tests to the Swift `Result` / `PigeonError`
   API. Empty `dartOut` diff. Camera: [#10939](https://github.com/flutter/packages/pull/10939)
   (prep) then [#10980](https://github.com/flutter/packages/pull/10980)
   (the switch; author noted it cannot be split further). Generated files
   make this the biggest PR — that is expected.

Do **not** combine steps 5 and 6. A Swift class can implement an Obj-C
Pigeon protocol, so the Host API language does **not** have to change in
the same PR as the plugin class. Combining them is what produces an
unreviewable "cutover" diff. If the combined hand-written plugin + Pigeon
rewrite would exceed ~500 lines, you **must** split this way rather than
ship one large PR.

### Swift plugin on Obj-C Pigeon

This is the missing slice that keeps the plugin PR small:

- Keep `pigeons/messages.dart` on `objcHeaderOut` / `objcSourceOut`.
- Swift plugin: `class FooPlugin: NSObject, FlutterPlugin, FSIFooApi`
  (the generated Obj-C `@protocol`).
- Register with `SetUpFSIFooApi(messenger, instance)`, not
  `FooApiSetup.setUp`.
- Completions stay `(ResultType?, FlutterError?) -> Void` / error
  out-params. Use `FlutterError`, not `PigeonError`.
- Tests keep constructing `FSI*` types and calling
  `plugin.configure(withParameters:error:)` / `signOutWithError(&error)`.
  Only rename `FLTFooPlugin` → `FooPlugin`.
- ExceptionCatcher (if the Obj-C plugin used `@try/@catch`) lands in
  this PR, because Swift cannot catch `NSException`.

The later Pigeon PR is then mostly generated `messages.g.swift` plus
mechanical signature updates on the already-Swift plugin and tests.

### Each incremental PR must

- Stay green per `AGENTS.md`: `format`, `analyze`, `dart-test`, and native
  tests (plus `validate` / `publish-check` / `license-check` when wrapping
  up a PR).
- Update CHANGELOG + version when it changes **non-test production** code
  (`AGENTS.md` + contributing rules). Packaging-only or test-only PRs may
  use `NEXT` / override labels only if they match the documented exemptions.
- Be independently revertable: later PRs in the series depend on earlier
  ones, but reverting the tip must not leave `main` unbuildable.
- Not add dead Swift that nothing calls — wire Obj-C → Swift in the same PR.

### Full-cutover mode (opt-in)

When explicitly requested: Phases 0→8 in one PR. No mixed-language period.
Matches `url_launcher_ios` / `file_selector_ios`. Skip the `<pkg>_objc`
split unless you still need an ExceptionCatcher module.

## The migration workflow

### Phase 0 — Baseline
Run the existing native test suite and record the passing test count before
touching anything (swap `--ios` for `--macos`, or use both, per the Platform
variants table):
```bash
dart run script/tool/bin/flutter_plugin_tools.dart native-test --ios --no-integration --packages <pkg>
```

### Phase 1 — Pigeon

**Incremental (default): skip this phase until the last PR, even if the
plugin class is already Swift.** A Swift plugin can implement the Obj-C
generated Host API (`messages.g.h` / `.m`, `SetUpF*Api`). Switching
`swiftOut` earlier is what forces an oversized combined diff.

**Full-cutover, or the last incremental PR:**
If `pigeons/messages.dart` (or equivalent) has `objcHeaderOut`/`objcSourceOut`/
`objcOptions`, replace with a `swiftOut` pointing at the platform's `Sources/`
directory from the Platform variants table, e.g.:
```dart
swiftOut: 'ios/<pkg>/Sources/<pkg>/messages.g.swift',
```
Keep `dartOut` and all type/enum/method definitions untouched — only the output
target changes. Regenerate: `dart run pigeon --input pigeons/messages.dart`
(run from the package directory). Delete the old generated `.h`/`.m`. Diff
generated types field-by-field against the old Obj-C ones, and confirm
`git diff` on the Dart output (`lib/src/messages.g.dart` or similar) is empty —
if it isn't, something in the Dart API changed and that's a bug in this step,
not an expected side effect. Run `dart run script/tool/bin/flutter_plugin_tools.dart dart-test --packages <pkg>`
now, before touching any Swift, to confirm the Dart side is still green. If no
Pigeon file exists (some older plugins hand-write their platform channel
handling), skip the regeneration but still run `dart-test` as a baseline.

### Phase 2 — Port leaf utility classes first
Port bottom-up (classes with no OCMock-mocked dependencies first) so each can be
tested in isolation immediately. **Incremental default: one class (or ~500-line
slice) per PR.** After each port, remaining Obj-C must **call the new Swift**
(via `@objc` / the Swift module) and the old `.m/.h` for that class is deleted
in the same PR — no duplicate implementations.

1. Pure-logic utility classes (string/data formatting, math, parsing).
2. Simple protocol/provider wrapper classes (view/window provider, etc.).
3. Port their corresponding **plain test files** (no OCMock) 1:1 — mechanical
   Obj-C→Swift syntax conversion. Use the **Swift Testing** framework
   (`import Testing`, `@Suite`, `@Test`, `#expect`/`#require`), not XCTest — see
   "Native test framework: Swift Testing, not XCTest" below. Run immediately
   before moving to the next class.

### Phase 3 — Protocol seams for OCMock'd system APIs
OCMock can mock class/static methods on system frameworks (e.g.
`OCMClassMock([AVCaptureDevice class])` + `OCMStub(ClassMethod(...))`, or
`OCMClassMock([NSFileManager class])`, `OCMClassMock([CLLocationManager class])`,
`OCMClassMock([NSUserDefaults class])` — whatever system class the *target*
plugin's tests actually mock). Swift tests cannot mock system classes this way,
so introduce a thin protocol wrapping **exactly** the static/instance calls
being mocked today (nothing more, and nothing the target plugin doesn't
actually use), with a production implementation and inject it via initializer
parameter (default = production impl). The pattern is always the same
regardless of domain:

1. From the Step 0 OCMock grep, list every distinct system class + method
   being mocked.
2. For each, define a small protocol with just those methods, named for what
   it does (not for the system class), e.g. `protocol PermissionChecker`, not
   `protocol AVCaptureDeviceWrapper`.
3. Write a `Default*` production implementation that calls straight through
   to the real system API.
4. Inject the protocol (not the concrete type) into the class under test.

Cases seen in real migrations (illustrative, not exhaustive — the target
plugin may mock entirely different frameworks):
- Permission/authorization status + request-access calls (camera, photos,
  location, contacts, bluetooth, etc. all follow the same
  `authorizationStatus` / `requestAccess`-style shape).
- Capability/availability checks (e.g. `isSourceTypeAvailable`).
- Object construction interception (mocked `alloc`/`init`) → factory
  closure/protocol instead.
- Data-holder objects returned by system APIs (e.g. picker results, file
  providers) → wrap only the specific methods actually used by the plugin;
  prefer constructing real lightweight instances over fakes where the SDK
  allows it.

### Phase 4 — Port the core plugin class(es)
**Incremental (default): after helpers/wrappers live in Swift, and before
Pigeon `swiftOut`.** Until this PR, keep the Obj-C plugin class and
`pluginClass:` unchanged.

**This PR (incremental):** Swift plugin conforming to the **Obj-C** Host
API — see "Swift plugin on Obj-C Pigeon". Do **not** change
`pigeons/messages.dart`, do **not** delete `messages.g.{h,m}`, and do
**not** rewrite tests onto the Swift `Result` API yet. Tests only rename
`FLTFooPlugin` → `FooPlugin`.

1. Rename off the vendor Obj-C prefix (e.g. `FLT`, `FPP`, whatever this repo's
   convention for the package is) to a plain Swift name (e.g.
   `FLTFooPlugin` → `FooPlugin`), matching `url_launcher_ios` precedent.
2. Preserve every public API method's validation/error handling/dismissal
   logic and every delegate callback's behavior exactly.
3. Test-only members (the old `*_Test.h` surface) become `internal` (not
   `@objc public`) members, accessed via `@testable import <pkg>` in tests.
4. Update `pubspec.yaml`'s `pluginClass` to the new Swift class name(s) — update
   every platform entry that changed (a `_darwin`-shared package has one entry
   per platform, e.g. both `ios:` and `macos:`). Leave `dartPluginClass`
   untouched — it names a Dart class and has nothing to do with this migration.
5. Delete the Obj-C plugin `.m`/`.h` (and `*_Test.h`) in this PR. Leave Pigeon
   generated Obj-C and any ExceptionCatcher in `<pkg>_objc`.

**Full-cutover only** (or after the later Pigeon PR has removed generated
Obj-C): delete remaining `.m`/`.h`, the modulemap, umbrella header, and
`include/` once nothing references them, then simplify `Package.swift`
(drop `cSettings`/header-search-path except ExceptionCatcher) and the
podspec:
   ```ruby
   s.swift_version = '5.0'
   s.source_files = '<pkg>/Sources/**/*.swift'
   s.xcconfig = {
     'LIBRARY_SEARCH_PATHS' => '$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)/ $(SDKROOT)/usr/lib/swift',
     'LD_RUNPATH_SEARCH_PATHS' => '/usr/lib/swift',
   }
   ```

### Phase 5 — Port OCMock-heavy tests
For each OCMock construct, use the fakes from Phase 3:

| OCMock | Swift replacement |
|---|---|
| `OCMClassMock([Foo class])` + inject | Protocol-conforming fake struct/class, injected via initializer |
| `OCMStub(...).andReturn(x)` | Fake property/method returns `x` directly |
| `OCMStub(ClassMethod(...))` | Fake implements the protocol method wrapping that static call |
| `OCMVerify(times(n), ...)` | Fake records call count; `#expect(fake.callCount == n)` |
| `OCMExpect(...)` / `OCMVerifyAll` | Fake records invocations/arguments; assert after the fact |
| `OCMReject(...)` | Assert the fake's call count is `0` |
| `OCMArg.any()` / `OCMOCK_ANY` | Just don't constrain the fake's stubbed input |

Port every test method 1:1 — do not drop or merge test cases. Explicitly
double-check coverage of: permission states (authorized/denied/restricted/
not-determined, plus any "limited" variant), capability-unavailable paths,
malformed/failure inputs, "verify NOT called" assertions (`OCMReject`), and any
multi-item/batch flows with partial failures.

A ported `OCMVerify`/`OCMExpect` assertion is only meaningful if the fake it's
checking actually records something — the most common way a mechanical port
silently stops testing anything is a fake that returns a canned value but
never increments a call counter or stores the arguments it was called with.
When porting each one, confirm the fake has real state to assert against, not
just that the test compiles and passes.

Remove the OCMock dependency from the test target once no `.m`/`.swift` file
references it. In this repo OCMock is typically wired as an **SPM package
product dependency added directly to the test target inside the example app's
`project.pbxproj`** (look for an `XCRemoteSwiftPackageReference` named
`"ocmock"` and its corresponding `XCSwiftPackageProductDependency`/
`PBXBuildFile` entries), not a Podfile line. Prefer removing it via Xcode's
GUI ("Remove Package Dependency" on the test target's Frameworks list) rather
than hand-editing the `.pbxproj`, since it's easy to leave a dangling
reference that only breaks the build later. Whichever method you use, diff
the `.pbxproj` afterward and confirm only the expected OCMock-related lines
changed.

### Phase 6 — UI tests and example app (optional)
Native UI-automation tests without OCMock (`RunnerUITests`) are low-risk;
port for consistency if time allows, but not required for functional parity.
Leave the example app's `AppDelegate`/`main.m` as Objective-C unless the
plugin's own sibling packages establish otherwise — this repo doesn't require
converting the example app shell.

### Phase 7 — CHANGELOG, version, docs
Follow `AGENTS.md` for version and CHANGELOG updates. Every incremental PR
that changes non-test production code needs a patch bump and CHANGELOG
entry. Use `update-release-info` per PR, not only at the end:
```bash
dart run script/tool/bin/flutter_plugin_tools.dart update-release-info \
  --version=minimal --base-branch=origin/main \
  --changelog="Migrates <this slice> from Objective-C to Swift."
```
On the **final Pigeon PR** (or a full-cutover PR), use a slice-specific
changelog such as "Converts the Pigeon host API from Objective-C to Swift"
— do **not** rewrite earlier slice changelogs into one "migrates the
platform implementation" summary; those PRs already shipped their own
entries. For a true single-PR full-cutover, that summary line is fine:
```bash
dart run script/tool/bin/flutter_plugin_tools.dart update-release-info \
  --version=minimal --base-branch=origin/main \
  --changelog="Migrates the platform implementation from Objective-C to Swift."
```
Then check README.md and any architecture docs for now-stale Objective-C
references (endorsed-plugin READMEs are usually minimal boilerplate — only a
quick check needed). Check the umbrella app-facing package's docs too.

### Phase 8 — Validation (mandatory)
Run the `AGENTS.md` validation suite plus this skill's native-test commands.
Replace `<pkg>` with the actual package directory name, and use the platform
flag(s) from the Platform variants table (`--ios`, `--macos`, or both):
```bash
dart run script/tool/bin/flutter_plugin_tools.dart format --packages <pkg>
dart run script/tool/bin/flutter_plugin_tools.dart analyze --packages <pkg>
dart run script/tool/bin/flutter_plugin_tools.dart dart-test --packages <pkg>
dart run script/tool/bin/flutter_plugin_tools.dart native-test --ios --no-integration --packages <pkg>
dart run script/tool/bin/flutter_plugin_tools.dart native-test --ios --no-unit --packages <pkg>
dart run script/tool/bin/flutter_plugin_tools.dart podspec-check --packages <pkg>
dart run script/tool/bin/flutter_plugin_tools.dart validate --packages <pkg>
dart run script/tool/bin/flutter_plugin_tools.dart publish-check --packages <pkg>
dart run script/tool/bin/flutter_plugin_tools.dart license-check
```
`dart-test` must pass with zero failures — since the migration shouldn't touch
Dart code, any Dart test failure at this point means something in `dartOut`
generation or a Dart-facing type drifted and must be fixed before proceeding.
Confirm the native unit test count matches (or exceeds) the Phase 0 baseline.
Run on at least two simulator/OS versions if available. For permission-related
flows, reset simulator privacy state before manual smoke testing (adjust the
service name to whatever the plugin actually requests, e.g. `photos`,
`camera`, `contacts`, `location`, `microphone`):
```bash
xcrun simctl privacy <device> reset <service> <bundle-id>
```
Also verify both dependency paths resolve: CocoaPods (`example/<platform>/Podfile`)
and SPM (Xcode "Add Package"/the repo's SPM example variant).

### Phase 9 — End-of-migration summary (mandatory)
After **each incremental PR**, report briefly: files moved/ported, whether
the Obj-C plugin is still registered, next PR in the series.
Do **not** treat that as the end-of-migration summary.

Give the full summary below only when the migration is actually finished
(last Pigeon `swiftOut` PR, or a full-cutover PR) — never end that session silently:

- **What changed:** the `.h`/`.m` files deleted and their Swift replacements
  (including any renamed classes), `pubspec.yaml` `pluginClass` updates, and
  the CHANGELOG/version bump (old → new version).
- **Test parity:** the Phase 0 baseline native test count vs. the final
  count, stated explicitly (e.g. "42 tests before, 44 after — two were split
  for clarity, none dropped").
- **Validation status, command by command:** which of the Phase 8 commands
  actually ran and passed in this session, and which are **pending manual
  verification** and why (most commonly: no full Xcode/simulator available in
  this environment — see "Requires macOS + Xcode" below). Don't imply
  something passed if it was never run.
- **Anything flagged, not fixed:** any pre-existing bug, inconsistency, or
  surprising edge case noticed during the port that was intentionally left
  behavior-identical per the Non-negotiables (nothing should be silently
  fixed *or* silently ignored — surface it here even if it was also mentioned
  earlier in the session).
- **Concrete next steps for the user**, e.g.:
  - Commands they need to run themselves on a full-Xcode machine (native
    unit + UI tests, at least two simulator/OS versions).
  - Manual smoke testing for any permission-related flow (which service
    to reset with `xcrun simctl privacy ... reset`, and what to click
    through).
  - Reviewing the Xcode project (`.pbxproj`) diff by hand (deleted file
    references, and any OCMock package-dependency removal) since it's not
    realistically reviewable via a normal code-review diff view.
  - Confirming both CocoaPods and SPM example variants still build, if not
    already confirmed in this session.
- **Deployment note:** merging the PR is normally the entire release step —
  this repo's "release" GitHub Action publishes to pub.dev and tags the
  commit automatically once merged to `main`, no manual `publish` needed.
  The one exception is a package with `ci_config.yaml`'s `release: batch:
  true` set — flag if that applies, since release there happens on a
  separate, delayed cadence instead of immediately after merge.

Then, per "How to use this skill" step 9, ask whether the user wants the
optional Phase 10 coverage backfill next (unless they already stated a
preference earlier) — the summary itself should stay focused on the port
that was just done, not presuppose that answer.

### Phase 10 — (Optional) Backfill missing native test coverage
Only do this if the user explicitly opted in (per "How to use this skill"),
and only after Phase 9's summary confirms the pure port is fully validated.
Prefer landing this as its **own commit/PR**, separate from the zero-behavior-
change port, so each stays independently reviewable and revertable — a
reviewer shouldn't have to untangle "mechanical port" from "new test
behavior" in one diff.

1. Identify gaps objectively rather than by guesswork where possible:
   ```bash
   xcodebuild test -scheme RunnerTests -enableCodeCoverage YES \
     -resultBundlePath /tmp/<pkg>-coverage.xcresult ...
   xcrun xccov view --report /tmp/<pkg>-coverage.xcresult
   ```
   (adjust scheme/destination flags to match the package's example project).
   If code coverage tooling isn't available in the environment, fall back to
   manually cross-referencing each public/internal method and branch
   (especially error paths and edge cases like nil/0/empty-collection
   handling) against the now-ported test suite.
2. Write new tests using the exact same conventions as the rest of the port:
   Swift Testing (`@Suite`/`@Test`/`#expect`), and the Phase 3 protocol fakes
   for anything touching a system API.
3. The "no behavior change" Non-negotiable still applies here in spirit: if a
   new test fails against the plugin's *current* behavior, that's either a
   wrong test expectation or a **pre-existing latent bug** — flag it to the
   user and let them decide, don't silently change production code to make a
   new test pass without calling it out.
4. Close with its own short summary: how many tests were added, what's now
   covered that wasn't before, and anything still not practically coverable
   (e.g. requires physical hardware or a specific OS version unavailable in
   CI).

## Requires macOS + Xcode

Phases 0 and 8's native/integration test runs and simulator smoke testing
require a Mac with Xcode and simulators installed — they cannot run on Linux/
Windows. If invoked from a non-Mac environment, produce the full plan/code
changes but flag these specific steps as pending manual verification on a Mac,
rather than skipping them silently.

Even on a Mac, check *before* Phase 0 whether a full Xcode install (not just
the Command Line Tools) is actually present, since only having the Command
Line Tools looks similar to having no macOS access at all until a native-test
command fails partway through:
```bash
xcode-select -p        # should print a path ending in Xcode.app/Contents/Developer,
                        # not .../CommandLineTools
xcodebuild -showsdks    # should list at least one iphonesimulator SDK
```
If only Command Line Tools are installed, treat native-test/simulator steps
the same as the non-Mac case above: produce the code changes and flag those
specific validation steps as pending manual verification, rather than
attempting to run them.
