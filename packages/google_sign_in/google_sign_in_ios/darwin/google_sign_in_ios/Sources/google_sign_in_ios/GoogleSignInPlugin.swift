// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import GoogleSignIn
import google_sign_in_ios_objc

#if os(macOS)
  import FlutterMacOS
  import AppKit
#else
  import Flutter
  import UIKit
#endif

/// The key within `GoogleService-Info.plist` used to hold the application's client id.
/// See https://developers.google.com/identity/sign-in/ios/start for more info.
private let kClientIdKey = "CLIENT_ID"
private let kServerClientIdKey = "SERVER_CLIENT_ID"

private func loadGoogleServiceInfo() -> [String: Any]? {
  guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
    return nil
  }
  return NSDictionary(contentsOfFile: plistPath) as? [String: Any]
}

/// Deep-converts values to something that can be safely encoded with the standard message codec,
/// for use in making NSError userInfo values safe to send as FlutterError details.
///
/// Unexpected types are converted to a description string.
private func sanitizedUserInfo(_ value: Any) -> Any {
  if let error = value as? NSError {
    return [
      "domain": error.domain,
      "code": String(error.code),
      "localizedDescription": error.localizedDescription,
      "userInfo": sanitizedUserInfo(error.userInfo),
    ]
  }
  if value is String {
    return value
  }
  if let url = value as? URL {
    return url.absoluteString
  }
  if value is NSNumber {
    return value
  }
  if let array = value as? [Any] {
    return array.map { sanitizedUserInfo($0) }
  }
  if let dict = value as? [AnyHashable: Any] {
    var safeValues: [AnyHashable: Any] = [:]
    for (key, nested) in dict {
      safeValues[key] = sanitizedUserInfo(nested)
    }
    return safeValues
  }
  return "[Unsupported type: \(String(describing: type(of: value)))]"
}

/// Maps an NSError to a corresponding PigeonError.
///
/// This should only be used when an error can't be recognized and mapped to a
/// GoogleSignInErrorCode.
private func pigeonError(for error: NSError) -> PigeonError {
  PigeonError(
    code: "\(error.domain): \(error.code)",
    message: error.localizedDescription,
    details: sanitizedUserInfo(error.userInfo))
}

/// Maps a GIDSignInErrorCode to the corresponding Pigeon GoogleSignInErrorCode.
private func pigeonErrorCode(forGIDSignInErrorCode code: Int) -> GoogleSignInErrorCode {
  switch code {
  case GIDSignInError.keychain.rawValue:
    return .keychainError
  case GIDSignInError.canceled.rawValue:
    return .canceled
  case GIDSignInError.hasNoAuthInKeychain.rawValue:
    return .noAuthInKeychain
  case GIDSignInError.EMM.rawValue:
    return .eemError
  case GIDSignInError.scopesAlreadyGranted.rawValue:
    return .scopesAlreadyGranted
  case GIDSignInError.mismatchWithCurrentUser.rawValue:
    return .userMismatch
  case GIDSignInError.unknown.rawValue:
    return .unknown
  default:
    return .unknown
  }
}

/// Flutter plugin for Google Sign-In.
public final class GoogleSignInPlugin: NSObject, FlutterPlugin, GoogleSignInApi {
  /// Instance used to manage Google Sign In authentication including
  /// sign in, sign out, and requesting additional scopes.
  let signIn: SignInClient

  /// A mapping of user IDs to GoogleUser instances to use for follow-up calls.
  var usersByIdentifier: [String: GoogleUser] = [:]

  /// The contents of GoogleService-Info.plist, if it exists.
  private let googleServiceProperties: [String: Any]?

