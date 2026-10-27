import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {

  /// 内容视图的自然高度
  private var contentHeight: CGFloat = 357
  private var suppressResignKeyUntil: Date?
  private var isClosing = false

  /// Used to avoid immediately re-opening the panel when a click on the status
  /// item first causes `resignKey()` -> `close()` and then triggers the toggle action.
  private(set) var lastClosedAt: Date = .distantPast

  init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
    super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView], backing: backing, defer: flag)

    // The app keeps a strong reference to the panel and reuses it forever.
    // Without this, AppKit may release the window when it is closed and the
    // next `openPanel()` would message a dangling object.
    self.isReleasedWhenClosed = false

    self.isFloatingPanel = true
    self.level = .statusBar
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    self.backgroundColor = .clear
    self.isOpaque = false
    self.hasShadow = true
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = false // 禁止拖动
    self.hidesOnDeactivate = false
  }

  // Close automatically when out of focus, e.g. outside click. The small delay
  // lets a SwiftUI popover or the Settings window become key without tearing
  // the panel (and the popover) down first.
  override func resignKey() {
    super.resignKey()

    if isClosing { return }
    if let until = suppressResignKeyUntil, Date() < until {
      return
    }

    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 90_000_000)
      guard let self, self.isVisible, !self.isClosing else { return }

      // If another Pastable window (popover/settings) took focus, keep the panel.
      if NSApp.isActive {
        let otherWindowIsFocused = NSApp.windows.contains { window in
          window !== self &&
            window.isVisible &&
            (window.isKeyWindow || window.level.rawValue > self.level.rawValue)
        }
        if otherWindowIsFocused { return }
      }

      self.close()
    }
  }

  override func close() {
    guard !isClosing else { return }
    isClosing = true
    lastClosedAt = Date()
    super.close()
    isClosing = false

    AppState.shared.isPanelVisible = false
  }

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }

  func suppressResignKey(duration: TimeInterval) {
    suppressResignKeyUntil = Date().addingTimeInterval(duration)
  }

  func setContent<Content: View>(view: Content) {
    let hostingView = NSHostingView(rootView: view)
    self.contentView = hostingView

    // 获取内容的自然高度
    hostingView.layoutSubtreeIfNeeded()
    let fittingSize = hostingView.fittingSize
    contentHeight = fittingSize.height > 0 ? fittingSize.height : 357

    // 设置初始位置
    positionAtBottom(animated: false)
  }

  /// 将窗口定位到鼠标所在屏幕的物理底部，全宽，高度跟随内容。
  /// 使用 `screen.frame` 而不是 `visibleFrame`：后者会在当前显示程序坞的
  /// 那块屏幕上预留程序坞高度，导致面板在扩展屏上被顶起（内置屏不显示
  /// 程序坞时则正常）。面板层级高于 Dock，程序坞展示就展示，不为其预留
  /// 空间，所有屏幕都贴物理底边。
  func positionAtBottom(animated: Bool = true) {
    let mouseLocation = NSEvent.mouseLocation
    let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    guard let screen else { return }

    let screenFrame = screen.frame
    let panelHeight = min(contentHeight, screenFrame.height)
    let finalFrame = NSRect(
      x: screenFrame.origin.x,
      y: screenFrame.origin.y,
      width: screenFrame.width,
      height: panelHeight
    )

    if animated && self.isVisible {
      self.setFrame(finalFrame, display: true, animate: true)
    } else {
      self.setFrame(finalFrame, display: true)
    }
  }
}

// MARK: - Preview

#Preview("浮动面板内容") {
  ContentView()
    .frame(maxWidth: .infinity)
    .modelContainer(for: HistoryItem.self, inMemory: true)
}
