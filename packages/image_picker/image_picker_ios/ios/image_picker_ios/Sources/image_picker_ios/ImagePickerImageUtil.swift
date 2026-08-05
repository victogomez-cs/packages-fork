// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import ImageIO
import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

/// Holds scaled GIF frames and the delay interval between them.
final class GIFInfo {
  let images: [UIImage]
  let interval: TimeInterval

  init(images: [UIImage], interval: TimeInterval) {
    self.images = images
    self.interval = interval
  }
}

enum ImagePickerImageUtil {
  /// Resizes the given image to fit within maxWidth (if non-nil) and maxHeight (if non-nil).
  static func scaledImage(
    _ image: UIImage?,
    maxWidth: NSNumber?,
    maxHeight: NSNumber?,
    isMetadataAvailable: Bool
  ) -> UIImage? {
    guard let image else { return nil }

    let originalWidth = Double(image.size.width)
    let originalHeight = Double(image.size.height)

    let hasMaxWidth = maxWidth != nil
    let hasMaxHeight = maxHeight != nil

    if (originalWidth == maxWidth?.doubleValue && originalHeight == maxHeight?.doubleValue)
      || (!hasMaxWidth && !hasMaxHeight)
    {
      // Nothing to scale.
      return image
    }

    let aspectRatio = originalWidth / originalHeight

    var width =
      hasMaxWidth
      ? min(round(maxWidth!.doubleValue), originalWidth) : originalWidth
    var height =
      hasMaxHeight
      ? min(round(maxHeight!.doubleValue), originalHeight) : originalHeight

    let shouldDownscaleWidth = hasMaxWidth && maxWidth!.doubleValue < originalWidth
    let shouldDownscaleHeight = hasMaxHeight && maxHeight!.doubleValue < originalHeight
    let shouldDownscale = shouldDownscaleWidth || shouldDownscaleHeight

    if shouldDownscale {
      let widthForMaxHeight = height * aspectRatio
      let heightForMaxWidth = width / aspectRatio

      if heightForMaxWidth > height {
        width = round(widthForMaxHeight)
      } else {
        height = round(heightForMaxWidth)
      }
    }

    if !isMetadataAvailable {
      let imageToScale = UIImage(
        cgImage: image.cgImage!, scale: 1, orientation: image.imageOrientation)
      return drawScaledImage(imageToScale, width: width, height: height)
    }

    // Scaling the image always rotates itself based on the current imageOrientation of the
    // original Image. Set to orientationUp for the original image before scaling, so the scaled
    // image doesn't mess up with the pixels.
    let imageToScale = UIImage(cgImage: image.cgImage!, scale: 1, orientation: .up)

    // The image orientation is manually set to UIImageOrientationUp which swapped the aspect
    // ratio in some scenarios. For example, when the original image has orientation left, the
    // horizontal pixels should be scaled to `width` and the vertical pixels should be scaled to
    // `height`. After setting the orientation to up, we end up scaling the horizontal pixels to
    // `height` and vertical to `width`. Below swap will solve this issue.
    if image.imageOrientation == .left || image.imageOrientation == .right
      || image.imageOrientation == .leftMirrored || image.imageOrientation == .rightMirrored
    {
      let temp = width
      width = height
      height = temp
    }
    return drawScaledImage(imageToScale, width: width, height: height)
  }

  /// Resize all gif animation frames.
  static func scaledGIFImage(
    _ data: Data,
    maxWidth: NSNumber?,
    maxHeight: NSNumber?
  ) -> GIFInfo {
    var options: [CFString: Any] = [
      kCGImageSourceShouldCache: true
    ]
    let gifTypeIdentifier: String
    if #available(iOS 14.0, *) {
      gifTypeIdentifier = UTType.gif.identifier
    } else {
      gifTypeIdentifier = kUTTypeGIF as String
    }
    options[kCGImageSourceTypeIdentifierHint] = gifTypeIdentifier

    let imageSource = CGImageSourceCreateWithData(data as CFData, options as CFDictionary)!
    let numberOfFrames = CGImageSourceGetCount(imageSource)
    var images: [UIImage] = []
    images.reserveCapacity(numberOfFrames)

    var interval: TimeInterval = 0.0
    for index in 0..<numberOfFrames {
      let imageRef = CGImageSourceCreateImageAtIndex(imageSource, index, options as CFDictionary)!

      let properties =
        CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil) as? [CFString: Any]
      let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]

      var delay = gifProperties?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
      if delay == nil {
        delay = gifProperties?[kCGImagePropertyGIFDelayTime] as? NSNumber
      }

      if interval == 0.0 {
        interval = delay?.doubleValue ?? 0.0
      }

      var image = UIImage(cgImage: imageRef, scale: 1.0, orientation: .up)
      image =
        scaledImage(
          image, maxWidth: maxWidth, maxHeight: maxHeight, isMetadataAvailable: true) ?? image

      images.append(image)
    }

    return GIFInfo(images: images, interval: interval)
  }

  private static func drawScaledImage(_ imageToScale: UIImage?, width: Double, height: Double)
    -> UIImage?
  {
    guard let imageToScale, width != 0, height != 0 else {
      return nil
    }
    let imageRenderer = UIGraphicsImageRenderer(
      size: CGSize(width: width, height: height),
      format: imageToScale.imageRendererFormat)
    return imageRenderer.image { rendererContext in
      let cgContext = rendererContext.cgContext

      // Flip vertically to translate between UIKit and Quartz.
      cgContext.translateBy(x: 0, y: height)
      cgContext.scaleBy(x: 1, y: -1)
      cgContext.draw(
        imageToScale.cgImage!,
        in: CGRect(x: 0, y: 0, width: width, height: height))
    }
  }
}
