import UIKit
import ObjectiveC.runtime

enum AppIconManager {
    /// Pass nil to revert to the primary icon. Names must match an
    /// alternate icon set declared in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
    ///
    /// Suppresses the "You have changed the icon for X" alert by swizzling
    /// UIViewController.present(_:animated:completion:) for the duration of the call.
    static func setIcon(_ name: String?) async {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        if UIApplication.shared.alternateIconName == name { return }

        let swizzle = PresentSwizzle()
        swizzle.install()
        defer { swizzle.uninstall() }

        do {
            try await UIApplication.shared.setAlternateIconName(name)
        } catch {
            // Ignored — most failures are "icon name not declared".
        }
    }
}

/// Swaps UIViewController.present(_:animated:completion:) with a no-op version
/// so iOS's icon-change alert never reaches the screen. Restores on uninstall.
private final class PresentSwizzle {
    private let cls: AnyClass = UIViewController.self
    private let selector = #selector(UIViewController.present(_:animated:completion:))
    private var originalImp: IMP?

    func install() {
        guard let method = class_getInstanceMethod(cls, selector) else { return }
        let block: @convention(block) (UIViewController, UIViewController, Bool, (() -> Void)?) -> Void = { _, _, _, completion in
            completion?()
        }
        let newImp = imp_implementationWithBlock(block)
        originalImp = method_setImplementation(method, newImp)
    }

    func uninstall() {
        guard let originalImp,
              let method = class_getInstanceMethod(cls, selector) else { return }
        method_setImplementation(method, originalImp)
    }
}
