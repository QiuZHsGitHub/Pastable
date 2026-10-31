import SwiftUI
import SwiftData

struct CardCell: View {
  let item: HistoryItem
  var isSelected: Bool = false
  /// Folded search tokens; while non-empty the card explains why it matched:
  /// every hit is highlighted and the preview jumps to the first one when it
  /// lives beyond what the card normally shows.
  var highlightTokens: [String] = []
  var onCopy: (() -> Void)? = nil
  
  @State private var isHovered: Bool = false
  @State private var itemThumbnail: NSImage? = nil
  @State private var fileThumbnail: NSImage? = nil
  @State private var appIconImage: NSImage? = nil // Fix: Store distinct image state
  @State private var fileIconImage: NSImage? = nil // Fix: Store file icon state
  @Environment(\.colorScheme) private var colorScheme

  private var theme: AppTheme { AppTheme.theme(for: colorScheme) }

  /// Primes the asynchronously loaded pieces from their process-wide caches so
  /// a card that scrolls back into view paints immediately instead of flashing
  /// a spinner while its background task re-runs (`LazyHStack` drops cell state
  /// as soon as a card leaves the visible band). All lookups are cache-only —
  /// no icon resolution or decoding on the main thread; misses stay `nil` and
  /// fill in via `.task` exactly as before.
  init(item: HistoryItem, isSelected: Bool = false, highlightTokens: [String] = [], onCopy: (() -> Void)? = nil) {
    self.item = item
    self.isSelected = isSelected
    self.highlightTokens = highlightTokens
    self.onCopy = onCopy

    _itemThumbnail = State(initialValue: ImageCache.shared.cachedThumbnail(forKey: item.thumbnailCacheKey))
    if let url = item.fileURLs.first {
      _fileThumbnail = State(initialValue: ImageCache.shared.cachedThumbnail(forKey: url.absoluteString))
      _fileIconImage = State(initialValue: ImageCache.shared.cachedFileIcon(forPath: url.path))
    }
    if let bundleId = item.application {
      _appIconImage = State(initialValue: ImageCache.shared.cachedAppIcon(forBundleId: bundleId))
    }
    let cachedPreview = PreviewCache.shared.preview(forKey: item.attributedPreviewCacheKey)
    if let cachedPreview {
      _cachedAttributedText = State(initialValue: cachedPreview.text)
    }
    if let hex = cachedPreview?.backgroundHex ?? item.cachedRTFBackgroundHexColor {
      _contentBackgroundColor = State(initialValue: Color(hex: hex))
    }
  }

