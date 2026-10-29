import AppKit
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel!
  var statusItem: NSStatusItem!
  private var outsideClickMonitor: Any?
  private var outsideClickGlobalMonitor: Any?
  private var panelClickMonitor: Any?
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

    // Follow the user across Spaces / fullscreen transitions. The shelf is
    // explicit-dismiss only: switching window, app or Space must never close
    // it (that used to make it "flash shut" whenever Cmd+Tab or a Space swipe
    // changed the frontmost app).
    observeWorkspaceChanges()

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

    // The panel used to close itself from `resignKey()` before this button
    // action fired. Ignore a toggle that lands within the same click so it
    // cannot immediately reopen the panel it just closed.
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
    if let frontmost = NSWorkspace.shared.frontmostApplication, Self.isPasteTarget(frontmost) {
      previousApplication = frontmost
    }

    // 激活应用，确保窗口能接收键盘事件
    NSApp.activate(ignoringOtherApps: true)

    // 重新定位到底部
    panel.positionAtBottom()

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

  /// Resolve the app a paste should be delivered to *right now*.
  ///
  /// The shelf stays open while the user switches to another window or app, so
  /// the app the panel was originally opened over may no longer be the one in
  /// front. Prefer whichever app is frontmost at paste time; only when Pastable
  /// itself (or a system UI agent such as Control Center) is active, fall back
  /// to — and re-activate — the last real app.
  /// Returns the app that must take focus before Cmd+V is posted.
  @MainActor func pasteTargetApplication() -> NSRunningApplication? {
    let frontmost = NSWorkspace.shared.frontmostApplication
    if let frontmost, Self.isPasteTarget(frontmost) {
      previousApplication = frontmost
      // The click that started this paste may have activated Pastable a beat
      // earlier (see the panel click monitor). Re-assert the target so the
      // synthesized Cmd+V cannot land on Pastable as it closes.
      frontmost.activate(options: [])
      return frontmost
    }
    return restorePreviousApplication()
  }

  /// Apps that can actually receive a synthesized Cmd+V. Menu-bar agents,
  /// Control Center, the Dock and similar system UI take focus while the shelf
  /// stays open but must never become the paste destination.
  private static func isPasteTarget(_ app: NSRunningApplication) -> Bool {
    guard !app.isTerminated,
          app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
    return app.activationPolicy == .regular
  }

  /// Return keyboard focus to the last app that was in front of the shelf
  /// (recorded on open, then kept current by the activation observer). Called
  /// before synthesizing Cmd+V; otherwise the paste can be delivered to
  /// Pastable. Returns the app that was activated so
  /// `Clipboard.paste(whenReadyFor:)` can wait for it to actually take focus
  /// before posting the keystroke.
  @MainActor @discardableResult
  func restorePreviousApplication() -> NSRunningApplication? {
    guard let previousApplication else { return nil }
    self.previousApplication = nil

    guard Self.isPasteTarget(previousApplication) else { return nil }

    previousApplication.activate(options: [])
    return previousApplication
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

  // MARK: - Workspace changes

  /// Keeps the shelf alive (and on the right Space) while the user moves
  /// between apps, windows and Spaces.
  ///
  /// The panel deliberately does not dismiss on focus loss: it is a
  /// non-activating shelf, and switching Space, entering fullscreen or using
  /// Cmd+Tab all take focus away for a moment. Closing on those events made it
  /// look like it "flashed shut" whenever another window became active.
  private func observeWorkspaceChanges() {
    let workspaceCenter = NSWorkspace.shared.notificationCenter

    // Remember the most recently used app, so a card click pastes into
    // whichever app the user is in *now* rather than the one the panel was
    // opened over.
    workspaceCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            Self.isPasteTarget(app) else { return }
      Task { @MainActor in
        guard let self, self.panel.isVisible else { return }
        self.previousApplication = app
      }
    }

    // `canJoinAllSpaces` normally moves the panel along, but during a
    // Space/fullscreen transition AppKit can leave a non-activating panel
    // behind or order it below the new Space's windows. Re-assert it once the
    // animation has settled.
    workspaceCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.panel.isVisible else { return }
        try? await Task.sleep(nanoseconds: 150_000_000)
        guard self.panel.isVisible else { return }
        self.panel.reassertOnActiveSpace()
      }
    }

    // Display (dis)connection / resolution change: re-anchor to the physical
    // bottom of the screen under the pointer.
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.panel.isVisible else { return }
        self.panel.positionAtBottom(animated: false)
      }
    }
  }

  // MARK: - Outside clicks

  private func setupOutsideClickMonitors() {
    // Local monitor (clicks while app is active)
    outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      let location = NSEvent.mouseLocation
      Task { @MainActor in
        self?.handleOutsideClick(at: location)
      }
      return event
    }

    // Global monitor (clicks when app is inactive)
    outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      let location = NSEvent.mouseLocation
      Task { @MainActor in
        self?.handleOutsideClick(at: location)
      }
    }

    // The panel is non-activating so it never steals focus when it appears.
    // But once it stays on screen while the user works elsewhere, clicking the
    // shelf itself (search field, filters, background) must make Pastable
    // active again — otherwise the caret would blink in the search field while
    // every keystroke still went to the other app. Deferred until after the
    // click is handled: a click on a card closes the panel, and that path must
    // not bounce activation through Pastable on its way to the target app.
    panelClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
      MainActor.assumeIsolated {
        guard let self, event.window === self.panel, self.panel.isVisible else { return }
        Task { @MainActor in
          guard self.panel.isVisible, !NSApp.isActive else { return }
          NSApp.activate(ignoringOtherApps: true)
          self.panel.makeKey()
        }
      }
      return event
    }
  }

  /// Any click outside the shelf dismisses it — another app's window, the menu
  /// bar, the Dock or the desktop. Clicks on Pastable's own UI (the status
  /// item, the Settings window, the panel's popover/menu) are part of the app
  /// and must not close it.
  @MainActor private func handleOutsideClick(at point: NSPoint) {
    guard panel.isVisible, !panel.frame.contains(point) else { return }
    if isPointOnOwnWindow(point) { return }
    panel.close()
  }

  private func isPointOnOwnWindow(_ point: NSPoint) -> Bool {
    if let statusWindow = statusItem.button?.window, statusWindow.frame.contains(point) {
      return true
    }

    // `isOnActiveSpace` matters: windows belonging to another Space share the
    // same screen coordinates and would otherwise swallow the click.
    for window in NSApp.windows where window.isVisible && window.isOnActiveSpace {
      if window.frame.contains(point) {
        return true
      }
    }

    return isPointOnOwnWindowAccordingToWindowServer(point)
  }

  /// `NSApp.windows` does not always contain the private windows AppKit uses
  /// for popovers and menus, so also ask WindowServer for the windows we own.
  private func isPointOnOwnWindowAccordingToWindowServer(_ point: NSPoint) -> Bool {
    guard let mainScreen = NSScreen.screens.first,
          let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
      return false
    }

    // NSEvent uses a bottom-left origin anchored at the main screen, the window
    // list uses a top-left origin anchored at the main screen. Mirror across
    // the main screen's top edge; this is valid for every attached display.
    let cgPoint = CGPoint(x: point.x, y: mainScreen.frame.maxY - point.y)
    return Self.isPoint(cgPoint, coveredBy: windows, ownedBy: Int(ProcessInfo.processInfo.processIdentifier))
  }

  /// Pure hit-test over WindowServer window dictionaries
  /// (`CGWindowListCopyWindowInfo`): does a visible window of `processID`
  /// cover the point? Fully transparent windows are ignored.
  static func isPoint(_ point: CGPoint, coveredBy windows: [[String: Any]], ownedBy processID: Int) -> Bool {
    for window in windows {
      guard let owner = window[kCGWindowOwnerPID as String] as? Int, owner == processID else { continue }
      guard let alpha = window[kCGWindowAlpha as String] as? Double, alpha > 0.01 else { continue }
      guard let boundsInfo = window[kCGWindowBounds as String] as? [String: Any],
            let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary) else { continue }
      if bounds.contains(point) {
        return true
      }
    }
    return false
  }
}
