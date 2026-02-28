//
//  WindowManager.swift
//  DebugSwift
//
//  Created by Matheus Gois on 18/12/23.
//

import Foundation
import UIKit

@MainActor
enum WindowManager {
    nonisolated(unsafe) static var isSelectingWindow = false

    static var rootNavigation: UINavigationController? {
        window.rootViewController as? UINavigationController
    }

    static let window: CustomWindow = {
        let window: CustomWindow
        if let scene = currentWindowScene {
            window = CustomWindow(windowScene: scene)
        } else {
            window = CustomWindow(frame: UIScreen.main.bounds)
        }
        window.windowLevel = .alert + 1

        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.interactivePopGestureRecognizer?.isEnabled = false
        navigation.setBackgroundColor(color: .clear)
        window.rootViewController = navigation
        window.isHidden = false
        return window
    }()

    static var currentWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted {
                scenePriority(for: $0.activationState) > scenePriority(for: $1.activationState)
            }
            .first
    }

    static func prepareWindowForOverlay() {
        guard let scene = currentWindowScene else {
            window.isHidden = false
            return
        }

        if window.windowScene !== scene {
            window.isHidden = true
            window.windowScene = scene
            window.frame = scene.coordinateSpace.bounds
        }

        window.isHidden = false
    }

    private static func scenePriority(for activationState: UIScene.ActivationState) -> Int {
        switch activationState {
        case .foregroundActive: return 3
        case .foregroundInactive: return 2
        case .background: return 1
        case .unattached: return 0
        @unknown default: return -1
        }
    }

    static func presentDebugger() {
        prepareWindowForOverlay()
        guard !FloatViewManager.isShowingDebuggerView else { return }
        FloatViewManager.isShowingDebuggerView = true
        if let viewController = FloatViewManager.shared.floatViewController {
            // Prevent clicks
            window.isUserInteractionEnabled = false
            // Remove keyboard, if opened.
            UIWindow.keyWindow?.endEditing(true)

            rootNavigation?.pushViewController(
                viewController,
                animated: true
            )
            window.isUserInteractionEnabled = true
        }
    }

    static func removeDebugger() {
        FloatViewManager.isShowingDebuggerView = false
        removeNavigationBar()
        rootNavigation?.popViewController(animated: true)
    }

    static func showNavigationBar() {
        rootNavigation?.setBackgroundColor()
    }

    static func removeNavigationBar() {
        rootNavigation?.setBackgroundColor(color: .clear)
    }

    static func presentViewDebugger() {
        prepareWindowForOverlay()
        guard !FloatViewManager.isShowingDebuggerView else { return }
        FloatViewManager.isShowingDebuggerView = true

        let alertController = UIAlertController(
            title: "Select a Window",
            message: nil,
            preferredStyle: .actionSheet
        )

        alertController.popoverPresentationController?.sourceView = WindowManager.rootNavigation?.view

        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = FloatViewManager.shared.ballView
            popoverController.sourceRect = FloatViewManager.shared.ballView.bounds
        }

        let filteredWindows = UIWindowScene._windows.filter { window in
            String(describing: type(of: window)) != "UITextEffectsWindow"
                && window.windowLevel < UIWindow.Level.alert
        }

        guard filteredWindows.count > 1 else {
            InAppViewDebugger.presentForWindow(filteredWindows.first)
            return
        }

        // Add an action for each window
        for window in filteredWindows {
            let className = NSStringFromClass(type(of: window))
            let moduleName = Bundle(for: type(of: window)).bundleIdentifier ?? "Unknown Module"

            let actionTitle = "\(className) - \(moduleName)"
            let action = UIAlertAction(title: actionTitle, style: .default) { _ in
                // Handle the selected window here
                isSelectingWindow = false
                InAppViewDebugger.presentForWindow(window)
            }
            alertController.addAction(action)
        }

        // Add a cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            isSelectingWindow = false
            removeViewDebugger()
        }
        alertController.addAction(cancelAction)

        // Present the UIAlertController
        isSelectingWindow = true
        rootNavigation?.present(alertController, animated: true)
    }

    static func removeViewDebugger() {
        FloatViewManager.isShowingDebuggerView = false
        rootNavigation?.dismiss(animated: true)
    }
}

final class CustomWindow: UIWindow {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if WindowManager.isSelectingWindow { return true }

        let ballView = FloatViewManager.shared.ballView
        if
            ballView.point(inside: convert(point, to: ballView), with: event) ||
            FloatViewManager.isShowingDebuggerView {
            return true
        }

        return false
    }
}
