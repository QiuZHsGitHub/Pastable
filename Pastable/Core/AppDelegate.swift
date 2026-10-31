import AppKit
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel!
  var statusItem: NSStatusItem!
  private var outsideClickMonitor: Any?
  private var outsideClickGlobalMonitor: Any?
  private var globalKeyMonitor: CFMachPort?
  private var globalKeyRunLoopSource: CFRunLoopSource?
  private var previousApplication: NSRunningApplication?
  private var searchFocusTask: Task<Void, Never>?

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

  func applicationWillTerminate(_ notification: Notification) {
    MainActor.assumeIsolated { stopGlobalKeyMonitor() }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    #if DEBUG
    // End-to-end UI tests launch with a temporary store and ask for a
    // deterministic history. Debug-only; production builds never seed.
    MainActor.assumeIsolated { seedDemoHistoryIfRequested() }
    #endif

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
    // The key-event tap lives only while the shelf is on screen, no matter
    // which code path closes the panel (Esc, outside click, paste, hotkey).
    panel.onClose = { [weak self] in
      MainActor.assumeIsolated { self?.stopGlobalKeyMonitor() }
    }
    panel.onHeaderMouseDown = { [weak self] in
      MainActor.assumeIsolated { self?.activatePanelForInteraction() }
    }
    panel.onSearchMouseDown = { [weak self] in
      MainActor.assumeIsolated { self?.focusPanelForSearch() }
    }

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

    // `--open-settings <general|storage|shortcuts|about>` lets the release
    // smoke test drive Settings without accessibility scripting.
    let arguments = ProcessInfo.processInfo.arguments
    if let index = arguments.firstIndex(of: "--open-settings"),
       arguments.indices.contains(index + 1) {
      let tab: AppState.SettingsTab?
      switch arguments[index + 1] {
      case "general": tab = .general
      case "storage": tab = .storage
      case "shortcuts": tab = .shortcuts
      case "about": tab = .about
      default: tab = nil
      }
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 600_000_000)
        self.openSettingsWindow(tab: tab)
      }
    }
    #endif

  }

  // MARK: - Debug seeding

