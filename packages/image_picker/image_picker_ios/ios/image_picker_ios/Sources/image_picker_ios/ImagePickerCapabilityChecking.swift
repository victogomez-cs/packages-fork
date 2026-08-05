// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import UIKit

/// Protocol for UIImagePickerController capability checks.
///
/// Exists to allow injecting an alternate implementation for testing.
protocol ImagePickerCapabilityChecking: AnyObject {
  func isSourceTypeAvailable(_ sourceType: UIImagePickerController.SourceType) -> Bool
  func isCameraDeviceAvailable(_ cameraDevice: UIImagePickerController.CameraDevice) -> Bool
}

/// Default implementation that forwards to UIImagePickerController.
final class DefaultImagePickerCapabilityChecker: ImagePickerCapabilityChecking {
  func isSourceTypeAvailable(_ sourceType: UIImagePickerController.SourceType) -> Bool {
    UIImagePickerController.isSourceTypeAvailable(sourceType)
  }

  func isCameraDeviceAvailable(_ cameraDevice: UIImagePickerController.CameraDevice) -> Bool {
    UIImagePickerController.isCameraDeviceAvailable(cameraDevice)
  }
}
