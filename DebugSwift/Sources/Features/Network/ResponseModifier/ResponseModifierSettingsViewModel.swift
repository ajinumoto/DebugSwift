//
//  ResponseModifierSettingsViewModel.swift
//  DebugSwift
//
//  Created by Adjie Satryo Pamungkas on 02/10/2026.
//

import Foundation

final class ResponseModifierSettingsViewModel {
    private let manager: NetworkInjectionManager
    private(set) var searchText: String = ""

    var onStateUpdated: (() -> Void)?

    init(manager: NetworkInjectionManager = .shared) {
        self.manager = manager
    }

    var isMasterEnabled: Bool {
        get { manager.getRewriteConfig().isEnabled }
        set {
            var config = manager.getRewriteConfig()
            config.isEnabled = newValue
            manager.setRewriteConfig(config)
            onStateUpdated?()
        }
    }

    var allRules: [ResponseBodyRewriteRule] {
        manager.getRewriteConfig().rules
    }

    var filteredRules: [ResponseBodyRewriteRule] {
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

    var areAllRulesEnabled: Bool {
        !allRules.isEmpty && allRules.allSatisfy(\.isEnabled)
    }

    var enabledRuleCountSummary: String {
        let rules = allRules
        let enabledCount = rules.filter(\.isEnabled).count
        return "\(enabledCount)/\(rules.count)"
    }

    var isShortCircuitEnabled: Bool {
        get { manager.isRewriteShortCircuitEnabled() }
        set {
            manager.setRewriteShortCircuitEnabled(newValue)
            onStateUpdated?()
        }
    }

    var isMultipleMatchEnabled: Bool {
        get { manager.isRewriteMultipleMatchEnabled() }
        set {
            manager.setRewriteMultipleMatchEnabled(newValue)
            onStateUpdated?()
        }
    }

    var isAutoEnableOnRunEnabled: Bool {
        get { manager.shouldAutoEnableRewriteOnRun() }
        set {
            manager.setRewriteAutoEnableOnRun(newValue)
            onStateUpdated?()
        }
    }

    func rule(at index: Int) -> ResponseBodyRewriteRule? {
        guard index >= 0 && index < filteredRules.count else { return nil }
        return filteredRules[index]
    }

    func setRuleEnabled(at index: Int, isEnabled: Bool) {
        guard let targetRule = rule(at: index) else { return }
        var config = manager.getRewriteConfig()
        if let ruleIndex = config.rules.firstIndex(where: { $0.urlPattern == targetRule.urlPattern && $0.httpMethod == targetRule.httpMethod }) {
            config.rules[ruleIndex].isEnabled = isEnabled
            manager.setRewriteConfig(config)
            onStateUpdated?()
        }
    }

    func setAllRulesEnabled(_ isEnabled: Bool) {
        var config = manager.getRewriteConfig()
        config.rules = config.rules.map {
            var rule = $0
            rule.isEnabled = isEnabled
            return rule
        }
        manager.setRewriteConfig(config)
        onStateUpdated?()
    }

    func saveRule(_ rule: ResponseBodyRewriteRule, editIndex: Int?) {
        var config = manager.getRewriteConfig()
        if let editIndex, config.rules.indices.contains(editIndex) {
            config.rules[editIndex] = rule
        } else if let existingIndex = config.rules.firstIndex(where: { $0.urlPattern == rule.urlPattern && $0.httpMethod == rule.httpMethod }) {
            config.rules[existingIndex] = rule
        } else {
            config.rules.append(rule)
        }
        manager.setRewriteConfig(config)
        onStateUpdated?()
    }

    func deleteRule(at index: Int) {
        guard let targetRule = rule(at: index) else { return }
        var config = manager.getRewriteConfig()
        config.rules.removeAll { $0.urlPattern == targetRule.urlPattern && $0.httpMethod == targetRule.httpMethod }
        manager.setRewriteConfig(config)
        onStateUpdated?()
    }

    func resetAll() {
        let resetConfig = ResponseBodyRewriteConfig(isEnabled: false, rules: [])
        manager.setRewriteConfig(resetConfig)
        manager.setRewriteAutoEnableOnRun(false)
        manager.setRewriteMultipleMatchEnabled(false)
        manager.setRewriteShortCircuitEnabled(true)
        onStateUpdated?()
    }

    func exportCSVData() -> (data: Data, fileName: String)? {
        let csv = RewriteRulesCSV.export(rules: allRules)
        guard let data = csv.data(using: .utf8) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "response_modifier_rules_\(formatter.string(from: Date())).csv"
        return (data, fileName)
    }

    func applyImportedRules(_ importedRules: [ResponseBodyRewriteRule]) -> (created: Int, updated: Int) {
        var config = manager.getRewriteConfig()
        var created = 0
        var updated = 0
        for importedRule in importedRules {
            if let existingIndex = config.rules.firstIndex(where: { $0.urlPattern == importedRule.urlPattern && $0.httpMethod == importedRule.httpMethod }) {
                config.rules[existingIndex].responseBody = importedRule.responseBody
                config.rules[existingIndex].responseStatusCode = importedRule.responseStatusCode
                config.rules[existingIndex].httpMethod = importedRule.httpMethod
                updated += 1
            } else {
                config.rules.append(importedRule)
                created += 1
            }
        }
        manager.setRewriteConfig(config)
        onStateUpdated?()
        return (created, updated)
    }

    func updateSearch(text: String) {
        searchText = text.trimmingCharacters(in: .whitespaces)
        onStateUpdated?()
    }
}