#if DEBUG
  /// Seeds a deterministic demo history into the temporary store used by the
  /// end-to-end UI tests. Debug-only and a no-op on non-empty stores, so a
  /// relaunch test keeps whatever the previous run left behind.
  @MainActor
  private func seedDemoHistoryIfRequested() {
    guard ProcessInfo.processInfo.arguments.contains("--seed-demo-history") else { return }
    // Only ever seed a redirected store. A developer running the Debug app
    // against their real history must not get demo records injected.
    guard let storeOverride = ProcessInfo.processInfo.environment["PASTABLE_STORAGE_DIR"],
          !storeOverride.isEmpty else { return }
    let storage = Storage.shared
    guard storage.itemCount() == 0 else { return }

    let now = Date()
    var offset = 0

    func add(
      _ contents: [(NSPasteboard.PasteboardType, Data)],
      application: String,
      thumbnail: Data? = nil
    ) {
      let item = HistoryItem(contents: contents.map {
        HistoryItemContent(type: $0.0.rawValue, value: $0.1)
      })
      item.application = application
      item.firstCopiedAt = now.addingTimeInterval(TimeInterval(-offset * 60))
      item.lastCopiedAt = item.firstCopiedAt
      item.thumbnailData = thumbnail
      item.deriveDisplayMetadata()
      storage.addOrUpdate(item)
      offset += 1
    }

    func text(_ value: String) -> (NSPasteboard.PasteboardType, Data) {
      (NSPasteboard.PasteboardType.string, Data(value.utf8))
    }

    add([text("记得明天下午3点开会讨论新项目方案")], application: "com.apple.Notes")
    add([text("""
    func fetchData() async throws {
      let url = URL(string: "https://api.example.com")!
      let (data, _) = try await URLSession.shared.data(from: url)
      return try JSONDecoder().decode(Response.self, from: data)
    }
    """)], application: "com.apple.dt.Xcode")
    add([text("https://github.com/apple/swift")], application: "com.apple.Safari")
    add([text("""
    .card {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border-radius: 12px;
      padding: 16px;
    }
    """)], application: "com.microsoft.VSCode")
    add([text("""
    {
      "name": "Pastable",
      "version": "1.2.1",
      "private": true
    }
    """)], application: "com.microsoft.VSCode")
    add([text("git commit -m \"feat: add clipboard manager\"")], application: "com.apple.Terminal")
    add([text("#C8402E")], application: "com.figma.Desktop")
    add(
      [text(String(repeating: "Long note about clipboard ergonomics. ", count: 12))],
      application: "com.google.Chrome"
    )

    if let png = Self.demoScreenshotPNG() {
      add(
        [(NSPasteboard.PasteboardType.png, png)],
        application: "com.apple.Safari",
        thumbnail: HistoryItem.thumbnailData(from: png)
      )
    }

    let samples = (storage.url?.deletingLastPathComponent() ?? FileManager.default.temporaryDirectory)
      .appendingPathComponent("SeedSamples", isDirectory: true)
    try? FileManager.default.createDirectory(at: samples, withIntermediateDirectories: true)
    let plan = samples.appendingPathComponent("Q4 launch plan.md")
    let budget = samples.appendingPathComponent("budget-2026.csv")
    try? "# Q4 launch plan\n\n- Ship 1.2.1\n- Write release notes\n".write(
      to: plan,
      atomically: true,
      encoding: .utf8
    )
    try? "quarter,revenue\nQ3,98000\nQ4,120000\n".write(
      to: budget,
      atomically: true,
      encoding: .utf8
    )
    add([
      (NSPasteboard.PasteboardType.fileURL, plan.dataRepresentation),
      (NSPasteboard.PasteboardType.fileURL, budget.dataRepresentation)
    ], application: "com.apple.finder")

    add([
      text("Pastable rich text sample"),
      (NSPasteboard.PasteboardType.html, Data("<b>Pastable rich text sample</b>".utf8))
    ], application: "com.apple.Notes")
  }

  private static func demoScreenshotPNG() -> Data? {
    let width = 720
    let height = 420
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let colors = [
      NSColor(srgbRed: 0.16, green: 0.36, blue: 0.86, alpha: 1).cgColor,
      NSColor(srgbRed: 0.55, green: 0.24, blue: 0.78, alpha: 1).cgColor
    ] as CFArray
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: colors,
      locations: [0, 1]
    ) {
      context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: width, y: height),
        options: []
      )
    }

    context.setFillColor(NSColor.white.withAlphaComponent(0.18).cgColor)
    for index in 0..<4 {
      let inset = CGFloat(48 + index * 34)
      context.fillEllipse(
        in: CGRect(x: inset, y: CGFloat(height) - inset - 90, width: 180, height: 180)
      )
    }
    context.setFillColor(NSColor.black.withAlphaComponent(0.22).cgColor)
    context.fill(CGRect(x: 56, y: 60, width: 430, height: 22))
    context.fill(CGRect(x: 56, y: 100, width: 300, height: 14))

    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  }
