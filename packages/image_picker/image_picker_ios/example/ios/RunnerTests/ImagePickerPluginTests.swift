// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import Photos
import PhotosUI
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import image_picker_ios

// MARK: - Test doubles

final class StubViewProvider: ViewProvider {
  var viewController: UIViewController?

  init(viewController: UIViewController? = nil) {
    self.viewController = viewController
  }
}

/// A picker controller that records source type and camera device assignments instead of applying
/// them to UIKit.
///
/// UIImagePickerController raises an exception when set to a source type the device doesn't
/// support, so a real instance can't be pointed at the camera on a simulator. The Objective-C tests
/// worked around this by having OCMock stub the class-level availability checks that UIKit itself
/// consults.
final class StubImagePickerController: UIImagePickerController {
  private(set) var assignedSourceType: UIImagePickerController.SourceType?
  private(set) var assignedCameraDevice: UIImagePickerController.CameraDevice?

  override var sourceType: UIImagePickerController.SourceType {
    get { .photoLibrary }
    set { assignedSourceType = newValue }
  }

  override var cameraDevice: UIImagePickerController.CameraDevice {
    get { assignedCameraDevice ?? .rear }
    set { assignedCameraDevice = newValue }
  }
}

/// A view controller that records presentation requests instead of performing them.
final class RecordingViewController: UIViewController {
  var presentedViewControllers: [UIViewController] = []

  override func present(
    _ viewControllerToPresent: UIViewController,
    animated: Bool,
    completion: (() -> Void)?
  ) {
    presentedViewControllers.append(viewControllerToPresent)
  }
}

final class FakeCameraPermissionChecker: CameraPermissionChecking {
  var status: AVAuthorizationStatus = .authorized
  var requestAccessGranted = true
  var authorizationStatusCallCount = 0
  var requestAccessCallCount = 0

  func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
    authorizationStatusCallCount += 1
    return status
  }

  func requestAccess(
    for mediaType: AVMediaType,
    completionHandler handler: @escaping @Sendable (Bool) -> Void
  ) {
    requestAccessCallCount += 1
    handler(requestAccessGranted)
  }
}

final class FakePhotoLibraryPermissionChecker: PhotoLibraryPermissionChecking {
  var status: PHAuthorizationStatus = .authorized
  var requestAuthorizationStatus: PHAuthorizationStatus = .authorized
  var authorizationStatusCallCount = 0
  var authorizationStatusForAccessLevelCallCount = 0
  var requestAuthorizationCallCount = 0

  func authorizationStatus() -> PHAuthorizationStatus {
    authorizationStatusCallCount += 1
    return status
  }

  @available(iOS 14.0, *)
  func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
    authorizationStatusForAccessLevelCallCount += 1
    return status
  }

  func requestAuthorization(_ handler: @escaping (PHAuthorizationStatus) -> Void) {
    requestAuthorizationCallCount += 1
    handler(requestAuthorizationStatus)
  }

  @available(iOS 14.0, *)
  func requestAuthorization(
    for accessLevel: PHAccessLevel,
    handler: @escaping (PHAuthorizationStatus) -> Void
  ) {
    requestAuthorizationCallCount += 1
    handler(requestAuthorizationStatus)
  }
}

final class FakeImagePickerCapabilityChecker: ImagePickerCapabilityChecking {
  var sourceTypeAvailable = true
  var cameraDeviceAvailable = true
  var requestedSourceTypes: [UIImagePickerController.SourceType] = []
  var requestedCameraDevices: [UIImagePickerController.CameraDevice] = []

  func isSourceTypeAvailable(_ sourceType: UIImagePickerController.SourceType) -> Bool {
    requestedSourceTypes.append(sourceType)
    return sourceTypeAvailable
  }

  func isCameraDeviceAvailable(_ cameraDevice: UIImagePickerController.CameraDevice) -> Bool {
    requestedCameraDevices.append(cameraDevice)
    return cameraDeviceAvailable
  }
}

@available(iOS 14.0, *)
final class RecordingPHPickerFactory: PHPickerViewControllerCreating {
  var lastConfiguration: PHPickerConfiguration?
  var makePickerCallCount = 0

