---
name: objc-to-swift-migration
description: >-
  Migrate a flutter/packages iOS/macOS plugin implementation (and its OCMock-based
  native tests) from Objective-C to Swift with zero behavior change, following the
  conventions established by url_launcher_ios, file_selector_ios, quick_actions_ios,
  and camera_avfoundation. Use when asked to migrate, convert, or rewrite a Darwin
  plugin package (e.g. "_ios" or "_macos" or "_darwin" suffixed package) from
  Objective-C to Swift, or to remove OCMock from a plugin's native tests. Also
  supports a coverage-only mode that reports current native test coverage and
  what's missing, with no code changes, before deciding whether to migrate.
  Example invocations: "/objc-to-swift-migration coverage-only for
  image_picker_ios" (report only, no changes), "/objc-to-swift-migration plan
  for google_sign_in_ios" (plan only, no code), "/objc-to-swift-migration
  migrate url_launcher_ios, including backfilling missing test coverage" (full
  implementation).
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
invoked, state the target package and what you want: a **coverage report
only**, a **plan** only, or a **full implementation**. For example:

- `/objc-to-swift-migration coverage-only for image_picker_ios` — report
  coverage, no plan or code changes.
- `/objc-to-swift-migration plan for google_sign_in_ios` — produce a plan,
  no code changes.
- `/objc-to-swift-migration migrate url_launcher_ios` — full implementation
  of the mandatory port (Phases 0-8).
- `/objc-to-swift-migration migrate camera_avfoundation, including
  backfilling missing test coverage` — full implementation plus the
  optional Phase 10 coverage backfill.

1. Read this entire file before writing any plan or code — the phases build on
   each other and the Non-negotiables apply throughout.
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
   Phases below (tailored with the actual discovered files/classes), and stop
   — do not start editing code until asked to implement it.
6. If asked to **implement**, work through the Phases in order (0→8), keeping
   the Non-negotiables satisfied at every step; don't jump ahead to Phase 4+
   before the protocol seams from Phase 3 exist if OCMock mocks system APIs.
7. If running on a non-Mac environment, see "Requires macOS + Xcode" at the
   bottom before starting — plan/code changes can still proceed, but flag
   native test/simulator steps as pending manual verification.
8. Always finish with **Phase 9's end-of-migration summary** — never end a
   migration session without it, even if some Phase 8 validation steps had to
   be skipped for environment reasons.
9. Only **after** that summary, ask whether the user also wants existing
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
  Phase 7). This repo's precedent (`url_launcher_ios` 6.2.0→6.2.1) treats a pure
  Obj-C→Swift rewrite as a **patch-level, non-breaking** change since the Dart API
  is untouched.
- **Format, analyze, Dart tests, and native tests must all pass** before
  considering any phase done — not just the native suite. Never skip
  `dart-test` just because the changes look native-only.

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
5. Ask the user explicitly: *"Would you like me to proceed with the full
   Objective-C → Swift migration and include writing the tests needed to
   close these gaps as part of it (so the migrated package ends up at ~100%
   native test coverage), just do the migration on its own, or neither for
   now?"*
6. Act on the answer:
   - **Full migration + close the gaps:** proceed through Phases 0→8 as
     normal, but treat Phase 10's coverage backfill as **in scope for this
     same effort** rather than a separately-opted-into follow-up — the
     Phase 10 opt-in question in "How to use this skill" has already been
     answered, so don't re-ask it. Still consider keeping the new-coverage
     tests as a distinguishable commit for reviewability, even if they end
     up in the same PR as the port.
   - **Full migration only:** proceed through Phases 0→8 normally, and ask
     the Phase 10 opt-in question later as usual (default: no).
   - **Neither:** stop — the coverage report was the whole ask.

## Reference templates in this repo

| Package | Demonstrates |
|---|---|
| `url_launcher/url_launcher_ios` | Best small/medium template: `Package.swift`, podspec, protocol-based DI (see its `Launcher.swift`/`ViewPresenter.swift`), `pluginClass` renamed off `FLT` prefix, patch-level version bump |
| `file_selector/file_selector_ios` | Same pattern, Pigeon `swiftOut` |
| `quick_actions_ios` | Dropped custom Obj-C `Test` submodule; also migrated `RunnerUITests` |
| `camera_avfoundation` | **Incremental** multi-PR migration pattern for large plugins; protocol wrappers around static system APIs (`AVCaptureDevice`, etc.) — copy this pattern whenever OCMock mocks a system-framework class method |

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
removed as a standalone effort before the rest of the migration. For these,
Phases 2/3/5 are largely already done — the remaining work is mostly Phase 1
(Pigeon) and Phase 4 (port the plugin class itself and delete the `.h`/`.m`),
with light edits to the existing Swift tests/fakes to match any renamed
types.

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

## Rollout strategy: big-bang vs incremental

Default to **big-bang** (single coherent PR/session covering all Sources + all
tests) — matches `url_launcher_ios`/`file_selector_ios` and is simplest.

Use **incremental** (multi-PR, one class at a time, temporary Obj-C/Swift interop)
only when the plugin is large — heuristic: **>3-4k lines of hand-written
Objective-C**, or the user/CI explicitly wants smaller reviewable PRs. Follow
`camera_avfoundation`'s history for that shape (utils → individual features →
plugin core → tests, each its own PR).

## The migration workflow

### Phase 0 — Baseline
Run the existing native test suite and record the passing test count before
touching anything (swap `--ios` for `--macos`, or use both, per the Platform
variants table):
```bash
dart run script/tool/bin/flutter_plugin_tools.dart native-test --ios --no-integration --packages <pkg>
```

### Phase 1 — Pigeon
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
tested in isolation immediately:
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
5. Delete all `.m`/`.h`, the modulemap, umbrella header, and `include/`
   directory once nothing references them.
6. Simplify `Package.swift` (drop `cSettings`/header-search-path/ObjC excludes)
   and the podspec (there may be one per platform for a `_darwin`-shared
   package):
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
```bash
dart run script/tool/bin/flutter_plugin_tools.dart update-release-info \
  --version=minimal --base-branch=origin/main \
  --changelog="Migrates the platform implementation from Objective-C to Swift."
```
Then check README.md and any architecture docs for now-stale Objective-C
references (endorsed-plugin READMEs are usually minimal boilerplate — only a
quick check needed). Check the umbrella app-facing package's docs too.

### Phase 8 — Validation (mandatory)
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
Never end a migration session silently — always close with a concise summary
covering, at minimum:

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
