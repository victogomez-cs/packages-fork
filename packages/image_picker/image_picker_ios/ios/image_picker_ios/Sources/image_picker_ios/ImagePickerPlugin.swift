// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import Flutter
import MobileCoreServices
import ObjectiveC
import Photos
import PhotosUI
import UIKit

/// The return handler used for all method calls, which internally adapts the provided result list
/// to return either a list or a single element depending on the original call.
typealias FlutterResultAdapter = ([String]?, Error?) -> Void

/// A container class for context to use when handling a method call from the Dart side.
final class ImagePickerMethodCallContext {
  /// The callback to provide results to the Dart caller.
  var result: FlutterResultAdapter

  /// The maximum size to enforce on the results.
  ///
  /// If nil, no resizing is done.
  var maxSize: MaxSize?

  /// The image quality to resample the results to.
  ///
  /// If nil, no resampling is done.
  var imageQuality: NSNumber?

  /// Maximum number of items to select. 0 indicates no maximum.
  var maxItemCount: Int = 0

  /// Whether the image should be picked with full metadata (requires gallery permissions).
  var requestFullMetadata: Bool = false

  /// Maximum duration for videos. 0 indicates no maximum.
  var maxDuration: TimeInterval = 0

  /// Whether the picker should include images in the list.
  var includeImages: Bool = false

  /// Whether the picker should include videos in the list.
  var includeVideo: Bool = false

  /// Initializes a new context that calls |result| on completion of the operation.
  init(result: @escaping FlutterResultAdapter) {
    self.result = result
  }
}

/// Mutable state shared by the individual save operations and the operation that returns the
/// final list to Dart.
private final class PickerSaveState {
  /// The saved paths, in selection order. NSNull means the item hasn't saved yet.
  var pathList: [Any]
  var saveError: Error?

  init(count: Int) {
    pathList = Array(repeating: NSNull(), count: count)
  }
}

public class ImagePickerPlugin: NSObject, FlutterPlugin, ImagePickerApi {
  /// The context of the Flutter method call that is currently being handled, if any.
  var callContext: ImagePickerMethodCallContext?

  /// A temporary UIWindow placed above Flutter's window to swallow all user
  /// interactions while UIImagePickerController is dismissing. This prevents
  /// stray taps from leaking to the Flutter view during the dismissal animation.
  var interactionBlockerWindow: UIWindow?

  /// The previously active key window before the interactionBlockerWindow is
  /// shown. Stored so we can restore the original key window after dismissal.
  weak var previousKeyWindow: UIWindow?

  /// A PHPickerViewControllerCreating to use instead of the default factory.
  ///
  /// Typed as Any? because PHPickerViewControllerCreating is only available on iOS 14+, and stored
  /// properties can't be annotated with availability.
  var phPickerFactoryOverride: Any?

  /// The UIImagePickerController instances that will be used when a new
  /// controller would normally be created. Each call to
  /// createImagePickerController will remove the current first element from
  /// the array.
  private var imagePickerControllerOverrides: [UIImagePickerController]?

  /// The view provider to use for displaying native view controllers.
  private let viewProvider: ViewProvider
  private let cameraPermissionChecker: CameraPermissionChecking
  private let photoLibraryPermissionChecker: PhotoLibraryPermissionChecking
  private let capabilityChecker: ImagePickerCapabilityChecking

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ImagePickerPlugin(viewProvider: DefaultViewProvider(registrar: registrar))
    ImagePickerApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  init(
    viewProvider: ViewProvider,
    cameraPermissionChecker: CameraPermissionChecking = DefaultCameraPermissionChecker(),
    photoLibraryPermissionChecker: PhotoLibraryPermissionChecking =
      DefaultPhotoLibraryPermissionChecker(),
    capabilityChecker: ImagePickerCapabilityChecking = DefaultImagePickerCapabilityChecker()
  ) {
    self.viewProvider = viewProvider
    self.cameraPermissionChecker = cameraPermissionChecker
    self.photoLibraryPermissionChecker = photoLibraryPermissionChecker
    self.capabilityChecker = capabilityChecker
    super.init()
  }

  private func createImagePickerController() -> UIImagePickerController {
    if let controller = imagePickerControllerOverrides?.first {
      imagePickerControllerOverrides?.removeFirst()
      return controller
    }

    return UIImagePickerController()
  }