#endif

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
    stopGlobalKeyMonitor()
    panel.close()
    if restorePrevious {
      restorePreviousApplication()
    }
  }

  @MainActor func openPanel() {
    if let frontmost = NSWorkspace.shared.frontmostApplication, Self.isPasteTarget(frontmost) {
      previousApplication = frontmost
    }

    // Deliberately no NSApp.activate / makeKey here. The shelf is a
    // non-activating HUD: the document keeps the keyboard, and the key tap
    // below routes only the shelf's navigation shortcuts to us. This is what
    // makes "keep typing while the shelf is open" actually true.
    panel.positionAtBottom()
    panel.orderFrontRegardless()

    AppState.shared.isPanelVisible = true
    // CloudKit may have delivered a duplicate while the panel was closed.
    Storage.shared.deduplicateHistory()
    // Reset search on open. The search field deliberately does NOT take
    // keyboard focus: opening the panel (whichever way it was triggered) must
    // never steal typed input from whatever the user is doing. ⌘⇧F or a click
    // on the field focuses it.
    AppState.shared.searchText = ""
    AppState.shared.resetSelection()
    AppState.shared.searchFocusRequest = .blur

    startGlobalKeyMonitor()
  }

  // MARK: - Keyboard focus handoff

  /// Called when the user explicitly asks for the search field (⌘⇧F or a click
  /// in the type-to-search row). Only then does Pastable become active/key.
  ///
  /// Activation is asynchronous on macOS 14+. Wait until the panel is actually
  /// frontmost before sending the SwiftUI focus signal, otherwise FocusState
  /// turns true while keystrokes still go to the previous app.
  @MainActor func focusPanelForSearch() {
    guard panel.isVisible else { return }
    if NSApp.isActive && panel.isKeyWindow {
      AppState.shared.searchFocusRequest = .focus
      return
    }

    searchFocusTask?.cancel()
    searchFocusTask = Task { @MainActor [weak self] in
      guard let self else { return }

      for _ in 0..<8 {
        guard self.panel.isVisible else { return }
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        self.panel.makeKey()
        if NSApp.isActive && self.panel.isKeyWindow { break }
        try? await Task.sleep(nanoseconds: 60_000_000)
      }

      guard self.panel.isVisible else { return }
      AppState.shared.searchFocusRequest = .focus
      ReviewPrompt.shared.requestIfNeeded(from: self.panel.reviewController)
    }
  }

  /// Give the keyboard back to the document after the search field (or a
  /// non-text control) is done. The shelf stays visible and keeps working.
  @MainActor func releasePanelFocus() {
    guard panel.isVisible, NSApp.isActive || panel.isKeyWindow else { return }
    panel.makeFirstResponder(nil)
    panel.resignKey()
    if restorePreviousApplication() == nil {
      NSApp.deactivate()
    }
  }

  @MainActor private func activatePanelForInteraction() {
    guard panel.isVisible else { return }
    if !NSApp.isActive {
      NSApp.activate(ignoringOtherApps: true)
    }
    if !panel.isKeyWindow {
      panel.makeKey()
    }
    // The review prompt is deliberately deferred until the next time the panel
    // is legitimately hosting a focused interaction; opening it no longer
    // activates the app, so asking there would steal focus.
    ReviewPrompt.shared.requestIfNeeded(from: panel.reviewController)
  }

  // MARK: - Global key tap

  /// The shelf is a non-activating HUD, so the document keeps the keyboard.
  /// A session event tap consumes only the shelf's navigation keys (arrows,
  /// Return, Esc, ⌘1…9, ⌘⌫, ⌘⇧F) and lets every printable character reach the
  /// focused text field. It requires Accessibility + Input Monitoring; when
  /// the tap cannot run, mouse interaction still works and typing is never
  /// stolen.
  @MainActor private func startGlobalKeyMonitor() {
    // The tap needs both Accessibility and Input Monitoring. Without the
    // latter it would be created but never receive keys; skipping it keeps the
    // panel usable (mouse + preserved typing) instead of silently failing.
    guard globalKeyMonitor == nil,
          panel.isVisible,
          AXIsProcessTrusted(),
          CGPreflightListenEventAccess() else { return }

    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: Self.globalKeyCallback,
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else { return }

    globalKeyMonitor = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    globalKeyRunLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  @MainActor private func stopGlobalKeyMonitor() {
    if let source = globalKeyRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
    if let tap = globalKeyMonitor {
      CGEvent.tapEnable(tap: tap, enable: false)
      CFMachPortInvalidate(tap)
    }
    globalKeyRunLoopSource = nil
    globalKeyMonitor = nil
  }

  @MainActor private func restartGlobalKeyMonitor() {
    guard let tap = globalKeyMonitor else { return }
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  private static let globalKeyCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      MainActor.assumeIsolated { delegate.restartGlobalKeyMonitor() }
      return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else { return Unmanaged.passUnretained(event) }
    let consumed = MainActor.assumeIsolated { delegate.handleGlobalKey(event) }
    return consumed ? nil : Unmanaged.passUnretained(event)
  }

  @MainActor private func handleGlobalKey(_ event: CGEvent) -> Bool {
    guard panel.isVisible, NSApp.modalWindow == nil else { return false }
    // A Settings window or an open popover owns its own arrow/Return handling.
    if NSApp.isActive, let keyWindow = NSApp.keyWindow, keyWindow !== panel {
      return false
    }

    let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
      .intersection(.deviceIndependentFlagsMask)
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

    switch keyCode {
    case 53: // Escape
      closePanel(restorePrevious: true)
      return true

    case 36, 76: // Return / keypad Enter
      guard !flags.contains(.command), !flags.contains(.option) else { return false }
      if let item = AppState.shared.item(with: AppState.shared.selectedItemID)
        ?? AppState.shared.displayItems.first {
        paste(item: item)
        return true
      }
      return false

    case 51 where flags.contains(.command): // Cmd + Delete
      guard let item = AppState.shared.item(with: AppState.shared.hoveredItemID)
        ?? AppState.shared.item(with: AppState.shared.selectedItemID) else {
        return false
      }
      delete(item: item)
      return true

    case 123, 124: // Left / Right
      // Arrow events carry undocumented/function/numericPad bits (synthetic
      // events even include 0x20000000). Only the modifiers that change the
      // meaning of navigation should block it.
      let navigationFlags = flags.intersection([.command, .option, .control, .shift])
      guard AppState.shared.searchText.isEmpty, navigationFlags.isEmpty else { return false }
      AppState.shared.moveSelection(by: keyCode == 123 ? -1 : 1)
      return true

    default:
      break
    }

    // ⌘⇧F focuses the search field (the panel is not key yet, so the SwiftUI
    // keyboard shortcut cannot fire on its own).
    if keyCode == 3, flags.contains(.command), flags.contains(.shift) {
      focusPanelForSearch()
      return true
    }

    let disallowedFlags: NSEvent.ModifierFlags = [.option, .control]
    if flags.intersection(disallowedFlags).isEmpty,
       flags.contains(.command) || flags.contains(.function),
       let index = Self.digitIndex(
         keyCode: keyCode,
         characters: NSEvent(cgEvent: event)?.charactersIgnoringModifiers
       ) {
      let items = AppState.shared.displayItems
      if items.indices.contains(index) {
        paste(item: items[index])
        return true
      }
    }
    return false
  }

  private static func digitIndex(keyCode: UInt16, characters: String?) -> Int? {
    let numberKeys: [UInt16: Int] = [
      18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
    ]
    if let index = numberKeys[keyCode] {
      return index - 1
    }

    let functionKeys: [UInt16: Int] = [
      122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9
    ]
    if let index = functionKeys[keyCode] {
      return index - 1
    }

    if let characters, let number = Int(characters), number >= 1, number <= 9 {
      return number - 1
    }
    return nil
  }

  // MARK: - Paste / delete

  /// Single implementation used by both the in-panel keyboard monitor and the
  /// global key tap. Closes the shelf first, then resolves the paste target so
  /// the synthesized ⌘V lands in whatever app is in front at that moment.
  @MainActor func paste(item: HistoryItem) {
    AppState.shared.selectedItemID = item.persistentModelID
    closePanel()
    let target = pasteTargetApplication()

    item.lastCopiedAt = Date()
    item.numberOfCopies += 1
    do {
      try Storage.shared.context.save()
    } catch {
      AppLogger.Storage.error("Failed to save paste timestamp", error: error)
    }

    Clipboard.shared.copy(item)
    Task { @MainActor in
      if await Clipboard.shared.paste(whenReadyFor: target) {
        ReviewPrompt.shared.recordSuccessfulPaste()
      }
    }
  }

  @MainActor func delete(item: HistoryItem) {
    Storage.shared.context.delete(item)
    do {
      try Storage.shared.context.save()
    } catch {
      AppLogger.Storage.error("Failed to delete history item", error: error)
    }
    if AppState.shared.selectedItemID == item.persistentModelID {
      AppState.shared.resetSelection()
    }
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
