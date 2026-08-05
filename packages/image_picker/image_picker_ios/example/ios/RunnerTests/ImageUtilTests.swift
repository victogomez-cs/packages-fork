// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import CoreImage
import Testing
import UIKit

@testable import image_picker_ios

// Corner colors of test image scaled to 3x2. Format is "R G B A".
private let colorRepresentation3x2BottomLeftYellow = "1 0.776471 0 1"
private let colorRepresentation3x2TopLeftRed = "1 0.0666667 0 1"
private let colorRepresentation3x2BottomRightCyan = "0 0.772549 1 1"
private let colorRepresentation3x2TopRightBlue = "0 0.0705882 0.996078 1"

/// Returns the color of the given pixel of `image`, in "R G B A" form.
private func colorStringAtPixel(_ image: UIImage, _ pixelX: Int, _ pixelY: Int) -> String {
  guard let cgImage = image.cgImage else {
    return ""
  }

  // The context is only one pixel, but the row length is taken from the source image, matching
  // the drawing call below, so the buffer must be able to hold a full source row.
  var buffer = [UInt8](repeating: 0, count: max(cgImage.bytesPerRow, 4))
  buffer.withUnsafeMutableBytes { rawBuffer in
    guard
      let context = CGContext(
        data: rawBuffer.baseAddress,
        width: 1,
        height: 1,
        bitsPerComponent: cgImage.bitsPerComponent,
        bytesPerRow: cgImage.bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: cgImage.bitmapInfo.rawValue)
    else {
      return
    }
    context.draw(
      cgImage,
      in: CGRect(
        x: -pixelX, y: -pixelY, width: cgImage.width, height: cgImage.height))
  }

  let argb =
    UInt32(buffer[3]) << 24 | UInt32(buffer[2]) << 16 | UInt32(buffer[1]) << 8 | UInt32(buffer[0])
  let blue = argb & 0xff
  let green = argb >> 8 & 0xff
  let red = argb >> 16 & 0xff
  let alpha = argb >> 24 & 0xff

  return CIColor(
    red: CGFloat(red) / 255,
    green: CGFloat(green) / 255,
    blue: CGFloat(blue) / 255,
    alpha: CGFloat(alpha) / 255
  ).stringRepresentation
}

@MainActor
struct ImageUtilTests {
  @Test func scaledImageEqualSizeReturnsSameImage() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    let scaledImage = ImagePickerImageUtil.scaledImage(
      image,
      maxWidth: NSNumber(value: Double(image.size.width)),
      maxHeight: NSNumber(value: Double(image.size.height)),
      isMetadataAvailable: true)

