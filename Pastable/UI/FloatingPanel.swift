import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
  
  /// 内容视图的自然高度
  private var contentHeight: CGFloat = 357
  private var suppressResignKeyUntil: Date?
  
  init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
    super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView], backing: backing, defer: flag)
    
    self.isFloatingPanel = true
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    self.backgroundColor = .clear
    self.isOpaque = false
    self.hasShadow = true 
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = false // 禁止拖动
    self.hidesOnDeactivate = false
  }
  
  // Close automatically when out of focus, e.g. outside click.
  override func resignKey() {
    if let until = suppressResignKeyUntil, Date() < until {
      return
    }
    super.resignKey()
    close()
  }
  
  override func close() {
    super.close()
    Task { @MainActor in
      AppState.shared.isPanelVisible = false
    }
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
  
  /// 将窗口定位到屏幕底部，全宽，高度跟随内容
  func positionAtBottom(animated: Bool = true) {
    guard let screen = NSScreen.main else { return }
    
    let screenFrame = screen.frame
    let panelHeight = contentHeight
    let panelWidth = screenFrame.width
    
    let finalFrame = NSRect(
      x: screenFrame.origin.x,
      y: 0,  // 屏幕底部
      width: panelWidth,
      height: panelHeight
    )
    
    if animated && self.isVisible {
      self.setFrame(finalFrame, display: true, animate: true)
    } else {
      self.setFrame(finalFrame, display: true)
    }
  }
  
  /// 从底部滑入显示
  func slideIn() {
    guard let screen = NSScreen.main else { return }
    
    let screenFrame = screen.frame
    let panelHeight = contentHeight
    let panelWidth = screenFrame.width
    
    // 最终位置（底部对齐）
    let finalFrame = NSRect(
      x: screenFrame.origin.x,
      y: 0,  // 屏幕底部
      width: panelWidth,
      height: panelHeight
    )
    
    // 初始位置（隐藏在屏幕下方）
    let startFrame = NSRect(
      x: screenFrame.origin.x,
      y: -panelHeight,  // 屏幕下方
      width: panelWidth,
      height: panelHeight
    )
    
    // 设置初始位置
    self.setFrame(startFrame, display: false)
    self.makeKeyAndOrderFront(nil)
    
    // 动画滑入
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.3
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      self.animator().setFrame(finalFrame, display: true)
    })
  }
  
  /// 滑出隐藏
  func slideOut(completion: (() -> Void)? = nil) {
    guard NSScreen.main != nil else {
      self.orderOut(nil)
      completion?()
      return
    }
    
    let panelHeight = self.frame.height
    
    // 目标位置（隐藏在屏幕下方）
    let targetFrame = NSRect(
      x: self.frame.origin.x,
      y: -panelHeight,  // 移到屏幕下方
      width: self.frame.width,
      height: panelHeight
    )
    
    // 动画滑出
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.25
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      self.animator().setFrame(targetFrame, display: true)
    }, completionHandler: {
      self.orderOut(nil)
      completion?()
    })
  }
}

// MARK: - Preview

#Preview("浮动面板内容") {
  ContentView()
    .frame(maxWidth: .infinity)
    .modelContainer(for: HistoryItem.self, inMemory: true)
}
