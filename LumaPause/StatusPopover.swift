import AppKit
import SwiftUI

final class StatusPopover {
    private let popover = NSPopover()
    private weak var statusButton: NSStatusBarButton?

    init(statusButton: NSStatusBarButton, rootView: some View) {
        self.statusButton = statusButton
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: rootView)
        popover.behavior = .applicationDefined  // kendiliğinden kapanmasın
        popover.animates = true
    }

    func show() {
        guard let button = statusButton else { return }
        if popover.isShown { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func close() {
        if popover.isShown { popover.performClose(nil) }
    }

    func toggle() {
        if popover.isShown { close() } else { show() }
    }

    func setRootView(_ view: some View) {
        popover.contentViewController?.view = NSHostingView(rootView: view)
    }
}
