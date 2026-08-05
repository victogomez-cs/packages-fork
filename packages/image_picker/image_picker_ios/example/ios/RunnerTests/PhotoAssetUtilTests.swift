// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import ImageIO
import Testing
import UIKit

@testable import image_picker_ios

@MainActor
struct PhotoAssetUtilTests {
  @Test func getAssetFromImagePickerInfoShouldReturnNilIfNotAvailable() {
    #expect(ImagePickerPhotoAssetUtil.getAsset(fromImagePickerInfo: [:]) == nil)
  }

  @Test func saveImageWithOriginalImageDataShouldSaveWithTheCorrectExtensionAndMetaData() throws {
    // test jpg
    let dataJPG = ImagePickerTestImages.jpgTestData
    let imageJPG = try #require(UIImage(data: dataJPG))
    let savedPathJPG = ImagePickerPhotoAssetUtil.saveImageWithOriginalImageData(
      dataJPG,
      image: imageJPG,
      maxWidth: nil,
      maxHeight: nil,
      imageQuality: nil)
    #expect(URL(string: savedPathJPG)?.pathExtension == "jpg")

    let originalMetaDataJPG = ImagePickerMetaDataUtil.getMetaData(fromImageData: dataJPG)
    let newDataJPG = try Data(contentsOf: URL(fileURLWithPath: savedPathJPG))
    let newMetaDataJPG = ImagePickerMetaDataUtil.getMetaData(fromImageData: newDataJPG)
    #expect(
      originalMetaDataJPG?["ProfileName"] as? String == newMetaDataJPG?["ProfileName"] as? String)

    // test png
    let dataPNG = ImagePickerTestImages.pngTestData
    let imagePNG = try #require(UIImage(data: dataPNG))
    let savedPathPNG = ImagePickerPhotoAssetUtil.saveImageWithOriginalImageData(
      dataPNG,
      image: imagePNG,
      maxWidth: nil,
      maxHeight: nil,
      imageQuality: nil)
    #expect(URL(string: savedPathPNG)?.pathExtension == "png")

    let originalMetaDataPNG = ImagePickerMetaDataUtil.getMetaData(fromImageData: dataPNG)
    let newDataPNG = try Data(contentsOf: URL(fileURLWithPath: savedPathPNG))
    let newMetaDataPNG = ImagePickerMetaDataUtil.getMetaData(fromImageData: newDataPNG)
    #expect(
      originalMetaDataPNG?["ProfileName"] as? String == newMetaDataPNG?["ProfileName"] as? String)
  }

  @Test func saveImageWithPickerInfoShouldSaveWithDefaultExtension() throws {
    let imageJPG = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    let savedPathJPG = ImagePickerPhotoAssetUtil.saveImageWithPickerInfo(
      nil, image: imageJPG, imageQuality: nil)
    #expect(savedPathJPG.hasSuffix(kImagePickerDefaultSuffix))
  }

  @Test func saveImageWithPickerInfoShouldSaveWithTheCorrectExtensionAndMetaData() throws {
    let dummyInfo: [UIImagePickerController.InfoKey: Any] = [
      .mediaMetadata: [
        kCGImagePropertyExifDictionary as String: [
          kCGImagePropertyExifUserComment as String: "aNote"
        ]
      ]
    ]
    let imageJPG = try #require(UIImage(data: ImagePickerTestImages.jpgTestData))
    let savedPathJPG = ImagePickerPhotoAssetUtil.saveImageWithPickerInfo(
      dummyInfo, image: imageJPG, imageQuality: nil)
    let data = try Data(contentsOf: URL(fileURLWithPath: savedPathJPG))
    let meta = ImagePickerMetaDataUtil.getMetaData(fromImageData: data)
    let exif = try #require(meta?[kCGImagePropertyExifDictionary as String] as? [AnyHashable: Any])
    #expect(exif[kCGImagePropertyExifUserComment as String] as? String == "aNote")
  }

  @Test func saveImageWithOriginalImageDataShouldSaveAsGifAnimation() throws {
    // test gif
    let dataGIF = ImagePickerTestImages.gifTestData
    let imageGIF = try #require(UIImage(data: dataGIF))
    let imageSource = try #require(CGImageSourceCreateWithData(dataGIF as CFData, nil))

    let numberOfFrames = CGImageSourceGetCount(imageSource)

    let savedPathGIF = ImagePickerPhotoAssetUtil.saveImageWithOriginalImageData(
      dataGIF,
      image: imageGIF,
      maxWidth: nil,
      maxHeight: nil,
      imageQuality: nil)
    #expect(URL(string: savedPathGIF)?.pathExtension == "gif")

    let newDataGIF = try Data(contentsOf: URL(fileURLWithPath: savedPathGIF))
    let newImageSource = try #require(CGImageSourceCreateWithData(newDataGIF as CFData, nil))
    let newNumberOfFrames = CGImageSourceGetCount(newImageSource)

    #expect(numberOfFrames == newNumberOfFrames)
  }

  @Test func saveImageWithOriginalImageDataShouldSaveAsScaledGifAnimation() throws {
    // test gif
    let dataGIF = ImagePickerTestImages.gifTestData
    let imageGIF = try #require(UIImage(data: dataGIF))

    let imageSource = try #require(CGImageSourceCreateWithData(dataGIF as CFData, nil))
    let numberOfFrames = CGImageSourceGetCount(imageSource)

    let savedPathGIF = ImagePickerPhotoAssetUtil.saveImageWithOriginalImageData(
      dataGIF,
      image: imageGIF,
      maxWidth: NSNumber(value: 3),
      maxHeight: NSNumber(value: 2),
      imageQuality: nil)
    let newDataGIF = try Data(contentsOf: URL(fileURLWithPath: savedPathGIF))
    let newImage = try #require(UIImage(data: newDataGIF))

    #expect(newImage.size.width == 3)
    #expect(newImage.size.height == 2)

    let newImageSource = try #require(CGImageSourceCreateWithData(newDataGIF as CFData, nil))
    let newNumberOfFrames = CGImageSourceGetCount(newImageSource)

    #expect(numberOfFrames == newNumberOfFrames)
  }
}
