//
//  LocalizationManager.swift
//  Localization
//
//  Created by Sam Rayner on 03/10/2018.
//  Copyright © 2018 Sam Rayner. All rights reserved.
//

import Foundation

final class LocalizationManager {
    typealias LanguageCode = String
    typealias TranslationKey = String
    typealias LanguageTranslations = [TranslationKey: String]
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

    private(set) var currentBundle: Bundle = Bundle(for: LocalizationManager.self)

    init(stringsFilename: String = "Localizable.strings",
         bundleExtension: String = "localizationBundle",
         localizationBundleDestination: URL = documentsDirectory) {
        self.stringsFilename = stringsFilename
        self.bundleExtension = bundleExtension
        self.localizationBundleDestination = localizationBundleDestination
        self.currentBundle = findOrCreateLocalizationBundle()
    }

    private let lProjExtension = "lproj"

    private var plistFormat: PropertyListSerialization.PropertyListFormat = .binary
    private let plistDecoder = PropertyListDecoder()
    private lazy var plistEncoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = plistFormat
        return encoder
    }()

    private func findOrCreateLocalizationBundle() -> Bundle {
        if let existingBundle = localizationBundle() { return existingBundle }

        let classBundle = Bundle(for: LocalizationManager.self)

        do {
            return try localizationBundle(named: self.newBundleName(), from: classBundle)
        } catch {
            print("Failed to copy localizations from app Bundle to a new Bundle in the documents directory: \(error)")
            return classBundle
        }
    }

    private func contentsOfDirectory(at url: URL) -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [])
        } catch {
            return []
        }
    }

    private func localizationBundleURLs() -> [URL] {
        return contentsOfDirectory(at: localizationBundleDestination)
            .filter { $0.pathExtension == bundleExtension }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func lProjURLs(for bundle: Bundle) -> [URL] {
        return contentsOfDirectory(at: bundle.bundleURL)
            .filter { $0.pathExtension == lProjExtension }
    }

    private func lProjURL(for languageCode: LanguageCode, in bundle: Bundle? = nil) -> URL? {
        return lProjURLs(for: bundle ?? currentBundle).first {
            $0.deletingPathExtension().lastPathComponent == languageCode
        }
    }

    private func localizationBundle() -> Bundle? {
        var urls = localizationBundleURLs()

        defer {
            //clean up old bundles (shouldn't be any)
            urls.forEach { try? FileManager.default.removeItem(at: $0) }
        }

        guard let url = urls.first,
            let bundle = Bundle(url: url),
            !lProjURLs(for: bundle).isEmpty else { return nil }

        _ = urls.removeFirst() //don't clean up current bundle

        return bundle
    }

    private func updateTranslations(_ old: Translations, with updates: Translations) -> Translations {
        var new = old
        for (key, value) in updates {
            new[key] = old[key, default: [:]].merging(value) { $1 }
        }
        return new
    }

    private func newBundleName() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let dateString = formatter.string(from: Date())
        return "\(dateString).\(bundleExtension)"
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

        for sourceLprojURL in lProjURLs(for: sourceBundle) {
            let sourceStringsURL = sourceLprojURL.appendingPathComponent(stringsFilename)
            let docsLprojURL = docsBundleURL.appendingPathComponent(sourceLprojURL.lastPathComponent)

            if FileManager.default.fileExists(atPath: sourceStringsURL.path) {
                try? FileManager.default.removeItem(at: docsLprojURL) //in case already exists
                try FileManager.default.copyItem(at: sourceLprojURL, to: docsLprojURL)
            }
        }

        guard let newBundle = Bundle(url: docsBundleURL) else { throw LocalizationManager.Errors.copy }

        return newBundle
    }

    private func translationsFromBundle(_ bundle: Bundle) throws -> Translations {
        var translations: Translations = [:]

        for sourceLprojURL in lProjURLs(for: bundle) {
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

    private func setBundle(_ newBundle: Bundle) {
        let oldBundle = currentBundle
        currentBundle = newBundle
        try? FileManager.default.removeItem(at: oldBundle.bundleURL) //clean up old bundle
    }

    func bundle(for languageCode: String? = nil) -> Bundle {
        guard let languageCode = languageCode else { return currentBundle }
        guard let url = lProjURL(for: languageCode) else { return currentBundle }
        return Bundle(url: url) ?? currentBundle
    }

    func updateBundle(with translations: Translations) throws {
        let existingTranslations = try translationsFromBundle(currentBundle)
        let updatedTranslations = updateTranslations(existingTranslations, with: translations)
        let newBundle = try localizationBundle(named: newBundleName(), from: updatedTranslations)
        setBundle(newBundle)
    }
}
