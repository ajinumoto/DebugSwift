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
                $0.activationState.priority > $1.activationState.priority
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

private extension UIScene.ActivationState {
    var priority: Int {
        switch self {
        case .foregroundActive: return 3
        case .foregroundInactive: return 2
        case .background: return 1
        case .unattached: return 0
        @unknown default: return -1
        }
    }
}