  /// Sets UIImagePickerController instances that will be used when a new
  /// controller would normally be created. Each call to
  /// createImagePickerController will remove the current first element from
  /// the array.
  ///
  /// Should be used for testing purposes only.
  func setImagePickerControllerOverrides(_ imagePickerControllers: [UIImagePickerController]) {
    imagePickerControllerOverrides = imagePickerControllers
  }

  /// Returns the UIImagePickerControllerCameraDevice to use given [source].
  ///
  /// - Parameter source: The source specification from Dart.
  private func cameraDevice(for source: SourceSpecification)
    -> UIImagePickerController.CameraDevice
  {
    switch source.camera {
    case .front:
      return .front
    case .rear:
      return .rear
    }
  }

  @available(iOS 14, *)
  private func launchPHPicker(context: ImagePickerMethodCallContext) {
    var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
    config.selectionLimit = context.maxItemCount
    config.preferredAssetRepresentationMode = .current
    var filters: [PHPickerFilter] = []
    if context.includeImages {
      filters.append(.images)
    }
    if context.includeVideo {
      filters.append(.videos)
    }
    config.filter = PHPickerFilter.any(of: filters)

    let factory =
      (phPickerFactoryOverride as? PHPickerViewControllerCreating)
      ?? DefaultPHPickerViewControllerFactory()
    let pickerViewController = factory.makePicker(configuration: config)
    pickerViewController.delegate = self
    pickerViewController.presentationController?.delegate = self
    callContext = context

    showPhotoLibrary(phPicker: pickerViewController)
  }

  private func launchUIImagePicker(
    source: SourceSpecification,
    context: ImagePickerMethodCallContext
  ) {
    let imagePickerController = createImagePickerController()
    imagePickerController.modalPresentationStyle = .currentContext
    imagePickerController.delegate = self
    var mediaTypes: [String] = []
    if context.includeImages {
      mediaTypes.append(kUTTypeImage as String)
    }
    if context.includeVideo {
      mediaTypes.append(kUTTypeMovie as String)
      imagePickerController.videoQuality = .typeHigh
    }
    imagePickerController.mediaTypes = mediaTypes
    if context.maxDuration != 0.0 {
      imagePickerController.videoMaximumDuration = context.maxDuration
    }

    callContext = context

    switch source.type {
    case .camera:
      checkCameraAuthorization(
        imagePicker: imagePickerController, camera: cameraDevice(for: source))
    case .gallery:
      if context.requestFullMetadata {
        checkPhotoAuthorization(imagePicker: imagePickerController)
      } else {
        showPhotoLibrary(imagePicker: imagePickerController)
      }
    }
  }

  // MARK: - ImagePickerApi

