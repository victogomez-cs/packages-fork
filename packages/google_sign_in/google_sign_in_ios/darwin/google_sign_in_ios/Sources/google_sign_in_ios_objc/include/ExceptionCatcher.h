// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// This file (and ExceptionCatcher.m) intentionally remain Objective-C after the
// plugin's Swift migration.
//
// The previous Obj-C implementation used @try/@catch around GIDSignIn calls so
// that unexpected NSExceptions became Flutter/Pigeon errors instead of
// crashing. Swift's do/catch cannot catch NSException, and the Google Sign-In
// SDK (and unit-test fakes) can still raise them. This helper preserves that
// behavior.
//
// It lives in its own google_sign_in_ios_objc target because Swift Package
// Manager does not allow mixing Swift and Objective-C sources in one target.

/// Runs `block`, returning any Objective-C exception it raises.
FOUNDATION_EXPORT NSException *_Nullable FSICatchException(void (^block)(void));

NS_ASSUME_NONNULL_END
