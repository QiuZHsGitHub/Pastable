import AppKit

/// Minimal "document app" used by the end-to-end experience tests as the paste
/// target. It is intentionally disposable: its text is only in memory, so a
/// test can type, paste and kill the process without touching user documents.
final class FixtureDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow!
  private var textView: NSTextView!

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    let mainMenu = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "Quit",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Cut", action: #selector(NSTextView.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSTextView.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSTextView.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSTextView.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    NSApp.mainMenu = mainMenu

    window = NSWindow(
      contentRect: NSRect(x: 140, y: 470, width: 760, height: 400),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Pastable E2E Document"

    textView = NSTextView(frame: window.contentView!.bounds)
    textView.autoresizingMask = [.width, .height]
    textView.isRichText = false
    textView.font = .systemFont(ofSize: 18)
    textView.string = "Meeting notes"
    window.contentView!.addSubview(textView)

    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(textView)
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

let application = NSApplication.shared
let delegate = FixtureDelegate()
application.delegate = delegate
application.run()
