# Migration PR Slices — in_app_purchase_storekit

This file lists a recommended stacked PR plan (incremental slices ~500 lines) to port remaining Objective-C sources to Swift with zero behavior change.

## Overview
- Target package: `in_app_purchase_storekit`
- Obj‑C sources: [darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/)
- Swift sources already present: [darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/)

## PR1 — Port `FIAObjectTranslator`
- Goal: Replace `FIAObjectTranslator.{m,h}` with a Swift translation and delete the Obj‑C pair in the same PR.
- Obj‑C to remove:
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAObjectTranslator.m](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAObjectTranslator.m)
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FIAObjectTranslator.h](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FIAObjectTranslator.h)
- New Swift file (suggested):
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/Translators/FIAObjectTranslator.swift](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/Translators/FIAObjectTranslator.swift)
- Tests / validation for PR:
  - `dart run script/tool/bin/flutter_plugin_tools.dart format --packages in_app_purchase_storekit`
  - `dart run script/tool/bin/flutter_plugin_tools.dart analyze --packages in_app_purchase_storekit`
  - `dart run script/tool/bin/flutter_plugin_tools.dart dart-test --packages in_app_purchase_storekit`
  - `dart run script/tool/bin/flutter_plugin_tools.dart native-test --ios --no-integration --packages in_app_purchase_storekit`

## PR2 — Port `FIATransactionCache`
- Obj‑C to remove:
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIATransactionCache.m](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIATransactionCache.m)
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FIATransactionCache.h](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FIATransactionCache.h)
- New Swift file:
  - `Sources/in_app_purchase_storekit/Caches/FIATransactionCache.swift`
- Validation: same test commands as PR1.

## PR3 — Port `FIAPReceiptManager`
- Obj‑C to remove:
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAPReceiptManager.m](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAPReceiptManager.m)
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FIAPReceiptManager.h](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FIAPReceiptManager.h)
- New Swift file:
  - `Sources/in_app_purchase_storekit/Receipts/FIAPReceiptManager.swift`

## PR4 — Port request/handler classes
- Obj‑C to remove:
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAPRequestHandler.m](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAPRequestHandler.m)
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FIAPRequestHandler.h](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FIAPRequestHandler.h)
  - Protocol shim files if used by this handler: [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/Protocols/FLTRequestHandlerProtocol.m](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/Protocols/FLTRequestHandlerProtocol.m)
- New Swift file(s):
  - `Sources/in_app_purchase_storekit/Handlers/FIAPRequestHandler.swift`

## PR5 — Port payment-queue classes & delegate
- Obj‑C to remove:
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAPaymentQueueHandler.m](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAPaymentQueueHandler.m)
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAPPaymentQueueDelegate.m](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/FIAPPaymentQueueDelegate.m)
  - [packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FLTPaymentQueueProtocol.h](packages/in_app_purchase/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit_objc/include/in_app_purchase_storekit_objc/FLTPaymentQueueProtocol.h)
- New Swift files:
  - `Sources/in_app_purchase_storekit/PaymentQueue/FIAPaymentQueueHandler.swift`
  - `Sources/in_app_purchase_storekit/PaymentQueue/FIAPaymentQueueDelegate.swift`

## PR6 — Packaging cleanup & finalization
- Tasks:
  - Delete leftover Obj‑C include directory and umbrella headers when safe.
  - Simplify `Package.swift` (drop `cSettings`/Obj‑C header-search exclusions) if present.
  - Update `in_app_purchase_storekit.podspec` to point at Swift sources only.
  - Add `CHANGELOG.md` entry + patch version bump.
  - Validation: run full Phase 8 validation commands (format/analyze/dart-test/native-test/podspec-check/validate).

## Notes & conventions
- Keep each PR small and independently mergeable; run `dart-test` and native tests locally.
- Do not switch Pigeon `swiftOut` until the cutover PR (only required if the plugin class itself moves or generated Obj‑C is being removed).
- If any OCMock-like usage is discovered in tests, insert protocol seams + fakes before porting those classes (Phase 3). CHANGELOG indicates OCMock was already removed for this package.

## Suggested git workflow (local, stacked branches)
```
git checkout -b objc-to-swift/inappstorekit/pr1-fia-translator
# implement PR1 locally, run tests, commit
git checkout -b objc-to-swift/inappstorekit/pr2-transaction-cache
# implement PR2 on top of PR1
...
```

## Where to start now
- I can generate the first PR skeleton by implementing `FIAObjectTranslator.swift` and updating callers, or produce patch templates for each PR for you to review. Which do you prefer?
