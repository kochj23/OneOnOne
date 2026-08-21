//
//  CloudKitServiceTests.swift
//  OneOnOneTests
//
//  Regression guard: the app must launch under XCTest without CloudKit crashing.
//  An unsigned test/CI host has no valid iCloud entitlement, so an eager
//  CKContainer(identifier:) os_crashes the host (EXC_BREAKPOINT) before any test
//  runs. CloudKitService.setupContainer() must skip CloudKit under tests instead.
//
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class CloudKitServiceTests: XCTestCase {

    /// The XCTest environment must be detectable — this is what gates the
    /// CloudKit-skip guard that keeps the host app from crashing on launch.
    @MainActor
    func testDetectsXCTestEnvironment() {
        XCTAssertTrue(CloudKitService.isRunningUnderTests)
    }

    /// Touching the shared service (which triggers container setup) must not crash
    /// under tests, and CloudKit must report itself unavailable rather than
    /// attempting a real CKContainer.
    @MainActor
    func testSharedServiceLaunchesWithoutCloudKitCrash() {
        let service = CloudKitService.shared
        XCTAssertNotNil(service)
        XCTAssertFalse(service.isCloudAvailable)
    }
}
