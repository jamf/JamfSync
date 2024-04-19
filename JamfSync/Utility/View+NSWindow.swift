//
//  Copyright 2024, Jamf
//

import SwiftUI

/**
 hack to avoid crashes on window close, and remove the window from the
 NSApplication stack, ie: avoid leaking window objects
 */
fileprivate final class WindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.removeWindowsItem(sender)
        return true
    }
}

public extension View {
    func openInNewWindow(_ introspect: @escaping (_ window: NSWindow) -> Void) {
        let windowDelegate = WindowDelegate()
        let rv = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        rv.isReleasedWhenClosed = false
        rv.title = "New Window"
        // who owns who :-)
        rv.delegate = windowDelegate
        rv.contentView = NSHostingView(rootView: self)
        introspect(rv)
        rv.center()
        rv.makeKeyAndOrderFront(nil)
    }
}
