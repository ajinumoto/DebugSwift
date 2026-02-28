//
//  UIApplication+.swift
//  DebugSwift
//
//  Created by Matheus Gois on 16/12/23.
//

import UIKit

extension UIApplication {
    static var keyWindow: UIWindow? {
        let allScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted {
                scenePriority(for: $0.activationState) > scenePriority(for: $1.activationState)
            }

        for scene in allScenes {
            if let keyWindow = scene.windows.first(where: \.isKeyWindow) {
                return keyWindow
            }

            if let visibleWindow = scene.windows.first(where: {
                !$0.isHidden && $0.alpha > .zero && $0.windowLevel == .normal
            }) {
                return visibleWindow
            }
        }

        return nil
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
    
    class func topViewController(
        _ base: UIViewController? = UIApplication.keyWindow?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        return base
    }
}

extension UIWindowScene {
    static var _windows: [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
    }
}
