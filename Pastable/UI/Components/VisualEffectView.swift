import SwiftUI
import AppKit

/// macOS 原生毛玻璃效果视图
struct VisualEffectView: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .menu
  var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
  var state: NSVisualEffectView.State = .active
  
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = state
    return view
  }
  
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
    nsView.state = state
  }
}

#Preview("毛玻璃效果") {
  ZStack {
    Image(systemName: "photo.artframe")
      .resizable()
      .frame(width: 200, height: 200)
    
    VisualEffectView(material: .menu)
      .frame(width: 150, height: 100)
  }
  .frame(width: 300, height: 300)
}
