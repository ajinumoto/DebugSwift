//
//  NetworkBreakpointManager.swift
//  DebugSwift
//
//  Created by Adjie Satryo Pamungkas on 02/10/2026.
//

import UIKit

final class NetworkBreakpointManager: @unchecked Sendable {
    static let shared = NetworkBreakpointManager()

    private let presentationLock = DispatchSemaphore(value: 1)

    private init() {}

    func handleRequestBreakpoint(request: URLRequest) -> BreakpointAction {
        if Thread.isMainThread {
            return .resume(statusCode: nil, modifiedHeaders: nil, modifiedBody: nil)
        }

        guard presentationLock.wait(timeout: .now() + 60) == .success else {
            return .resume(statusCode: nil, modifiedHeaders: nil, modifiedBody: nil)
        }
        defer { presentationLock.signal() }

        let semaphore = DispatchSemaphore(value: 0)
        let actionBox = BreakpointActionBox(defaultAction: .resume(statusCode: nil, modifiedHeaders: nil, modifiedBody: nil))

        let url = request.url
        let method = (request.httpMethod ?? HTTPMethod.get.rawValue).uppercased()
        let headers = request.allHTTPHeaderFields ?? [:]
        let bodyData = request.httpBody ?? request.httpBodyStream?.toData()
        let bodyString = bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        DispatchQueue.main.async {
            guard let topVC = UIApplication.topViewController(),
                  topVC.view.window != nil,
                  !topVC.isBeingDismissed else {
                semaphore.signal()
                return
            }

            let sheetVC = NetworkBreakpointSheetViewController(
                phase: .request,
                url: url,
                method: method,
                statusCode: 200,
                headers: headers,
                body: bodyString
            ) { action in
                actionBox.set(action)
                semaphore.signal()
            }

            let nav = UINavigationController(rootViewController: sheetVC)
            nav.modalPresentationStyle = .pageSheet
            nav.presentationController?.delegate = sheetVC
            nav.isModalInPresentation = false
            if #available(iOS 15.0, *) {
                if let sheet = nav.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                }
            }

            topVC.present(nav, animated: true)
        }

        let waitResult = semaphore.wait(timeout: .now() + 60)
        if waitResult == .timedOut {
            DispatchQueue.main.async {
                UIApplication.topViewController()?.dismiss(animated: true)
            }
            return .resume(statusCode: nil, modifiedHeaders: nil, modifiedBody: bodyData)
        }
        return actionBox.get()
    }

    func handleResponseBreakpoint(
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data
    ) -> BreakpointAction {
        if Thread.isMainThread {
            return .resume(statusCode: response?.statusCode, modifiedHeaders: nil, modifiedBody: nil)
        }

        guard presentationLock.wait(timeout: .now() + 60) == .success else {
            return .resume(statusCode: response?.statusCode, modifiedHeaders: nil, modifiedBody: nil)
        }
        defer { presentationLock.signal() }

        let semaphore = DispatchSemaphore(value: 0)
        let actionBox = BreakpointActionBox(defaultAction: .resume(statusCode: response?.statusCode, modifiedHeaders: nil, modifiedBody: nil))

        let url = response?.url ?? request.url
        let method = (request.httpMethod ?? HTTPMethod.get.rawValue).uppercased()
        var headers = [String: String]()
        if let headerFields = response?.allHeaderFields {
            for (key, value) in headerFields {
                headers["\(key)"] = "\(value)"
            }
        }
        let bodyString = String(data: data, encoding: .utf8) ?? ""

        DispatchQueue.main.async {
            guard let topVC = UIApplication.topViewController(),
                  topVC.view.window != nil,
                  !topVC.isBeingDismissed else {
                semaphore.signal()
                return
            }

            let sheetVC = NetworkBreakpointSheetViewController(
                phase: .response,
                url: url,
                method: method,
                statusCode: response?.statusCode ?? 200,
                headers: headers,
                body: bodyString
            ) { action in
                actionBox.set(action)
                semaphore.signal()
            }

            let nav = UINavigationController(rootViewController: sheetVC)
            nav.modalPresentationStyle = .pageSheet
            nav.presentationController?.delegate = sheetVC
            nav.isModalInPresentation = false
            if #available(iOS 15.0, *) {
                if let sheet = nav.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.prefersGrabberVisible = true
                }
            }

            topVC.present(nav, animated: true)
        }

        let waitResult = semaphore.wait(timeout: .now() + 60)
        if waitResult == .timedOut {
            DispatchQueue.main.async {
                UIApplication.topViewController()?.dismiss(animated: true)
            }
            return .resume(statusCode: response?.statusCode, modifiedHeaders: nil, modifiedBody: nil)
        }
        return actionBox.get()
    }
}

private final class BreakpointActionBox: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.debugswift.breakpoint.action-box")
    private var action: BreakpointAction

    init(defaultAction: BreakpointAction) {
        self.action = defaultAction
    }

    func set(_ newAction: BreakpointAction) {
        queue.sync { action = newAction }
    }

    func get() -> BreakpointAction {
        queue.sync { action }
    }
}

