import AppKit
import SwiftData
import Vision
import CryptoKit

extension HistoryItem {
    static var examples: [HistoryItem] {
        // 1. Swift 代码片段
        let swiftCode = """
        func fetchData() async throws {
            let url = URL(string: "https://api.example.com")!
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(Response.self, from: data)
        }
        """
        let item1 = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: swiftCode.data(using: .utf8))])
        item1.title = swiftCode
        item1.application = "com.apple.dt.Xcode"
        item1.firstCopiedAt = Date().addingTimeInterval(-120) // 2分钟前
        
        // 2. 普通文本
        let item2 = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: "记得明天下午3点开会讨论新项目方案".data(using: .utf8))])
        item2.title = "记得明天下午3点开会讨论新项目方案"
        item2.application = "com.apple.Notes"
        item2.firstCopiedAt = Date().addingTimeInterval(-3600) // 1小时前
        
        // 3. URL 链接
        let item3 = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: "https://github.com/apple/swift".data(using: .utf8))])
        item3.title = "https://github.com/apple/swift"
        item3.application = "com.google.Chrome"
        item3.firstCopiedAt = Date().addingTimeInterval(-7200) // 2小时前
        
        // 4. JSON 数据
        let jsonData = """
        {
            "name": "Pastable",
            "version": "1.0.0",
            "description": "A modern clipboard manager"
        }
        """
        let item4 = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: jsonData.data(using: .utf8))])
        item4.title = jsonData
        item4.application = "com.microsoft.VSCode"
        item4.firstCopiedAt = Date().addingTimeInterval(-10800) // 3小时前
        
        // 5. CSS 代码
        let cssCode = """
        .card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 12px;
            padding: 16px;
        }
        """
        let item5 = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: cssCode.data(using: .utf8))])
        item5.title = cssCode
        item5.application = "com.microsoft.VSCode"
        item5.firstCopiedAt = Date().addingTimeInterval(-14400) // 4小时前
        
        // 6. 命令行
        let item6 = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: "git commit -m \"feat: add clipboard manager\"".data(using: .utf8))])
        item6.title = "git commit -m \"feat: add clipboard manager\""
        item6.application = "com.apple.Terminal"
        item6.firstCopiedAt = Date().addingTimeInterval(-18000) // 5小时前
        
        // 7. 邮箱地址
        let item7 = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: "contact@example.com".data(using: .utf8))])
        item7.title = "contact@example.com"
        item7.application = "com.apple.mail"
        item7.firstCopiedAt = Date().addingTimeInterval(-21600) // 6小时前
        
        // 8. 长文本
        let longText = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
        let item8 = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: longText.data(using: .utf8))])
        item8.title = longText
        item8.application = "com.google.Chrome"
        item8.firstCopiedAt = Date().addingTimeInterval(-86400) // 1天前
        
        return [item1, item2, item3, item4, item5, item6, item7, item8]
    }

}


@Model
class HistoryItem {
  private static let transientTypes: [String] = [
    NSPasteboard.PasteboardType.modified.rawValue,
    NSPasteboard.PasteboardType.fromPastable.rawValue,
    NSPasteboard.PasteboardType.linkPresentationMetadata.rawValue,
    NSPasteboard.PasteboardType.customWebKitPasteboardData.rawValue,
    NSPasteboard.PasteboardType.source.rawValue,
    NSPasteboard.PasteboardType.customChromiumWebData.rawValue,
    NSPasteboard.PasteboardType.chromiumSourceUrl.rawValue,
    NSPasteboard.PasteboardType.chromiumSourceToken.rawValue,
    NSPasteboard.PasteboardType.notesRichText.rawValue
  ]

  var application: String?
  var firstCopiedAt: Date = Date.now
  var lastCopiedAt: Date = Date.now
  var numberOfCopies: Int = 1
  var pin: String?
  var title = ""
  var cachedPreviewText: String?
  var cachedAdaptiveHexColor: String? // Cache for adaptive theme color
  var cachedRTFBackgroundHexColor: String? // Cache for RTF content background color
  var contentHash: String? = nil // Stable hash for de-duplication

