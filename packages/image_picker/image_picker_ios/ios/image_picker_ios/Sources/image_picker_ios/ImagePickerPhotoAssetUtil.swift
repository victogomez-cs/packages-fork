// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import ImageIO
import MobileCoreServices
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

enum ImagePickerPhotoAssetUtil {
  static func getAsset(fromImagePickerInfo info: [UIImagePickerController.InfoKey: Any]) -> PHAsset?
  {
    return info[.phAsset] as? PHAsset
  }

  /// Saves video to temporary URL. Returns nil on failure.
  static func saveVideo(from videoURL: URL) -> URL? {
    if !FileManager.default.isReadableFile(atPath: videoURL.path) {
      return nil
    }
    let fileName = videoURL.lastPathComponent
    let destination = URL(fileURLWithPath: temporaryFilePath(fileName))
    do {
      try FileManager.default.copyItem(at: videoURL, to: destination)
    } catch {
      return nil
    }
    return destination
  }

  /// Saves image with correct meta data and extension copied from the original asset.
  /// maxWidth and maxHeight are used only for GIF images.
  static func saveImageWithOriginalImageData(
    _ originalImageData: Data?,
    image: UIImage,
    maxWidth: NSNumber?,
    maxHeight: NSNumber?,
    imageQuality: NSNumber?
  ) -> String {
    var suffix = kImagePickerDefaultSuffix
    var type = kImagePickerMIMETypeDefault
    var metaData: [AnyHashable: Any]?

    // Getting the image type from the original image data if necessary.
    if let originalImageData {
      type = ImagePickerMetaDataUtil.getImageMIMEType(fromImageData: originalImageData)
      suffix =
        ImagePickerMetaDataUtil.imageTypeSuffix(from: type) ?? kImagePickerDefaultSuffix
      metaData = ImagePickerMetaDataUtil.getMetaData(fromImageData: originalImageData)
    }
    if type == .gif, let originalImageData {
      let gifInfo = ImagePickerImageUtil.scaledGIFImage(
        originalImageData, maxWidth: maxWidth, maxHeight: maxHeight)
      return saveImage(withMetaData: metaData, gifInfo: gifInfo, suffix: suffix)
    } else {
      return saveImage(
        withMetaData: metaData, image: image, suffix: suffix, type: type,
        imageQuality: imageQuality)
    }
  }

  /// Save image with correct meta data and extension copied from image picker result info.
  static func saveImageWithPickerInfo(
    _ info: [UIImagePickerController.InfoKey: Any]?,
    image: UIImage,
    imageQuality: NSNumber?
  ) -> String {
    let metaData = info?[.mediaMetadata] as? [AnyHashable: Any]
    return saveImage(
      withMetaData: metaData,
      image: image,
      suffix: kImagePickerDefaultSuffix,
      type: kImagePickerMIMETypeDefault,
      imageQuality: imageQuality)
  }

  private static func saveImage(
    withMetaData metaData: [AnyHashable: Any]?,
    gifInfo: GIFInfo,
    suffix: String
  ) -> String {
    let path = temporaryFilePath(suffix)
    return saveImage(withMetaData: metaData, gifInfo: gifInfo, path: path)
  }

  private static func saveImage(
    withMetaData metaData: [AnyHashable: Any]?,
    image: UIImage,
    suffix: String,
    type: ImagePickerMIMEType,
    imageQuality: NSNumber?
  ) -> String {
    var data = ImagePickerMetaDataUtil.convertImage(image, usingType: type, quality: imageQuality)
    if let metaData {
      if let updatedData = ImagePickerMetaDataUtil.image(from: data, withMetaData: metaData) {
        // If updating the metadata fails, just save the original.
        data = updatedData
      }
    }

    return createFile(data, suffix: suffix)
  }

  private static func saveImage(
    withMetaData metaData: [AnyHashable: Any]?,
    gifInfo: GIFInfo,
    path: String
  ) -> String {
    let imageType: CFString
    if #available(iOS 14.0, *) {
      imageType = UTType.gif.identifier as CFString
    } else {
      imageType = kUTTypeGIF
    }
    let destination = CGImageDestinationCreateWithURL(
      URL(fileURLWithPath: path) as CFURL,
      imageType,
      gifInfo.images.count,
      nil)!

    let frameProperties: [CFString: Any] = [
      kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: gifInfo.interval
      ]
    ]

    // Matches Obj-C: copy metaData, then set loop count on the GIF sub-dictionary if present.
    // Messaging nil when the GIF dictionary is absent is a no-op in Obj-C.
    var gifMetaProperties: [AnyHashable: Any] = metaData ?? [:]
    if var gifProperties = gifMetaProperties[kCGImagePropertyGIFDictionary]
      as? [AnyHashable: Any]
    {
      gifProperties[kCGImagePropertyGIFLoopCount] = 0
      gifMetaProperties[kCGImagePropertyGIFDictionary] = gifProperties
    }

    CGImageDestinationSetProperties(destination, gifMetaProperties as CFDictionary)

    for image in gifInfo.images {
      CGImageDestinationAddImage(destination, image.cgImage!, frameProperties as CFDictionary)
    }

    CGImageDestinationFinalize(destination)
    return path
  }

  private static func temporaryFilePath(_ suffix: String) -> String {
    let fileExtension = "image_picker_%@" + suffix
    let guid = ProcessInfo.processInfo.globallyUniqueString
    let tmpFile = String(format: fileExtension, guid)
    return (NSTemporaryDirectory() as NSString).appendingPathComponent(tmpFile)
  }

  private static func createFile(_ data: Data, suffix: String) -> String {
    let tmpPath = temporaryFilePath(suffix)
    if FileManager.default.createFile(atPath: tmpPath, contents: data, attributes: nil) {
      return tmpPath
    } else {
      // Matches Obj-C: the `nil;` expression was a no-op; path is still returned.
      return tmpPath
    }
  }
}
