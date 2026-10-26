import SwiftUI

struct CardCell: View {
  let item: HistoryItem
  var isSelected: Bool = false
  var onCopy: (() -> Void)? = nil
  
  @State private var isHovered: Bool = false
  @State private var itemThumbnail: NSImage? = nil
  @State private var fileThumbnail: NSImage? = nil
  @State private var appIconImage: NSImage? = nil // Fix: Store distinct image state
  @State private var fileIconImage: NSImage? = nil // Fix: Store file icon state
  @Environment(\.colorScheme) private var colorScheme

  private var theme: AppTheme { AppTheme.theme(for: colorScheme) }
  
  var body: some View {
    ZStack {
      // 自适应色 -> 深色两段渐变。比「纯色 + 黑遮罩」更有层次，也避免
      // 浅色 App 图标把整张卡压成一块灰。
      backgroundGradient

      // 主内容
      VStack(alignment: .leading, spacing: 8) {
        // Header — only when it adds information. For plain text the title is
        // just a truncated copy of the body and used to be rendered twice.
        if shouldShowTitle {
          HStack {
            Text(cardTitle)
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(theme.textPrimary)
              .lineLimit(1)
              .padding(.trailing, 40)

            Spacer()
          }
        }
        
        // Content Preview
        if item.isImage {
          // Case A: Direct Image Data (Screenshots, etc.)
          // Rendered from the capture-time thumbnail; the original payload is
          // never decoded on this path.
          if let image = itemThumbnail {
            Image(nsImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .strokeBorder(theme.imageBorder, lineWidth: 1)
              )
          } else {
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
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
                 .cornerRadius(6)
                 .overlay(
                   RoundedRectangle(cornerRadius: 6)
                     .strokeBorder(theme.imageBorder, lineWidth: 1)
                 )
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
            // Case C.1: Hex Color Preview (Full Fill + readable value)
            ZStack {
              Color(hex: hexCode)
              Text(hexCode.uppercased())
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.contrastText(on: hexCode))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.contrastChip(on: hexCode), in: RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6))
          } else {
            // Case C.2: Regular Text (Preview)
            Group {
              if let attrStr = cachedAttributedText {
                Text(attrStr)
                  .frame(width: 236, alignment: .topLeading)
                  .multilineTextAlignment(.leading)
                  .lineSpacing(2)
              } else {
                Text(previewDisplayText)
                  .font(item.isCode ? .system(size: 13, design: .monospaced) : .system(size: 13))
                  .foregroundColor(theme.textBody)
                  .multilineTextAlignment(.leading)
                  .lineSpacing(2)
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
        
        // Footer: source icon → time → detail → type. Type is the only
        // emphasized item; everything else is secondary metadata.
        HStack(spacing: 6) {
          if let icon = appIconImage {
            Image(nsImage: icon)
              .resizable()
              .frame(width: 16, height: 16)
              .cornerRadius(4)
          }

          Text(item.lastCopiedAt.timeAgoDisplay())
            .font(.system(size: 11.5))
            .foregroundColor(theme.textSecondary)
            .lineLimit(1)

          Spacer(minLength: 4)

          Text(detailText)
            .font(.system(size: 11.5))
            .foregroundColor(theme.textTertiary)
            .lineLimit(1)

          HStack(spacing: 5) {
            Circle()
              .fill(categoryIndicatorColor)
              .frame(width: 6, height: 6)
            Text(contentTypeLabel)
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(theme.typePillText)
              .lineLimit(1)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(theme.typePillBackground)
          .clipShape(Capsule())
        }
      }
      .padding(12)
      

      
    }
    .frame(width: 260, height: 241)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(
          isSelected ? theme.accent : theme.cardBorder,
          lineWidth: isSelected ? 1.5 : 1
        )
    )
    .shadow(color: isSelected ? theme.accent.opacity(theme.accentGlow) : .clear, radius: 10)
    .shadow(color: Color.black.opacity(theme.isDark ? (isHovered ? 0.36 : 0.26) : (isHovered ? 0.14 : 0.09)), radius: 18, x: 0, y: 10)
    .shadow(color: Color.black.opacity(theme.isDark ? 0.14 : 0.05), radius: 6, x: 0, y: 4)
    .scaleEffect(isHovered ? 1.02 : 1.0)
    .animation(.easeOut(duration: 0.18), value: isHovered)
    .animation(nil, value: itemThumbnail)
    .animation(nil, value: fileThumbnail)
    .animation(nil, value: appIconImage)
    .animation(nil, value: fileIconImage)
    .animation(nil, value: cachedAttributedText)
    .animation(nil, value: contentBackgroundColor)
    .onHover { hovering in
      isHovered = hovering
    }
    .task(id: item.persistentModelID) {
      let itemId = item.persistentModelID
      let cachedRTFBackgroundHex = item.cachedRTFBackgroundHexColor
      let rtfData = item.rtfData
      let fileURL = item.fileURLs.first
      let isImageFile = item.isImageFile
      let isFile = item.isFile
      let isImageContent = item.isImage
      let appBundleId = item.application

      if let cachedHex = cachedRTFBackgroundHex {
        contentBackgroundColor = Color(hex: cachedHex)
      }

      // 0. Direct image content: paint from the capture-time preview. Legacy
      // records (stored before previews existed) generate one on first display
      // and persist it, so the cost is paid at most once per record.
      if isImageContent {
        let thumbKey = item.thumbnailCacheKey
        let preRendered = item.thumbnailData
        let legacyPayload = preRendered == nil ? item.imageData : nil

        let box = await Task.detached(priority: .userInitiated) { () -> SendableThumbnail in
          if let cached = ImageCache.shared.cachedThumbnail(forKey: thumbKey) {
            return SendableThumbnail(value: cached, generated: nil)
          }

          var generated: Data?
          let image: NSImage?
          if let preRendered {
            image = NSImage(data: preRendered)
          } else if let legacyPayload, let data = HistoryItem.thumbnailData(from: legacyPayload) {
            generated = data
            image = NSImage(data: data)
          } else {
            image = nil
          }
          ImageCache.shared.storeThumbnail(image, forKey: thumbKey)
          return SendableThumbnail(value: image, generated: generated)
        }.value

        guard item.persistentModelID == itemId else { return }
        itemThumbnail = box.value
        if let generated = box.generated, item.thumbnailData == nil {
          item.thumbnailData = generated
          try? item.modelContext?.save()
        }
      }

      // 1. Load File Thumbnail
      if isImageFile, let url = fileURL {
        let box = await Task.detached(priority: .userInitiated) { () -> SendableImage in
          let thumbnail = ImageCache.shared.thumbnail(forKey: url.absoluteString) {
            HistoryItem.loadThumbnail(for: url)
          }
          return SendableImage(value: thumbnail)
        }.value

        guard item.persistentModelID == itemId else { return }
        fileThumbnail = box.value
      }

      // 2. Load App Icon for the footer (the card background follows the
      // category tint, matching the Figma design; app-icon average colors are
      // intentionally not used for the card surface anymore).
      if let bundleId = appBundleId,
         let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.path {
        let box = await Task.detached(priority: .userInitiated) { () -> SendableImage in
          SendableImage(value: ImageCache.shared.appIcon(forBundleId: bundleId, path: path))
        }.value

        guard item.persistentModelID == itemId else { return }
        appIconImage = box.value
      }

      // 3. Load Generic File Icon
      if isFile, !isImageFile, let url = fileURL {
        let box = await Task.detached(priority: .userInitiated) { () -> SendableImage in
          SendableImage(value: ImageCache.shared.fileIcon(forPath: url.path))
        }.value

        guard item.persistentModelID == itemId else { return }
        fileIconImage = box.value
      }

      // 4. Parse RTF content off the main thread.
      if let rtfData, self.cachedAttributedText == nil {
        let parsed = await Task.detached(priority: .userInitiated) { () -> (AttributedString, Color?)? in
          guard let rtf = NSAttributedString(rtf: rtfData, documentAttributes: nil) else { return nil }
          return (AttributedString(rtf), rtf.effectiveBackgroundColor)
        }.value

        guard item.persistentModelID == itemId else { return }
        if let parsed {
          cachedAttributedText = parsed.0
          contentBackgroundColor = parsed.1
          if item.cachedRTFBackgroundHexColor == nil,
             let color = parsed.1,
             let hex = color.toHex() {
            item.cachedRTFBackgroundHexColor = hex
            try? item.modelContext?.save()
          }
        }
      }
    }
  }

  // MARK: - Private Properties
  @State private var cachedAttributedText: AttributedString? = nil
  @State private var contentBackgroundColor: Color? = nil
  
  /// Single source of truth for the category accent. The color card uses the
  /// actual hex value, everything else uses the type color.
  private var tintHex: String {
    if let hex = item.hexColor { return hex }
    if item.isCode { return AppPalette.categoryCode }
    if item.isLink { return AppPalette.categoryLink }
    if item.isImage || item.isFile { return AppPalette.categoryMedia }
    return AppPalette.categoryAll
  }

  private var categoryIndicatorColor: Color {
    Color(hex: tintHex)
  }

  /// Figma card surface: category tint at the top fading to the card base.
  /// Dark uses 18%/24%; light uses 10%/16% over white.
  private var backgroundGradient: some View {
    LinearGradient(
      colors: [
        theme.cardTop(tintHex: tintHex, selected: isSelected),
        theme.cardBase
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private static let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
  }()

  /// Card body text, capped at what the 10-line preview can ever show so
  /// SwiftUI never lays out megabyte-sized strings.
  private var previewDisplayText: String {
    String(item.previewableText.prefix(2_000))
  }

  /// Footer metadata straight from the columns derived at capture time
  /// (`HistoryItem.deriveDisplayMetadata`); legacy records compute once and
  /// cache instead of re-scanning payloads on every frame.
  private var detailText: String {
    if item.isImage {
      return Self.byteFormatter.string(fromByteCount: Int64(item.displayTotalSize))
    }

    if item.isFile {
      let count = item.displayFileCount
      if count == 1 {
        return NSLocalizedString("unit.one_file", comment: "One file")
      }
      return String(format: NSLocalizedString("unit.files_format", comment: "N files"), count)
    }

    return String(
      format: NSLocalizedString("unit.chars_format", comment: "N characters"),
      item.displayTextLength
    )
  }

  private var shouldShowTitle: Bool {
    if item.isFile { return true }
    if item.isImage { return !item.title.isEmpty }

    let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return false }

    let preview = item.previewableText.trimmingCharacters(in: .whitespacesAndNewlines)
    return !preview.hasPrefix(title)
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

private struct SendableImage: @unchecked Sendable {
  let value: NSImage?
}

/// Thumbnail lookup result, including a preview that was generated on the fly
/// and should be persisted back to the model.
private struct SendableThumbnail: @unchecked Sendable {
  let value: NSImage?
  let generated: Data?
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
