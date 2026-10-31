import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {

  /// 内容视图的自然高度
  private var contentHeight: CGFloat = 357
  private var isClosing = false

  /// A tiny controller whose view lives in the panel. StoreKit 2 needs an
  /// `NSViewController` that can host its review sheet; the shelf itself is
  /// built with a plain `NSView`, so this gives the request a legitimate host
  /// without changing the content hierarchy.
  private(set) var reviewController: NSViewController?

  /// Used to avoid immediately re-opening the panel from the same status-item
  /// click that just closed it.
  private(set) var lastClosedAt: Date = .distantPast

  /// Called for every close path (Esc, outside click, paste, hotkey) so the
  /// global key tap can be torn down exactly once.
  var onClose: (() -> Void)?

  /// Called before the first click in the type-to-search row is dispatched.
  /// The panel is not key, so this is where the app activates itself just in
  /// time for the search field (or a category tab) to receive the click.
  var onHeaderMouseDown: (() -> Void)?

  /// Called for the first click in the search row while the panel is not yet
  /// active. The click is swallowed and focus is handed over asynchronously,
  /// which avoids AppKit deactivating the app mid-click.
  var onSearchMouseDown: (() -> Void)?

  private var swallowNextMouseUp = false

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

  // The panel is a shelf: it stays on screen while the user keeps working in
  // other windows / apps / Spaces. Dismissal is explicit (Esc, the global
  // shortcut, a paste, or a click on the desktop), so losing key focus — which
  // happens on every Space change, Cmd+Tab or click into another app — must
  // not tear it down. `NSApplication.didResignActiveNotification` is likewise
  // not observed any more; see `AppDelegate`.

  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown {
      swallowNextMouseUp = false
    }
    if event.type == .leftMouseUp, swallowNextMouseUp {
      swallowNextMouseUp = false
      return
    }

    if event.type == .leftMouseDown, isVisible {
      let localPoint = event.locationInWindow
      let panelHeight = contentView?.bounds.height ?? frame.height
      if localPoint.y >= panelHeight - 72 {
        let searchMinX = frame.width - 440
        let searchMaxX = frame.width - 74
        let inSearchRow = localPoint.x >= searchMinX && localPoint.x <= searchMaxX
        if inSearchRow, !NSApp.isActive || !isKeyWindow {
          // Swallow the first click: AppKit would otherwise deactivate us a
          // beat later, before the text field can become first responder.
          swallowNextMouseUp = true
          onSearchMouseDown?()
          return
        }
        onHeaderMouseDown?()
      }
    }
    super.sendEvent(event)
  }

  override func close() {
    guard !isClosing else { return }
    isClosing = true
    lastClosedAt = Date()
    super.close()
    isClosing = false

    AppState.shared.isPanelVisible = false
    onClose?()
    // Persist the deferred card artifacts (generated thumbnails etc.) while the
    // shelf is idle instead of waiting out the debounce timer.
    DeferredModelWriter.shared.flush()
  }

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }

  /// Bring the shelf back to the front of the currently active Space without
  /// activating the app or stealing keyboard focus. Called after a Space /
  /// fullscreen transition, where AppKit can leave a non-activating panel
  /// behind even though it joined all Spaces.
  func reassertOnActiveSpace() {
    guard isVisible, !isClosing else { return }
    orderFrontRegardless()
  }

  func setContent<Content: View>(view: Content) {
    // The shelf is a non-activating HUD. `acceptsFirstMouse` makes the first
    // click on a card act immediately instead of merely making the window key.
    let hostingView = ShelfHostingView(rootView: view)
    self.contentView = hostingView

    let reviewHost = NSViewController()
    let reviewView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    reviewView.wantsLayer = true
    reviewView.layer?.backgroundColor = NSColor.clear.cgColor
    reviewHost.view = reviewView
    hostingView.addSubview(reviewView)
    reviewController = reviewHost

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

/// Hosting view that lets the first click reach the SwiftUI controls while the
/// panel is not the key window.
private final class ShelfHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Preview

#Preview("浮动面板内容") {
  ContentView()
    .frame(maxWidth: .infinity)
    .modelContainer(for: HistoryItem.self, inMemory: true)
}