  @Relationship(deleteRule: .cascade, inverse: \HistoryItemContent.item)
  var contents: [HistoryItemContent] = []

  // Non-persistent caches. Cards ask for these properties many times while the
  // panel is open; recomputing regexes / decoding images on every body pass was
  // the main cause of scroll and search jank.
  @Transient private var cachedImageValue: NSImage?
  @Transient private var cachedImageLoaded = false
  @Transient private var cachedImageDataValue: Data?
  @Transient private var cachedImageDataLoaded = false
  @Transient private var cachedFileURLsValue: [URL]?
  @Transient private var cachedFileURLsLoaded = false
  @Transient private var cachedIsImageFileFlag: Bool?
  @Transient private var cachedCodeFlag: Bool?
  @Transient private var cachedLinkFlag: Bool?
  @Transient private var cachedHexColorValue: String?
  @Transient private var cachedHexColorLoaded = false
  @Transient private var cachedFallbackPreviewText: String?
  @Transient private var textRecognitionScheduled = false

  init(contents: [HistoryItemContent] = [], contentHash: String? = nil) {
    self.firstCopiedAt = Date.now
    self.lastCopiedAt = Date.now
    self.contents = contents
    // Pre-calculate preview text to avoid repeated NSAttributedString parsing
    self.cachedPreviewText = self.computePreviewText()
    // Helper to set title immediately as well
    self.title = self.generateTitle()
    self.contentHash = contentHash ?? Self.computeContentHash(contents: contents)
    #if DEBUG
    let preview = cachedPreviewText?.prefix(60) ?? ""
    print("[HistoryItem][init] \(ISO8601DateFormatter().string(from: Date())) contents=\(contents.count) preview=\(preview)")
    #endif
  }

  func supersedes(_ item: HistoryItem) -> Bool {
    return item.contents
      .filter { content in
        !Self.transientTypes.contains(content.type)
      }
      .allSatisfy { content in
        contents.contains(where: { $0.type == content.type && $0.value == content.value })
      }
  }

  static func computeContentHash(contents: [HistoryItemContent]) -> String {
    computeContentHash(rawContents: contents.map {
      RawContentSnapshot(type: $0.type, value: $0.value)
    })
  }

  /// Hash a pasteboard snapshot without requiring SwiftData models. Used by the
  /// capture pipeline so hashing (and image decoding) can happen off the main thread.
  static func computeContentHash(rawContents: [RawContentSnapshot]) -> String {
    let typeSet = Set(rawContents.map(\.type))
    func sha256(_ data: Data) -> String {
      let digest = SHA256.hash(data: data)
      return digest.map { String(format: "%02x", $0) }.joined()
    }
    func dataForType(_ type: NSPasteboard.PasteboardType) -> Data? {
      rawContents.first(where: { $0.type == type.rawValue })?.value
    }

    // Prefer plain text
    if typeSet.contains(NSPasteboard.PasteboardType.string.rawValue),
       let data = dataForType(.string),
       let text = String(data: data, encoding: .utf8),
       !text.isEmpty {
      return "text:\(sha256(Data(text.utf8)))"
    }

    // File URLs
    if typeSet.contains(NSPasteboard.PasteboardType.fileURL.rawValue) {
      let urls = rawContents
        .filter { $0.type == NSPasteboard.PasteboardType.fileURL.rawValue }
        .compactMap { $0.value }
        .compactMap { URL(dataRepresentation: $0, relativeTo: nil, isAbsolute: true)?.absoluteString }
        .sorted()
        .joined(separator: "\n")
      if !urls.isEmpty {
        return "files:\(sha256(Data(urls.utf8)))"
      }
    }

    // Image data
    for imageType in [NSPasteboard.PasteboardType.png, .tiff, .jpeg, .heic] {
      if let data = dataForType(imageType), !data.isEmpty {
        return "image:\(sha256(data))"
      }
    }

    // RTF
    if let data = dataForType(.rtf),
       let rtf = NSAttributedString(rtf: data, documentAttributes: nil)?.string,
       !rtf.isEmpty {
      return "rtf:\(sha256(Data(rtf.utf8)))"
    }

    // HTML
    if let data = dataForType(.html),
       let html = NSAttributedString(html: data, documentAttributes: nil)?.string,
       !html.isEmpty {
      return "html:\(sha256(Data(html.utf8)))"
    }

    // Fallback: hash first non-empty data
    if let raw = rawContents.first(where: { $0.value != nil })?.value {
      return "raw:\(sha256(raw))"
    }

    return ""
  }

