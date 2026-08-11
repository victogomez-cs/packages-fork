// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// See ExceptionCatcher.h for why this Objective-C helper is required after the
// Swift migration.

#import "include/ExceptionCatcher.h"

NSException *_Nullable FSICatchException(void (^block)(void)) {
  @try {
    block();
    return nil;
  } @catch (NSException *exception) {
    return exception;
  }
}
