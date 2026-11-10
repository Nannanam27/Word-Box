import Cocoa
import WebKit

/// Keeps the word list in ~/Library/Application Support/WordBox/cards.json
final class CardStore {
    let fileURL: URL
    let backupURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("WordBox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("cards.json")
        backupURL = dir.appendingPathComponent("cards.backup.json")
    }

    /// The saved list as a JSON array literal, or "[]" when there is nothing valid yet.
    func loadJSON() -> String {
        for url in [fileURL, backupURL] {
            if let data = try? Data(contentsOf: url),
               (try? JSONSerialization.jsonObject(with: data)) is [Any],
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        return "[]"
    }

    func save(_ cards: Any) {
        guard JSONSerialization.isValidJSONObject(cards),
              let data = try? JSONSerialization.data(withJSONObject: cards, options: [.prettyPrinted, .sortedKeys])
        else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Lets the window be dragged from the strip behind the traffic-light buttons.
final class DragStrip: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { window?.zoom(nil) } else { window?.performDrag(with: event) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    let store = CardStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        let content = WKUserContentController()
        let boot = """
        window.__wordboxCards = \(store.loadJSON());
        document.documentElement.classList.add("native");
        """
        content.addUserScript(WKUserScript(source: boot, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        content.add(self, name: "wordbox")

        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        if #available(macOS 13.3, *) { webView.isInspectable = true }
        webView.autoresizingMask = [.width, .height]

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Word Box"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 420, height: 560)
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.086, green: 0.082, blue: 0.075, alpha: 1)
                : NSColor(red: 0.953, green: 0.941, blue: 0.910, alpha: 1)
        }

        let container = NSView(frame: window.contentRect(forFrameRect: window.frame))
        webView.frame = container.bounds
        container.addSubview(webView)
        let strip = DragStrip(frame: NSRect(x: 0, y: container.bounds.height - 34, width: container.bounds.width, height: 34))
        strip.autoresizingMask = [.width, .minYMargin]
        container.addSubview(strip)
        window.contentView = container

        window.setFrameAutosaveName("WordBoxMain")
        if !window.setFrameUsingName("WordBoxMain") { window.center() }
        window.makeKeyAndOrderFront(nil)

        if let page = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              body["type"] as? String == "save",
              let cards = body["cards"] as? [Any] else { return }
        store.save(cards)
    }

    // Open outside links in the default browser instead of inside the app.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, action.navigationType == .linkActivated, url.scheme != "file" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc func showDataFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Word Box", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let show = appMenu.addItem(withTitle: "Show My Words File in Finder", action: #selector(showDataFolder), keyEquivalent: "")
        show.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Word Box", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Word Box", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
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
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let view = NSMenu(title: "View")
        let full = view.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.command, .control]
        viewItem.submenu = view
        main.addItem(viewItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