  func generateTitle() -> String {
    // Images get their title from a background Vision pass after insertion.
    // Never block a pasteboard capture on OCR, and avoid decoding the image just
    // to decide whether OCR is needed.
    guard !hasImageRepresentation else { return "" }
    
    // If it's a file, use the filename as title (decoded)
    if let fileURL = fileURLs.first {
      return fileURL.lastPathComponent.removingPercentEncoding ?? fileURL.lastPathComponent
    }

    // 1k characters is trade-off for performance
    var title = previewableText.shortened(to: 1_000)

    // TODO: Add support for settings like showSpecialSymbols
    let showSpecialSymbols = false 

    if showSpecialSymbols {
      if let range = title.range(of: "^ +", options: .regularExpression) {
        title = title.replacingOccurrences(of: " ", with: "·", range: range)
      }
      if let range = title.range(of: " +$", options: .regularExpression) {
        title = title.replacingOccurrences(of: " ", with: "·", range: range)
      }
      title = title
        .replacingOccurrences(of: "\n", with: "⏎")
        .replacingOccurrences(of: "\t", with: "⇥")
    } else {
      title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return title
  }

  /// True for records like an empty clipboard string, which would render as a
  /// blank "0 字" card. Images/files are never considered empty: their hash
  /// prefix lets us distinguish them without loading the binary payload.
  var isEffectivelyEmpty: Bool {
    if !previewableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return false
    }

    let hash = contentHash ?? ""
    if hash.hasPrefix("image:") || hash.hasPrefix("files:") {
      return false
    }

    return true
  }

  var previewableText: String {
    if let cached = cachedPreviewText, !cached.isEmpty {
      return cached
    }
    if let cached = cachedFallbackPreviewText {
      return cached
    }
    // Fallback for records created by an older version of the app.
    let text = computePreviewText()
    cachedFallbackPreviewText = text
    return text
  }
  
  private func computePreviewText() -> String {
    if !fileURLs.isEmpty {
      return fileURLs
        .compactMap { $0.absoluteString.removingPercentEncoding }
        .joined(separator: "\n")
    } else if let text = text, !text.isEmpty {
      return text
    } else if let rtf = rtf, !rtf.string.isEmpty {
      return rtf.string
    } else if let html = html, !html.string.isEmpty {
      return html.string
    } else {
      return title
    }
  }

  var fileURLs: [URL] {
    if cachedFileURLsLoaded {
      return cachedFileURLsValue ?? []
    }

    let urls: [URL]
    if universalClipboardText {
      urls = []
    } else {
      urls = allContentData([.fileURL])
        .compactMap { URL(dataRepresentation: $0, relativeTo: nil, isAbsolute: true) }
    }

    cachedFileURLsValue = urls
    cachedFileURLsLoaded = true
    return urls
  }

  var htmlData: Data? { contentData([.html]) }
  var html: NSAttributedString? {
    guard let data = htmlData else {
      return nil
    }

    return NSAttributedString(html: data, documentAttributes: nil)
  }

  var hasImageRepresentation: Bool {
    contentData([.png, .jpeg, .heic, .tiff]) != nil
  }

  var imageData: Data? {
    if cachedImageDataLoaded {
      return cachedImageDataValue
    }

    var data = contentData([.png, .jpeg, .heic, .tiff])
    if data == nil, universalClipboardImage, let url = fileURLs.first {
      data = try? Data(contentsOf: url)
    }

    cachedImageDataValue = data
    cachedImageDataLoaded = true
    return data
  }

