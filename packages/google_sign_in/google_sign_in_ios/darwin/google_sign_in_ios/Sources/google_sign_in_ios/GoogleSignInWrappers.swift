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

// Protocol conformances for SDK types that can be used as direct passthroughs for nested
// properties. Methods that return protocol-typed completions still need thin adapters below
// because GIDSignIn's completion signatures use concrete SDK types.

extension GIDProfileData: GoogleProfileData {}

extension GIDToken: GoogleAuthToken {}

/// Implementation of SignInClient that passes through to GIDSignIn.
final class GIDSignInWrapper: SignInClient {
  let signIn: GIDSignIn

  init(signIn: GIDSignIn = .sharedInstance) {
    self.signIn = signIn
  }

  var configuration: GIDConfiguration? {
    get { signIn.configuration }
    set { signIn.configuration = newValue }
  }

  func handle(_ url: URL) -> Bool {
    signIn.handle(url)
  }

  func restorePreviousSignIn(completion: ((GoogleUser?, Error?) -> Void)?) {
    signIn.restorePreviousSignIn { user, error in
      completion?(user.map { GIDGoogleUserWrapper(user: $0) }, error)
    }
  }

  func signOut() {
    signIn.signOut()
  }

  func disconnect(completion: ((Error?) -> Void)?) {
    signIn.disconnect(completion: completion)
  }

  #if os(iOS) || targetEnvironment(macCatalyst)
    func signIn(
      withPresenting presentingViewController: UIViewController?,
      hint: String?,
      additionalScopes: [String]?,
      nonce: String?,
      completion: ((GoogleAuthSignInResult?, Error?) -> Void)?
    ) {
      // Force-unwrap matches prior Obj-C passing of a possibly-nil controller into the SDK's
      // nonnull parameter (see flutter/flutter#101700).
      signIn.signIn(
        withPresenting: presentingViewController!,
        hint: hint,
        additionalScopes: additionalScopes,
        nonce: nonce
      ) { result, error in
        completion?(result.map { GIDSignInResultWrapper(result: $0) }, error)
      }
    }
  #elseif os(macOS)
    func signIn(
      withPresenting presentingWindow: NSWindow?,
      hint: String?,
      additionalScopes: [String]?,
      nonce: String?,
      completion: ((GoogleAuthSignInResult?, Error?) -> Void)?
    ) {
      signIn.signIn(
        withPresenting: presentingWindow!,
        hint: hint,
        additionalScopes: additionalScopes,
        nonce: nonce
      ) { result, error in
        completion?(result.map { GIDSignInResultWrapper(result: $0) }, error)
      }
    }
  #endif
}

/// Implementation of GoogleAuthSignInResult that passes through to GIDSignInResult.
final class GIDSignInResultWrapper: GoogleAuthSignInResult {
  let result: GIDSignInResult

  init?(result: GIDSignInResult?) {
    guard let result else { return nil }
    self.result = result
  }

  init(result: GIDSignInResult) {
    self.result = result
  }

  var user: GoogleUser {
    GIDGoogleUserWrapper(user: result.user)
  }

  var serverAuthCode: String? {
    result.serverAuthCode
  }
}

/// Implementation of GoogleUser that passes through to GIDGoogleUser.
final class GIDGoogleUserWrapper: GoogleUser {
  let user: GIDGoogleUser

  init?(user: GIDGoogleUser?) {
    guard let user else { return nil }
    self.user = user
  }

  init(user: GIDGoogleUser) {
    self.user = user
  }

  var userID: String? { user.userID }

  var profile: GoogleProfileData? {
    user.profile.map { $0 as GoogleProfileData }
  }

  var grantedScopes: [String]? { user.grantedScopes }

  var accessToken: GoogleAuthToken { user.accessToken }

  var refreshToken: GoogleAuthToken { user.refreshToken }

  var idToken: GoogleAuthToken? { user.idToken }

  func refreshTokensIfNeeded(completion: @escaping (GoogleUser?, Error?) -> Void) {
    user.refreshTokensIfNeeded { refreshedUser, error in
      completion(refreshedUser.map { GIDGoogleUserWrapper(user: $0) }, error)
    }
  }

  #if os(iOS) || targetEnvironment(macCatalyst)
    func addScopes(
      _ scopes: [String],
      presenting presentingViewController: UIViewController?,
      completion: ((GoogleAuthSignInResult?, Error?) -> Void)?
    ) {
      user.addScopes(scopes, presenting: presentingViewController!) { result, error in
        completion?(result.map { GIDSignInResultWrapper(result: $0) }, error)
      }
    }
  #elseif os(macOS)
    func addScopes(
      _ scopes: [String],
      presenting presentingWindow: NSWindow?,
      completion: ((GoogleAuthSignInResult?, Error?) -> Void)?
    ) {
      user.addScopes(scopes, presenting: presentingWindow!) { result, error in
        completion?(result.map { GIDSignInResultWrapper(result: $0) }, error)
      }
    }
  #endif
}
