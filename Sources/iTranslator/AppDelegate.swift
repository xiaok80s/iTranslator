import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

extension Notification.Name {
    static let settingsToggled = Notification.Name("iTranslatorSettingsToggled")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private let model = TranslatorModel()
    private let width: CGFloat = 340
    private var height: CGFloat = 360
    private var lastHidden = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "iTranslator")
            button.target = self
            button.action = #selector(togglePanel(_:))
        }

        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: 14)

        let host = NSHostingView(rootView: TranslatorView(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            host.topAnchor.constraint(equalTo: effect.topAnchor),
            host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.contentView = effect

        NotificationCenter.default.addObserver(forName: .settingsToggled, object: nil, queue: .main) { [weak self] note in
            let show = note.object as? Bool ?? false
            MainActor.assumeIsolated { self?.resize(to: show ? 580 : 360) }
        }
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let size = radius * 2 + 1
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    // Accessory apps have no menu bar, so text shortcuts (⌘A/C/V/X/Z) need a hidden Edit menu.
    private func installEditMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = mainMenu
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel.isVisible {
            panel.orderOut(nil)
        } else if Date().timeIntervalSince(lastHidden) > 0.25 {
            showPanel()
        }
    }

    private func showPanel() {
        guard let buttonWindow = statusItem.button?.window else { return }
        let buttonFrame = buttonWindow.frame
        let screen = buttonWindow.screen ?? NSScreen.main
        var x = buttonFrame.midX - width / 2
        if let vf = screen?.visibleFrame {
            x = min(max(x, vf.minX + 6), vf.maxX - width - 6)
        }
        let top = buttonFrame.minY - 4 // just below the menu bar
        panel.setFrame(NSRect(x: x, y: top - height, width: width, height: height), display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func resize(to newHeight: CGFloat) {
        guard panel.isVisible else { height = newHeight; return }
        let top = panel.frame.maxY
        height = newHeight
        panel.setFrame(NSRect(x: panel.frame.minX, y: top - newHeight, width: width, height: newHeight), display: true, animate: false)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Keep the panel (and its translation view) alive while Apple's download dialog has focus.
        if model.appleBusy { return }
        lastHidden = Date()
        panel.orderOut(nil)
    }
}
