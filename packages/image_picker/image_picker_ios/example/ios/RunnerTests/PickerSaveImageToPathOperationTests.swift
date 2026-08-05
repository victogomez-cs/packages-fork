// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import ImageIO
import Photos
import PhotosUI
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import image_picker_ios

struct PickerSaveImageToPathOperationTests {
  @available(iOS 14.0, *)
  @Test func saveWebPImage() async throws {
    let result = try pickerResult(forResource: "webpImage", withExtension: "webp")

    await verifySavingImage(with: result, fullMetadata: true, extension: "jpg")
  }

  @available(iOS 14.0, *)
  @Test func savePNGImage() async throws {
    let result = try pickerResult(forResource: "pngImage", withExtension: "png")

    await verifySavingImage(with: result, fullMetadata: true, extension: "png")
  }

  @available(iOS 14.0, *)
  @Test func saveJPGImage() async throws {
    let result = try pickerResult(forResource: "jpgImage", withExtension: "jpg")

    await verifySavingImage(with: result, fullMetadata: true, extension: "jpg")
  }

  @available(iOS 14.0, *)
  @Test func saveGIFImage() async throws {
    let imageURL = try #require(
      ImagePickerTestBundle.bundle.url(forResource: "gifImage", withExtension: "gif"))
    let itemProvider = try #require(NSItemProvider(contentsOf: imageURL))
    let result = pickerResult(with: itemProvider)

    let dataGIF = try Data(contentsOf: imageURL)
    let imageSource = try #require(CGImageSourceCreateWithData(dataGIF as CFData, nil))
    let numberOfFrames = CGImageSourceGetCount(imageSource)