  func pickImage(
    source: SourceSpecification,
    maxSize: MaxSize,
    imageQuality: Int64?,
    requestFullMetadata: Bool,
    completion: @escaping (Result<String?, Error>) -> Void
  ) {
    cancelInProgressCall()
    // Matches Obj-C: when paths.count > 1, fires invalid_result and then still
    // invokes completion a second time with the first path / error.
    let context = ImagePickerMethodCallContext { paths, error in
      if let paths = paths, paths.count > 1 {
        completion(
          .failure(
            PigeonError(
              code: "invalid_result",
              message: "Incorrect number of return paths provided",
              details: nil)))
      }
      if let error = error {
        completion(.failure(error))
      } else {
        completion(.success(paths?.first))
      }
    }
    context.includeImages = true
    context.maxSize = maxSize
    context.imageQuality = imageQuality.map { NSNumber(value: $0) }
    context.maxItemCount = 1
    context.requestFullMetadata = requestFullMetadata

    if source.type == .gallery {  // Capture is not possible with PHPicker
      if #available(iOS 14, *) {
        launchPHPicker(context: context)
      } else {
        launchUIImagePicker(source: source, context: context)
      }
    } else {
      launchUIImagePicker(source: source, context: context)
    }
  }

  func pickMultiImage(
    maxSize: MaxSize,
    imageQuality: Int64?,
    requestFullMetadata: Bool,
    limit: Int64?,
    completion: @escaping (Result<[String], Error>) -> Void
  ) {
    cancelInProgressCall()
    let context = ImagePickerMethodCallContext(result: listResultAdapter(for: completion))
    context.includeImages = true
    context.maxSize = maxSize
    context.imageQuality = imageQuality.map { NSNumber(value: $0) }
    context.requestFullMetadata = requestFullMetadata
    context.maxItemCount = Int(limit ?? 0)

    if #available(iOS 14, *) {
      launchPHPicker(context: context)
    } else {
      // Camera is ignored for gallery mode, so the value here is arbitrary.
      launchUIImagePicker(
        source: SourceSpecification(type: .gallery, camera: .rear), context: context)
    }
  }

  /// Selects images and videos and returns their paths.
  func pickMedia(
    mediaSelectionOptions: MediaSelectionOptions,
    completion: @escaping (Result<[String], Error>) -> Void
  ) {
    cancelInProgressCall()
    let context = ImagePickerMethodCallContext(result: listResultAdapter(for: completion))
    context.maxSize = mediaSelectionOptions.maxSize
    context.imageQuality = mediaSelectionOptions.imageQuality.map { NSNumber(value: $0) }
    context.requestFullMetadata = mediaSelectionOptions.requestFullMetadata
    context.includeImages = true
    context.includeVideo = true
    let limit = mediaSelectionOptions.limit
    if !mediaSelectionOptions.allowMultiple {
      context.maxItemCount = 1
    } else if let limit = limit {
      context.maxItemCount = Int(limit)
    }

    if #available(iOS 14, *) {
      launchPHPicker(context: context)
    } else {
      // Camera is ignored for gallery mode, so the value here is arbitrary.
      launchUIImagePicker(
        source: SourceSpecification(type: .gallery, camera: .rear), context: context)
    }
  }

  func pickVideo(
    source: SourceSpecification,
    maxDurationSeconds: Int64?,
    completion: @escaping (Result<String?, Error>) -> Void
  ) {
    cancelInProgressCall()
    let context = ImagePickerMethodCallContext { paths, error in
      if let paths = paths, paths.count > 1 {
        completion(
          .failure(
            PigeonError(
              code: "invalid_result",
              message: "Incorrect number of return paths provided",
              details: nil)))
      }
      if let error = error {
        completion(.failure(error))
      } else {
        completion(.success(paths?.first))
      }
    }
    context.includeVideo = true
    context.maxItemCount = 1
    context.maxDuration = TimeInterval(maxDurationSeconds ?? 0)

    if source.type == .gallery {  // Capture is not possible with PHPicker
      if #available(iOS 14, *) {
        launchPHPicker(context: context)
      } else {
        launchUIImagePicker(source: source, context: context)
      }
    } else {
      launchUIImagePicker(source: source, context: context)
    }
  }

  func pickMultiVideo(
    maxDurationSeconds: Int64?,
    limit: Int64?,
    completion: @escaping (Result<[String], Error>) -> Void
  ) {
    cancelInProgressCall()
    let context = ImagePickerMethodCallContext(result: listResultAdapter(for: completion))
    context.includeVideo = true
    context.maxItemCount = Int(limit ?? 0)
    context.maxDuration = TimeInterval(maxDurationSeconds ?? 0)

    if #available(iOS 14, *) {
      launchPHPicker(context: context)
    } else {
      // Camera is ignored for gallery mode, so the value here is arbitrary.
      launchUIImagePicker(
        source: SourceSpecification(type: .gallery, camera: .rear), context: context)
    }
  }

  // MARK: -

  /// Returns an adapter that forwards a path list, or an error, to a Pigeon list completion.
  private func listResultAdapter(
    for completion: @escaping (Result<[String], Error>) -> Void
  ) -> FlutterResultAdapter {
    return { paths, error in
      if let error = error {
        completion(.failure(error))
      } else {
        completion(.success(paths ?? []))
      }
    }
  }

  /// If a call is still in progress, cancels it by returning an error and then clearing state.
  ///
  /// TODO(stuartmorgan): Eliminate this, and instead track context per image picker (e.g., using
  /// associated objects).
  private func cancelInProgressCall() {
    if callContext != nil {
      sendCallResultWithError(
        PigeonError(
          code: "multiple_request",
          message: "Cancelled by a second request",
          details: nil))
      callContext = nil
    }
  }

  private func showCamera(
    _ device: UIImagePickerController.CameraDevice,
    imagePicker imagePickerController: UIImagePickerController
  ) {
    objc_sync_enter(self)
    let isBeingPresented = imagePickerController.isBeingPresented
    objc_sync_exit(self)
    if isBeingPresented {
      return
    }

    // Camera is not available on simulators
    if capabilityChecker.isSourceTypeAvailable(.camera)
      && capabilityChecker.isCameraDeviceAvailable(device)
    {
      imagePickerController.sourceType = .camera
      imagePickerController.cameraDevice = device
      let presentingController = presentingViewControllerForImagePickerInNewWindow()
      presentingController?.present(imagePickerController, animated: true, completion: nil)
    } else {
      let cameraErrorAlert = UIAlertController(
        title: NSLocalizedString("Error", comment: "Alert title when camera unavailable"),
        message: NSLocalizedString(
          "Camera not available.", comment: "Alert message when camera unavailable"),
        preferredStyle: .alert)
      cameraErrorAlert.addAction(
        UIAlertAction(
          title: NSLocalizedString("OK", comment: "Alert button when camera unavailable"),
          style: .default
        ) { _ in
        })
      viewProvider.viewController?.present(cameraErrorAlert, animated: true, completion: nil)
      sendCallResultWithSavedPathList(nil)
    }
  }

  private func checkCameraAuthorization(
    imagePicker imagePickerController: UIImagePickerController,
    camera device: UIImagePickerController.CameraDevice
  ) {
    let status = cameraPermissionChecker.authorizationStatus(for: .video)

    switch status {
    case .authorized:
      showCamera(device, imagePicker: imagePickerController)
    case .notDetermined:
      // The completion handler is @Sendable, but everything it touches is only ever used from
      // the main queue, which it immediately hops back to.
      nonisolated(unsafe) let plugin = self
      cameraPermissionChecker.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          if granted {
            plugin.showCamera(device, imagePicker: imagePickerController)
          } else {
            plugin.errorNoCameraAccess(.denied)
          }
        }
      }
    default:
      errorNoCameraAccess(status)
    }
  }

  private func checkPhotoAuthorization(imagePicker imagePickerController: UIImagePickerController) {
    let status = photoLibraryPermissionChecker.authorizationStatus()
    switch status {
    case .notDetermined:
      photoLibraryPermissionChecker.requestAuthorization { status in
        DispatchQueue.main.async {
          if status == .authorized {
            self.showPhotoLibrary(imagePicker: imagePickerController)
          } else {
            self.errorNoPhotoAccess(status)
          }
        }
      }
    case .authorized:
      showPhotoLibrary(imagePicker: imagePickerController)
    default:
      errorNoPhotoAccess(status)
    }
  }

  private func errorNoCameraAccess(_ status: AVAuthorizationStatus) {
    switch status {
    case .restricted:
      sendCallResultWithError(
        PigeonError(
          code: "camera_access_restricted",
          message: "The user is not allowed to use the camera.",
          details: nil))
    default:
      sendCallResultWithError(
        PigeonError(
          code: "camera_access_denied",
          message: "The user did not allow camera access.",
          details: nil))
    }
  }

  private func errorNoPhotoAccess(_ status: PHAuthorizationStatus) {
    switch status {
    case .restricted:
      sendCallResultWithError(
        PigeonError(
          code: "photo_access_restricted",
          message: "The user is not allowed to use the photo.",
          details: nil))
    default:
      sendCallResultWithError(
        PigeonError(
          code: "photo_access_denied",
          message: "The user did not allow photo access.",
          details: nil))
    }
  }

  @available(iOS 14, *)
  private func showPhotoLibrary(phPicker pickerViewController: PHPickerViewController) {
    viewProvider.viewController?.present(pickerViewController, animated: true, completion: nil)
  }

  private func showPhotoLibrary(imagePicker imagePickerController: UIImagePickerController) {
    imagePickerController.sourceType = .photoLibrary
    viewProvider.viewController?.present(imagePickerController, animated: true, completion: nil)
  }

  private func getDesiredImageQuality(_ imageQuality: NSNumber?) -> NSNumber {
    guard let imageQuality = imageQuality else {
      return NSNumber(value: 1)
    }
    if imageQuality.intValue < 0 || imageQuality.intValue > 100 {
      return NSNumber(value: 1)
    }
    return NSNumber(value: imageQuality.floatValue / 100)
  }

  // MARK: -

  private func saveImage(
    withOriginalImageData originalImageData: Data?,
    image: UIImage?,
    maxWidth: NSNumber?,
    maxHeight: NSNumber?,
    imageQuality: NSNumber?
  ) {
    let savedPath = ImagePickerPhotoAssetUtil.saveImageWithOriginalImageData(
      originalImageData,
      image: image ?? UIImage(),
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality)
    sendCallResultWithSavedPathList([savedPath])
  }

  private func saveImage(
    withPickerInfo info: [UIImagePickerController.InfoKey: Any]?,
    image: UIImage?,
    imageQuality: NSNumber?
  ) {
    let savedPath = ImagePickerPhotoAssetUtil.saveImageWithPickerInfo(
      info,
      image: image ?? UIImage(),
      imageQuality: imageQuality)
    sendCallResultWithSavedPathList([savedPath])
  }

  /// Validates the provided paths list, then sends it via `callContext.result` as the result of
  /// the original platform channel method call, clearing the in-progress call state.
  ///
  /// - Parameter pathList: The paths to return. nil indicates a cancelled operation.
  func sendCallResultWithSavedPathList(_ pathList: [Any]?) {
    guard let callContext = callContext else {
      return
    }

    if let pathList = pathList, pathList.contains(where: { $0 is NSNull }) {
      callContext.result(
        nil,
        PigeonError(
          code: "create_error",
          message: "pathList's items should not be null",
          details: nil))
    } else {
      callContext.result(pathList?.compactMap { $0 as? String } ?? [], nil)
    }
    self.callContext = nil
  }

  /// Sends the given error via `callContext.result` as the result of the original platform channel
  /// method call, clearing the in-progress call state.
  ///
  /// - Parameter error: The error to return.
  private func sendCallResultWithError(_ error: Error) {
    guard let callContext = callContext else {
      return
    }
    callContext.result(nil, error)
    self.callContext = nil
  }

  /// Why a separate UIWindow for the interaction blocker?
  /// Flutter renders inside a UIWindow owned by FlutterViewController. UIImagePickerController is
  /// presented in that same window and dismisses with an animation; during that brief transition,
  /// taps can “leak” to the Flutter view underneath.
  ///
  /// A view-based blocker (added to the host view hierarchy) isn’t reliable because the host
  /// view’s bounds/constraints/rotation/transitions can change during presentation/dismissal,
  /// causing the blocker to move or be removed.
  ///
  /// Instead we create a dedicated UIWindow (windowLevel + 1) with its own root VC to swallow all
  /// touches during the dismissal window, then restore the previous key window afterward.
  /// The image picker is presented on this blocker window so it appears above everything.
  ///
  /// - Returns: The view controller that should be used to present the image picker.
  private func presentingViewControllerForImagePickerInNewWindow() -> UIViewController? {
    if let interactionBlockerWindow = interactionBlockerWindow {
      return interactionBlockerWindow.rootViewController
    }
    let topController = viewProvider.viewController
    guard let presentingWindow = topController?.view.window else {
      return topController
    }
    previousKeyWindow = presentingWindow
    let blockerWindow: UIWindow
    if let windowScene = presentingWindow.windowScene {
      blockerWindow = UIWindow(windowScene: windowScene)
    } else {
      blockerWindow = UIWindow(frame: presentingWindow.bounds)
    }
    blockerWindow.frame = presentingWindow.bounds
    blockerWindow.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blockerWindow.windowLevel = UIWindow.Level(presentingWindow.windowLevel.rawValue + 1)
    let viewController = UIViewController()
    viewController.view.backgroundColor = .clear
    viewController.view.isUserInteractionEnabled = true
    blockerWindow.rootViewController = viewController
    blockerWindow.makeKeyAndVisible()
    interactionBlockerWindow = blockerWindow
    return viewController
  }

  /// Removes the temporary interaction-blocking window and restores the previous
  /// key window. This is called after UIImagePickerController has fully dismissed,
  /// once it is safe for Flutter to receive user input again.
  func removeInteractionBlocker() {
    guard let interactionBlockerWindow = interactionBlockerWindow else {
      return
    }
    interactionBlockerWindow.isHidden = true
    previousKeyWindow?.makeKey()
    self.interactionBlockerWindow = nil
    previousKeyWindow = nil
  }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension ImagePickerPlugin: UIAdaptivePresentationControllerDelegate {
  public func presentationControllerDidDismiss(
    _ presentationController: UIPresentationController
  ) {
    sendCallResultWithSavedPathList(nil)
  }
}

