//
//  LocalizationManagerTests.swift
//  LocalizationTests
//
//  Created by Sam Rayner on 03/10/2018.
//  Copyright © 2018 Sam Rayner. All rights reserved.
//

import XCTest
@testable import Localization

class LocalizationManagerTests: XCTestCase {
    static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let bundlesDirectory = documentsDirectory.appendingPathComponent("testBundles")

    let manager = LocalizationManager(
        stringsFilename: "Localizable.strings",
        bundleExtension: "testBundle",
        localizationBundleDestination: bundlesDirectory
    )

    override class func tearDown() {
        super.tearDown()
        let documents = (try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [], options: [])) ?? []
        documents.forEach { try? FileManager.default.removeItem(at: $0) } //clean up all documents
    }

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: LocalizationManagerTests.bundlesDirectory,
                                                 withIntermediateDirectories: false,
                                                 attributes: nil)
    }

    func test_bundleForLanguageCode() {
        let defaultLanguageBundle = manager.bundle()
        XCTAssertEqual(
            defaultLanguageBundle.bundleURL.pathExtension,
            "testBundle"
        )

        let parentDirectoryPath = defaultLanguageBundle.bundleURL.deletingLastPathComponent()
        XCTAssertEqual(
            parentDirectoryPath.lastPathComponent,
            "testBundles"
        )

        let frBundle = manager.bundle(for: "fr")
        XCTAssertTrue(
            frBundle.bundleURL.path.hasSuffix(".testBundle/fr.lproj")
        )
    }

    func test_updateBundleWithTranslations() throws {
        XCTAssertEqual(
            NSLocalizedString("hello",
                              tableName: "Localizable",
                              bundle: manager.bundle(),
                              comment: ""),
            "HELLO Copied from main bundle!"
        )

        XCTAssertEqual(
            NSLocalizedString("hello",
                              tableName: "Localizable",
                              bundle: manager.bundle(for: "fr"),
                              comment: ""),
            "BONJOUR Copied from main bundle!"
        )

        XCTAssertEqual(
            NSLocalizedString("goodbye",
                              tableName: "Localizable",
                              bundle: manager.bundle(),
                              comment: ""),
            "BYE Copied from main bundle!"
        )

        XCTAssertEqual(
            NSLocalizedString("goodbye",
                              tableName: "Localizable",
                              bundle: manager.bundle(for: "fr"),
                              comment: ""),
            "AUREVOIR Copied from main bundle!"
        )

        try manager.updateBundle(with: [
            "en": [
                "hello": "Hi"
            ],
            "fr": [
                "hello": "Salut"
            ]
        ])

        XCTAssertEqual(
            NSLocalizedString("hello",
                              tableName: "Localizable",
                              bundle: manager.bundle(),
                              comment: ""),
            "Hi"
        )

        XCTAssertEqual(
            NSLocalizedString("hello",
                              tableName: "Localizable",
                              bundle: manager.bundle(for: "en"),
                              comment: ""),
            "Hi"
        )

        XCTAssertEqual(
            NSLocalizedString("hello",
                              tableName: "Localizable",
                              bundle: manager.bundle(for: "fr"),
                              comment: ""),
            "Salut"
        )

        XCTAssertEqual(
            NSLocalizedString("goodbye",
                              tableName: "Localizable",
                              bundle: manager.bundle(),
                              comment: ""),
            "BYE Copied from main bundle!"
        )

        XCTAssertEqual(
            NSLocalizedString("goodbye",
                              tableName: "Localizable",
                              bundle: manager.bundle(for: "fr"),
                              comment: ""),
            "AUREVOIR Copied from main bundle!"
        )
    }
}