  func makePicker(configuration: PHPickerConfiguration) -> PHPickerViewController {
    lastConfiguration = configuration
    makePickerCallCount += 1
    return PHPickerViewController(configuration: configuration)
  }
}

// MARK: - Tests

@Suite(.serialized)
@MainActor
struct ImagePickerPluginTests {
  @Test func pluginPickImageDeviceBack() {
    // Camera source type and the rear camera device are supported, and camera access is
    // authorized.
    let plugin = makePlugin()
    let controller = StubImagePickerController()
    plugin.setImagePickerControllerOverrides([controller])

    plugin.pickImage(
      source: SourceSpecification(type: .camera, camera: .rear),
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: true
    ) { _ in }

    #expect(controller.assignedCameraDevice == .rear)
  }

  @Test func pluginPickImageDeviceFront() {
    let plugin = makePlugin()
    let controller = StubImagePickerController()
    plugin.setImagePickerControllerOverrides([controller])

    plugin.pickImage(
      source: SourceSpecification(type: .camera, camera: .front),
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: true
    ) { _ in }

    #expect(controller.assignedCameraDevice == .front)
  }

  @Test func pluginPickVideoDeviceBack() {
    let plugin = makePlugin()
    let controller = StubImagePickerController()
    plugin.setImagePickerControllerOverrides([controller])

    plugin.pickVideo(
      source: SourceSpecification(type: .camera, camera: .rear),
      maxDurationSeconds: nil
    ) { _ in }

    #expect(controller.assignedCameraDevice == .rear)
  }

  @Test func pluginPickVideoDeviceFront() {
    let plugin = makePlugin()
    let controller = StubImagePickerController()
    plugin.setImagePickerControllerOverrides([controller])

    plugin.pickVideo(
      source: SourceSpecification(type: .camera, camera: .front),
      maxDurationSeconds: nil
    ) { _ in }

    #expect(controller.assignedCameraDevice == .front)
  }

  @Test func pickMultiImageShouldUseUIImagePickerControllerOnPreiOS14() {
    if #available(iOS 14, *) {
      return
    }

    let photoLibraryPermissionChecker = FakePhotoLibraryPermissionChecker()
    photoLibraryPermissionChecker.status = .authorized
    let plugin = makePlugin(photoLibraryPermissionChecker: photoLibraryPermissionChecker)
    let controller = StubImagePickerController()
    plugin.setImagePickerControllerOverrides([controller])

    plugin.pickMultiImage(
      maxSize: MaxSize(width: 100, height: 200),
      imageQuality: 50,
      requestFullMetadata: true,
      limit: nil
    ) { _ in }