  var body: some View {
    ZStack {
      // 自适应色 -> 深色两段渐变。比「纯色 + 黑遮罩」更有层次，也避免
      // 浅色 App 图标把整张卡压成一块灰。
      backgroundGradient

      // 主内容
      VStack(alignment: .leading, spacing: 8) {
        // Header — only when it adds information. For plain text the title is
        // just a truncated copy of the body and used to be rendered twice.
        titleView
        
        // Content Preview
        contentPreview
        
        footerView
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
    // One shadow pass per card instead of three. Every `.shadow` renders the
    // card offscreen once more, and the shelf shows dozens of cards while
    // scrolling; the accent glow now only exists while the card is selected,
    // and the two elevation shadows are merged (opacity nudged up so the
    // perceived depth stays the same).
    .cardShadow(
      glow: isSelected ? theme.accent.opacity(theme.accentGlow) : nil,
      elevation: Color.black.opacity(elevationOpacity)
    )
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
    .task(id: CardCellTaskKey(itemID: item.persistentModelID, tokens: highlightTokens)) {
      let itemId = item.persistentModelID

      // Capture every model read up front — SwiftData objects must not be
      // touched from the detached task below — and fold all background work
      // (thumbnail lookup/decode, icons, RTF parse) into that single task so
      // the card updates its state once instead of up to five times, each of
      // which used to trigger a separate re-render while scrolling. Note that
      // this capture stays cheap: app-path resolution (LaunchServices) belongs
      // to the detached load below, never to the main actor.
      let inputs = CardAssetsInputs(
        thumbnailKey: item.thumbnailCacheKey,
        previewKey: item.attributedPreviewCacheKey,
        preRenderedThumbnail: item.thumbnailData,
        // Legacy records (stored before previews existed) generate one on
        // first display and persist it, so the cost is paid at most once.
        legacyImagePayload: item.thumbnailData == nil ? item.imageData : nil,
        isImageContent: item.isImage,
        fileURL: item.fileURLs.first,
        isImageFile: item.isImageFile,
        isFile: item.isFile,
        appBundleId: item.application,
        rtfData: item.rtfData,
        previewSource: item.previewableText,
        titleText: cardTitle,
        highlightTokens: highlightTokens,
        highlightColor: theme.accent,
        previewFont: item.isCode ? .system(size: 13, design: .monospaced) : .system(size: 13),
        previewForeground: theme.textBody
      )

      let assets = await Task.detached(priority: .userInitiated) {
        CardAssets.load(inputs)
      }.value

      guard item.persistentModelID == itemId else { return }

      // Compare before assigning: a card whose caches were primed at init time
      // (or that re-runs this task on a search change) must not invalidate its
      // body just to store the identical value again.
      if let thumbnail = assets.thumbnail, itemThumbnail !== thumbnail {
        itemThumbnail = thumbnail
      }
      if let fileThumbnail = assets.fileThumbnail, self.fileThumbnail !== fileThumbnail {
        self.fileThumbnail = fileThumbnail
      }
      if let appIcon = assets.appIcon, appIconImage !== appIcon {
        appIconImage = appIcon
      }
      if let fileIcon = assets.fileIcon, fileIconImage !== fileIcon {
        fileIconImage = fileIcon
      }
      if let preview = assets.attributedPreview {
        if cachedAttributedText != preview.text {
          cachedAttributedText = preview.text
        }
        if let hex = preview.backgroundHex {
          let color = Color(hex: hex)
          if contentBackgroundColor != color {
            contentBackgroundColor = color
          }
        }
      }
      // Search feedback always overwrites (including with `nil` when the query
      // changed) so the card falls back to its normal rendering — but only on
      // actual change.
      if searchPreview != assets.searchPreview {
        searchPreview = assets.searchPreview
      }
      if highlightedTitle != assets.searchTitle {
        highlightedTitle = assets.searchTitle
      }

      // Persist artifacts generated on the fly, at most once per record. The
      // writes are batched and deferred: a save per card re-fetches the shelf's
      // `@Query` and re-renders the whole list, which used to stutter exactly
      // while legacy cards were scrolling into view.
      if assets.generatedThumbnailData != nil || assets.generatedBackgroundHex != nil {
        DeferredModelWriter.shared.enqueue(context: item.modelContext) { [weak item] in
          guard let item else { return }
          if item.thumbnailData == nil, let generated = assets.generatedThumbnailData {
            item.thumbnailData = generated
          }
          if item.cachedRTFBackgroundHexColor == nil, let hex = assets.generatedBackgroundHex {
            item.cachedRTFBackgroundHexColor = hex
          }
        }
      }
    }
  }

  // MARK: - Body pieces
  // Split out of `body` so the compiler type-checks each piece on its own —
  // one expression this large blows past the type-checker's size limit.

  @ViewBuilder
  private var titleView: some View {
    if shouldShowTitle {
      HStack {
        Group {
          if let highlightedTitle {
            Text(highlightedTitle)
          } else {
            Text(cardTitle)
          }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(theme.textPrimary)
        .lineLimit(1)
        .padding(.trailing, 40)

        Spacer()
      }
    }
  }

  @ViewBuilder
  private var contentPreview: some View {
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
          if let searchPreview {
            // Search feedback: preview windowed to the first hit with
            // every hit highlighted (see `SearchHighlight`), so the card
            // shows why it matched even for hits deep in the body.
            Text(searchPreview)
              .frame(width: 236, alignment: .topLeading)
              .multilineTextAlignment(.leading)
              .lineSpacing(2)
          } else if let attrStr = cachedAttributedText {
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
  }

  /// Footer: source icon → time → detail → type. Type is the only
  /// emphasized item; everything else is secondary metadata.
  @ViewBuilder
  private var footerView: some View {
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

  // MARK: - Private Properties
  @State private var cachedAttributedText: AttributedString? = nil
  @State private var contentBackgroundColor: Color? = nil
  @State private var searchPreview: AttributedString? = nil
  @State private var highlightedTitle: AttributedString? = nil
  
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

  /// Opacity of the merged elevation shadow (was two stacked shadows, so the
  /// values are nudged up to keep the same perceived depth).
  private var elevationOpacity: Double {
    theme.isDark ? (isHovered ? 0.40 : 0.30) : (isHovered ? 0.17 : 0.11)
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

    // Only the visible head of the preview matters for the "title is just a
    // copy of the body" check; never trim megabyte-sized payloads here — this
    // runs on every body pass.
    let preview = item.previewableText.prefix(2_000).trimmingCharacters(in: .whitespacesAndNewlines)
    return !preview.hasPrefix(title)
  }

  private var cardTitle: String {
    // Prefer the title captured with the record. For a multi-file copy this is
    // the first file in copy order and stays stable across relaunches; deriving
    // it again from `fileURLs.first` re-reads a SwiftData to-many relationship
    // whose order is not guaranteed.
    let storedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !storedTitle.isEmpty {
      return storedTitle
    }

    // Legacy rows without a persisted title fall back to the file name.
    if item.isFile, let fileURL = item.fileURLs.first {
      return fileURL.lastPathComponent.removingPercentEncoding ?? fileURL.lastPathComponent
    }

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

/// Re-runs the card's background load when either the record or the active
/// search changes: the "why did this match" highlight is part of the load.
private struct CardCellTaskKey: Hashable {
  let itemID: PersistentIdentifier
  let tokens: [String]
}

/// Immutable snapshot of everything `CardAssets.load` needs, captured on the
/// main actor so the detached task never touches a SwiftData model.
private struct CardAssetsInputs: @unchecked Sendable {
  let thumbnailKey: String
  let previewKey: String
  let preRenderedThumbnail: Data?
  let legacyImagePayload: Data?
  let isImageContent: Bool
  let fileURL: URL?
  let isImageFile: Bool
  let isFile: Bool
  let appBundleId: String?
  let rtfData: Data?
  let previewSource: String
  let titleText: String
  let highlightTokens: [String]
  let highlightColor: Color
  let previewFont: Font
  let previewForeground: Color
}

/// One batched background load for a card: thumbnail, file thumbnail, app
/// icon, file icon and parsed RTF preview. `generatedThumbnailData` and
/// `generatedBackgroundHex` are artifacts computed on the fly that the caller
/// persists back to the model (at most once per record).
private struct CardAssets: @unchecked Sendable {
  let thumbnail: NSImage?
  let generatedThumbnailData: Data?
  let fileThumbnail: NSImage?
  let appIcon: NSImage?
  let fileIcon: NSImage?
  let attributedPreview: AttributedPreview?
  let generatedBackgroundHex: String?
  let searchPreview: AttributedString?
  let searchTitle: AttributedString?

  static func load(_ inputs: CardAssetsInputs) -> CardAssets {
    // 0. Direct image content: paint from the capture-time preview.
    var thumbnail: NSImage?
    var generatedThumbnail: Data?
    if inputs.isImageContent {
      if let cached = ImageCache.shared.cachedThumbnail(forKey: inputs.thumbnailKey) {
        thumbnail = cached
      } else {
        let image: NSImage?
        if let preRendered = inputs.preRenderedThumbnail {
          image = NSImage(data: preRendered)
        } else if let legacy = inputs.legacyImagePayload,
                  let data = HistoryItem.thumbnailData(from: legacy) {
          generatedThumbnail = data
          image = NSImage(data: data)
        } else {
          image = nil
        }
        // Stores a fully decoded copy and returns it, so the card's first draw
        // never pays the decode on the main thread.
        thumbnail = ImageCache.shared.storeThumbnail(image, forKey: inputs.thumbnailKey)
      }
    }

    // 1. File thumbnail for image files.
    var fileThumbnail: NSImage?
    if inputs.isImageFile, let url = inputs.fileURL {
      fileThumbnail = ImageCache.shared.thumbnail(forKey: url.absoluteString) {
        HistoryItem.loadThumbnail(for: url)
      }
    }

    // 2. App icon for the footer (the card background follows the category
    // tint; app-icon average colors are intentionally not used for it). The
    // cache resolves the app path internally — LaunchServices lookups can hit
    // disk and must stay off the main actor.
    var appIcon: NSImage?
    if let bundleId = inputs.appBundleId {
      appIcon = ImageCache.shared.appIcon(forBundleId: bundleId)
    }

    // 3. Generic file icon.
    var fileIcon: NSImage?
    if inputs.isFile, !inputs.isImageFile, let url = inputs.fileURL {
      fileIcon = ImageCache.shared.fileIcon(forPath: url.path)
    }

    // 4. Parsed RTF preview, served from `PreviewCache` when some earlier
    // appearance of this record already paid for the parse.
    var preview: AttributedPreview?
    var generatedHex: String?
    if let rtfData = inputs.rtfData {
      if let cached = PreviewCache.shared.preview(forKey: inputs.previewKey) {
        preview = cached
      } else if let rtf = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
        let parsed = AttributedPreview(
          text: AttributedString(rtf),
          backgroundHex: rtf.effectiveBackgroundColor?.toHex()
        )
        PreviewCache.shared.store(parsed, forKey: inputs.previewKey)
        preview = parsed
        generatedHex = parsed.backgroundHex
      }
    }

    // 5. Search feedback ("why did this match"): highlighted preview and
    // title. When the first hit lives beyond the visible head of the text,
    // the preview switches to a window around it — plain text in that case,
    // since slicing rich text would drop its styling.
    var searchPreviewText: AttributedString?
    var searchTitle: AttributedString?
    if !inputs.highlightTokens.isEmpty {
      let tokens = inputs.highlightTokens
      let slice = SearchHighlight.windowedSlice(of: inputs.previewSource, tokens: tokens)

      if let slice, slice.isWindow {
        searchPreviewText = SearchHighlight.highlighted(
          slice.text,
          tokens: tokens,
          color: inputs.highlightColor,
          font: inputs.previewFont,
          foreground: inputs.previewForeground
        )
      } else if let preview {
        searchPreviewText = SearchHighlight.highlightedHead(
          preview.text,
          tokens: tokens,
          color: inputs.highlightColor
        )
      } else if let slice {
        searchPreviewText = SearchHighlight.highlighted(
          slice.text,
          tokens: tokens,
          color: inputs.highlightColor,
          font: inputs.previewFont,
          foreground: inputs.previewForeground
        )
      }

      if let titleSlice = SearchHighlight.windowedSlice(of: inputs.titleText, tokens: tokens) {
        searchTitle = SearchHighlight.highlighted(
          titleSlice.text,
          tokens: tokens,
          color: inputs.highlightColor
        )
      }
    }

    return CardAssets(
      thumbnail: thumbnail,
      generatedThumbnailData: generatedThumbnail,
      fileThumbnail: fileThumbnail,
      appIcon: appIcon,
      fileIcon: fileIcon,
      attributedPreview: preview,
      generatedBackgroundHex: generatedHex,
      searchPreview: searchPreviewText,
      searchTitle: searchTitle
    )
  }
}

private extension View {
  /// Applies at most two shadow passes: an optional selection glow plus one
  /// merged elevation shadow (previously two stacked elevation shadows).
  @ViewBuilder
  func cardShadow(glow: Color?, elevation: Color) -> some View {
    if let glow {
      self
        .shadow(color: glow, radius: 10)
        .shadow(color: elevation, radius: 18, x: 0, y: 10)
    } else {
      self.shadow(color: elevation, radius: 18, x: 0, y: 10)
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
