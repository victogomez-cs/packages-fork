// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import Testing

@testable import url_launcher_ios

@MainActor
struct URLLaunchSessionTests {

  @Test func didCompleteInitialLoadSuccessfully() {
    var results: [InAppLoadResult] = []
    let session = URLLaunchSession(url: URL(string: "https://flutter.dev")!) { result in
      switch result {
      case .success(let details):
        results.append(details)
      case .failure:
        Issue.record("Unexpected error")
      }
    }

    session.safariViewController(session.safariViewController, didCompleteInitialLoad: true)

    #expect(results == [.success])
  }

  @Test func didCompleteInitialLoadUnsuccessfully() {
    var results: [InAppLoadResult] = []
    let session = URLLaunchSession(url: URL(string: "https://flutter.dev")!) { result in
      switch result {
      case .success(let details):
        results.append(details)
      case .failure:
        Issue.record("Unexpected error")
      }
    }

    session.safariViewController(session.safariViewController, didCompleteInitialLoad: false)

    #expect(results == [.failedToLoad])
  }

  @Test func didFinishWithoutPriorLoadCompletionReportsDismissed() {
    var results: [InAppLoadResult] = []
    var didFinishCalled = false
    let session = URLLaunchSession(url: URL(string: "https://flutter.dev")!) { result in
      switch result {
      case .success(let details):
        results.append(details)
      case .failure:
        Issue.record("Unexpected error")
      }
    }
    session.didFinish = { didFinishCalled = true }

    session.safariViewControllerDidFinish(session.safariViewController)

    #expect(results == [.dismissed])
    #expect(didFinishCalled)
  }

  @Test func didFinishAfterLoadCompletionDoesNotReportAgain() {
    var results: [InAppLoadResult] = []
    var didFinishCalled = false
    let session = URLLaunchSession(url: URL(string: "https://flutter.dev")!) { result in
      switch result {
      case .success(let details):
        results.append(details)
      case .failure:
        Issue.record("Unexpected error")
      }
    }
    session.didFinish = { didFinishCalled = true }

    session.safariViewController(session.safariViewController, didCompleteInitialLoad: true)
    session.safariViewControllerDidFinish(session.safariViewController)

    // Only the initial load completion should have reported a result; the
    // subsequent dismissal must not report a second, conflicting result.
    #expect(results == [.success])
    #expect(didFinishCalled)
  }

  @Test func closeInvokesSafariViewControllerDidFinish() {
    var results: [InAppLoadResult] = []
    var didFinishCalled = false
    let session = URLLaunchSession(url: URL(string: "https://flutter.dev")!) { result in
      switch result {
      case .success(let details):
        results.append(details)
      case .failure:
        Issue.record("Unexpected error")
      }
    }
    session.didFinish = { didFinishCalled = true }

    session.close()

    #expect(results == [.dismissed])
    #expect(didFinishCalled)
  }
}
