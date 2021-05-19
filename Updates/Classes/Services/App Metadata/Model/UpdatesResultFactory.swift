//
//  UpdatesResultFactory.swift
//  Updates
//
//  Created by Ross Butler on 10/04/2020.
//

import Foundation

struct UpdatesResultFactory: Factory {
    
    struct Dependencies {
        let appVersion: String
        let comparator: VersionComparator
        let notifying: NotificationMode
        let operatingSystemVersion: String
    }
    
    private let bundleVersion: String
    private let configuration: ConfigurationResult
    private let journalingService: VersionJournalingService
    private let operatingSystemVersion: String
    
    init(
        configuration: ConfigurationResult,
        bundleVersion: String,
        journalingService: VersionJournalingService,
        operatingSystemVersion: String
    ) {
        self.bundleVersion = bundleVersion
        self.configuration = configuration
        self.journalingService = journalingService
        self.operatingSystemVersion = operatingSystemVersion
    }
    
    func manufacture() -> UpdatesResult {
        guard let appStoreVersion = configuration.version else {
            return .none
        }
        let isUpdateAvailable = isUpdateAvailableForSystemVersion()
        let isUpdateMandatory = isUpdateMandatory()
        let shouldNotify = self.shouldNotify(for: appStoreVersion)
        let update = Update(
            appStoreId: configuration.appStoreId,
            newVersionString: appStoreVersion,
            releaseNotes: configuration.releaseNotes,
            shouldNotify: isUpdateAvailable,
            isMandatory: isUpdateMandatory
        )
        let willNotify = (isUpdateAvailable && shouldNotify)
            || (configuration.notificationMode == .withoutAvailableUpdate)
        return willNotify ? .available(update) : .none
    }
    
}

private extension UpdatesResultFactory {
    
    private func isUpdateMandatory() -> Bool {
        guard let appStoreVersion = configuration.version,
              let minRequiredOSVersion = configuration.minOSRequired,
              let minVersionRequired = configuration.minVersionRequired else {
            return false
        }
        let isUpdateMandatory = isUpdateMandatory(
            appVersion: bundleVersion,
            apiVersion: appStoreVersion,
            minVersionRequired: minVersionRequired)
        
        let isRequiredOSAvailable = systemVersionAvailable(
            currentOSVersion: operatingSystemVersion,
            requiredVersionString: minVersionRequired)
        return isUpdateMandatory && isRequiredOSAvailable
    }
    
    private func isUpdateAvailableForSystemVersion() -> Bool {
        guard let appStoreVersion = configuration.version,
            let minRequiredOSVersion = configuration.minOSRequired else {
                return false
        }
        let comparator = configuration.comparator
        let isNewVersionAvailable = updateAvailable(
            appVersion: bundleVersion,
            apiVersion: appStoreVersion,
            comparator: comparator
        )
        let isRequiredOSAvailable = systemVersionAvailable(
            currentOSVersion: operatingSystemVersion,
            requiredVersionString: minRequiredOSVersion
        )
        return isNewVersionAvailable && isRequiredOSAvailable
    }
    
    /// Check whether we've notified the user about this version already.
    private func shouldNotify(for version: String) -> Bool {
        let notificationCount = journalingService.notificationCount(for: version)
        let notificationMode = configuration.notificationMode
        if notificationCount < notificationMode.notificationCount {
            journalingService.incrementNotificationCount(for: version)
            return true
        }
        return false
    }
    
    /// Determines whether the required version of iOS is available on the current device.
    /// - parameter currentOSVersion The current version of iOS as determined by `UIDevice.current.systemVersion`.
    private func systemVersionAvailable(currentOSVersion: String, requiredVersionString: String) -> Bool {
        let comparisonResult = Updates.compareVersions(
            lhs: requiredVersionString,
            rhs: currentOSVersion,
            comparator: .patch
        )
        return comparisonResult != .orderedDescending
    }
    
    private func isUpdateMandatory(appVersion: String, apiVersion: String, minVersionRequired: String) -> Bool {
        let appIsObselete = Updates.compareVersions(lhs: appVersion, rhs: minVersionRequired, comparator: .patch) == .orderedAscending
        let minVersionAvailable = Updates.compareVersions(lhs: apiVersion, rhs: minVersionRequired, comparator: .patch) != .orderedAscending
        return appIsObselete && minVersionAvailable
    }
    
    private func updateAvailable(appVersion: String, apiVersion: String, comparator: VersionComparator) -> Bool {
        return Updates.compareVersions(lhs: appVersion, rhs: apiVersion, comparator: comparator) == .orderedAscending
    }
    
}
