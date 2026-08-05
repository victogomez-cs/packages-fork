// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import ImageIO
import UIKit

enum ImagePickerMIMEType: UInt {
  case png
  case jpeg
  case gif
  case other
}

let kImagePickerDefaultSuffix = ".jpg"
let kImagePickerMIMETypeDefault: ImagePickerMIMEType = .jpeg

private let kFirstByteJPEG: UInt8 = 0xFF
private let kFirstBytePNG: UInt8 = 0x89
private let kFirstByteGIF: UInt8 = 0x47

enum ImagePickerMetaDataUtil {
  /// Retrieve MIME type by reading the image data. We currently only support some popular types.
  static func getImageMIMEType(fromImageData imageData: Data) -> ImagePickerMIMEType {
    guard !imageData.isEmpty else {
      return .other
    }
    let firstByte = imageData[imageData.startIndex]
    switch firstByte {
    case kFirstByteJPEG:
      return .jpeg
    case kFirstBytePNG:
      return .png
    case kFirstByteGIF:
      return .gif
    default:
      return .other
    }
  }

  /// Get corresponding suffix from type.
  static func imageTypeSuffix(from type: ImagePickerMIMEType) -> String? {
    switch type {
    case .jpeg:
      return ".jpg"
    case .png:
      return ".png"
    case .gif:
      return ".gif"
    default:
      return nil
    }
  }

  static func getMetaData(fromImageData imageData: Data) -> [AnyHashable: Any]? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
      return nil
    }
    return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any]
  }

  /// Creates and returns data for a new image based on imageData, but with the given metadata.
  ///
  /// If creating a new image fails, returns nil.
  static func image(from imageData: Data, withMetaData metadata: [AnyHashable: Any]) -> Data? {
    let targetData = NSMutableData()
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
      return nil
    }

    guard let sourceType = CGImageSourceGetType(source),
      let destination = CGImageDestinationCreateWithData(
        targetData as CFMutableData, sourceType, 1, nil)
    else {
      return nil
    }

    CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
    CGImageDestinationFinalize(destination)
    return targetData as Data
  }

  /// Converting UIImage to a Data with the type provided.
  ///
  /// The quality is for JPEG type only, it defaults to 1. Compressing is not supported for type
  /// other than JPEG; a log is printed and the image is returned with original quality.
  static func convertImage(
    _ image: UIImage,
    usingType type: ImagePickerMIMEType,
    quality: NSNumber?
  ) -> Data {
    if quality != nil && type != .jpeg {
      let suffix = imageTypeSuffix(from: type) ?? "(null)"
      NSLog(
        "image_picker: compressing is not supported for type %@. Returning the image with original quality",
        suffix)
    }

    switch type {
    case .jpeg:
      let qualityFloat: CGFloat = quality != nil ? CGFloat(truncating: quality!) : 1
      return image.jpegData(compressionQuality: qualityFloat) ?? Data()
    case .png:
      return image.pngData() ?? Data()
    default:
      // converts to JPEG by default.
      let qualityFloat: CGFloat = quality != nil ? CGFloat(truncating: quality!) : 1
      return image.jpegData(compressionQuality: qualityFloat) ?? Data()
    }
  }
}
