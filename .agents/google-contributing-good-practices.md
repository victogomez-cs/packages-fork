# Flutter / packages contributing good practices

Working notes for contributing to Flutter open source (especially `flutter/packages`). This is not an official Flutter document. The links below are the source of truth.

---

## Official contributing docs

Read these before opening a PR. The packages repo does not duplicate the full Flutter process; it points at it.

### flutter/flutter

- [Contributing to Flutter](https://github.com/flutter/flutter/blob/main/CONTRIBUTING.md) — start here: community norms, CLA, Discord, setup, review path.
- [Code of conduct](https://github.com/flutter/flutter/blob/main/CODE_OF_CONDUCT.md) — be gracious, respectful, and professional.
- [Tree hygiene](https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md) — how to land a PR, get review, handle tests, breaking changes, and AI-assisted contributions.
- [Style guide for Flutter repo](https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md) — Dart API design, comments, TODOs.
- [Chat / Discord](https://github.com/flutter/flutter/blob/main/docs/contributing/Chat.md) — `#hackers-new` for new contributors; do not ping for review until the documented wait has passed.
- [Contributor access](https://github.com/flutter/flutter/blob/main/docs/contributing/Contributor-access.md) — who can approve and land PRs.
- [Landing changes with autosubmit](https://github.com/flutter/flutter/blob/main/docs/infra/Landing-Changes-With-Autosubmit.md) — reviewers add the `autosubmit` label; a bot merges.
- [CLA](https://cla.developers.google.com/) — required for every first-time contributor.



### flutter/packages

- [packages CONTRIBUTING.md](https://github.com/flutter/packages/blob/main/CONTRIBUTING.md) — packages-specific setup, code owners, language style, formatters.
- [Setting up the Packages development environment](https://github.com/flutter/flutter/blob/main/docs/ecosystem/contributing/Setting-up-the-Packages-development-environment.md)
- [Packages repository structure](https://github.com/flutter/flutter/blob/main/docs/ecosystem/Plugins-and-Packages-repository-structure.md)
- [Contributing to Plugins and Packages](https://github.com/flutter/flutter/blob/main/docs/ecosystem/contributing/README.md) — versioning, CHANGELOG style, federated plugins, Swift migration.
- [Plugin tests](https://github.com/flutter/flutter/blob/main/docs/ecosystem/testing/Plugin-Tests.md) — how to find and run plugin tests.
- [PR template](https://github.com/flutter/packages/blob/main/.github/PULL_REQUEST_TEMPLATE.md) — checklist every PR must follow.
- [Suggested reviewers](https://github.com/flutter/packages/blob/main/SUGGESTED_REVIEWERS.md) — iOS/macOS: `@hellohuanlin`, `@louisehsu`, and others by area.
- [Repository tooling](https://github.com/flutter/packages/blob/main/script/tool/README.md) — `format`, `analyze`, `native-test`, `update-release-info`.



### Language style (from packages CONTRIBUTING.md)

- Dart: Flutter style, `dart format`
- C++: Google style, `clang-format`
- Java: Google style, `google-java-format`
- Kotlin: Android Kotlin style, `ktfmt`
- Objective-C: [Google Objective-C style](https://google.github.io/styleguide/objcguide.html), `clang-format`
- Swift: [Google Swift style](https://google.github.io/swift/), `swift-format`

Always format with the repo tool:

```bash
dart run $REPO_ROOT/script/tool/bin/flutter_plugin_tools.dart format --packages <changed_packages>
```

---



## Core process (from Tree hygiene)

Condensed. Details live in the [Tree hygiene](https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md) page.

1. File or reuse a GitHub issue. Every PR should list at least one issue.
2. Discuss non-trivial design on the issue first.
3. Implement on a branch from current `main`, with tests.
4. Open a PR from a **fork** (see [Where to open a PR](#where-to-open-a-pr)). Title for packages: `[package_name] Short description`.
5. Sign the CLA. Fill the PR checklist honestly.
6. Wait for reviewers to be assigned (weekly triage). Contributors without write access are limited to **2 concurrent open PRs** per repo (drafts do not count).
7. Keep CI green. If only tests changed, version/CHANGELOG may be exempt; if CI disagrees, wait for a team member to add an override label rather than arguing in code.
8. Address review comments, then wait for **GitHub Approve (LGTM)** from the code owners and from anyone else who left comments. An “LGTM” text comment is not enough.
9. Do **not** merge the PR yourself. Add the `autosubmit` label (or ask a reviewer to add it if you are not in `flutter-hackers`). A bot lands it. See [Landing changes with autosubmit](https://github.com/flutter/flutter/blob/main/docs/infra/Landing-Changes-With-Autosubmit.md).
10. Watch post-submit. If something breaks, revert first.

**When to ping in Discord:** only if **nobody has reviewed after two weeks**. Start in `#hackers` or `#hackers-new` with what the PR does and a link. Do not Discord-ping just because comments were addressed.

**@-mentions:** never in commit messages (they notify people on every rebase). If you need to mention someone, do it in a **PR comment**.

**Updating a branch:** on the PR page, GitHub may show **This branch is out-of-date with the base branch**. Click **Update branch**. That merges the latest `main` into your feature branch. The PR’s changed-files list should stay the same.

To update locally instead:

```bash
git fetch upstream
git rebase upstream/main
git push origin your_branch_name
```

If GitHub ever shows dozens of files when your real change is one file, rebase (or close/reopen the PR) to refresh the diff. Never force-push `main`.

---



## Where to open a PR

Team process (confirmed with Flutter iOS / packages maintainers). [Tree hygiene](https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#overview) is the official source: work on a **fork**, open a PR into `flutter/packages` `main`, then land with **autosubmit**.

### Landing (every PR)

Once the PR is approved and CI is green, **do not click Merge**. Add the `autosubmit` label. The bot squash-merges when it is ready.

- If you are in `flutter-hackers`, you add the label.
- If you are not, a reviewer adds it.

Manual merge skips the landing path Flutter uses for tree health and reverts.

### PRs come from a fork

A PR should **not** be pushed to `flutter/packages`. Use the fork.

Tree hygiene names the fork `origin` and upstream `upstream`. In this checkout, `origin` is `flutter/packages` and the fork is `fork`. Push the feature branch to **the fork**:

```bash
git fetch origin
git checkout origin/main -b your_branch_name
# implement, commit
git push fork your_branch_name
```

Open the PR against `flutter/packages` `main` from that fork branch. Example: [flutter/packages#12536](https://github.com/flutter/packages/pull/12536) (`victogomez-cs/packages-fork` → `flutter/packages` `main`).

This matches Tree hygiene step 5–6 (branch on your GitHub **fork**, then submit the PR).

---



## Lessons from previous PRs

Team expectations on top of the official docs. Where a lesson came from a specific review, that PR is linked in the item.

### 1. Address Gemini comments

[flutter/packages#12484](https://github.com/flutter/packages/pull/12484)

The PR template says Gemini Code Assist is a trial and is **not** authoritative Flutter-team review. You may wait for a human if you are unsure.

In practice, human reviewers (for example `@hellohuanlin`) have asked authors to **address Gemini comments**. Do not ignore the bot.

What to do:

- Read every Gemini note.
- If it is correct, fix it and reply on that thread with what changed.
- If it is wrong, incomplete, or conflicts with a human comment, **reply on the thread** explaining why you did not take it. Silence looks like the comment was skipped.
- If a human later disagrees with Gemini, follow the human reviewer.
- Never tell a reviewer “addressed” just because an AI said so. Check the diff yourself ([AI contribution guidelines](https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#ai-contribution-guidelines)).



### 2. Avoid Objective-C runtime hacks

[flutter/packages#12484](https://github.com/flutter/packages/pull/12484)

Do not call Obj-C from Swift tests with `performSelector`, `NSSelectorFromString`, `perform(_:with:with:)`, or other untyped runtime APIs. Reviewers will reject that: it is not type-checked, the IDE cannot warn, and it is fragile.

If a method cannot be invoked in a typed way (example: `UIOpenURLContext` has no public initializer, so `scene:openURLContexts:` cannot be constructed in tests):

- Prefer a nearby typed API that covers the same production path (for example `application:openURL:` already forwards to `handleURL:`).
- Do **not** change production Obj-C in a tests-only PR just to make an untyped test compile.
- Do **not** add OCMock or a production test seam unless the reviewer asks for it.
- If the real test has to wait for the Swift migration, drop the untyped test and leave a proper TODO (see below).

Typed Swift or a documented gap is better than a clever hack.

### 3. After addressing review comments

[flutter/packages#12484](https://github.com/flutter/packages/pull/12484)

1. Push the fix to the **feature branch** (never force-push `main`).
2. Reply on **each review thread** with what you did, or why you did not.
3. Optionally leave a short top-level PR comment so the reviewer is notified, for example:
  > @hellohuanlin addressed the review comments — PTAL.
  
  - That is expected and allowed. GitHub already notifies on thread replies; the top-level ping is extra clarity, not a substitute for thread replies.
  
4. Wait for GitHub **Approve**. Then add `autosubmit` (or ask the reviewer to). Do **not** click Merge.
5. Do **not** ping Discord for a re-review. Chat is for “no review after two weeks,” not “I pushed a fix.”



### 4. Keep the PR scoped

[flutter/packages#12484](https://github.com/flutter/packages/pull/12484)

- Tests-only PRs should not change production `.m` / `.h` unless a test cannot exist otherwise **and** the reviewer agrees.
- Do not add extra tests or platforms “while we are here” after a review comment. Mid-review scope creep creates new comments.
- Bug fixes found while backfilling tests belong in a **separate** PR (or a comment + issue if the fix is too large). Migration and coverage PRs should stay focused. See [Swift migration testing notes](https://github.com/flutter/flutter/blob/main/docs/ecosystem/contributing/README.md#testing).



### 5. TODOs

[flutter/packages#12484](https://github.com/flutter/packages/pull/12484)

From the [Flutter style guide](https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md):

- Write `TODO` in all caps.
- Include `(GitHub-username)` of the person with context (usually you).
- Include an **issue link** (required).
- Place the TODO as its own comment, not glued to an unrelated test or method so it looks like it documents the wrong code.

Example:

```swift
// TODO(victogomez-cs): Re-add a typed scene:openURLContexts: test after
// the Obj-C plugin is migrated to Swift. See
// https://github.com/flutter/flutter/issues/119103
```



### 6. Tests and coverage

[flutter/packages#12484](https://github.com/flutter/packages/pull/12484)

- CI does **not** gate on a coverage percentage. Reviewers **read** the tests. A 100% number is not a substitute for complete, typed tests.
- Backfill unit tests in a **separate PR before** converting Obj-C to Swift, when that does not require a production refactor.
- Run native tests the way CI does (`flutter_plugin_tools` `native-test`). Some packages are on the Xcode warnings exception list; a bare local `native-test` can be stricter than CI.
- For iOS locally, prefer a simulator destination (or `flutter build ios --debug --config-only --simulator`). Device signing is a common false failure that CI does not hit.



### 7. GitHub / git hygiene we already hit

[flutter/packages#12484](https://github.com/flutter/packages/pull/12484)

- When GitHub shows **This branch is out-of-date with the base branch**, click **Update branch**. That merges the latest `main` in. The changed-files count does **not** grow from that update.
- If GitHub ever shows dozens of files but your real change is one file, rebase onto current `main` or close/reopen the PR to refresh the diff. Never force-push `main`.
- CLA: a Cloudsufi Google work email is already covered by the company CLA. If the CLA bot still fails, look for a `Co-authored-by` on the commit who is **not** on that CLA (Cursor, Claude, or other bots). Drop those co-author trailers and push again.
- Tests-only changes are usually version/CHANGELOG exempt. User-facing or production changes must update both (prefer `update-release-info`).



### 8. How to reply on GitHub

[flutter/packages#12484](https://github.com/flutter/packages/pull/12484)

Be polite. Explain what happened and why. Give a next step. Example for dropping an untyped test:

> Dropped the `scene:openURLContexts:` test. `UIOpenURLContext` has no public initializer, so the only way to call that Obj-C method was `performSelector`, which loses compilation safety. `application:openURL:` already covers the same `handleURL:` path. Left a TODO to re-add a typed test after the Swift migration ([https://github.com/flutter/flutter/issues/119103](https://github.com/flutter/flutter/issues/119103)).

---



## Quick checklist before asking for re-review

- [ ] Gemini threads: fixed **or** replied with a reason.
- [ ] Human review threads: each one has a reply.
- [ ] No runtime hacks.
- [ ] PR still matches the original scope (no drive-by files or extra platforms).
- [ ] TODOs use `TODO(username)` plus an issue URL.
- [ ] Code formatted with `flutter_plugin_tools format`.
- [ ] CI green (or failures explained as existing on `main`).
- [ ] Ready to land with `autosubmit`, not a manual merge.
- [ ] Top-level “PTAL” comment on the PR if a reviewer already engaged.
- [ ] No Discord ping unless two weeks have passed with no review.
- [ ] You personally verified the “addressed” claim; you did not paste an AI summary.