// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import ImageIO
import Testing
import UIKit

@testable import image_picker_ios

@MainActor
struct MetaDataUtilTests {
  @Test func getImageMIMETypeFromImageData() {
    // test jpeg
    #expect(
      ImagePickerMetaDataUtil.getImageMIMEType(fromImageData: ImagePickerTestImages.jpgTestData)
        == .jpeg)

    // test png
    #expect(
      ImagePickerMetaDataUtil.getImageMIMEType(fromImageData: ImagePickerTestImages.pngTestData)
        == .png)

    // test gif
    #expect(
      ImagePickerMetaDataUtil.getImageMIMEType(fromImageData: ImagePickerTestImages.gifTestData)
        == .gif)
  }

  @Test func suffixFromType() {
    // test jpeg
    #expect(ImagePickerMetaDataUtil.imageTypeSuffix(from: .jpeg) == ".jpg")

    // test png
    #expect(ImagePickerMetaDataUtil.imageTypeSuffix(from: .png) == ".png")

    // test gif
    #expect(ImagePickerMetaDataUtil.imageTypeSuffix(from: .gif) == ".gif")

    // test other
    #expect(ImagePickerMetaDataUtil.imageTypeSuffix(from: .other) == nil)
  }

  @Test func getMetaData() throws {
    let metaData = ImagePickerMetaDataUtil.getMetaData(
      fromImageData: ImagePickerTestImages.jpgTestData)
    let exif = try #require(
      metaData?[kCGImagePropertyExifDictionary as String] as? [AnyHashable: Any])
    let pixelXDimension = exif[kCGImagePropertyExifPixelXDimension as String] as? NSNumber
    #expect(pixelXDimension?.intValue == 12)
  }

  @Test func writeMetaData() throws {
    let dataJPG = ImagePickerTestImages.jpgTestData

    let metaData = try #require(ImagePickerMetaDataUtil.getMetaData(fromImageData: dataJPG))
    let tmpFile = "image_picker_test.jpg"
    let tmpDirectory = NSTemporaryDirectory()
    let tmpPath = (tmpDirectory as NSString).appendingPathComponent(tmpFile)
    let newData = try #require(ImagePickerMetaDataUtil.image(from: dataJPG, withMetaData: metaData))
    #expect(FileManager.default.createFile(atPath: tmpPath, contents: newData, attributes: nil))

    let savedTmpImageData = try Data(contentsOf: URL(fileURLWithPath: tmpPath))
    let tmpMetaData = try #require(
      ImagePickerMetaDataUtil.getMetaData(fromImageData: savedTmpImageData))
    #expect((tmpMetaData as NSDictionary).isEqual(to: metaData))
  }

  @Test func updateMetaDataBadData() {
    let imageData = Data()

    let metaData = ImagePickerMetaDataUtil.getMetaData(fromImageData: imageData)
    let newData = ImagePickerMetaDataUtil.image(from: imageData, withMetaData: metaData ?? [:])
    #expect(newData == nil)
  }

  @Test func convertImageToData() throws {
    let imageJPG = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    let convertedDataJPG = ImagePickerMetaDataUtil.convertImage(
      imageJPG, usingType: .jpeg, quality: NSNumber(value: 0.5))
    #expect(ImagePickerMetaDataUtil.getImageMIMEType(fromImageData: convertedDataJPG) == .jpeg)

    let convertedDataPNG = ImagePickerMetaDataUtil.convertImage(
      imageJPG, usingType: .png, quality: nil)
    #expect(ImagePickerMetaDataUtil.getImageMIMEType(fromImageData: convertedDataPNG) == .png)
  }
}
