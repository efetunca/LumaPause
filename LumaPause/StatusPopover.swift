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

        // Popover window oluşunca ekrana sığdır (fullscreen'da kesilmeyi önler)
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let win = self.popover.contentViewController?.view.window,
                let screen = win.screen ?? NSScreen.main
            else { return }

            let visible = screen.visibleFrame
            var f = win.frame

            if f.maxY > visible.maxY {
                f.origin.y = visible.maxY - f.height + 24
            }

            win.setFrame(f, display: true)
        }
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
