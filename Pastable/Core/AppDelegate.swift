import AppKit
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel!
  var statusItem: NSStatusItem!
  private var outsideClickMonitor: Any?
  private var outsideClickGlobalMonitor: Any?
  private var previousApplication: NSRunningApplication?

  func applicationWillFinishLaunching(_ notification: Notification) {
    Preferences.registerDefaults()
    // Start observing Core Data + CloudKit events before the SwiftData
    // container is first opened, so a failed initial sync is visible in
    // Settings instead of silently showing "connected".
    _ = CloudSyncMonitor.shared
    applyUIAutomationAppearanceIfNeeded()
    // Hide the Dock icon before the first frame to avoid a dock-icon flash.
    NSApp.setActivationPolicy(.accessory)
  }

  /// Debug-only launch hook used by screenshot automation; the shipping app
  /// simply follows the macOS system appearance (NSApp.appearance defaults nil).
  private func applyUIAutomationAppearanceIfNeeded() {
    #if DEBUG
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "--ui-appearance"),
          args.indices.contains(index + 1) else { return }
    switch args[index + 1] {
    case "light": NSApp.appearance = NSAppearance(named: .aqua)
    case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
    default: NSApp.appearance = nil
    }
    #endif
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register AppDelegate in AppState
    AppState.shared.appDelegate = self

    // Start Clipboard Monitoring
    Clipboard.shared.start()

    // Setup HotKey
    KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
      Task { @MainActor in
        self?.togglePanel()
      }
    }

    // Create Panel (会自动定位到屏幕底部)
    panel = FloatingPanel(
      contentRect: .zero, // 初始 rect 会被 positionAtBottom 覆盖
      backing: .buffered,
      defer: false
    )

    // Set Content
    let contentView = ContentView()
      .modelContainer(Storage.shared.container)
      .environmentObject(AppState.shared)

    panel.setContent(view: contentView)

    // Close panel when clicking outside
    setupOutsideClickMonitors()

    // Close the panel when the whole app loses focus (Cmd+Tab, etc.).
    NotificationCenter.default.addObserver(
      forName: NSApplication.didResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.panel.isVisible else { return }
        self.panel.close()
      }
    }

    // Status Bar Item
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
      if let appIcon = NSImage(named: "icon_status_bar_logo") {
        appIcon.size = NSSize(width: 18, height: 18)
        button.image = appIcon
      } else {
        button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Pastable")
      }
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // Enforce the configured history limit / retention for existing installs,
    // but never delete hundreds of legacy items without asking first.
    Task { @MainActor in
      await handleHistoryMaintenance()
    }
    #if DEBUG
    // UI automation / screenshot hook; compiled out of release builds.
    if ProcessInfo.processInfo.arguments.contains("--show-panel") {
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 400_000_000)
        self.openPanel()
      }
    }
    #endif

  }

  // MARK: - Maintenance

  @MainActor
  private func handleHistoryMaintenance() async {
    let preview = Storage.shared.maintenancePreview()

    guard preview.needsAttention else {
      await Storage.shared.performMaintenance()
      return
    }

    let snoozeUntil = UserDefaults.standard.double(forKey: Preferences.Key.maintenanceSnoozeUntil)
    if Date().timeIntervalSince1970 < snoozeUntil {
      // The user chose "Later" recently. Keep growing the store rather than
      // silently deleting items behind their back.
      Storage.shared.pauseAutomaticMaintenance()
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = NSLocalizedString("maintenance.title", comment: "Clean up history")
    alert.informativeText = String(
      format: NSLocalizedString("maintenance.message", comment: "Explain history cleanup"),
      preview.total,
      preview.limit,
      preview.expired,
      preview.suggestedLimit
    )
    alert.addButton(withTitle: NSLocalizedString("maintenance.clean", comment: "Clean up"))
    alert.addButton(withTitle: NSLocalizedString("maintenance.keep", comment: "Keep everything"))
    alert.addButton(withTitle: NSLocalizedString("maintenance.later", comment: "Later"))

    switch alert.runModal() {
    case .alertFirstButtonReturn:
      UserDefaults.standard.removeObject(forKey: Preferences.Key.maintenanceSnoozeUntil)
      Storage.shared.resumeAutomaticMaintenance()
      await Storage.shared.performMaintenance()

    case .alertSecondButtonReturn:
      UserDefaults.standard.removeObject(forKey: Preferences.Key.maintenanceSnoozeUntil)
      // Preserve the user's data and adjust the preferences so the prompt does
      // not come back on every launch.
      UserDefaults.standard.set(preview.suggestedLimit, forKey: Preferences.Key.historySize)
      UserDefaults.standard.set(0, forKey: Preferences.Key.historyRetentionDuration)
      Storage.shared.resumeAutomaticMaintenance()
      AppLogger.Storage.info("Kept \(preview.total) legacy items; raised limit to \(preview.suggestedLimit)")

    default:
      // Don't silently trim during this session (or for the next week).
      Storage.shared.pauseAutomaticMaintenance()
      let snooze = Date().addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970
      UserDefaults.standard.set(snooze, forKey: Preferences.Key.maintenanceSnoozeUntil)
    }
  }

  // MARK: - Panel

  @MainActor @objc func togglePanel() {
    if panel.isVisible {
      closePanel(restorePrevious: true)
      return
    }

    // A click on the status item closes the panel through `resignKey()` before
    // the button action fires. Ignore that same click so it does not reopen.
    if Date().timeIntervalSince(panel.lastClosedAt) < 0.25 {
      return
    }

    openPanel()
  }

  @MainActor func closePanel(restorePrevious: Bool = false) {
    panel.close()
    if restorePrevious {
      restorePreviousApplication()
    }
  }

  @MainActor func openPanel() {
    if let frontmost = NSWorkspace.shared.frontmostApplication,
       frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
      previousApplication = frontmost
    }

    // 激活应用，确保窗口能接收键盘事件
    NSApp.activate(ignoringOtherApps: true)

    // 重新定位到底部
    panel.positionAtBottom()

    // Avoid immediate close on first show due to transient focus loss
    panel.suppressResignKey(duration: 0.4)
    panel.orderFrontRegardless()
    panel.makeKey()
    panel.makeFirstResponder(nil)

    AppState.shared.isPanelVisible = true
    // CloudKit may have delivered a duplicate while the panel was closed.
    Storage.shared.deduplicateHistory()
    // Reset search on open. The search field deliberately does NOT take
    // keyboard focus: opening the panel (whichever way it was triggered) must
    // never steal typed input from whatever the user is doing. ⌘⇧F or a click
    // on the field focuses it. `makeFirstResponder(nil)` above plus this blur
    // request clear any focus the field still holds from a previous session.
    AppState.shared.searchText = ""
    AppState.shared.resetSelection()
    AppState.shared.searchFocusRequest = .blur
  }

  /// Return keyboard focus to the app the panel was opened over. Called before
  /// synthesizing Cmd+V; otherwise the paste can be delivered to Pastable.
  /// Returns the app that was activated so `Clipboard.paste(whenReadyFor:)` can
  /// wait for it to actually take focus before posting the keystroke.
  @MainActor @discardableResult
  func restorePreviousApplication() -> NSRunningApplication? {
    guard let previousApplication,
          previousApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
      return nil
    }

    previousApplication.activate(options: [])
    let restored = previousApplication
    self.previousApplication = nil
    return restored
  }

  // MARK: - Status item

  @MainActor @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    if NSApp.currentEvent?.type == .rightMouseUp {
      showStatusMenu()
    } else {
      togglePanel()
    }
  }

  @MainActor private func showStatusMenu() {
    let menu = NSMenu()

    let openItem = NSMenuItem(
      title: NSLocalizedString("menu.open", comment: "Open Pastable"),
      action: #selector(openFromMenu),
      keyEquivalent: ""
    )
    openItem.target = self
    menu.addItem(openItem)

    let settingsItem = NSMenuItem(
      title: NSLocalizedString("menu.settings", comment: "Settings"),
      action: #selector(openSettings),
      keyEquivalent: ","
    )
    settingsItem.target = self
    menu.addItem(settingsItem)

    let aboutItem = NSMenuItem(
      title: NSLocalizedString("menu.about", comment: "About"),
      action: #selector(openAbout),
      keyEquivalent: ""
    )
    aboutItem.target = self
    menu.addItem(aboutItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: NSLocalizedString("menu.quit", comment: "Quit"),
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  @MainActor @objc private func openFromMenu() {
    openPanel()
  }

  @MainActor @objc private func openSettings() {
    openSettingsWindow(tab: nil)
  }

  @MainActor @objc private func openAbout() {
    openSettingsWindow(tab: .about)
  }

  @MainActor @objc private func quit() {
    NSApp.terminate(nil)
  }

  /// Opens the Settings window, selecting `tab` when given.
  ///
  /// The SwiftUI `Settings` scene only responds to SwiftUI's own `openSettings`
  /// environment action. The classic AppKit `showSettingsWindow:` trick is
  /// accepted by `SwiftUI.AppDelegate` but silently does nothing in this app,
  /// so we use the action captured from the panel's hosted hierarchy at launch
  /// (see `SearchBar.onAppear`); it works even while the panel is closed.
  @MainActor func openSettingsWindow(tab: AppState.SettingsTab?) {
    if let tab {
      AppState.shared.settingsTab = tab
    }

    NSApp.activate(ignoringOtherApps: true)

    // Defer past any menu/popover tracking that is still unwinding: opening a
    // window from inside a tracking run loop is unreliable.
    Task { @MainActor in
      if let openSettings = AppState.shared.openSettingsAction {
        openSettings()
        return
      }
      // Fallback for the case the panel UI has not been evaluated yet.
      if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
      }
    }
  }

  // MARK: - Outside clicks

  private func setupOutsideClickMonitors() {
    // Local monitor (clicks while app is active)
    outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      Task { @MainActor in
        self?.handleOutsideClick()
      }
      return event
    }

    // Global monitor (clicks when app is inactive)
    outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      Task { @MainActor in
        self?.handleOutsideClick()
      }
    }
  }

  @MainActor private func handleOutsideClick() {
    guard panel.isVisible else { return }
    let mouseLocation = NSEvent.mouseLocation
    if !panel.frame.contains(mouseLocation) && !isPointInAnyAppWindow(mouseLocation) {
      panel.close()
    }
  }

  private func isPointInAnyAppWindow(_ point: NSPoint) -> Bool {
    if let statusWindow = statusItem.button?.window, statusWindow.frame.contains(point) {
      return true
    }

    for window in NSApp.windows where window.isVisible {
      if window.frame.contains(point) {
        return true
      }
    }
    return false
  }
}