  var image: NSImage? {
    if cachedImageLoaded {
      return cachedImageValue
    }

    let value = imageData.flatMap(NSImage.init(data:))
    cachedImageValue = value
    cachedImageLoaded = true
    return value
  }

  var rtfData: Data? { contentData([.rtf]) }
  var rtf: NSAttributedString? {
    guard let data = rtfData else {
      return nil
    }

    return NSAttributedString(rtf: data, documentAttributes: nil)
  }

  var text: String? {
    guard let data = contentData([.string]) else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  var modified: Int? {
    guard let data = contentData([.modified]),
          let modified = String(data: data, encoding: .utf8) else {
      return nil
    }

    return Int(modified)
  }

  var universalClipboard: Bool { contentData([.universalClipboard]) != nil }

  private var universalClipboardImage: Bool { universalClipboard && fileURLs.first?.pathExtension == "jpeg" }
  private var universalClipboardText: Bool {
    universalClipboard && contentData([.html, .tiff, .png, .jpeg, .rtf, .string, .heic]) != nil
  }

  private func contentData(_ types: [NSPasteboard.PasteboardType]) -> Data? {
    let content = contents.first(where: { content in
      return types.contains(NSPasteboard.PasteboardType(content.type))
    })

    return content?.value
  }

  private func allContentData(_ types: [NSPasteboard.PasteboardType]) -> [Data] {
    return contents
      .filter { types.contains(NSPasteboard.PasteboardType($0.type)) }
      .compactMap { $0.value }
  }

  /// Run Vision off the main thread and only fill an empty title.
  /// Called after the item has been inserted into a context so the result can
  /// be persisted safely.
  func scheduleTextRecognitionIfNeeded() {
    guard !textRecognitionScheduled, title.isEmpty, hasImageRepresentation, let data = imageData else {
      return
    }
    textRecognitionScheduled = true

    let itemID = persistentModelID
    guard let context = modelContext else { return }
    let contextBox = MainContextBox(context: context)
    Task.detached(priority: .utility) {
      guard let text = Self.recognizeText(in: data), !text.isEmpty else { return }

      await MainActor.run {
        guard let model = contextBox.context.model(for: itemID) as? HistoryItem,
              model.title.isEmpty else { return }
        let recognized = String(text.prefix(500))
        model.title = recognized
        // Images start with an empty preview. Populate it so the OCR text is
        // searchable and cards show a meaningful header.
        if model.cachedPreviewText?.isEmpty ?? true {
          model.cachedPreviewText = recognized
        }
        try? contextBox.context.save()
      }
    }
  }

  private static func recognizeText(in data: Data) -> String? {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .fast
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["zh-Hans", "en-US"]

    let handler = VNImageRequestHandler(data: data)
    do {
      try handler.perform([request])
    } catch {
      return nil
    }

    let observations = request.results ?? []
    let text = observations
      .compactMap { $0.topCandidates(1).first?.string }
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
  }
}

import UniformTypeIdentifiers

extension HistoryItem {
  var isCode: Bool {
    if let cached = cachedCodeFlag {
      return cached
    }
    let result = computeIsCode()
    cachedCodeFlag = result
    return result
  }

