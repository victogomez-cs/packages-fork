// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import PhotosUI
import UIKit

/// Factory for creating PHPickerViewController instances.
///
/// Exists so tests can intercept construction (previously done via OCMock alloc/init).
@available(iOS 14, *)
protocol PHPickerViewControllerCreating: AnyObject {
  func makePicker(configuration: PHPickerConfiguration) -> PHPickerViewController
}

@available(iOS 14, *)
final class DefaultPHPickerViewControllerFactory: PHPickerViewControllerCreating {
  func makePicker(configuration: PHPickerConfiguration) -> PHPickerViewController {
    PHPickerViewController(configuration: configuration)
  }
}