// MARK: - PHPickerViewControllerDelegate

@available(iOS 14, *)
extension ImagePickerPlugin: PHPickerViewControllerDelegate {
  public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    didFinishPicking(results: results.map { PickerResultHandle($0) }, dismissing: picker)
  }

  /// Saves each picked item and returns the resulting paths to Dart, dismissing `picker` first if
  /// it is non-nil.
  ///
  /// Separate from the delegate method above so that tests can supply results without a
  /// PHPickerResult, which cannot be constructed outside of PhotosUI.
  func didFinishPicking(results: [PickerResultHandle], dismissing picker: UIViewController?) {
    picker?.dismiss(animated: true, completion: nil)
    if results.isEmpty {
      sendCallResultWithSavedPathList(nil)
      return
    }
    var saveQueue: OperationQueue? = OperationQueue()
    saveQueue?.name = "Flutter Save Image Queue"
    saveQueue?.qualityOfService = .userInitiated

    let currentCallContext = callContext
    let maxWidth = currentCallContext?.maxSize?.width.map { NSNumber(value: $0) }
    let maxHeight = currentCallContext?.maxSize?.height.map { NSNumber(value: $0) }
    let imageQuality = currentCallContext?.imageQuality
    let desiredImageQuality = getDesiredImageQuality(imageQuality)
    let requestFullMetadata = currentCallContext?.requestFullMetadata ?? false
    let saveState = PickerSaveState(count: results.count)
    // This operation will be executed on the main queue after
    // all selected files have been saved.
    let sendListOperation = BlockOperation { [weak self] in
      if let saveError = saveState.saveError {
        self?.sendCallResultWithError(saveError)
      } else {
        self?.sendCallResultWithSavedPathList(saveState.pathList)
      }
      // Retain queue until here.
      saveQueue = nil
    }

    for (index, result) in results.enumerated() {
      guard
        let saveOperation = PHPickerSaveImageToPathOperation(
          result: result,
          maxHeight: maxHeight,
          maxWidth: maxWidth,
          desiredImageQuality: desiredImageQuality,
          fullMetadata: requestFullMetadata,
          savedPathBlock: { savedPath, error in
            if let savedPath = savedPath {
              saveState.pathList[index] = savedPath
            } else {
              saveState.saveError = error
            }
          })
      else {
        continue
      }
      sendListOperation.addDependency(saveOperation)
      saveQueue?.addOperation(saveOperation)
    }

    // Schedule the final Flutter callback on the main queue
    // to be run after all images have been saved.
    OperationQueue.main.addOperation(sendListOperation)
  }
}

