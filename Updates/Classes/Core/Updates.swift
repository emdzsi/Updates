//
//  Updates.swift
//  Updates
//
//  Created by Ross Butler on 12/27/18.
//

import Foundation
import StoreKit

public class Updates {
    
    // MARK: Global State
    
    public static var configurationType: ConfigurationType = {
        for configurationType in ConfigurationType.allCases where bundledConfigurationURL(configurationType) != nil {
            return configurationType
        }
        return .json // Default configuration type.
    }()
    
    /// Defaults configuration URL to bundled configuration and detects configuration type when set.
    public static var configurationURL: URL? = bundledConfigurationURL() {
        didSet { // detect configuration format by extension
            guard let lastPathComponent = configurationURL?.lastPathComponent.lowercased() else {
                return
            }
            let configExtension = configurationType.rawValue.lowercased()
            for configurationType in ConfigurationType.allCases where lastPathComponent.contains(configExtension) {
                Updates.configurationType = configurationType
                return
            }
        }
    }
    
    public static var appStoreId: String? {
        didSet {
            guard appStoreURL == nil, let appStoreId = appStoreId, let productName = productName else {
                return
            }
            appStoreURL = appStoreURL(appStoreId: appStoreId, productName: productName)
        }
    }
    
    public static var appStoreURL: URL?
    
    /// Returns the URL to open the app with the specified identifier in the App Store.
    /// - Parameters:
    ///     - appStoreId: The app store identifier specified as a String.
    /// - Returns: The URL required to launch the App Store page for the specified app,
    /// provided a valid identifier is provided.
    static func appStoreURL(for appStoreId: String) -> URL? {
        Updates.appStoreId = appStoreId
        return appStoreURL
    }
    
    public static let buildString: String? = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String
    
    public static var bundleIdentifier: String? = Bundle.main.bundleIdentifier
    
    public static var comparingVersions: VersionComparator = .patch
    
    public static var countryCode: String? = {
        let currentBundle = Bundle(for: Updates.self)
        if #available(iOS 13.0, macCatalyst 13.0, *),
            let iso3166Alpha3CountryCode = SKPaymentQueue.default().storefront?.countryCode,
            !iso3166Alpha3CountryCode.isEmpty,
            let iso3166Mapping = currentBundle.infoDictionary?["ISO3166Map"] as? [String: String],
            let iso3166Alpha2CountryCode = iso3166Mapping[iso3166Alpha3CountryCode] {
            return iso3166Alpha2CountryCode
        } else {
            return Locale.current.regionCode
        }
    }()
    
    public internal(set) static var isFirstLaunchFollowingInstall: Bool = false
    
    public internal(set) static var isFirstLaunchFollowingUpdate: Bool = false
    
    public static var newVersionString: String?
    
    public static var notifying: NotificationMode = .once
    
    public static var minimumOSVersion: String?
    
    public static let productName: String? = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
    
    public static var releaseNotes: String?
    
    public static var updatingMode: UpdatingMode = .automatically
    
    public static var versionString: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    public static var minVersionRequired: String?
    
    public static func checkForUpdates(currentOSVersion: String, completion: @escaping (UpdatesResult) -> Void) {
        guard let configURL = configurationURL, let cachedConfigURL = cachedConfigurationURL else {
            checkForUpdates(
                configuration: programmaticConfiguration(),
                operatingSystemVersion: currentOSVersion,
                completion: completion
            )
            return
        }
        let configurationService = Services.configuration(
            configurationURL: configURL,
            cachedConfigurationURL: cachedConfigURL
        )
        configurationService.fetchSettings(defaults: programmaticConfiguration()) { result in
            switch result {
            case .success(let configuration):
                checkForUpdates(
                    configuration: configuration,
                    operatingSystemVersion: currentOSVersion,
                    completion: completion
                )
            case .failure:
                checkForUpdates(
                    configuration: programmaticConfiguration(),
                    operatingSystemVersion: currentOSVersion,
                    completion: completion
                )
            }
        }
    }
    
    private static func checkForUpdates(configuration: ConfigurationResult,
                                        operatingSystemVersion: String,
                                        completion: @escaping (UpdatesResult) -> Void) {
        guard let bundleVersion = configuration.version, let buildString = configuration.buildString else {
            completion(.none)
            return
        }
        Updates.appStoreId = configuration.appStoreId
        registerBuild(bundleVersion: bundleVersion, buildString: buildString)
        let updatesService: UpdateResolutionService
        if let bundleIdentifier = bundleIdentifier, let countryCode = countryCode,
            let appMetadataService = Services.appMetadata(
                bundleIdentifier: bundleIdentifier,
                countryCode: countryCode
            ) {
            updatesService = Services.updateResolutionService(
                appMetadataService: appMetadataService,
                bundleVersion: bundleVersion,
                configuration: configuration,
                operatingSystemVersion: operatingSystemVersion,
                strategy: configuration.updatingMode
            )
        } else {
            updatesService = Services.updateResolutionService(
                appMetadataService: nil,
                bundleVersion: bundleVersion,
                configuration: configuration,
                operatingSystemVersion: operatingSystemVersion,
                strategy: .manually
            )
        }
        updatesService.checkForUpdates(completion: completion)
    }
    
    private static func programmaticConfiguration() -> ConfigurationResult {
        return ConfigurationResult(
            appStoreId: appStoreId,
            build: buildString,
            comparator: comparingVersions,
            minRequiredOSVersion: minimumOSVersion,
            notifying: notifying,
            releaseNotes: releaseNotes,
            updatingMode: updatingMode,
            version: versionString,
            minVersionRequired: minVersionRequired
        )
    }
    
    private static func registerBuild(bundleVersion: String, buildString: String) {
        let versionJournaling = Services.journaling
        _ = versionJournaling.registerBuild(versionString: bundleVersion, buildString: buildString, comparator: .build)
    }
    
}