    var operation: PHPickerSaveImageToPathOperation?
    await confirmation("Path was created") { pathCreated in
      await confirmation("Operation completed") { operationCompleted in
        operation = PHPickerSaveImageToPathOperation(
          result: result,
          maxHeight: NSNumber(value: 100),
          maxWidth: NSNumber(value: 100),
          desiredImageQuality: NSNumber(value: 100),
          fullMetadata: false,
          savedPathBlock: { savedPath, _ in
            let savedPath = savedPath ?? ""
            #expect(FileManager.default.fileExists(atPath: savedPath))

            // Ensure gif is animated.
            #expect(URL(string: savedPath)?.pathExtension == "gif")
            if let newDataGIF = try? Data(contentsOf: URL(fileURLWithPath: savedPath)),
              let newImageSource = CGImageSourceCreateWithData(newDataGIF as CFData, nil)
            {
              #expect(numberOfFrames == CGImageSourceGetCount(newImageSource))
            } else {
              Issue.record("Could not read the saved gif")
            }
            pathCreated()
          })
        guard let operation else {
          Issue.record("Failed to create the save operation")
          return
        }
        await runToCompletion(operation) { operationCompleted() }
      }
    }
    #expect(operation?.isFinished == true)
  }

  @available(iOS 14.0, *)
  @Test func saveBMPImage() async throws {
    let result = try pickerResult(forResource: "bmpImage", withExtension: "bmp")

    await verifySavingImage(with: result, fullMetadata: true, extension: "jpg")
  }

  @available(iOS 14.0, *)
  @Test func saveHEICImage() async throws {
    let result = try pickerResult(forResource: "heicImage", withExtension: "heic")

    await verifySavingImage(with: result, fullMetadata: true, extension: "jpg")
  }

  @available(iOS 14.0, *)
  @Test func saveWithOrientation() async throws {
    let result = try pickerResult(
      forResource: "jpgImageWithRightOrientation", withExtension: "jpg")

    var operation: PHPickerSaveImageToPathOperation?
    await confirmation("Path was created") { pathCreated in
      await confirmation("Operation completed") { operationCompleted in
        operation = PHPickerSaveImageToPathOperation(
          result: result,
          maxHeight: NSNumber(value: 10),
          maxWidth: NSNumber(value: 10),
          desiredImageQuality: NSNumber(value: 100),
          fullMetadata: false,
          savedPathBlock: { savedPath, _ in
            let savedPath = savedPath ?? ""
            #expect(FileManager.default.fileExists(atPath: savedPath))

            // Ensure image retained it's orientation data.
            #expect(URL(string: savedPath)?.pathExtension == "jpg")
            if let image = UIImage(contentsOfFile: savedPath) {
              #expect(image.imageOrientation == .right)
              #expect(image.size.width == 7)
              #expect(image.size.height == 10)
            } else {
              Issue.record("Could not read the saved image")
            }
            pathCreated()
          })
        guard let operation else {
          Issue.record("Failed to create the save operation")
          return
        }
        await runToCompletion(operation) { operationCompleted() }
      }
    }
    #expect(operation?.isFinished == true)
  }

  @available(iOS 14.0, *)
  @Test func saveICNSImage() async throws {
    let result = try pickerResult(forResource: "icnsImage", withExtension: "icns")

    await verifySavingImage(with: result, fullMetadata: true, extension: "jpg")
  }

  @available(iOS 14.0, *)
  @Test func saveICOImage() async throws {
    let result = try pickerResult(forResource: "icoImage", withExtension: "ico")

    await verifySavingImage(with: result, fullMetadata: true, extension: "jpg")
  }

  @available(iOS 14.0, *)
  @Test func saveProRAWImage() async throws {
    let result = try pickerResult(forResource: "proRawImage", withExtension: "dng")

    await verifySavingImage(with: result, fullMetadata: true, extension: "jpg")
  }

  @available(iOS 14.0, *)
  @Test func saveTIFFImage() async throws {
    let result = try pickerResult(forResource: "tiffImage", withExtension: "tiff")

    await verifySavingImage(with: result, fullMetadata: true, extension: "jpg")
  }

  @available(iOS 14.0, *)
  @Test func nonexistentImage() async throws {
    let imageURL = ImagePickerTestBundle.bundle.url(forResource: "bogus", withExtension: "png")
    // A provider for a nonexistent file has no registered types, so it matches no media type.
    let itemProvider = imageURL.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
    let result = pickerResult(with: itemProvider)

    await confirmation("invalid source error") { errorReported in
      guard
        let operation = PHPickerSaveImageToPathOperation(
          result: result,
          maxHeight: NSNumber(value: 100),
          maxWidth: NSNumber(value: 100),
          desiredImageQuality: NSNumber(value: 100),
          fullMetadata: true,
          savedPathBlock: { _, error in
            #expect(error?.code == "invalid_source")
            errorReported()
          })
      else {
        Issue.record("Failed to create the save operation")
        return
      }
      await runToCompletion(operation) {}
    }
  }

  @available(iOS 14.0, *)
  @Test func failingImageLoad() async throws {
    let loadDataError = NSError(domain: "PHPickerDomain", code: 1234, userInfo: nil)

    let itemProvider = NSItemProvider()
    itemProvider.registerDataRepresentation(
      forTypeIdentifier: UTType.image.identifier, visibility: .all
    ) { completionHandler in
      completionHandler(nil, loadDataError)
      return nil
    }
    let result = pickerResult(with: itemProvider)

    await confirmation("invalid image error") { errorReported in
      guard
        let operation = PHPickerSaveImageToPathOperation(
          result: result,
          maxHeight: NSNumber(value: 100),
          maxWidth: NSNumber(value: 100),
          desiredImageQuality: NSNumber(value: 100),
          fullMetadata: true,
          savedPathBlock: { _, error in
            // NSItemProvider wraps a loader failure in its own error, so the reported message and
            // details come from that wrapper rather than from loadDataError itself.
            #expect(error?.code == "invalid_image")
            #expect(error?.message?.isEmpty == false)
            #expect((error?.details as? String)?.isEmpty == false)
            errorReported()
          })
      else {
        Issue.record("Failed to create the save operation")
        return
      }
      await runToCompletion(operation) {}
    }
  }

  /// The Swift implementation never consults PHAsset for PHPicker results, so this only validates
  /// that saving still succeeds when full metadata isn't requested.
  @available(iOS 14.0, *)
  @Test func savePNGImageWithoutFullMetadata() async throws {
    let result = try pickerResult(forResource: "pngImage", withExtension: "png")

    await verifySavingImage(with: result, fullMetadata: false, extension: "png")
  }

  // MARK: - Helpers

  /// Returns a picker result backed by the given item provider.
  private func pickerResult(with itemProvider: NSItemProvider) -> PickerResultHandle {
    PickerResultHandle(
      itemProvider: itemProvider,
      assetIdentifier: itemProvider.registeredTypeIdentifiers.first)
  }

  /// Returns a picker result backed by the named test bundle resource.
  private func pickerResult(
    forResource resource: String,
    withExtension fileExtension: String
  ) throws -> PickerResultHandle {
    let imageURL = try #require(
      ImagePickerTestBundle.bundle.url(forResource: resource, withExtension: fileExtension))
    return pickerResult(with: try #require(NSItemProvider(contentsOf: imageURL)))
  }

  /// Validates the saving process of PHPickerSaveImageToPathOperation.
  ///
  /// PHPickerSaveImageToPathOperation is responsible for saving a picked image to the disk for
  /// later use. It is expected that the saving is always successful.
  @available(iOS 14.0, *)
  private func verifySavingImage(
    with result: PickerResultHandle,
    fullMetadata: Bool,
    extension expectedExtension: String
  ) async {
    var operation: PHPickerSaveImageToPathOperation?
    await confirmation("Path was created") { pathCreated in
      await confirmation("Operation completed") { operationCompleted in
        operation = PHPickerSaveImageToPathOperation(
          result: result,
          maxHeight: NSNumber(value: 100),
          maxWidth: NSNumber(value: 100),
          desiredImageQuality: NSNumber(value: 100),
          fullMetadata: fullMetadata,
          savedPathBlock: { savedPath, _ in
            let savedPath = savedPath ?? ""
            #expect(FileManager.default.fileExists(atPath: savedPath))
            #expect(URL(string: savedPath)?.pathExtension == expectedExtension)
            pathCreated()
          })
        guard let operation else {
          Issue.record("Failed to create the save operation")
          return
        }
        await runToCompletion(operation) { operationCompleted() }
      }
    }
    #expect(operation?.isFinished == true)
  }

  /// Starts `operation` and waits for it to finish, calling `onCompletion` from its completion
  /// block.
  private func runToCompletion(
    _ operation: Operation,
    onCompletion: @escaping @Sendable () -> Void
  ) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      operation.completionBlock = {
        onCompletion()
        continuation.resume()
      }
      operation.start()
    }
  }
}