// MARK: - UIImagePickerControllerDelegate

extension ImagePickerPlugin: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  public func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    let videoURL = info[.mediaURL] as? URL
    picker.dismiss(animated: true) { [weak self] in
      self?.removeInteractionBlocker()
    }
    // The method dismissViewControllerAnimated does not immediately prevent
    // further didFinishPickingMediaWithInfo invocations. A nil check is necessary
    // to prevent below code to be unwantly executed multiple times and cause a
    // crash.
    guard let context = callContext else {
      return
    }
    if let videoURL = videoURL {
      guard let destination = ImagePickerPhotoAssetUtil.saveVideo(from: videoURL) else {
        sendCallResultWithError(
          PigeonError(
            code: "flutter_image_picker_copy_video_error",
            message: "Could not cache the video file.",
            details: nil))
        return
      }

      sendCallResultWithSavedPathList([destination.path])
    } else {
      var image = info[.editedImage] as? UIImage
      if image == nil {
        image = info[.originalImage] as? UIImage
      }
      let maxWidth = context.maxSize?.width.map { NSNumber(value: $0) }
      let maxHeight = context.maxSize?.height.map { NSNumber(value: $0) }
      let imageQuality = context.imageQuality
      let desiredImageQuality = getDesiredImageQuality(imageQuality)

      var originalAsset: PHAsset?
      if context.requestFullMetadata {
        // Full metadata are available only in PHAsset, which requires gallery permission.
        originalAsset = ImagePickerPhotoAssetUtil.getAsset(fromImagePickerInfo: info)
      }

      if maxWidth != nil || maxHeight != nil {
        image = ImagePickerImageUtil.scaledImage(
          image,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          isMetadataAvailable: true)
      }

      guard let originalAsset = originalAsset else {
        // Image picked without an original asset (e.g. User took a photo directly)
        saveImage(withPickerInfo: info, image: image, imageQuality: desiredImageQuality)
        return
      }

      let scaledImage = image
      PHImageManager.default().requestImageDataAndOrientation(for: originalAsset, options: nil) {
        imageData, dataUTI, orientation, _ in
        // maxWidth and maxHeight are used only for GIF images.
        self.saveImage(
          withOriginalImageData: imageData,
          image: scaledImage,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: desiredImageQuality)
      }
    }
  }

  /// Tells the delegate that the user cancelled the pick operation.
  ///
  /// - Parameter picker: The controller object managing the image picker interface.
  public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) { [weak self] in
      self?.removeInteractionBlocker()
    }
    sendCallResultWithSavedPathList(nil)
  }
}
