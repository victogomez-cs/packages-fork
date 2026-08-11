// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import GoogleSignIn

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

/// An abstraction around the GIDProfileData methods used by the plugin, to allow injecting an
/// alternate implementation in unit tests.
///
/// See GIDProfileData for documentation, as this should always be implemented as a direct
/// passthrough to GIDProfileData.
protocol GoogleProfileData: AnyObject {
  var email: String { get }
  var name: String { get }
  var hasImage: Bool { get }
  func imageURL(withDimension dimension: UInt) -> URL?
}

/// An abstraction around the GIDToken methods used by the plugin, to allow injecting an
/// alternate implementation in unit tests.
///
/// See GIDToken for documentation, as this should always be implemented as a direct
/// passthrough to GIDToken.
protocol GoogleAuthToken: AnyObject {
  var tokenString: String { get }
  var expirationDate: Date? { get }
}

/// An abstraction around the GIDSignInResult methods used by the plugin, to allow injecting an
/// alternate implementation in unit tests.
///
/// See GIDSignInResult for documentation, as this should always be implemented as a direct
/// passthrough to GIDSignInResult.
protocol GoogleAuthSignInResult: AnyObject {
  var user: GoogleUser { get }
  var serverAuthCode: String? { get }
}

/// An abstraction around the GIDGoogleUser methods used by the plugin, to allow injecting an
/// alternate implementation in unit tests.
///
/// See GIDGoogleUser for documentation, as this should always be implemented as a direct
/// passthrough to GIDGoogleUser.
protocol GoogleUser: AnyObject {
  var userID: String? { get }
  var profile: GoogleProfileData? { get }
  var grantedScopes: [String]? { get }
  var accessToken: GoogleAuthToken { get }
  var refreshToken: GoogleAuthToken { get }
  var idToken: GoogleAuthToken? { get }

  func refreshTokensIfNeeded(completion: @escaping (GoogleUser?, Error?) -> Void)

  #if os(iOS) || targetEnvironment(macCatalyst)
    /// Presenting controller is optional to preserve prior Obj-C nil-passing behavior into the
    /// SDK's nonnull parameter (and to allow unit tests without a real UI hierarchy).
    func addScopes(
      _ scopes: [String],
      presenting presentingViewController: UIViewController?,
      completion: ((GoogleAuthSignInResult?, Error?) -> Void)?
    )
  #elseif os(macOS)
    func addScopes(
      _ scopes: [String],
      presenting presentingWindow: NSWindow?,
      completion: ((GoogleAuthSignInResult?, Error?) -> Void)?
    )
  #endif
}

/// An abstraction around the GIDSignIn methods used by the plugin, to allow injecting an alternate
/// implementation in unit tests.
///
/// See GIDSignIn for documentation, as this should always be implemented as a direct passthrough
/// to GIDSignIn.
protocol SignInClient: AnyObject {
  var configuration: GIDConfiguration? { get set }

  func handle(_ url: URL) -> Bool

  func restorePreviousSignIn(completion: ((GoogleUser?, Error?) -> Void)?)

  func signOut()

  func disconnect(completion: ((Error?) -> Void)?)

  #if os(iOS) || targetEnvironment(macCatalyst)
    /// Presenting controller is optional to preserve prior Obj-C nil-passing behavior into the
    /// SDK's nonnull parameter (and to allow unit tests without a real UI hierarchy).
    func signIn(
      withPresenting presentingViewController: UIViewController?,
      hint: String?,
      additionalScopes: [String]?,
      nonce: String?,
      completion: ((GoogleAuthSignInResult?, Error?) -> Void)?
    )
  #elseif os(macOS)
    func signIn(
      withPresenting presentingWindow: NSWindow?,
      hint: String?,
      additionalScopes: [String]?,
      nonce: String?,
      completion: ((GoogleAuthSignInResult?, Error?) -> Void)?
    )
  #endif
}
