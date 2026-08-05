// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import PhotosUI

/// The subset of PHPickerResult used when saving a picked item.
///
/// PHPickerResult has no public initializer, so this indirection allows tests to drive the save
/// path with a hand-built NSItemProvider.
struct PickerResultHandle {
  let itemProvider: NSItemProvider
  let assetIdentifier: String?

  @available(iOS 14, *)
  init(_ result: PHPickerResult) {
    itemProvider = result.itemProvider
    assetIdentifier = result.assetIdentifier
  }

  init(itemProvider: NSItemProvider, assetIdentifier: String? = nil) {
    self.itemProvider = itemProvider
    self.assetIdentifier = assetIdentifier
  }
}