  private func computeIsCode() -> Bool {
    // 0. Exclude non-text types
    if isImage || isFile { return false }

    let text = previewableText
    guard text.count > 10 else { return false }
    
    // Quick Check: Swift Documentation
    if text.contains("///") { return true }
    
    var score = 0
    
    // Rule 1: Alphanumeric Ratio >= 55% (+2)
    // Code is dense with English letters/numbers. Natural language (especially non-English) is sparser in ASCII.
    let alphanumericCount = text.unicodeScalars.reduce(into: 0) { count, scalar in
      if scalar.properties.isAlphabetic || CharacterSet.decimalDigits.contains(scalar) {
        count += 1
      }
    }
    let ratio = Double(alphanumericCount) / Double(text.count)
    if ratio >= 0.55 { score += 2 }
    
    // Rule 2: Paired English Parentheses (+2)
    // Simple heuristic: check if count of '(' equals count of ')' and count > 0
    let openParenCount = text.filter { $0 == "(" }.count
    let closeParenCount = text.filter { $0 == ")" }.count
    if openParenCount > 0 && openParenCount == closeParenCount { score += 2 }
    
    // Rule 3: Line Endings (+1)
    // Check if lines end with common code symbols: ; { } : -> =
    // Check last non-whitespace character of text or lines
    let lineEndPattern = "[;{}:=>]\\s*$"
    if text.range(of: lineEndPattern, options: .regularExpression) != nil { score += 1 }
    
    // Rule 4: Keywords (+3)
    // Unified regex for the most common keywords across mainstream languages.
    if let regex = Self.codeKeywordsRegex {
        let matches = regex.numberOfMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        if matches >= 2 { score += 3 }
    }
    
    // Rule 5: Paired Braces/Brackets (+2)
    let openBrace = text.filter { $0 == "{" }.count
    let closeBrace = text.filter { $0 == "}" }.count
    let openBracket = text.filter { $0 == "[" }.count
    let closeBracket = text.filter { $0 == "]" }.count
    
    if (openBrace > 0 && openBrace == closeBrace) || (openBracket > 0 && openBracket == closeBracket) {
        score += 2
    }
    
    // Rule 6: Comments (+1)
    if text.contains("//") || text.contains("/*") || text.contains("# ") || text.contains("<!--") {
        score += 1
    }
    
    // Final Threshold: >= 6
    return score >= 6
  }

  private static let codeKeywordsRegex: NSRegularExpression? = {
    let pattern = "(?x)\\b(" +
        "func|var|let|if|else|return|class|struct|import|public|private|void|int|double|float|string|bool" +
        "|def|elif|for|while|try|except|with|lambda|pass" +
        "|function|const|await|async|export|interface|extends" +
        "|public|static|new|package" +
        "|echo|array|use|namespace" +
        "|SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|CREATE|TABLE" +
        "|mov|push|pop|call|ret" +
        ")\\b"
    return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
  }()

  var isLink: Bool {
    if let cached = cachedLinkFlag {
      return cached
    }
    let result = computeIsLink()
    cachedLinkFlag = result
    return result
  }

  private func computeIsLink() -> Bool {
    let text = previewableText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return false }
    
    // Performance optimization: Check if it looks like a URL first
    guard text.contains(".") || text.contains(":") else { return false }
    
    do {
        let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector.matches(in: text, options: [], range: range)
        
        // Return true if we found a link and it covers most of the string (e.g. not just "Go to google.com")
        if let match = matches.first {
            return match.range.length == range.length
        }
    } catch {
        return false
    }
    return false
  }
  
  var isImage: Bool {
    return image != nil
  }
  
  var isImageFile: Bool {
    if let cached = cachedIsImageFileFlag {
      return cached
    }

    let result: Bool
    if let url = fileURLs.first,
       let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
      result = type.conforms(to: .image)
    } else {
      result = false
    }

    cachedIsImageFileFlag = result
    return result
  }
  
  var isFile: Bool {
    return !fileURLs.isEmpty
  }
  
  /// Efficiently load a thumbnail from a file URL using ImageIO
  static func loadThumbnail(for url: URL, maxPixelSize: Int = 400) -> NSImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
    
    let options: [CFString: Any] = [
         kCGImageSourceCreateThumbnailFromImageAlways: true,
         kCGImageSourceCreateThumbnailWithTransform: true,
         kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]
    
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return NSImage(cgImage: cgImage, size: .zero)
  }
  var hexColor: String? {
    if cachedHexColorLoaded {
      return cachedHexColorValue
    }

    let text = previewableText.trimmingCharacters(in: .whitespacesAndNewlines)
    let pattern = "^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"
    let value = text.range(of: pattern, options: .regularExpression) != nil ? text : nil

    cachedHexColorValue = value
    cachedHexColorLoaded = true
    return value
  }
}

/// A single, explicitly main-actor-confined context reference used to hop the
/// result of background OCR back to SwiftData.
private struct MainContextBox: @unchecked Sendable {
  let context: ModelContext
}
