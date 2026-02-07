import SwiftUI

struct CardCell: View {
  let item: HistoryItem
  var isSelected: Bool = false
  var onCopy: (() -> Void)? = nil
  
  @State private var isHovered: Bool = false
  @State private var fileThumbnail: NSImage? = nil
  @State private var appIconImage: NSImage? = nil // Fix: Store distinct image state
  @State private var fileIconImage: NSImage? = nil // Fix: Store file icon state
  @ObservedObject var themeManager = ThemeManager.shared
  private let imageCache = ImageCache.shared
  
  var body: some View {
    ZStack {
      // 背景渐变
      backgroundGradient
      
      // 右下角模糊装饰圆形
      Circle()
        .fill(Color.white.opacity(0.05))
        .frame(width: 112, height: 112)
        .blur(radius: 24)
        .offset(x: 60, y: 80)
      
      // 主内容
      VStack(alignment: .leading, spacing: 8) {
        // Header
        HStack {
          Text(cardTitle)
            .font(.system(size: 16))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.trailing, 40)
          
          Spacer()
        }
        
        // Content Preview
        if let image = item.image {
          // Case A: Direct Image Data (Screenshots, etc.)
          Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(4)
        } else if item.isFile, item.fileURLs.first != nil {
           // Case B: Files
           // check if image file
           if item.isImageFile {
             if let thumb = fileThumbnail {
               // Case B.1: Image File Preview (Thumbnail)
               Image(nsImage: thumb)
                 .resizable()
                 .aspectRatio(contentMode: .fit)
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
                 .cornerRadius(4)
             }
           } else {
             // Case B.2: Generic File Icon
             if let icon = fileIconImage {
               VStack {
                 Image(nsImage: icon)
                   .resizable()
                   .aspectRatio(contentMode: .fit)
                   .frame(width: 112, height: 112)
                 Spacer()
               }
               .frame(maxWidth: .infinity, maxHeight: .infinity)
               .padding(.top, 20)
             } else {
               ProgressView()
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
             }
           }
        } else {
          // Case C: Text or Color
          if let hexCode = item.hexColor {
            // Case C.1: Hex Color Preview (Full Fill)
            Color(hex: hexCode)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .frame(minHeight: 120) // Ensure it takes up space even if empty? Text cards are usually fixed height.
              .cornerRadius(4)
          } else {
            // Case C.2: Regular Text (Preview)
            Group {
              if let attrStr = cachedAttributedText {
                Text(attrStr)
                  .frame(width: 236, alignment: .topLeading)
                  .multilineTextAlignment(.leading)
              } else {
                Text(item.previewableText)
                  .font(item.isCode ? .system(size: 13, design: .monospaced) : .system(size: 13))
                  .foregroundColor(Color(hex: "#FFFFFF").opacity(0.8))
                  .multilineTextAlignment(.leading)
                  .frame(width: 236, alignment: .topLeading)
              }
            }
            .lineLimit(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Group {
                    if let bgColor = contentBackgroundColor {
                        bgColor
                    } else if let hex = item.cachedRTFBackgroundHexColor {
                        Color(hex: hex)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(4)
          }
        }
        
        // Footer
        HStack {
          Text(item.firstCopiedAt.timeAgoDisplay())
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.6))
          
          Spacer()
          
          Text("\(item.previewableText.count) chars")
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.6))
          
          Text(contentTypeLabel)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.2))
            .overlay(alignment: .bottom) {
                 Rectangle()
                   .fill(categoryIndicatorColor)
                   .frame(height: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .foregroundColor(.white.opacity(0.8))
        }
      }
      .padding(12)
      

      
      // App Icon (Watermark style) - 展示在右上角 (Z-Index Top)
      if let icon = appIconImage {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 70, height: 70)
          .cornerRadius(8)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .padding(.top, -15)
          .padding(.trailing, -15)
      }
    }
    .frame(width: 260, height: 241)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 10)
    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
    .scaleEffect(isHovered ? 1.05 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: isHovered)
    .animation(nil, value: fileThumbnail)
    .animation(nil, value: appIconImage)
    .animation(nil, value: fileIconImage)
    .animation(nil, value: adaptiveColor)
    .animation(nil, value: cachedAttributedText)
    .animation(nil, value: contentBackgroundColor)
    .onHover { hovering in
      isHovered = hovering
    }
    .task(id: item.persistentModelID) {
      let itemId = item.persistentModelID
      let isAdaptiveMode = ThemeManager.shared.currentMode == .adaptive
      let cachedAdaptiveHex = item.cachedAdaptiveHexColor
      let cachedRTFBackgroundHex = item.cachedRTFBackgroundHexColor
      let rtfData = item.rtfData
      let fileURL = item.fileURLs.first
      let isImageFile = item.isImageFile
      let isFile = item.isFile
      let appBundleId = item.application

      // 1. Load File Thumbnail
      if isImageFile, let url = fileURL {
        Task.detached(priority: .userInitiated) {
          let thumb = self.imageCache.thumbnail(forURL: url) { HistoryItem.loadThumbnail(for: $0) }
          await MainActor.run {
            guard item.persistentModelID == itemId else { return }
            fileThumbnail = thumb
          }
        }
      }
      
      // 2. Load App Icon
      if let bundleId = appBundleId,
         let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.path {
        Task.detached(priority: .userInitiated) {
          let icon = self.imageCache.appIcon(forBundleId: bundleId, path: path)
          var adaptive: Color? = nil
          var adaptiveHexToCache: String? = nil
          
          if isAdaptiveMode {
            if let cachedHex = cachedAdaptiveHex {
              adaptive = Color(hex: cachedHex)
            } else if let color = icon?.averageColor() {
              adaptive = color
              adaptiveHexToCache = color.toHex()
            }
          }
          
          await MainActor.run {
            guard item.persistentModelID == itemId else { return }
            appIconImage = icon
            if let adaptive = adaptive {
              self.adaptiveColor = adaptive
            }
            if let adaptiveHexToCache = adaptiveHexToCache {
              item.cachedAdaptiveHexColor = adaptiveHexToCache
            }
          }
        }
      }
      
      // 3. Load Generic File Icon
      if isFile, !isImageFile, let url = fileURL {
        Task.detached(priority: .userInitiated) {
          let icon = self.imageCache.fileIcon(forPath: url.path)
          await MainActor.run {
            guard item.persistentModelID == itemId else { return }
            fileIconImage = icon
          }
        }
      }
      
      // 5. Load RTF Content & Background (Optimization)
      
      // A. Try Color Cache First (For Background)
      if let cachedHex = cachedRTFBackgroundHex {
           self.contentBackgroundColor = Color(hex: cachedHex)
      }
      
      // B. Parse RTF Async (To get the text & validation)
      if let rtfData = rtfData, self.cachedAttributedText == nil {
          Task.detached(priority: .userInitiated) {
              // Reconstruct attributed string from Data on background thread
              if let rtf = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                  let attrStr = AttributedString(rtf)
                  let bgColor = rtf.effectiveBackgroundColor
                  
                  await MainActor.run {
                      guard item.persistentModelID == itemId else { return }
                      self.cachedAttributedText = attrStr
                      // Update active background color from actual content (self-healing)
                      self.contentBackgroundColor = bgColor
                      
                      // Cache the background color if missing
                      if item.cachedRTFBackgroundHexColor == nil, let color = bgColor, let hex = color.toHex() {
                          item.cachedRTFBackgroundHexColor = hex
                      }
                  }
              }
          }
      }
    }
  }
  
  // MARK: - Private Properties
  @State private var adaptiveColor: Color? = nil
  @State private var cachedAttributedText: AttributedString? = nil
  @State private var contentBackgroundColor: Color? = nil
  
  private var categoryIndicatorColor: Color {
      if item.isCode { return Color(hex: "#3B82F6") } // Code: Blue
      if item.isLink { return Color(hex: "#A855F7") } // Link: Purple
      if item.isImage || item.isFile { return Color(hex: "#EC4899") } // Others: Pink
      return Color(hex: "#9CA3AF") // Text/Default: Gray
  }
  
  @ViewBuilder
  private var backgroundGradient: some View {
    let palette = ThemeManager.shared.activePalette
    
    // 1. Priority: Adaptive App Color (Source-based)
    if ThemeManager.shared.currentMode == .adaptive {
        if let adaptive = adaptiveColor {
            adaptive
        } else if let cachedHex = item.cachedAdaptiveHexColor {
             Color(hex: cachedHex)
        }
    } 
    // 2. Priority: Theme Palette (Category-based)
    else {
        if item.isCode {
          palette.codeColor
        } else if item.isLink {
          palette.linkColor
        } else if item.isImage || item.isFile {
          palette.otherColor
        } else {
          // Text or Color (Hex Code falls here, usually implies Text category)
          palette.textColor
        }
    }
  }
  
  private var cardTitle: String {
    // 1. If it's a file, always show the filename (ignoring potentially stale item.title)
    if item.isFile, let fileURL = item.fileURLs.first {
      return fileURL.lastPathComponent.removingPercentEncoding ?? fileURL.lastPathComponent
    }
    
    // 2. Use stored title if available
    if !item.title.isEmpty {
      return item.title
    }
    
    // 3. Fallback
    return String(item.previewableText.prefix(50))
  }
  
  private var contentTypeLabel: String {
    if item.hexColor != nil {
        return NSLocalizedString("category.color", comment: "Color")
    } else if item.isImage {
        return NSLocalizedString("category.image", comment: "Image")
    } else if item.isFile {
        return NSLocalizedString("category.file", comment: "File")
    } else if item.isLink {
        return NSLocalizedString("category.link", comment: "Link")
    } else if item.isCode {
        return NSLocalizedString("category.code", comment: "Code")
    } else {
        return NSLocalizedString("category.text", comment: "Text")
    }
  }
}

#Preview("代码卡片 - 未选中") {
  CardCell(item: HistoryItem.examples[0])
    .padding()
    .background(Color.black)
}

#Preview("代码卡片 - 选中") {
  CardCell(item: HistoryItem.examples[0], isSelected: true, onCopy: { print("Copy") })
    .padding()
    .background(Color.black)
}

#Preview("文本卡片") {
  CardCell(item: HistoryItem.examples[1])
    .padding()
    .background(Color.black)
}
