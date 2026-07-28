import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private let hotKeyManager = HotKeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureWindow()
        configureStatusItem()
        hotKeyManager.register(
            onPress: { Task { @MainActor in AppState.shared.hotKeyPressed() } },
            onRelease: { Task { @MainActor in AppState.shared.hotKeyReleased() } }
        )
    }

    private func configureWindow() {
        let contentView = ContentView()
            .environmentObject(AppState.shared)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "OpenWisprFlow"
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        self.window = window
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "OpenWisprFlow")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showWindow)

        let menu = NSMenu()
        menu.addItem(menuItem(title: "Start or Stop Dictation", action: #selector(toggleDictation)))
        menu.addItem(menuItem(title: "Show OpenWisprFlow", action: #selector(showWindow)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        self.statusItem = statusItem
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func toggleDictation() {
        Task { @MainActor in
            AppState.shared.toggleFromHotKey()
        }
    }

    @objc private func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
