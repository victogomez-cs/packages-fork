// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// The return handler used by PHPickerSaveImageToPathOperation, called with the path the media was
/// saved to, or an error if saving failed.
typealias GetSavedPath = (String?, PigeonError?) -> Void

/// An operation that saves a single PHPickerResult to a file, scaling and re-encoding images as
/// requested.
@available(iOS 14, *)
final class PHPickerSaveImageToPathOperation: Operation, @unchecked Sendable {
  private let result: PickerResultHandle
  private let maxHeight: NSNumber?
  private let maxWidth: NSNumber?
  private let desiredImageQuality: NSNumber?
  /// Stored to mirror the Obj-C implementation; the PHPicker flow never reads it.
  private let requestFullMetadata: Bool
  private let getSavedPath: GetSavedPath

  private var _executing = false
  private var _finished = false

  init?(
    result: PickerResultHandle,
    maxHeight: NSNumber?,
    maxWidth: NSNumber?,
    desiredImageQuality: NSNumber?,
    fullMetadata: Bool,
    savedPathBlock: @escaping GetSavedPath
  ) {
    self.result = result
    self.maxHeight = maxHeight
    self.maxWidth = maxWidth
    self.desiredImageQuality = desiredImageQuality
    self.requestFullMetadata = fullMetadata
    self.getSavedPath = savedPathBlock
    super.init()
  }

  override var isAsynchronous: Bool {
    return true
  }

  override var isExecuting: Bool {
    return _executing
  }

  override var isFinished: Bool {
    return _finished
  }

  private func setExecuting(_ isExecuting: Bool) {
    willChangeValue(forKey: "isExecuting")
    _executing = isExecuting
    didChangeValue(forKey: "isExecuting")
  }

  private func setFinished(_ isFinished: Bool) {
    willChangeValue(forKey: "isFinished")
    _finished = isFinished
    didChangeValue(forKey: "isFinished")
  }

  private func completeOperation(path savedPath: String?, error: PigeonError?) {
    getSavedPath(savedPath, error)
    setExecuting(false)
    setFinished(true)
  }

  override func start() {
    if isCancelled {
      setFinished(true)
      return
    }

    setExecuting(true)

    // This supports uniform types that conform to UTTypeImage.
    // This includes UTTypeHEIC, UTTypeHEIF, UTTypeLivePhoto, UTTypeICO, UTTypeICNS, UTTypePNG
    // UTTypeGIF, UTTypeJPEG, UTTypeWebP, UTTypeTIFF, UTTypeBMP, UTTypeSVG, UTTypeRAWImage
    if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
      result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
        data, error in
        if let data = data {
          self.processImage(data)
        } else {
          let nsError = error as NSError?
          let flutterError = PigeonError(
            code: "invalid_image",
            message: nsError?.localizedDescription,
            details: nsError?.domain)
          self.completeOperation(path: nil, error: flutterError)
        }
      }
    } else if result.itemProvider.hasItemConformingToTypeIdentifier(
      // This supports uniform types that conform to UTTypeMovie.
      // This includes kUTTypeVideo, kUTTypeMPEG4, public.3gpp, kUTTypeMPEG,
      // public.3gpp2, public.avi, kUTTypeQuickTimeMovie.
      UTType.movie.identifier)
    {
      processVideo()
    } else {
      let flutterError = PigeonError(
        code: "invalid_source",
        message: "Invalid media source.",
        details: nil)
      completeOperation(path: nil, error: flutterError)
    }
  }

  /// Processes the image.
  private func processImage(_ pickerImageData: Data) {
    var localImage = UIImage(data: pickerImageData)

    if maxWidth != nil || maxHeight != nil {
      localImage = ImagePickerImageUtil.scaledImage(
        localImage,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        isMetadataAvailable: true)
    }
    // maxWidth and maxHeight are used only for GIF images.
    let savedPath = ImagePickerPhotoAssetUtil.saveImageWithOriginalImageData(
      pickerImageData,
      image: localImage ?? UIImage(),
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: desiredImageQuality)
    completeOperation(path: savedPath, error: nil)
  }

  /// Processes the video.
  private func processVideo() {
    let typeIdentifier = result.itemProvider.registeredTypeIdentifiers.first ?? ""
    result.itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) {
      videoURL, error in
      if let error = error {
        let nsError = error as NSError
        let flutterError = PigeonError(
          code: "invalid_image",
          message: nsError.localizedDescription,
          details: nsError.domain)
        self.completeOperation(path: nil, error: flutterError)
        return
      }

      guard let videoURL = videoURL,
        let destination = ImagePickerPhotoAssetUtil.saveVideo(from: videoURL)
      else {
        self.completeOperation(
          path: nil,
          error: PigeonError(
            code: "flutter_image_picker_copy_video_error",
            message: "Could not cache the video file.",
            details: nil))
        return
      }

      self.completeOperation(path: destination.path, error: nil)
    }
  }
}