    // Assert the same instance (not just equal objects).
    #expect(scaledImage === image)
  }

  @Test func scaledImageNilSizeReturnsSameImage() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    let scaledImage = ImagePickerImageUtil.scaledImage(
      image,
      maxWidth: nil,
      maxHeight: nil,
      isMetadataAvailable: true)

    // Assert the same instance (not just equal objects).
    #expect(scaledImage === image)
  }

  @Test func scaledImageShouldBeScaled() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))

    let scaledWidth = 3
    let scaledHeight = 2
    let scaledImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: scaledWidth),
        maxHeight: NSNumber(value: scaledHeight),
        isMetadataAvailable: true))
    #expect(scaledImage.size.width == CGFloat(scaledWidth))
    #expect(scaledImage.size.height == CGFloat(scaledHeight))

    // Check the corners to make sure nothing has been rotated.
    #expect(colorStringAtPixel(scaledImage, 0, 0) == colorRepresentation3x2BottomLeftYellow)
    #expect(
      colorStringAtPixel(scaledImage, 0, scaledHeight - 1) == colorRepresentation3x2TopLeftRed)
    #expect(
      colorStringAtPixel(scaledImage, scaledWidth - 1, 0) == colorRepresentation3x2BottomRightCyan)
    #expect(
      colorStringAtPixel(scaledImage, scaledWidth - 1, scaledHeight - 1)
        == colorRepresentation3x2TopRightBlue)
  }

  @Test func scaledImageShouldBeScaledWithNoMetadata() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))

    let scaledWidth = 3
    let scaledHeight = 2
    let scaledImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: scaledWidth),
        maxHeight: NSNumber(value: scaledHeight),
        isMetadataAvailable: false))
    #expect(scaledImage.size.width == CGFloat(scaledWidth))
    #expect(scaledImage.size.height == CGFloat(scaledHeight))

    // Check the corners to make sure nothing has been rotated.
    #expect(colorStringAtPixel(scaledImage, 0, 0) == colorRepresentation3x2BottomLeftYellow)
    #expect(
      colorStringAtPixel(scaledImage, 0, scaledHeight - 1) == colorRepresentation3x2TopLeftRed)
    #expect(
      colorStringAtPixel(scaledImage, scaledWidth - 1, 0) == colorRepresentation3x2BottomRightCyan)
    #expect(
      colorStringAtPixel(scaledImage, scaledWidth - 1, scaledHeight - 1)
        == colorRepresentation3x2TopRightBlue)
  }

  @Test func scaledImageShouldBeCorrectRotation() throws {
    let imageURL = try #require(
      ImagePickerTestBundle.bundle.url(
        forResource: "jpgImageWithRightOrientation", withExtension: "jpg"))
    let imageData = try Data(contentsOf: imageURL)
    let image = try #require(UIImage(data: imageData))
    #expect(image.size.width == 130)
    #expect(image.size.height == 174)
    #expect(image.imageOrientation == .right)

    let newImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: 10),
        maxHeight: NSNumber(value: 10),
        isMetadataAvailable: true))
    #expect(newImage.size.width == 10)
    #expect(newImage.size.height == 7)
    #expect(newImage.imageOrientation == .up)
  }

  @Test func scaledGIFImageShouldBeScaled() {
    // gif image that frame size is 3 and the duration is 1 second.
    let info = ImagePickerImageUtil.scaledGIFImage(
      ImagePickerTestImages.gifTestData,
      maxWidth: NSNumber(value: 3),
      maxHeight: NSNumber(value: 2))

    let images = info.images
    let duration = info.interval

    #expect(images.count == 3)
    #expect(duration == 1)

    for newImage in images {
      #expect(newImage.size.width == 3)
      #expect(newImage.size.height == 2)
    }
  }

  @Test func scaledImageTallImageShouldBeScaledBelowMaxHeight() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTallTestData))
    #expect(image.size.width == 4)
    #expect(image.size.height == 7)
    let newImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: 5),
        maxHeight: NSNumber(value: 5),
        isMetadataAvailable: true))

    #expect(newImage.size.width == 3)
    #expect(newImage.size.height == 5)
  }

  @Test func scaledImageTallImageShouldBeScaledBelowMaxWidth() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTallTestData))
    let newImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: 3),
        maxHeight: NSNumber(value: 10),
        isMetadataAvailable: true))

    #expect(newImage.size.width == 3)
    #expect(newImage.size.height == 5)
  }

  @Test func scaledImageTallImageShouldNotBeScaledAboveOriginalWidthOrHeight() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTallTestData))
    let newImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: 10),
        maxHeight: NSNumber(value: 10),
        isMetadataAvailable: true))

    #expect(newImage.size.width == 4)
    #expect(newImage.size.height == 7)
  }

  @Test func scaledImageWideImageShouldBeScaledBelowMaxHeight() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    #expect(image.size.width == 12)
    #expect(image.size.height == 7)
    let newImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: 20),
        maxHeight: NSNumber(value: 6),
        isMetadataAvailable: true))

    #expect(newImage.size.width == 10)
    #expect(newImage.size.height == 6)
  }

  @Test func scaledImageWideImageShouldBeScaledBelowMaxWidth() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    let newImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: 10),
        maxHeight: NSNumber(value: 10),
        isMetadataAvailable: true))

    #expect(newImage.size.width == 10)
    #expect(newImage.size.height == 6)
  }

  @Test func scaledImageWideImageShouldNotBeScaledAboveOriginalWidthOrHeight() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    let newImage = try #require(
      ImagePickerImageUtil.scaledImage(
        image,
        maxWidth: NSNumber(value: 100),
        maxHeight: NSNumber(value: 100),
        isMetadataAvailable: true))

    #expect(newImage.size.width == 12)
    #expect(newImage.size.height == 7)
  }

  @Test func scaledImageImageIsNil() {
    let newImage = ImagePickerImageUtil.scaledImage(
      nil,
      maxWidth: NSNumber(value: 1440),
      maxHeight: NSNumber(value: 1440),
      isMetadataAvailable: true)

    #expect(newImage == nil)
  }

  @Test func scaledImageMaxWidthZeroAndMaxHeightIsZero() throws {
    let image = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    let newImage = ImagePickerImageUtil.scaledImage(
      image,
      maxWidth: NSNumber(value: 0),
      maxHeight: NSNumber(value: 0),
      isMetadataAvailable: true)

    #expect(newImage == nil)
  }
}