    #expect(controller.assignedSourceType == .photoLibrary)
  }

  @Test func pickMediaShouldUseUIImagePickerControllerOnPreiOS14() {
    if #available(iOS 14, *) {
      return
    }

    let photoLibraryPermissionChecker = FakePhotoLibraryPermissionChecker()
    photoLibraryPermissionChecker.status = .authorized
    let plugin = makePlugin(photoLibraryPermissionChecker: photoLibraryPermissionChecker)
    let controller = StubImagePickerController()
    plugin.setImagePickerControllerOverrides([controller])
    let mediaSelectionOptions = MediaSelectionOptions(
      maxSize: MaxSize(width: 100, height: 200),
      imageQuality: 50,
      requestFullMetadata: true,
      allowMultiple: true,
      limit: nil)

    plugin.pickMedia(mediaSelectionOptions: mediaSelectionOptions) { _ in }

    #expect(controller.assignedSourceType == .photoLibrary)
  }

  @Test func pickImageWithoutFullMetadata() {
    let photoLibraryPermissionChecker = FakePhotoLibraryPermissionChecker()
    let plugin = makePlugin(photoLibraryPermissionChecker: photoLibraryPermissionChecker)
    plugin.setImagePickerControllerOverrides([UIImagePickerController()])

    plugin.pickImage(
      source: SourceSpecification(type: .gallery, camera: .front),
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: false
    ) { _ in }

    #expect(photoLibraryPermissionChecker.authorizationStatusCallCount == 0)
  }

  @Test func pickMultiImageWithoutFullMetadata() {
    let photoLibraryPermissionChecker = FakePhotoLibraryPermissionChecker()
    let plugin = makePlugin(photoLibraryPermissionChecker: photoLibraryPermissionChecker)
    plugin.setImagePickerControllerOverrides([UIImagePickerController()])

    plugin.pickMultiImage(
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: false,
      limit: nil
    ) { _ in }

    #expect(photoLibraryPermissionChecker.authorizationStatusCallCount == 0)
  }

  @Test func pickMediaWithoutFullMetadata() {
    let photoLibraryPermissionChecker = FakePhotoLibraryPermissionChecker()
    let plugin = makePlugin(photoLibraryPermissionChecker: photoLibraryPermissionChecker)
    plugin.setImagePickerControllerOverrides([UIImagePickerController()])

    let mediaSelectionOptions = MediaSelectionOptions(
      maxSize: MaxSize(width: 100, height: 200),
      imageQuality: 50,
      requestFullMetadata: true,
      allowMultiple: true,
      limit: nil)

    plugin.pickMedia(mediaSelectionOptions: mediaSelectionOptions) { _ in }

    #expect(photoLibraryPermissionChecker.authorizationStatusCallCount == 0)
  }

  // MARK: - Test camera devices

  @Test func pluginPickImageDeviceCancelClickMultipleTimes() {
    // The camera is reported as unavailable so that no camera UI is involved; the point of the test
    // is that repeated cancellation of an in-flight request doesn't crash.
    let capabilityChecker = FakeImagePickerCapabilityChecker()
    capabilityChecker.sourceTypeAvailable = false
    let plugin = makePlugin(capabilityChecker: capabilityChecker)
    let controller = StubImagePickerController()
    plugin.setImagePickerControllerOverrides([controller])

    plugin.pickImage(
      source: SourceSpecification(type: .camera, camera: .rear),
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: true
    ) { _ in }

    // To ensure the flow does not crash by multiple cancel call
    plugin.imagePickerControllerDidCancel(controller)
    plugin.imagePickerControllerDidCancel(controller)
  }

  @Test func cameraPickerInteractionBlockerWindowIsAddedAndRemoved() throws {
    let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)

    let window = UIWindow(windowScene: scene)
    window.frame = scene.coordinateSpace.bounds
    let rootViewController = UIViewController()
    window.rootViewController = rootViewController
    rootViewController.loadViewIfNeeded()
    window.makeKeyAndVisible()

    let plugin = makePlugin(viewProvider: StubViewProvider(viewController: rootViewController))
    plugin.setImagePickerControllerOverrides([StubImagePickerController()])

    plugin.pickImage(
      source: SourceSpecification(type: .camera, camera: .rear),
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: true
    ) { _ in }

    let interactionBlockerWindow = try #require(plugin.interactionBlockerWindow)
    #expect(plugin.previousKeyWindow === window)
    #expect(interactionBlockerWindow.windowLevel > window.windowLevel)
    #expect(!window.isKeyWindow)

    plugin.removeInteractionBlocker()

    #expect(plugin.interactionBlockerWindow == nil)
    #expect(plugin.previousKeyWindow == nil)
    #expect(window.isKeyWindow)
  }

  // MARK: - Test video duration

  @Test func pickingVideoWithDuration() {
    // As on the simulator the original test ran on, the camera is unavailable, so the picker is
    // configured but never presented.
    let capabilityChecker = FakeImagePickerCapabilityChecker()
    capabilityChecker.sourceTypeAvailable = false
    let plugin = makePlugin(capabilityChecker: capabilityChecker)
    let controller = StubImagePickerController()
    plugin.setImagePickerControllerOverrides([controller])

    plugin.pickVideo(
      source: SourceSpecification(type: .camera, camera: .rear),
      maxDurationSeconds: 95
    ) { _ in }

    #expect(controller.videoMaximumDuration == 95)
  }

  @Test func pickingMultiVideoWithDuration() {
    let plugin = makePlugin()

    plugin.pickMultiVideo(maxDurationSeconds: 95, limit: nil) { _ in }

    #expect(plugin.callContext?.maxDuration == 95)
  }

  @Test func pluginMultiImagePathHasNullItem() async {
    let plugin = makePlugin()

    await confirmation("result") { confirmed in
      plugin.callContext = ImagePickerMethodCallContext { _, error in
        #expect((error as? PigeonError)?.code == "create_error")
        confirmed()
      }
      plugin.sendCallResultWithSavedPathList([NSNull()])
    }
  }

  @Test func pluginMultiImagePathHasItem() async {
    let plugin = makePlugin()
    let pathList = ["test"]

    await confirmation("result") { confirmed in
      plugin.callContext = ImagePickerMethodCallContext { result, _ in
        #expect(result == pathList)
        confirmed()
      }
      plugin.sendCallResultWithSavedPathList(pathList)
    }
  }

  @Test func pluginMediaPathHasNoItem() async {
    let plugin = makePlugin()

    await confirmation("result") { confirmed in
      plugin.callContext = ImagePickerMethodCallContext { result, _ in
        #expect(result == [])
        confirmed()
      }
      plugin.sendCallResultWithSavedPathList([])
    }
  }

  @Test func pluginMediaPathConvertsNilToEmptyList() async {
    let plugin = makePlugin()

    await confirmation("result") { confirmed in
      plugin.callContext = ImagePickerMethodCallContext { result, _ in
        #expect(result == [])
        confirmed()
      }
      plugin.sendCallResultWithSavedPathList(nil)
    }
  }

  @Test func pluginMediaPathHasItem() async {
    let plugin = makePlugin()
    let pathList = ["test"]

    await confirmation("result") { confirmed in
      plugin.callContext = ImagePickerMethodCallContext { result, _ in
        #expect(result == pathList)
        confirmed()
      }
      plugin.sendCallResultWithSavedPathList(pathList)
    }
  }

  @available(iOS 14.0, *)
  @Test func sendsImageInvalidSourceError() async {
    // Item providers with no registered types do not conform to image, so the source is invalid.
    let failResult1 = PickerResultHandle(itemProvider: NSItemProvider())
    let failResult2 = PickerResultHandle(itemProvider: NSItemProvider())

    let plugin = makePlugin()

    await confirmation("result") { confirmed in
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        plugin.callContext = ImagePickerMethodCallContext { result, error in
          #expect(Thread.isMainThread)
          #expect(result == nil)
          #expect((error as? PigeonError)?.code == "invalid_source")
          confirmed()
          continuation.resume()
        }

        plugin.didFinishPicking(results: [failResult1, failResult2], dismissing: nil)
      }
    }
  }

  @available(iOS 14.0, *)
  @Test func sendsImageInvalidErrorWhenOneFails() async throws {
    let loadDataError = NSError(domain: "PHPickerDomain", code: 1234, userInfo: nil)

    let failItemProvider = NSItemProvider()
    failItemProvider.registerDataRepresentation(
      forTypeIdentifier: UTType.image.identifier, visibility: .all
    ) { completionHandler in
      completionHandler(nil, loadDataError)
      return nil
    }
    let failResult = PickerResultHandle(itemProvider: failItemProvider)

    let tiffResult = try pickerResult(forResource: "tiffImage", withExtension: "tiff")

    let plugin = makePlugin()

    await confirmation("result") { confirmed in
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        plugin.callContext = ImagePickerMethodCallContext { result, error in
          #expect(Thread.isMainThread)
          #expect(result == nil)
          #expect((error as? PigeonError)?.code == "invalid_image")
          confirmed()
          continuation.resume()
        }

        plugin.didFinishPicking(results: [failResult, tiffResult], dismissing: nil)
      }
    }
  }

  @available(iOS 14.0, *)
  @Test func savesImages() async throws {
    let tiffResult = try pickerResult(forResource: "tiffImage", withExtension: "tiff")
    let pngResult = try pickerResult(forResource: "pngImage", withExtension: "png")

    let plugin = makePlugin()

    await confirmation("result") { confirmed in
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        plugin.callContext = ImagePickerMethodCallContext { result, error in
          #expect(Thread.isMainThread)
          #expect(result?.count == 2)
          #expect(error == nil)
          confirmed()
          continuation.resume()
        }

        plugin.didFinishPicking(results: [tiffResult, pngResult], dismissing: nil)
      }
    }
  }

  @available(iOS 14.0, *)
  @Test func pickImageDoesntRequestAuthorization() {
    let photoLibraryPermissionChecker = FakePhotoLibraryPermissionChecker()
    photoLibraryPermissionChecker.status = .notDetermined
    let plugin = makePlugin(photoLibraryPermissionChecker: photoLibraryPermissionChecker)

    plugin.pickImage(
      source: SourceSpecification(type: .gallery, camera: .front),
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: true
    ) { _ in }

    #expect(photoLibraryPermissionChecker.requestAuthorizationCallCount == 0)
  }

  @available(iOS 14.0, *)
  @Test func pickMultiImageDuplicateCallCancels() async {
    let photoLibraryPermissionChecker = FakePhotoLibraryPermissionChecker()
    photoLibraryPermissionChecker.status = .notDetermined
    let plugin = makePlugin(photoLibraryPermissionChecker: photoLibraryPermissionChecker)

    await confirmation("first call") { confirmed in
      plugin.pickMultiImage(
        maxSize: MaxSize(width: 100, height: 100),
        imageQuality: nil,
        requestFullMetadata: true,
        limit: nil
      ) { result in
        switch result {
        case .success:
          Issue.record("Expected an error")
        case .failure(let error):
          #expect((error as? PigeonError)?.code == "multiple_request")
        }
        confirmed()
      }
      plugin.pickMultiImage(
        maxSize: MaxSize(width: 100, height: 100),
        imageQuality: nil,
        requestFullMetadata: true,
        limit: nil
      ) { _ in }
    }
  }

  @available(iOS 14.0, *)
  @Test func pickMediaDuplicateCallCancels() async {
    let photoLibraryPermissionChecker = FakePhotoLibraryPermissionChecker()
    photoLibraryPermissionChecker.status = .notDetermined
    let plugin = makePlugin(photoLibraryPermissionChecker: photoLibraryPermissionChecker)

    let options = MediaSelectionOptions(
      maxSize: MaxSize(width: 100, height: 200),
      imageQuality: 50,
      requestFullMetadata: true,
      allowMultiple: true,
      limit: nil)

    await confirmation("first call") { confirmed in
      plugin.pickMedia(mediaSelectionOptions: options) { result in
        switch result {
        case .success:
          Issue.record("Expected an error")
        case .failure(let error):
          #expect((error as? PigeonError)?.code == "multiple_request")
        }
        confirmed()
      }
      plugin.pickMedia(mediaSelectionOptions: options) { _ in }
    }
  }

  @available(iOS 14.0, *)
  @Test func pickVideoDuplicateCallCancels() async {
    let cameraPermissionChecker = FakeCameraPermissionChecker()
    cameraPermissionChecker.status = .notDetermined
    // As on the simulator the original test ran on, the camera is unavailable, so granting access
    // shows the "camera not available" alert instead of a picker.
    let capabilityChecker = FakeImagePickerCapabilityChecker()
    capabilityChecker.sourceTypeAvailable = false
    let plugin = makePlugin(
      cameraPermissionChecker: cameraPermissionChecker, capabilityChecker: capabilityChecker)

    let source = SourceSpecification(type: .camera, camera: .rear)
    await confirmation("first call") { confirmed in
      plugin.pickVideo(source: source, maxDurationSeconds: nil) { result in
        switch result {
        case .success:
          Issue.record("Expected an error")
        case .failure(let error):
          #expect((error as? PigeonError)?.code == "multiple_request")
        }
        confirmed()
      }
      plugin.pickVideo(source: source, maxDurationSeconds: nil) { _ in }
    }
  }

  @Test func pickMultiImageWithLimit() {
    let plugin = makePlugin()

    plugin.pickMultiImage(
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: false,
      limit: 2
    ) { _ in }

    #expect(plugin.callContext?.maxItemCount == 2)
  }

  @Test func pickMediaWithLimitAllowsMultiple() {
    let plugin = makePlugin()
    let mediaSelectionOptions = MediaSelectionOptions(
      maxSize: MaxSize(width: 100, height: 200),
      imageQuality: nil,
      requestFullMetadata: false,
      allowMultiple: true,
      limit: 2)

    plugin.pickMedia(mediaSelectionOptions: mediaSelectionOptions) { _ in }

    #expect(plugin.callContext?.maxItemCount == 2)
  }

  @Test func pickMediaWithLimitMultipleNotAllowed() {
    let plugin = makePlugin()
    let mediaSelectionOptions = MediaSelectionOptions(
      maxSize: MaxSize(width: 100, height: 200),
      imageQuality: nil,
      requestFullMetadata: false,
      allowMultiple: false,
      limit: 2)

    plugin.pickMedia(mediaSelectionOptions: mediaSelectionOptions) { _ in }

    #expect(plugin.callContext?.maxItemCount == 1)
  }

  @Test func pickMultiImageWithoutLimit() {
    let plugin = makePlugin()

    plugin.pickMultiImage(
      maxSize: MaxSize(),
      imageQuality: nil,
      requestFullMetadata: false,
      limit: nil
    ) { _ in }

    #expect(plugin.callContext?.maxItemCount == 0)
  }

  @Test func pickMediaWithoutLimitAllowsMultiple() {
    let plugin = makePlugin()
    let mediaSelectionOptions = MediaSelectionOptions(
      maxSize: MaxSize(width: 100, height: 200),
      imageQuality: nil,
      requestFullMetadata: false,
      allowMultiple: true,
      limit: nil)

    plugin.pickMedia(mediaSelectionOptions: mediaSelectionOptions) { _ in }

    #expect(plugin.callContext?.maxItemCount == 0)
  }

  @Test func pickMultiVideoWithLimit() {
    let plugin = makePlugin()

    plugin.pickMultiVideo(maxDurationSeconds: nil, limit: 2) { _ in }

    #expect(plugin.callContext?.maxItemCount == 2)
  }

  @Test func pickMultiVideoWithoutLimit() {
    let plugin = makePlugin()

    plugin.pickMultiVideo(maxDurationSeconds: nil, limit: nil) { _ in }

    #expect(plugin.callContext?.maxItemCount == 0)
  }

  @available(iOS 14.0, *)
  @Test func pickVideoSetsCurrentRepresentationMode() {
    let pickerFactory = RecordingPHPickerFactory()
    let plugin = makePlugin(
      viewProvider: StubViewProvider(viewController: RecordingViewController()))
    plugin.phPickerFactoryOverride = pickerFactory

    plugin.pickVideo(
      source: SourceSpecification(type: .gallery, camera: .rear),
      maxDurationSeconds: nil
    ) { _ in }

    #expect(pickerFactory.makePickerCallCount == 1)
    #expect(pickerFactory.lastConfiguration?.preferredAssetRepresentationMode == .current)
  }

  // MARK: - Helpers

  /// Returns a plugin whose collaborators are all test doubles that report success by default.
  private func makePlugin(
    viewProvider: ViewProvider = StubViewProvider(),
    cameraPermissionChecker: CameraPermissionChecking = FakeCameraPermissionChecker(),
    photoLibraryPermissionChecker: PhotoLibraryPermissionChecking =
      FakePhotoLibraryPermissionChecker(),
    capabilityChecker: ImagePickerCapabilityChecking = FakeImagePickerCapabilityChecker()
  ) -> ImagePickerPlugin {
    return ImagePickerPlugin(
      viewProvider: viewProvider,
      cameraPermissionChecker: cameraPermissionChecker,
      photoLibraryPermissionChecker: photoLibraryPermissionChecker,
      capabilityChecker: capabilityChecker)
  }

  /// Returns a picker result backed by the named test bundle resource.
  private func pickerResult(
    forResource resource: String,
    withExtension fileExtension: String
  ) throws -> PickerResultHandle {
    let imageURL = try #require(
      ImagePickerTestBundle.bundle.url(forResource: resource, withExtension: fileExtension))
    let itemProvider = try #require(NSItemProvider(contentsOf: imageURL))
    return PickerResultHandle(
      itemProvider: itemProvider,
      assetIdentifier: itemProvider.registeredTypeIdentifiers.first)
  }
}
