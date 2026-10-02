//
//  NetworkInjectionManagerTests.swift
//  ExampleTests
//
//  Created by DebugSwift on 2026.
//

import XCTest
@testable import DebugSwift

final class NetworkInjectionManagerTests: XCTestCase {
    
    var manager: NetworkInjectionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        manager = NetworkInjectionManager.shared
        
        // Reset to default state
        manager.setDelayConfig(RequestDelayConfig())
        manager.setFailureConfig(NetworkFailureConfig())
        manager.setRewriteConfig(ResponseBodyRewriteConfig())
        manager.setDebugConfig(NetworkDebugConfig())
    }
    
    // MARK: - Delay Config Tests
    
    func testSetDelayConfig() {
        let config = RequestDelayConfig(
            isEnabled: true,
            fixedDelay: 2.0
        )
        
        manager.setDelayConfig(config)
        
        let retrieved = manager.getDelayConfig()
        XCTAssertTrue(retrieved.isEnabled)
        XCTAssertEqual(retrieved.fixedDelay, 2.0)
    }
    
    func testApplyDelayWhenEnabled() {
        let config = RequestDelayConfig(
            isEnabled: true,
            fixedDelay: 0.1 // Use small delay for testing
        )
        manager.setDelayConfig(config)
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let start = Date()
        
        manager.applyDelayIfNeeded(for: request)
        
        let duration = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(duration, 0.1)
    }
    
    func testApplyDelayWhenDisabled() {
        let config = RequestDelayConfig(
            isEnabled: false,
            fixedDelay: 1.0
        )
        manager.setDelayConfig(config)
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let start = Date()
        
        manager.applyDelayIfNeeded(for: request)
        
        let duration = Date().timeIntervalSince(start)
        XCTAssertLessThan(duration, 0.1) // Should be instant
    }
    
    func testApplyDelayWithURLPattern() {
        let config = RequestDelayConfig(
            isEnabled: true,
            fixedDelay: 0.1,
            urlPatterns: ["api.example.com"]
        )
        manager.setDelayConfig(config)
        
        // Matching URL
        var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        var start = Date()
        manager.applyDelayIfNeeded(for: request)
        var duration = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(duration, 0.1)
        
        // Non-matching URL
        request = URLRequest(url: URL(string: "https://other.com/users")!)
        start = Date()
        manager.applyDelayIfNeeded(for: request)
        duration = Date().timeIntervalSince(start)
        XCTAssertLessThan(duration, 0.1)
    }
    
    // MARK: - Failure Config Tests
    
    func testSetFailureConfig() {
        let config = NetworkFailureConfig(
            isEnabled: true,
            failureRate: 1.0,
            failureType: .timeout
        )
        
        manager.setFailureConfig(config)
        
        let retrieved = manager.getFailureConfig()
        XCTAssertTrue(retrieved.isEnabled)
        XCTAssertEqual(retrieved.failureRate, 1.0)
    }
    
    func testShouldInjectFailureWhenEnabled() {
        let config = NetworkFailureConfig(
            isEnabled: true,
            failureRate: 1.0,
            failureType: .timeout
        )
        manager.setFailureConfig(config)
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let result = manager.shouldInjectFailure(for: request)
        
        XCTAssertTrue(result.shouldInject)
        XCTAssertNotNil(result.error)
        XCTAssertEqual((result.error as NSError?)?.code, NSURLErrorTimedOut)
    }
    
    func testShouldInjectFailureWhenDisabled() {
        let config = NetworkFailureConfig(
            isEnabled: false,
            failureRate: 1.0,
            failureType: .timeout
        )
        manager.setFailureConfig(config)
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let result = manager.shouldInjectFailure(for: request)
        
        XCTAssertFalse(result.shouldInject)
        XCTAssertNil(result.error)
    }
    
    func testShouldInjectHTTPError() {
        let config = NetworkFailureConfig(
            isEnabled: true,
            failureRate: 1.0,
            failureType: .httpError(statusCode: 404)
        )
        manager.setFailureConfig(config)
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let result = manager.shouldInjectFailure(for: request)
        
        XCTAssertTrue(result.shouldInject)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.statusCode, 404)
    }
    
    func testShouldInjectFailureWithURLPattern() {
        let config = NetworkFailureConfig(
            isEnabled: true,
            failureRate: 1.0,
            failureType: .timeout,
            urlPatterns: ["api.example.com"]
        )
        manager.setFailureConfig(config)
        
        // Matching URL
        var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        var result = manager.shouldInjectFailure(for: request)
        XCTAssertTrue(result.shouldInject)
        
        // Non-matching URL
        request = URLRequest(url: URL(string: "https://other.com/users")!)
        result = manager.shouldInjectFailure(for: request)
        XCTAssertFalse(result.shouldInject)
    }
    
    func testShouldInjectFailureWithHTTPMethod() {
        let config = NetworkFailureConfig(
            isEnabled: true,
            failureRate: 1.0,
            failureType: .timeout,
            httpMethods: ["POST"]
        )
        manager.setFailureConfig(config)
        
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        
        // Matching method
        request.httpMethod = "POST"
        var result = manager.shouldInjectFailure(for: request)
        XCTAssertTrue(result.shouldInject)
        
        // Non-matching method
        request.httpMethod = "GET"
        result = manager.shouldInjectFailure(for: request)
        XCTAssertFalse(result.shouldInject)
    }
    
    // MARK: - Rewrite Config Tests
    
    func testSetRewriteConfig() {
        let rule = ResponseBodyRewriteRule(
            urlPattern: "https://api.example.com/*",
            responseBody: "{\"ok\":true}",
            responseStatusCode: 201
        )
        let config = ResponseBodyRewriteConfig(isEnabled: true, rules: [rule])
        
        manager.setRewriteConfig(config)
        
        let expectedRule = ResponseBodyRewriteRule(
            urlPattern: "https://api.example.com/*",
            responseBody: "{\"ok\":true}",
            responseStatusCode: 201,
            matchType: .wildcard
        )
        let retrieved = manager.getRewriteConfig()
        XCTAssertTrue(retrieved.isEnabled)
        XCTAssertEqual(retrieved.rules, [expectedRule])
        XCTAssertEqual(retrieved.rules.first?.responseStatusCode, 201)
    }
    
    func testMatchingRewriteRule() {
        let firstRule = ResponseBodyRewriteRule(
            urlPattern: "https://api.example.com/v1/*",
            responseBody: "{\"version\":\"v1\"}"
        )
        let secondRule = ResponseBodyRewriteRule(
            urlPattern: "https://api.example.com/v2/*",
            responseBody: "{\"version\":\"v2\"}"
        )
        let config = ResponseBodyRewriteConfig(isEnabled: true, rules: [firstRule, secondRule])
        manager.setRewriteConfig(config)
        
        let request = URLRequest(url: URL(string: "https://api.example.com/v2/users")!)
        let matched = manager.matchingRewriteRule(for: request)
        
        let expectedRule = ResponseBodyRewriteRule(
            urlPattern: "https://api.example.com/v2/*",
            responseBody: "{\"version\":\"v2\"}",
            matchType: .wildcard
        )
        XCTAssertEqual(matched, expectedRule)
    }
    
    func testRewriteRulesRemainWhenRewriteIsDisabled() {
        let rule = ResponseBodyRewriteRule(
            urlPattern: "https://api.example.com/*",
            responseBody: "{\"ok\":true}",
            responseStatusCode: 200
        )
        
        manager.setRewriteConfig(ResponseBodyRewriteConfig(isEnabled: true, rules: [rule]))
        manager.setRewriteConfig(ResponseBodyRewriteConfig(isEnabled: false, rules: [rule]))
        
        let expectedRule = ResponseBodyRewriteRule(
            urlPattern: "https://api.example.com/*",
            responseBody: "{\"ok\":true}",
            responseStatusCode: 200,
            matchType: .wildcard
        )
        let retrieved = manager.getRewriteConfig()
        XCTAssertFalse(retrieved.isEnabled)
        XCTAssertEqual(retrieved.rules, [expectedRule])
    }

    // MARK: - Debug Config Tests

    func testSetAndGetDebugConfig() {
        let rule = NetworkDebugRule(
            urlPattern: "https://api.example.com/checkout",
            httpMethod: .post,
            isEnabled: true
        )
        let config = NetworkDebugConfig(isEnabled: true, rules: [rule])
        manager.setDebugConfig(config)

        let retrieved = manager.getDebugConfig()
        XCTAssertTrue(retrieved.isEnabled)
        XCTAssertEqual(retrieved.rules.count, 1)
        XCTAssertEqual(retrieved.rules.first?.urlPattern, "https://api.example.com/checkout")
        XCTAssertEqual(retrieved.rules.first?.httpMethod, .post)
    }

    func testMatchingDebugRule() {
        let rule = NetworkDebugRule(
            urlPattern: "https://api.example.com/checkout",
            httpMethod: .post,
            isEnabled: true
        )
        manager.setDebugConfig(NetworkDebugConfig(isEnabled: true, rules: [rule]))

        var postRequest = URLRequest(url: URL(string: "https://api.example.com/checkout")!)
        postRequest.httpMethod = "POST"
        let matchedPost = manager.matchingDebugRule(for: postRequest)
        XCTAssertNotNil(matchedPost)
        XCTAssertEqual(matchedPost?.urlPattern, "https://api.example.com/checkout")

        var getRequest = URLRequest(url: URL(string: "https://api.example.com/checkout")!)
        getRequest.httpMethod = "GET"
        let matchedGet = manager.matchingDebugRule(for: getRequest)
        XCTAssertNil(matchedGet)

        // When debug config is disabled, should not match
        manager.setDebugConfig(NetworkDebugConfig(isEnabled: false, rules: [rule]))
        XCTAssertNil(manager.matchingDebugRule(for: postRequest))
    }

    // MARK: - MVVM & Persistence Tests

    func testNetworkDebugSettingsViewModel() {
        let viewModel = NetworkDebugSettingsViewModel(manager: manager)
        var updateCount = 0
        viewModel.onStateUpdated = {
            updateCount += 1
        }

        XCTAssertFalse(viewModel.isMasterEnabled)
        viewModel.setMasterEnabled(true)
        XCTAssertTrue(viewModel.isMasterEnabled)
        XCTAssertEqual(updateCount, 1)

        // Add rules
        viewModel.addRule(urlPattern: "*auth/login*", method: .post)
        viewModel.addRule(urlPattern: "*users*", method: .get)
        XCTAssertEqual(viewModel.numberOfRules, 2)
        XCTAssertEqual(updateCount, 3)

        // Search filtering
        viewModel.updateSearch(text: "login")
        XCTAssertTrue(viewModel.isSearching)
        XCTAssertEqual(viewModel.numberOfRules, 1)
        XCTAssertEqual(viewModel.rule(at: 0)?.urlPattern, "*auth/login*")

        // Clear search
        viewModel.updateSearch(text: "")
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertEqual(viewModel.numberOfRules, 2)

        // Toggle rule
        viewModel.setRuleEnabled(at: 0, isEnabled: false)
        XCTAssertFalse(viewModel.rule(at: 0)!.isEnabled)

        // Delete rule
        viewModel.deleteRule(at: 0)
        XCTAssertEqual(viewModel.numberOfRules, 1)

        // Clear all
        viewModel.clearAllRules()
        XCTAssertEqual(viewModel.numberOfRules, 0)
    }

    func testResponseModifierSettingsViewModel() {
        let viewModel = ResponseModifierSettingsViewModel(manager: manager)
        var updateCount = 0
        viewModel.onStateUpdated = {
            updateCount += 1
        }

        viewModel.isMasterEnabled = true
        XCTAssertTrue(viewModel.isMasterEnabled)

        // Preferences
        viewModel.isShortCircuitEnabled = false
        XCTAssertFalse(viewModel.isShortCircuitEnabled)
        viewModel.isMultipleMatchEnabled = true
        XCTAssertTrue(viewModel.isMultipleMatchEnabled)
        viewModel.isAutoEnableOnRunEnabled = true
        XCTAssertTrue(viewModel.isAutoEnableOnRunEnabled)

        // Save rule
        let rule = ResponseBodyRewriteRule(
            urlPattern: "https://api.example.com/data",
            responseBody: "{\"status\":\"ok\"}",
            responseStatusCode: 200,
            httpMethod: .get,
            isEnabled: true,
            matchType: .exact
        )
        viewModel.saveRule(rule, editIndex: nil)
        XCTAssertEqual(viewModel.allRules.count, 1)
        XCTAssertEqual(viewModel.enabledRuleCountSummary, "1/1")

        // Search
        viewModel.updateSearch(text: "api.example")
        XCTAssertEqual(viewModel.filteredRules.count, 1)
        viewModel.updateSearch(text: "nomatch")
        XCTAssertEqual(viewModel.filteredRules.count, 0)
        viewModel.updateSearch(text: "")

        // Export CSV
        let export = viewModel.exportCSVData()
        XCTAssertNotNil(export)
        XCTAssertTrue(export?.fileName.hasPrefix("response_modifier_rules_") == true)

        // Reset all
        viewModel.resetAll()
        XCTAssertFalse(viewModel.isMasterEnabled)
        XCTAssertEqual(viewModel.allRules.count, 0)
    }
}

