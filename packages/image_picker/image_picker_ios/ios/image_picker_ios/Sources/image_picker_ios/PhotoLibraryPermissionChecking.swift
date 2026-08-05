// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Photos

/// Protocol for photo-library authorization checks.
///
/// Exists to allow injecting an alternate implementation for testing.
protocol PhotoLibraryPermissionChecking: AnyObject {
  func authorizationStatus() -> PHAuthorizationStatus
  @available(iOS 14, *)
  func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus
  func requestAuthorization(_ handler: @escaping (PHAuthorizationStatus) -> Void)
  @available(iOS 14, *)
  func requestAuthorization(
    for accessLevel: PHAccessLevel,
    handler: @escaping (PHAuthorizationStatus) -> Void
  )
}

/// Default implementation that forwards to PHPhotoLibrary.
final class DefaultPhotoLibraryPermissionChecker: PhotoLibraryPermissionChecking {
  func authorizationStatus() -> PHAuthorizationStatus {
    PHPhotoLibrary.authorizationStatus()
  }

  @available(iOS 14, *)
  func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
    PHPhotoLibrary.authorizationStatus(for: accessLevel)
  }

  func requestAuthorization(_ handler: @escaping (PHAuthorizationStatus) -> Void) {
    PHPhotoLibrary.requestAuthorization(handler)
  }

  @available(iOS 14, *)
  func requestAuthorization(
    for accessLevel: PHAccessLevel,
    handler: @escaping (PHAuthorizationStatus) -> Void
  ) {
    PHPhotoLibrary.requestAuthorization(for: accessLevel, handler: handler)
  }
}