  /// The view provider, to access the current Flutter view.
  private let viewProvider: ViewProvider

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = GoogleSignInPlugin(viewProvider: DefaultViewProvider(registrar: registrar))
    registrar.addApplicationDelegate(instance)
    #if os(iOS)
      registrar.addSceneDelegate(instance)
    #endif
    // Workaround for https://github.com/flutter/flutter/issues/118103.
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    GoogleSignInApiSetup.setUp(binaryMessenger: messenger, api: instance)
  }

  /// Inject view provider for testing.
  convenience init(viewProvider: ViewProvider) {
    self.init(signIn: GIDSignInWrapper(), viewProvider: viewProvider)
  }

  /// Inject `SignInClient` for testing.
  convenience init(signIn: SignInClient, viewProvider: ViewProvider) {
    self.init(
      signIn: signIn,
      viewProvider: viewProvider,
      googleServiceProperties: loadGoogleServiceInfo())
  }

  /// Inject `SignInClient` and `googleServiceProperties` for testing.
  init(
    signIn: SignInClient,
    viewProvider: ViewProvider,
    googleServiceProperties: [String: Any]?
  ) {
    self.signIn = signIn
    self.viewProvider = viewProvider
    self.googleServiceProperties = googleServiceProperties

    // On the iOS simulator, we get "Broken pipe" errors after sign-in for some
    // unknown reason. We can avoid crashing the app by ignoring them.
    signal(SIGPIPE, SIG_IGN)
  }

  // MARK: - FlutterPlugin / URL handling

  #if os(iOS)
    public func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
      for context in urlContexts {
        _ = signIn.handle(context.url)
      }
    }

    public func application(
      _ app: UIApplication,
      open url: URL,
      options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
      return signIn.handle(url)
    }
  #else
    // Obj-C selector is handleOpenURLs:; Swift imports it as handleOpen(_:).
    public func handleOpen(_ urls: [URL]) -> Bool {
      var handled = false
      for url in urls {
        handled = signIn.handle(url) || handled
      }
      return handled
    }
  #endif

  // MARK: - GoogleSignInApi

  func configure(params: PlatformConfigurationParams) throws {
    // If configuration information was passed from Dart, or present in GoogleService-Info.plist,
    // use that. Otherwise, keep the default configuration, which GIDSignIn will automatically
    // populate from Info.plist values (the recommended configuration method).
    if let configuration = configuration(
      clientIdentifier: params.clientId,
      serverClientIdentifier: params.serverClientId,
      hostedDomain: params.hostedDomain)
    {
      signIn.configuration = configuration
    }
  }

  func restorePreviousSignIn(completion: @escaping (Result<SignInResult, Error>) -> Void) {
    signIn.restorePreviousSignIn { [weak self] user, error in
      self?.handleAuthResult(
        user: user, serverAuthCode: nil, error: error as NSError?, completion: completion)
    }
  }

  func signIn(
    scopeHint: [String],
    nonce: String?,
    completion: @escaping (Result<SignInResult, Error>) -> Void
  ) {
    if let exception = FSICatchException({
      self.signIn(
        hint: nil,
        additionalScopes: scopeHint,
        nonce: nonce
      ) { [weak self] signInResult, error in
        self?.handleAuthResult(
          user: signInResult?.user,
          serverAuthCode: signInResult?.serverAuthCode,
          error: error as NSError?,
          completion: completion)
      }
    }) {
      completion(
        .failure(
          PigeonError(
            code: "google_sign_in",
            message: exception.reason,
            details: exception.name.rawValue)))
    }
  }

  func getRefreshedAuthorizationTokens(
    userId: String,
    completion: @escaping (Result<SignInResult, Error>) -> Void
  ) {
    guard let user = usersByIdentifier[userId] else {
      completion(
        .success(
          SignInResult(
            success: nil,
            error: SignInFailure(
              type: .userMismatch,
              message: "The user is no longer signed in.",
              details: nil))))
      return
    }

    user.refreshTokensIfNeeded { [weak self] refreshedUser, error in
      self?.handleAuthResult(
        user: refreshedUser, serverAuthCode: nil, error: error as NSError?, completion: completion)
    }
  }

  func addScopes(
    scopes: [String],
    userId: String,
    completion: @escaping (Result<SignInResult, Error>) -> Void
  ) {
    guard let user = usersByIdentifier[userId] else {
      completion(
        .success(
          SignInResult(
            success: nil,
            error: SignInFailure(
              type: .userMismatch,
              message: "The user is no longer signed in.",
              details: nil))))
      return
    }

    if let exception = FSICatchException({
      self.addScopes(scopes, for: user) { [weak self] signInResult, error in
        self?.handleAuthResult(
          user: signInResult?.user,
          serverAuthCode: signInResult?.serverAuthCode,
          error: error as NSError?,
          completion: completion)
      }
    }) {
      completion(
        .failure(
          PigeonError(
            code: "request_scopes",
            message: exception.reason,
            details: exception.name.rawValue)))
    }
  }

  func signOut() throws {
    signIn.signOut()
    // usersByIdentifier is left populated, because the SDK may still support some operations on the
    // GIDGoogleUser object (e.g., returning existing, non-expired tokens). Operations that the SDK
    // doesn't support will return SDK errors that we can handle as normal.
  }

  func disconnect(completion: @escaping (Result<Void, Error>) -> Void) {
    signIn.disconnect { error in
      if let error = error as NSError? {
        completion(.failure(pigeonError(for: error)))
      } else {
        completion(.success(()))
      }
    }
  }

  // MARK: - Private

  /// Wraps the iOS and macOS sign in display methods.
  private func signIn(
    hint: String?,
    additionalScopes: [String]?,
    nonce: String?,
    completion: @escaping (GoogleAuthSignInResult?, Error?) -> Void
  ) {
    #if os(macOS)
      signIn.signIn(
        withPresenting: viewProvider.view?.window,
        hint: hint,
        additionalScopes: additionalScopes,
        nonce: nonce,
        completion: completion)
    #else
      signIn.signIn(
        withPresenting: topViewController(),
        hint: hint,
        additionalScopes: additionalScopes,
        nonce: nonce,
        completion: completion)
    #endif
  }

  /// Wraps the iOS and macOS scope addition methods.
  private func addScopes(
    _ scopes: [String],
    for user: GoogleUser,
    completion: @escaping (GoogleAuthSignInResult?, Error?) -> Void
  ) {
    #if os(macOS)
      user.addScopes(
        scopes,
        presenting: viewProvider.view?.window,
        completion: completion)
    #else
      user.addScopes(
        scopes,
        presenting: topViewController(),
        completion: completion)
    #endif
  }

  /// Returns nil if GoogleService-Info.plist not found and runtimeClientIdentifier is not provided.
  private func configuration(
    clientIdentifier runtimeClientIdentifier: String?,
    serverClientIdentifier runtimeServerClientIdentifier: String?,
    hostedDomain: String?
  ) -> GIDConfiguration? {
    let clientID =
      runtimeClientIdentifier ?? googleServiceProperties?[kClientIdKey] as? String
    guard let clientID else {
      // Creating a GIDConfiguration requires a client identifier.
      return nil
    }
    let serverClientID =
      runtimeServerClientIdentifier ?? googleServiceProperties?[kServerClientIdKey] as? String

    return GIDConfiguration(
      clientID: clientID,
      serverClientID: serverClientID,
      hostedDomain: hostedDomain,
      openIDRealm: nil)
  }

  private func handleAuthResult(
    user: GoogleUser?,
    serverAuthCode: String?,
    error: NSError?,
    completion: @escaping (Result<SignInResult, Error>) -> Void
  ) {
    if let user {
      didSignIn(for: user, serverAuthCode: serverAuthCode, completion: completion)
    } else if let error, error.domain == kGIDSignInErrorDomain {
      // Convert expected errors into structured failure return, and everything else
      // into a generic error.
      completion(
        .success(
          SignInResult(
            success: nil,
            error: SignInFailure(
              type: pigeonErrorCode(forGIDSignInErrorCode: error.code),
              message: error.localizedDescription,
              details: sanitizedUserInfo(error.userInfo)))))
    } else {
      // Mirrors Obj-C nil-messaging when `error` is nil: domain/code become (null)/0.
      let nsError =
        error
        ?? NSError(domain: "(null)", code: 0, userInfo: nil)
      completion(.failure(pigeonError(for: nsError)))
    }
  }

  private func didSignIn(
    for user: GoogleUser,
    serverAuthCode: String?,
    completion: @escaping (Result<SignInResult, Error>) -> Void
  ) {
    if let userID = user.userID {
      usersByIdentifier[userID] = user
    }

    var photoURL: URL?
    if let profile = user.profile, profile.hasImage {
      // Placeholder that will be replaced by on the Dart side based on screen size.
      photoURL = profile.imageURL(withDimension: 1337)
    }

    let userData = UserData(
      displayName: user.profile?.name,
      email: user.profile?.email ?? "",
      userId: user.userID ?? "",
      photoUrl: photoURL?.absoluteString,
      idToken: user.idToken?.tokenString)
    let result = SignInResult(
      success: SignInSuccess(
        user: userData,
        accessToken: user.accessToken.tokenString,
        grantedScopes: user.grantedScopes ?? [],
        serverAuthCode: serverAuthCode),
      error: nil)
    completion(.success(result))
  }

  #if os(iOS)
    private func topViewController() -> UIViewController? {
      topViewController(from: viewProvider.viewController)
    }

    /// Recursively iterates through the view hierarchy to return the top most view controller.
    ///
    /// It supports the following scenarios:
    ///
    /// - The view controller is presenting another view.
    /// - The view controller is a UINavigationController.
    /// - The view controller is a UITabBarController.
    private func topViewController(from viewController: UIViewController?) -> UIViewController? {
      guard let viewController else { return nil }
      if let navigationController = viewController as? UINavigationController {
        return topViewController(from: navigationController.viewControllers.last)
      }
      if let tabController = viewController as? UITabBarController {
        return topViewController(from: tabController.selectedViewController)
      }
      if let presented = viewController.presentedViewController {
        return topViewController(from: presented)
      }
      return viewController
    }
  #endif
}

#if os(iOS)
  // MARK: - FlutterSceneLifeCycleDelegate

  extension GoogleSignInPlugin: FlutterSceneLifeCycleDelegate {}
#endif
