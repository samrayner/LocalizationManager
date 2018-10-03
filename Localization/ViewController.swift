//
//  ViewController.swift
//  Localization
//
//  Created by Sam Rayner on 03/10/2018.
//  Copyright © 2018 The Floow. All rights reserved.
//

import UIKit

class LocalizationManager {
    typealias LanguageCode = String
    typealias TranslationKey = String
    typealias LanguageTranslations = [TranslationKey: LanguageCode]
    typealias Translations = [LanguageCode: LanguageTranslations]

    enum Errors: Error {
        case copy
        case creation
    }

    private static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let shared = LocalizationManager()

    private let localizationBundleDestination: URL
    private let stringsFilename: String
    private let bundleExtension: String

    init(stringsFilename: String = "Localizable.strings", bundleExtension: String = "localizationBundle", localizationBundleDestination: URL? = nil) {
        self.stringsFilename = stringsFilename
        self.bundleExtension = bundleExtension
        self.localizationBundleDestination = localizationBundleDestination ?? LocalizationManager.documentsDirectory
    }

    private let lProjExtension = "lproj"
    
    private var plistFormat: PropertyListSerialization.PropertyListFormat = .binary
    private let plistDecoder = PropertyListDecoder()
    private lazy var plistEncoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = plistFormat
        return encoder
    }()

    private lazy var currentBundle: Bundle = {
        if let existingBundle = localizationBundle() { return existingBundle }
        do {
            return try self.localizationBundle(named: self.newBundleName(), from: .main)
        } catch {
            print("Failed to copy localizations from main Bundle to a new Bundle in the documents directory: \(error)")
            return .main
        }
    }()

    private func contentsOfDirectory(at url: URL) -> [URL] {
        return (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [])) ?? []
    }

    private func localizationBundlePaths() -> [URL] {
        return contentsOfDirectory(at: localizationBundleDestination)
            .filter { $0.pathExtension == bundleExtension }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func lProjPaths(for bundle: Bundle) -> [URL] {
        return contentsOfDirectory(at: bundle.bundleURL)
            .filter { $0.pathExtension == lProjExtension }
    }

    private func localizationBundle() -> Bundle? {
        var paths = localizationBundlePaths()

        guard !paths.isEmpty else { return nil }

        let bundle = Bundle(url: paths.removeFirst())

        paths.forEach { try? FileManager.default.removeItem(at: $0) } //clean up old bundles (shouldn't be any)

        return bundle
    }

    private func updateTranslations(_ currentTranslatons: Translations, with newTranslations: Translations) -> Translations {
        return currentTranslatons.merging(newTranslations) { old, new in new }
    }

    private func newBundleName() -> String {
        return "\(Date().timeIntervalSince1970).\(bundleExtension)"
    }

    private func createDirectoryForBundle(named bundleName: String) throws -> URL {
        let docsBundleURL = localizationBundleDestination.appendingPathComponent(bundleName)

        if FileManager.default.fileExists(atPath: docsBundleURL.path) {
            try FileManager.default.removeItem(at: docsBundleURL)
        }

        try FileManager.default.createDirectory(at: docsBundleURL, withIntermediateDirectories: false, attributes: nil)

        return docsBundleURL
    }

    private func localizationBundle(named bundleName: String, from sourceBundle: Bundle) throws -> Bundle {
        let docsBundleURL = try createDirectoryForBundle(named: bundleName)

        for sourceLprojURL in lProjPaths(for: sourceBundle) {
            let sourceStringsURL = sourceLprojURL.appendingPathComponent(stringsFilename)
            let docsLprojURL = docsBundleURL.appendingPathComponent(sourceLprojURL.lastPathComponent)

            if FileManager.default.fileExists(atPath: sourceStringsURL.path) {
                try? FileManager.default.removeItem(at: docsLprojURL)
                try FileManager.default.copyItem(at: sourceLprojURL, to: docsLprojURL)
            }
        }

        guard let newBundle = Bundle(url: docsBundleURL) else { throw LocalizationManager.Errors.copy }

        return newBundle
    }

    private func translationsFromBundle(_ bundle: Bundle) throws -> Translations {
        var translations: Translations = [:]

        for sourceLprojURL in lProjPaths(for: bundle) {
            let languageCode = sourceLprojURL.deletingPathExtension().lastPathComponent
            let sourceStringsURL = sourceLprojURL.appendingPathComponent(stringsFilename)

            if FileManager.default.isReadableFile(atPath: sourceStringsURL.path) {
                let data = try Data(contentsOf: sourceStringsURL)
                translations[languageCode] = try plistDecoder.decode(LanguageTranslations.self, from: data, format: &plistFormat)
            }
        }

        return translations
    }

    private func localizationBundle(named bundleName: String, from translations: Translations) throws -> Bundle {
        let docsBundleURL = try createDirectoryForBundle(named: bundleName)

        for (languageCode, languageTranslations) in translations {
            let lprojURL = docsBundleURL.appendingPathComponent("\(languageCode).\(lProjExtension)")

            try FileManager.default.createDirectory(at: lprojURL, withIntermediateDirectories: false, attributes: nil)

            let data = try plistEncoder.encode(languageTranslations)
            try data.write(to: lprojURL.appendingPathComponent(stringsFilename), options: .atomic)
        }

        guard let newBundle = Bundle(url: docsBundleURL) else { throw LocalizationManager.Errors.creation }

        return newBundle
    }

    func bundle(for languageCode: String? = nil) -> Bundle {
        guard let languageCode = languageCode else { return currentBundle }
        let path = lProjPaths(for: currentBundle).first { $0.deletingPathExtension().lastPathComponent == languageCode }
        guard let url = path else { return .main }
        return Bundle(url: url) ?? currentBundle
    }

    func updateBundle(with translations: Translations) throws {
        let existingTranslations = try translationsFromBundle(currentBundle)
        let updatedTranslations = updateTranslations(existingTranslations, with: translations)
        let newBundle = try localizationBundle(named: newBundleName(), from: updatedTranslations)
        let oldBundle = currentBundle
        currentBundle = newBundle
        try? FileManager.default.removeItem(at: oldBundle.bundleURL) //clean up old bundle
    }
}
