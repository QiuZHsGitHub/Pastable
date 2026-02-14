import AppKit
import SwiftUI
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {
  var panel: FloatingPanel!
  var statusItem: NSStatusItem!
  private var outsideClickMonitor: Any?
  private var outsideClickGlobalMonitor: Any?
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register AppDelegate in AppState
    AppState.shared.appDelegate = self
    
    // Start Clipboard Monitoring
    Clipboard.shared.start()
    
    // Setup HotKey
    KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
      self?.togglePanel()
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
    
    // Status Bar Item
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
      if let appIcon = NSImage(named: "icon_status_bar_logo") {
        appIcon.size = NSSize(width: 18, height: 18)
        button.image = appIcon
      } else {
        button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Pastable")
      }
      button.action = #selector(togglePanel)
    }
    
    // Hide Dock Icon
    NSApp.setActivationPolicy(.accessory)
    
    // Perform Cleanup
    let retentionDuration = UserDefaults.standard.integer(forKey: "historyRetentionDuration")
    if retentionDuration > 0 {
      // 使用 Task 在后台执行清理，避免阻塞启动
      Task {
        await Storage.shared.cleanup(retentionDuration: retentionDuration)
      }
    }
  }
  
  @MainActor @objc func togglePanel() {
    if panel.isVisible {
      closePanel()
    } else {
      openPanel()
    }
  }
  
  @MainActor func closePanel() {
    panel.close()
  }
  
  @MainActor func openPanel() {
    // 激活应用，确保窗口能接收键盘事件
    NSApp.activate(ignoringOtherApps: true)
    
    // 重新定位到底部
    panel.positionAtBottom()
    
    // Avoid immediate close on first show due to transient focus loss
    panel.suppressResignKey(duration: 0.3)
    panel.orderFrontRegardless()
    panel.makeKey()
    panel.makeFirstResponder(nil)
    
    AppState.shared.isPanelVisible = true
    // Reset search on open
    AppState.shared.searchText = ""
  }
  
  private func setupOutsideClickMonitors() {
    // Local monitor (clicks while app is active)
    outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      self?.handleOutsideClick()
      return event
    }
    
    // Global monitor (clicks when app is inactive)
    outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      self?.handleOutsideClick()
    }
  }
  
  @MainActor private func handleOutsideClick() {
    guard panel.isVisible else { return }
    let mouseLocation = NSEvent.mouseLocation
    if !panel.frame.contains(mouseLocation) && !isPointInAnyAppWindow(mouseLocation) {
      closePanel()
    }
  }
  
  private func isPointInAnyAppWindow(_ point: NSPoint) -> Bool {
    for window in NSApp.windows where window.isVisible {
      if window.frame.contains(point) {
        return true
      }
    }
    return false
  }
}
