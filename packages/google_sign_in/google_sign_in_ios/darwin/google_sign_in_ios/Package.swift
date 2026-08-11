// swift-tools-version: 5.9

// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import PackageDescription

let package = Package(
  name: "google_sign_in_ios",
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "google-sign-in-ios", targets: ["google_sign_in_ios"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/google/GoogleSignIn-iOS.git",
      from: "9.0.0")
  ],
  targets: [
    // Tiny Obj-C helper so Swift can catch NSExceptions raised by the Google Sign-In SDK
    // (and by unit-test fakes). SPM does not allow mixing Swift and Obj-C in one target.
    .target(
      name: "google_sign_in_ios_objc",
      publicHeadersPath: "include"
    ),
    .target(
      name: "google_sign_in_ios",
      dependencies: [
        .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
        "google_sign_in_ios_objc",
      ],
      resources: [
        .process("Resources")
      ]
    ),
  ]
)
