//
//  NetworkDebugSettingsViewModel.swift
//  DebugSwift
//
//  Created by Adjie Satryo Pamungkas on 02/10/2026.
//

import Foundation

final class NetworkDebugSettingsViewModel {
    private let manager: NetworkInjectionManager
    private(set) var searchText: String = ""

    var onStateUpdated: (() -> Void)?

    init(manager: NetworkInjectionManager = .shared) {
        self.manager = manager
    }

    var isMasterEnabled: Bool {
        manager.getDebugConfig().isEnabled
    }

    var allRules: [NetworkDebugRule] {
        manager.getDebugConfig().rules
    }

    var filteredRules: [NetworkDebugRule] {
        let rules = allRules
        guard !searchText.isEmpty else { return rules }
        return rules.filter { rule in
            let patternMatch = rule.urlPattern.localizedCaseInsensitiveContains(searchText)
            let methodMatch = rule.httpMethod?.rawValue.localizedCaseInsensitiveContains(searchText) == true
            return patternMatch || methodMatch
        }
    }

    var isSearching: Bool {
        !searchText.isEmpty
    }

    var numberOfRules: Int {
        filteredRules.count
    }

    func rule(at index: Int) -> NetworkDebugRule? {
        guard index >= 0 && index < filteredRules.count else { return nil }
        return filteredRules[index]
    }

    func setMasterEnabled(_ isEnabled: Bool) {
        var config = manager.getDebugConfig()
        config.isEnabled = isEnabled
        manager.setDebugConfig(config)
        onStateUpdated?()
    }

    func setRuleEnabled(at index: Int, isEnabled: Bool) {
        guard let targetRule = rule(at: index) else { return }
        var config = manager.getDebugConfig()
        if let ruleIndex = config.rules.firstIndex(where: { $0.id == targetRule.id }) {
            config.rules[ruleIndex].isEnabled = isEnabled
            manager.setDebugConfig(config)
            onStateUpdated?()
        }
    }

    func addRule(urlPattern: String, method: HTTPMethod?) {
        let trimmedPattern = urlPattern.trimmingCharacters(in: .whitespaces)
        guard !trimmedPattern.isEmpty else { return }

        var config = manager.getDebugConfig()
        let newRule = NetworkDebugRule(urlPattern: trimmedPattern, httpMethod: method, isEnabled: true)
        config.rules.append(newRule)
        config.isEnabled = true
        manager.setDebugConfig(config)
        onStateUpdated?()
    }

    func deleteRule(at index: Int) {
        guard let targetRule = rule(at: index) else { return }
        var config = manager.getDebugConfig()
        config.rules.removeAll { $0.id == targetRule.id }
        manager.setDebugConfig(config)
        onStateUpdated?()
    }

    func clearAllRules() {
        guard !allRules.isEmpty else { return }
        var config = manager.getDebugConfig()
        config.rules.removeAll()
        manager.setDebugConfig(config)
        onStateUpdated?()
    }

    func updateSearch(text: String) {
        searchText = text.trimmingCharacters(in: .whitespaces)
        onStateUpdated?()
    }
}
