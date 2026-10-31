import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

// MARK: - Configuration

guard CommandLine.arguments.count >= 5 else {
  print("usage: e2e-runner <app-binary> <fixture-binary> <artifacts-dir> <bundle-id>")
  exit(2)
}

let appBinary = CommandLine.arguments[1]
let fixtureBinary = CommandLine.arguments[2]
let artifactsDir = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
let bundleID = CommandLine.arguments[4]
let workRoot = FileManager.default.temporaryDirectory
  .appendingPathComponent("PastableE2E-\(UUID().uuidString)", isDirectory: true)

try? FileManager.default.createDirectory(at: artifactsDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: workRoot, withIntermediateDirectories: true)

let primaryScreen = NSScreen.screens.first ?? NSScreen.main!
let screenWidth = primaryScreen.frame.width
let screenHeight = primaryScreen.frame.height

// MARK: - Results

enum Status: String, Codable {
  case pass = "PASS"
  case fail = "FAIL"
  case known = "KNOWN ISSUE"
  case skip = "SKIP"
}

struct TestResult: Codable {
  let name: String
  let status: String
  let detail: String
  let durationMs: Int
}

var results: [TestResult] = []
var timings: [String: Int] = [:]
var screenshots: [String] = []

func record(_ name: String, _ status: Status, _ detail: String = "", started: Date? = nil) {
  let ms = started.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
  results.append(TestResult(name: name, status: status.rawValue, detail: detail, durationMs: ms))
  let suffix = detail.isEmpty ? "" : " — \(detail)"
  print("  [\(status.rawValue)] \(name)\(suffix)")
}

@discardableResult
func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") -> Bool {
  record(name, condition ? .pass : .fail, condition ? "" : detail())
  return condition
}

func checkEq<T: Equatable>(_ name: String, _ actual: T, _ expected: T) {
  check(name, actual == expected, "expected \(expected), got \(actual)")
}

func checkKnownIssue(_ name: String, _ condition: Bool, detail: @autoclosure () -> String) {
  record(name, condition ? .pass : .known, condition ? "" : detail())
}

func section(_ title: String) {
  print("\n== \(title) ==")
}

func fail(_ message: String) {
  print("  [FAIL] \(message)")
  record(message, .fail)
}

// MARK: - Process helpers

@discardableResult
func runProcess(_ path: String, _ arguments: [String] = []) -> Int32 {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: path)
  process.arguments = arguments
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  do {
    try process.run()
  } catch {
    return -1
  }
  process.waitUntilExit()
  return process.terminationStatus
}

@discardableResult
func waitUntil(timeout: TimeInterval, interval: TimeInterval = 0.1, _ condition: () -> Bool) -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    if condition() { return true }
    Thread.sleep(forTimeInterval: interval)
  }
  return condition()
}

func sleep(_ seconds: TimeInterval) {
  Thread.sleep(forTimeInterval: seconds)
}

func storePath(_ name: String) -> String {
  let url = workRoot.appendingPathComponent(name, isDirectory: true)
  try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url.path
}

// MARK: - Accessibility helpers

func axApp(_ pid: pid_t) -> AXUIElement {
  AXUIElementCreateApplication(pid)
}

func axAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
    return nil
  }
  return value
}

func axString(_ element: AXUIElement, _ name: String) -> String {
  (axAttribute(element, name) as? String) ?? ""
}

func axElement(_ element: AXUIElement, _ name: String) -> AXUIElement? {
  guard let value = axAttribute(element, name),
        CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
  return (value as! AXUIElement)
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
  (axAttribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func axDescendants(_ root: AXUIElement, maxCount: Int = 4_000) -> [AXUIElement] {
  var result = [root]
  var queue = [root]
  while let element = queue.popLast(), result.count < maxCount {
    for child in axChildren(element) {
      result.append(child)
      queue.append(child)
    }
  }
  return result
}

func axWindows(_ pid: pid_t) -> [AXUIElement] {
  (axAttribute(axApp(pid), kAXWindowsAttribute) as? [AXUIElement]) ?? []
}

func axFrame(_ element: AXUIElement) -> CGRect? {
  guard let positionValue = axAttribute(element, kAXPositionAttribute),
        let sizeValue = axAttribute(element, kAXSizeAttribute) else { return nil }
  var position = CGPoint.zero
  var size = CGSize.zero
  guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
  return CGRect(origin: position, size: size)
}

func axRole(_ element: AXUIElement) -> String {
  axString(element, kAXRoleAttribute)
}

func axSubrole(_ element: AXUIElement) -> String {
  axString(element, kAXSubroleAttribute)
}

func axPress(_ element: AXUIElement) -> AXError {
  AXUIElementPerformAction(element, kAXPressAction as CFString)
}

func axBool(_ value: CFTypeRef?) -> Bool? {
  if let number = value as? NSNumber { return number.boolValue }
  if let bool = value as? Bool { return bool }
  if let string = value as? String { return string == "1" || string.lowercased() == "true" }
  return nil
}

func axFocused(_ element: AXUIElement) -> Bool {
  axBool(axAttribute(element, kAXFocusedAttribute)) ?? false
}

func axSetValue(_ element: AXUIElement, _ value: String) {
  AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef)
}

func axSetFocused(_ element: AXUIElement) {
  AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
}

func axButtons(in root: AXUIElement) -> [AXUIElement] {
  axDescendants(root).filter { axRole($0) == "AXButton" }
}

func axStaticTexts(in root: AXUIElement) -> [String] {
  axDescendants(root)
    .filter { axRole($0) == "AXStaticText" }
    .map { axString($0, kAXValueAttribute) }
    .filter { !$0.isEmpty }
}

// MARK: - WindowServer helpers

struct WindowInfo {
  let id: CGWindowID
  let layer: Int
  let bounds: CGRect
  let alpha: Double
}

func windowInfos(pid: pid_t) -> [WindowInfo] {
  let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
  guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    return []
  }
  return raw.compactMap { window in
    guard let owner = window[kCGWindowOwnerPID as String] as? NSNumber,
          owner.int32Value == pid,
          let number = window[kCGWindowNumber as String] as? NSNumber,
          let layer = window[kCGWindowLayer as String] as? NSNumber,
          let boundsDictionary = window[kCGWindowBounds as String] as? [String: Any],
          let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary) else {
      return nil
    }
    let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0
    return WindowInfo(
      id: CGWindowID(number.uint32Value),
      layer: layer.intValue,
      bounds: bounds,
      alpha: alpha
    )
  }
}

func panelWindowInfo(pid: pid_t) -> WindowInfo? {
  windowInfos(pid: pid).first {
    $0.layer == 25 && $0.bounds.width >= screenWidth - 4 && $0.bounds.height < 600
  }
}

func settingsWindowInfo(pid: pid_t) -> WindowInfo? {
  windowInfos(pid: pid).first {
    $0.layer == 8 && $0.bounds.width > 300 && $0.bounds.height > 200
  }
}

// MARK: - Screenshots and pixels

@discardableResult
func captureWindow(pid: pid_t, layer: Int, minimumWidth: CGFloat, name: String) -> URL? {
  guard let info = windowInfos(pid: pid).first(where: {
    $0.layer == layer && $0.bounds.width >= minimumWidth
  }) else {
    return nil
  }
  let url = artifactsDir.appendingPathComponent(name)
  for attempt in 0..<3 {
    let status = runProcess(
      "/usr/sbin/screencapture",
      ["-x", "-o", "-l", String(info.id), url.path]
    )
    if status == 0,
       let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
       (attributes[.size] as? NSNumber)?.intValue ?? 0 > 1_000 {
      screenshots.append(name)
      return url
    }
    if attempt < 2 { Thread.sleep(forTimeInterval: 0.3) }
  }
  return nil
}

func meanLuminance(of url: URL) -> Double? {
  guard let data = try? Data(contentsOf: url),
        let bitmap = NSBitmapImageRep(data: data) else { return nil }
  let width = bitmap.pixelsWide
  let height = bitmap.pixelsHigh
  guard width > 0, height > 0 else { return nil }

  let stepX = max(1, width / 60)
  let stepY = max(1, height / 40)
  var total = 0.0
  var count = 0

  for y in stride(from: 0, to: height, by: stepY) {
    for x in stride(from: 0, to: width, by: stepX) {
      guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
      total += 0.2126 * Double(color.redComponent)
        + 0.7152 * Double(color.greenComponent)
        + 0.0722 * Double(color.blueComponent)
      count += 1
    }
  }
  return count > 0 ? total / Double(count) : nil
}

// MARK: - Clipboard preservation

struct ClipItem {
  let entries: [(NSPasteboard.PasteboardType, Data)]
}

func snapshotClipboard() -> [ClipItem] {
  guard let items = NSPasteboard.general.pasteboardItems else { return [] }
  return items.map { item in
    ClipItem(entries: item.types.compactMap { type in
      item.data(forType: type).map { (type, $0) }
    })
  }
}

let fromPastableType = NSPasteboard.PasteboardType("com.pastable.from")

func restoreClipboard(_ snapshot: [ClipItem]) {
  let pasteboard = NSPasteboard.general
  pasteboard.clearContents()
  guard !snapshot.isEmpty else { return }

  var items: [NSPasteboardItem] = []
  for clip in snapshot {
    let item = NSPasteboardItem()
    for (type, data) in clip.entries where type != fromPastableType {
      item.setData(data, forType: type)
    }
    if !item.types.isEmpty { items.append(item) }
  }
  guard !items.isEmpty else { return }
  // Mark the restore as a Pastable write so the user's running copy ignores it.
  items.first?.setString("", forType: fromPastableType)
  pasteboard.writeObjects(items)
}

func pasteboardString() -> String? {
  NSPasteboard.general.string(forType: .string)
}

func pasteboardTypes() -> [String] {
  (NSPasteboard.general.types ?? []).map(\.rawValue)
}

func pasteboardFilePaths() -> [String] {
  (NSPasteboard.general.pasteboardItems ?? []).compactMap { item in
    guard let data = item.data(forType: .fileURL),
          let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) else {
      return nil
    }
    return url.path
  }
}

// MARK: - App preferences (isolated bundle id)

func setDefault(_ key: String, _ value: Bool) {
  CFPreferencesSetAppValue(
    key as CFString,
    value ? kCFBooleanTrue : kCFBooleanFalse,
    bundleID as CFString
  )
  CFPreferencesAppSynchronize(bundleID as CFString)
}

func setStringDefault(_ key: String, _ value: String) {
  CFPreferencesSetAppValue(key as CFString, value as CFString, bundleID as CFString)
  CFPreferencesAppSynchronize(bundleID as CFString)
}

func readDefault(_ key: String) -> Bool? {
  guard let value = CFPreferencesCopyAppValue(key as CFString, bundleID as CFString) else {
    return nil
  }
  return axBool(value)
}

// MARK: - Keyboard and mouse

let eventSource = CGEventSource(stateID: .hidSystemState)

func postKey(_ code: CGKeyCode, flags: CGEventFlags = []) {
  let down = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: true)!
  down.flags = flags
  down.post(tap: .cghidEventTap)
  Thread.sleep(forTimeInterval: 0.02)
  let up = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: false)!
  up.flags = flags
  up.post(tap: .cghidEventTap)
  Thread.sleep(forTimeInterval: 0.02)
}

func typeText(_ text: String) {
  for scalar in text.unicodeScalars {
    var units = Array(String(scalar).utf16)
    let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true)!
    down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.012)
    let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false)!
    up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
    up.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.012)
  }
}

/// US-layout key codes for the characters used by the E2E queries. Synthetic
/// Unicode events do not drive SwiftUI's NSTextField reliably (and bypass the
/// active IME); real key codes plus a Space commit mirror a user typing.
let asciiKeyCodes: [Character: CGKeyCode] = [
  "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
  "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
  "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
  "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "-": 27
]

func typeASCII(_ text: String) {
  for character in text.lowercased() {
    if let code = asciiKeyCodes[character] {
      postKey(code)
    }
  }
}

func commitTyping() {
  postKey(49) // Space commits Chinese IME composition and updates SwiftUI.
}

func click(_ point: CGPoint) {
  let down = CGEvent(
    mouseEventSource: eventSource,
    mouseType: .leftMouseDown,
    mouseCursorPosition: point,
    mouseButton: .left
  )!
  down.post(tap: .cghidEventTap)
  Thread.sleep(forTimeInterval: 0.04)
  let up = CGEvent(
    mouseEventSource: eventSource,
    mouseType: .leftMouseUp,
    mouseCursorPosition: point,
    mouseButton: .left
  )!
  up.post(tap: .cghidEventTap)
  Thread.sleep(forTimeInterval: 0.3)
}

func clickCenter(of element: AXUIElement) -> Bool {
  guard let frame = axFrame(element) else { return false }
  click(CGPoint(x: frame.midX, y: frame.midY))
  return true
}

func frontmostPID() -> pid_t? {
  NSWorkspace.shared.frontmostApplication?.processIdentifier
}

func activate(_ pid: pid_t, timeout: TimeInterval = 3) -> Bool {
  if frontmostPID() == pid { return true }
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    let script = "tell application \"System Events\" to set frontmost of (first process whose unix id is \(pid)) to true"
    runProcess("/usr/bin/osascript", ["-e", script])
    Thread.sleep(forTimeInterval: 0.12)
    if frontmostPID() == pid { return true }
  }
  return frontmostPID() == pid
}

// MARK: - App instance

final class AppInstance {
  let process = Process()
  let pid: pid_t
  let label: String
  let store: String
  var launchStartedAt = Date()

  init(label: String, store: String, arguments: [String]) throws {
    self.label = label
    self.store = store
    process.executableURL = URL(fileURLWithPath: appBinary)
    process.arguments = arguments
    var environment = ProcessInfo.processInfo.environment
    environment["PASTABLE_STORAGE_DIR"] = store
    process.environment = environment

    let logURL = artifactsDir.appendingPathComponent("app-\(label).log")
    FileManager.default.createFile(atPath: logURL.path, contents: nil)
    if let handle = try? FileHandle(forWritingTo: logURL) {
      process.standardOutput = handle
      process.standardError = handle
    }

    launchStartedAt = Date()
    try process.run()
    pid = process.processIdentifier
  }

  var alive: Bool {
    kill(pid, 0) == 0
  }

  func waitForPanel(timeout: TimeInterval = 8) -> Bool {
    waitUntil(timeout: timeout, interval: 0.08) { panelWindowInfo(pid: self.pid) != nil }
  }

  func waitForSettings(timeout: TimeInterval = 8) -> Bool {
    waitUntil(timeout: timeout, interval: 0.08) { settingsWindow(self.pid) != nil }
  }

  func waitForExit(timeout: TimeInterval = 5) -> Bool {
    waitUntil(timeout: timeout, interval: 0.08) { !self.alive }
  }

  func terminate() {
    guard alive else { return }
    process.terminate()
    _ = waitUntil(timeout: 5, interval: 0.08) { !self.alive }
    if alive {
      kill(pid, SIGKILL)
    }
  }

  func panel() -> AXUIElement? {
    panelWindow(self.pid)
  }

  func settings() -> AXUIElement? {
    settingsWindow(self.pid)
  }
}

// MARK: - Panel helpers

func panelWindow(_ pid: pid_t) -> AXUIElement? {
  axWindows(pid).first { element in
    guard let frame = axFrame(element) else { return false }
    return frame.width >= screenWidth - 4
      && abs(frame.maxY - screenHeight) < 4
      && frame.height < 600
  }
}

func settingsWindow(_ pid: pid_t) -> AXUIElement? {
  axWindows(pid).first {
    axString($0, kAXIdentifierAttribute) == "com_apple_SwiftUI_Settings_window"
  }
}

func panelScrollArea(_ pid: pid_t) -> AXUIElement? {
  guard let panel = panelWindow(pid) else { return nil }
  return axDescendants(panel).first { axRole($0) == "AXScrollArea" }
}

func cards(_ pid: pid_t) -> [AXUIElement] {
  guard let scroll = panelScrollArea(pid) else { return [] }
  return axButtons(in: scroll).filter { (axFrame($0)?.width ?? 0) > 100 }
}

func cardCount(_ pid: pid_t) -> Int {
  cards(pid).count
}

func cardDescriptions(_ pid: pid_t) -> [String] {
  cards(pid).map { axString($0, kAXDescriptionAttribute) }
}

func card(containing text: String, in pid: pid_t) -> AXUIElement? {
  cards(pid).first { axString($0, kAXDescriptionAttribute).contains(text) }
}

func waitForCardCount(_ pid: pid_t, _ count: Int, timeout: TimeInterval = 10) -> Bool {
  waitUntil(timeout: timeout, interval: 0.08) { cardCount(pid) == count }
}

func waitForCard(containing text: String, in pid: pid_t, timeout: TimeInterval = 8) -> Bool {
  waitUntil(timeout: timeout, interval: 0.08) {
    cardDescriptions(pid).contains { $0.contains(text) }
  }
}

func waitForCardsContaining(_ texts: [String], in pid: pid_t, timeout: TimeInterval = 8) -> Bool {
  waitUntil(timeout: timeout, interval: 0.08) {
    let descriptions = cardDescriptions(pid)
    return texts.allSatisfy { text in descriptions.contains { $0.contains(text) } }
  }
}

func categoryButton(_ title: String, in pid: pid_t) -> AXUIElement? {
  guard let panel = panelWindow(pid) else { return nil }
  return axDescendants(panel).first {
    axRole($0) == "AXButton" && axString($0, kAXDescriptionAttribute) == title
  }
}

func searchField(_ pid: pid_t) -> AXUIElement? {
  guard let panel = panelWindow(pid) else { return nil }
  return axDescendants(panel).first { axRole($0) == "AXTextField" }
}

func moreButton(_ pid: pid_t) -> AXUIElement? {
  guard let panel = panelWindow(pid) else { return nil }
  return axDescendants(panel).first { axString($0, kAXIdentifierAttribute) == "ellipsis" }
}

func statusItem(_ pid: pid_t) -> AXUIElement? {
  let app = axApp(pid)
  guard let bar = axElement(app, "AXExtrasMenuBar") else { return nil }
  return axChildren(bar).first
}

@discardableResult
func pressStatusItem(_ pid: pid_t) -> Bool {
  guard let item = statusItem(pid) else { return false }
  return axPress(item) == .success
}

/// Toggle the shelf via the menu bar item and wait for the requested state.
/// `AppDelegate.togglePanel` ignores presses within 0.25s of a close, so a
/// single press right after a copy is legitimately a no-op; retry once.
@discardableResult
func setPanelVisibleViaStatus(_ app: AppInstance, _ visible: Bool, timeout: TimeInterval = 4) -> Bool {
  func isVisible() -> Bool { panelWindowInfo(pid: app.pid) != nil }
  if isVisible() == visible { return true }
  for attempt in 0..<2 {
    _ = pressStatusItem(app.pid)
    if waitUntil(timeout: timeout, interval: 0.08, { isVisible() == visible }) {
      return true
    }
    if attempt == 0 { Thread.sleep(forTimeInterval: 0.45) }
  }
  return isVisible() == visible
}

func focusSearchByClick(_ app: AppInstance) -> Bool {
  guard let field = searchField(app.pid) else { return false }
  guard clickCenter(of: field) else { return false }
  // The first click is consumed; the panel activates and focuses the field a
  // few hundred milliseconds later.
  return waitUntil(timeout: 3, interval: 0.05) { axFocused(field) }
}

@discardableResult
func typeInSearch(_ app: AppInstance, _ query: String) -> Bool {
  for _ in 0..<2 {
    guard focusSearchByClick(app) else { continue }
    clearSearchField(app)
    axSetFocused(searchField(app.pid)!)
    typeASCII(query)
    commitTyping()
    if waitUntil(timeout: 3, interval: 0.05, {
      guard let field = searchField(app.pid) else { return false }
      return axString(field, kAXValueAttribute)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() == query.lowercased()
    }) {
      return true
    }
    Thread.sleep(forTimeInterval: 0.3)
  }
  return false
}

func clearSearchField(_ app: AppInstance) {
  guard let field = searchField(app.pid) else { return }
  axSetFocused(field)
  postKey(0, flags: .maskCommand) // Cmd+A
  postKey(51) // Delete
  Thread.sleep(forTimeInterval: 0.35)
}

func closePanelWithEscape(_ app: AppInstance) -> Bool {
  _ = activate(app.pid)
  postKey(53)
  return waitUntil(timeout: 3, interval: 0.08) { panelWindowInfo(pid: app.pid) == nil }
}

func ensurePanelClosed(_ app: AppInstance) {
  if panelWindowInfo(pid: app.pid) != nil {
    _ = closePanelWithEscape(app)
  }
}

// MARK: - Fixture document

final class Fixture {
  let process = Process()
  let pid: pid_t

  init() throws {
    process.executableURL = URL(fileURLWithPath: fixtureBinary)
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    pid = process.processIdentifier

    // Wait for the window and text area.
    _ = waitUntil(timeout: 6, interval: 0.1) { self.area() != nil }
  }

  var alive: Bool {
    kill(pid, 0) == 0
  }

  func area() -> AXUIElement? {
    axDescendants(axApp(pid)).first { axRole($0) == "AXTextArea" }
  }

  func text() -> String {
    guard let area = area() else { return "" }
    return axString(area, kAXValueAttribute)
  }

  func setText(_ text: String) {
    guard let area = area() else { return }
    axSetValue(area, text)
  }

  func focus() -> Bool {
    guard let area = area() else { return false }
    _ = activate(pid)
    _ = clickCenter(of: area)
    _ = waitUntil(timeout: 1.5, interval: 0.05) {
      NSWorkspace.shared.frontmostApplication?.processIdentifier == self.pid
    }
    if !axFocused(area) { axSetFocused(area) }
    return NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
  }

  func terminate() {
    guard alive else { return }
    process.terminate()
    _ = waitUntil(timeout: 4) { !self.alive }
    if alive { kill(pid, SIGKILL) }
  }
}

// MARK: - Settings helpers

func settingsTab(_ title: String, in pid: pid_t) -> AXUIElement? {
  guard let settings = settingsWindow(pid) else { return nil }
  return axDescendants(settings).first {
    axRole($0) == "AXButton"
      && (axString($0, kAXTitleAttribute) == title || axString($0, kAXDescriptionAttribute) == title)
  }
}

func settingsTexts(_ pid: pid_t) -> [String] {
  guard let settings = settingsWindow(pid) else { return [] }
  return axStaticTexts(in: settings)
}

func checkbox(near label: String, in pid: pid_t) -> AXUIElement? {
  guard let settings = settingsWindow(pid),
        let labelElement = axDescendants(settings).first(where: {
          axRole($0) == "AXStaticText" && axString($0, kAXValueAttribute) == label
        }),
        let labelFrame = axFrame(labelElement) else { return nil }

  return axDescendants(settings)
    .filter { axRole($0) == "AXCheckBox" }
    .min { lhs, rhs in
      let left = abs((axFrame(lhs)?.midY ?? .greatestFiniteMagnitude) - labelFrame.midY)
      let right = abs((axFrame(rhs)?.midY ?? .greatestFiniteMagnitude) - labelFrame.midY)
      return left < right
    }
}

func checkboxValue(_ element: AXUIElement) -> Bool? {
  axBool(axAttribute(element, kAXValueAttribute))
}

func toggleCheckbox(near label: String, in pid: pid_t, timeout: TimeInterval = 2) -> Bool? {
  guard let box = checkbox(near: label, in: pid) else { return nil }
  let before = checkboxValue(box)
  guard axPress(box) == .success else { return nil }
  _ = waitUntil(timeout: timeout, interval: 0.08) { checkboxValue(box) != before }
  return checkboxValue(box)
}

func findButton(containing text: String, in root: AXUIElement) -> AXUIElement? {
  axButtons(in: root).first { button in
    if axString(button, kAXTitleAttribute).contains(text) { return true }
    if axString(button, kAXDescriptionAttribute).contains(text) { return true }
    if axString(button, kAXValueAttribute).contains(text) { return true }
    return axDescendants(button).contains {
      axRole($0) == "AXStaticText" && axString($0, kAXValueAttribute).contains(text)
    }
  }
}

func closeSettingsWindow(_ pid: pid_t) -> Bool {
  guard let settings = settingsWindow(pid),
        let closeButton = axDescendants(settings).first(where: { axSubrole($0) == "AXCloseButton" }) else {
    return false
  }
  _ = axPress(closeButton)
  return waitUntil(timeout: 3, interval: 0.08) { settingsWindow(pid) == nil }
}

// MARK: - App lifecycle helpers

var launchedApps: [AppInstance] = []
var fixture: Fixture?
var originalClipboard: [ClipItem] = []

func launch(
  label: String,
  store: String,
  seed: Bool,
  showPanel: Bool = false,
  openSettings: Bool = false,
  dark: Bool = true,
  language: String = "zh-Hans"
) -> AppInstance? {
  var arguments = [
    "--ui-appearance", dark ? "dark" : "light",
    "-AppleLanguages", "(\(language))",
    "-AppleLocale", language == "en" ? "en_US" : "zh_CN"
  ]
  if seed { arguments.append("--seed-demo-history") }
  if showPanel { arguments.append("--show-panel") }
  if openSettings { arguments += ["--open-settings", "storage"] }

  do {
    let app = try AppInstance(label: label, store: store, arguments: arguments)
    launchedApps.append(app)
    return app
  } catch {
    fail("could not launch \(label): \(error)")
    return nil
  }
}

func cleanup() {
  for app in launchedApps where app.alive {
    app.terminate()
  }
  fixture?.terminate()
  restoreClipboard(originalClipboard)
  runProcess("/usr/bin/defaults", ["delete", bundleID])
  if workRoot.path.contains("PastableE2E-") {
    try? FileManager.default.removeItem(at: workRoot)
  }
}

defer { cleanup() }

// MARK: - Preflight

section("Environment")

check("accessibility permission", AXIsProcessTrusted(), "Accessibility permission is required for UI automation")
check("app binary exists", FileManager.default.isExecutableFile(atPath: appBinary), appBinary)
check("fixture binary exists", FileManager.default.isExecutableFile(atPath: fixtureBinary), fixtureBinary)
check("isolated bundle id", bundleID == "com.qzh.Pastable.e2e", bundleID)
check(
  "no user Pastable instance on the test bundle id",
  NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty,
  "quit com.qzh.Pastable.e2e first"
)
check("primary screen available", primaryScreen.frame.width > 0, "\(primaryScreen.frame)")

originalClipboard = snapshotClipboard()
setDefault("pasteAutomatically", false)
setDefault("playSounds", false)
setDefault("removeFormatting", false)
setDefault("saveText", true)
setDefault("saveImages", true)
setDefault("saveFiles", true)
setStringDefault("searchMode", "exact")

// Every scenario gets its own store so destructive checks cannot leak.
let storeEmpty = storePath("empty")
let storeMain = storePath("main")
let storeFocus = storePath("focus")
let storePaste = storePath("paste")
let storeFormat = storePath("format")
let storeDelete = storePath("delete")
let storeSettings = storePath("settings")
let storeQuit = storePath("quit")

// MARK: - Scenario: empty shelf

section("Empty shelf")

if let app = launch(label: "empty", store: storeEmpty, seed: false, showPanel: true) {
  if check("empty shelf becomes visible", app.waitForPanel()) {
    timings["launchToPanelMs"] = Int(Date().timeIntervalSince(app.launchStartedAt) * 1000)

    if let window = app.panel(), let frame = axFrame(window) {
      check("panel spans the screen width", abs(frame.width - screenWidth) < 2, "\(frame.width) vs \(screenWidth)")
      check("panel sits on the physical bottom", abs(frame.maxY - screenHeight) < 2, "maxY \(frame.maxY), screen \(screenHeight)")
      check("panel keeps shelf height", frame.height >= 250 && frame.height <= 450, "\(frame.height)")
    } else {
      fail("panel AX frame unavailable")
    }

    if let info = panelWindowInfo(pid: app.pid) {
      check("panel is above the Dock", info.layer >= 25, "layer \(info.layer)")
      check("panel is opaque", info.alpha > 0.9, "alpha \(info.alpha)")
    } else {
      fail("panel WindowServer info unavailable")
    }

    check("empty shelf does not activate Pastable", frontmostPID() != app.pid, "frontmost=\(frontmostPID() ?? -1)")
    checkEq("empty shelf has no cards", cardCount(app.pid), 0)

    let texts = axStaticTexts(in: app.panel() ?? axApp(app.pid))
    check("empty state explains the empty history", texts.contains("还没有剪贴板历史"), "\(texts.prefix(8))")
    check("empty state explains auto capture", texts.contains("复制任意内容后会自动出现在这里"), "\(texts.prefix(8))")
    check("empty state shows the open shortcut", texts.contains("⌘⇧V"), "\(texts.prefix(8))")
    check("empty state shows quick paste", texts.contains("⌘1–9"), "\(texts.prefix(8))")
    check("five category filters are present", ["全部", "文本", "代码", "链接", "媒体"].allSatisfy { categoryButton($0, in: app.pid) != nil })
    check("search field is present", searchField(app.pid) != nil)
    check("more menu button is present", moreButton(app.pid) != nil)

    if let screenshot = captureWindow(pid: app.pid, layer: 25, minimumWidth: 500, name: "01-empty-dark.png") {
      check("empty shelf screenshot captured", FileManager.default.fileExists(atPath: screenshot.path))
    } else {
      fail("could not capture the empty shelf")
    }

    check("empty shelf launch under 6s", Date().timeIntervalSince(app.launchStartedAt) < 6, "\(Int(Date().timeIntervalSince(app.launchStartedAt) * 1000))ms")
  }
  app.terminate()
}

// MARK: - Scenario: seeded shelf, search, categories, keyboard, copy

section("Seeded shelf")

if let app = launch(label: "main", store: storeMain, seed: true, showPanel: true) {
  if check("seeded shelf becomes visible", app.waitForPanel()) {
    check("all seeded records render", waitForCardCount(app.pid, 11), "cards=\(cardCount(app.pid))")
    Thread.sleep(forTimeInterval: 0.4)

    check("text card is present", waitForCard(containing: "记得明天下午3点开会讨论新项目方案", in: app.pid))
    check("code card is present", waitForCard(containing: "func fetchData", in: app.pid))
    check("link card is present", waitForCard(containing: "https://github.com/apple/swift", in: app.pid))
    let fileCardPresent = waitForCard(containing: "2 文件", in: app.pid)
    let fileCardDescription = cardDescriptions(app.pid).first { $0.contains("2 文件") } ?? ""
    check("file card is present with its size", fileCardPresent
      && fileCardDescription.contains("文件"),
      "\(cardDescriptions(app.pid).map { $0.prefix(50) })")
    check("multi-file card title follows copy order", fileCardDescription.contains("Q4 launch plan.md"), fileCardDescription)
    check("image card is present", waitForCard(containing: "图片", in: app.pid)
      && cardDescriptions(app.pid).contains { $0.contains("图片") && $0.contains("KB") })
    check("rich text card is present", waitForCard(containing: "Pastable rich text sample", in: app.pid))

    _ = captureWindow(pid: app.pid, layer: 25, minimumWidth: 500, name: "02-collection-dark.png")

    // Categories.
    if let code = categoryButton("代码", in: app.pid) {
      let started = Date()
      _ = axPress(code)
      let filtered = waitForCardCount(app.pid, 2)
      timings["categoryFilterMs"] = Int(Date().timeIntervalSince(started) * 1000)
      check("code filter shows only code cards", filtered && cardDescriptions(app.pid).allSatisfy { $0.contains("代码") }, "\(cardDescriptions(app.pid).map { $0.prefix(40) })")
      check("code filter is responsive", Date().timeIntervalSince(started) < 2)
    } else {
      fail("code filter not found")
    }

    if let all = categoryButton("全部", in: app.pid) {
      _ = axPress(all)
      _ = waitForCardCount(app.pid, 11)
      check("all filter restores every card", cardCount(app.pid) == 11)
    }

    if let links = categoryButton("链接", in: app.pid) {
      _ = axPress(links)
      let filtered = waitForCardCount(app.pid, 1)
      let descriptions = cardDescriptions(app.pid)
      check("link filter shows the single link card", filtered
        && descriptions.contains { $0.contains("github.com/apple/swift") }
        && !descriptions.contains { $0.contains("Q4 launch plan.md") }, "\(descriptions.map { $0.prefix(40) })")
    }

    if let media = categoryButton("媒体", in: app.pid) {
      _ = axPress(media)
      let filtered = waitForCardsContaining(["图片", "2 文件"], in: app.pid)
      check("media filter includes image and file cards", filtered && cardCount(app.pid) == 2, "\(cardDescriptions(app.pid).map { $0.prefix(40) })")
    }

    if let text = categoryButton("文本", in: app.pid) {
      _ = axPress(text)
      let filtered = waitForCardsContaining(["记得明天下午", "Pastable rich text sample", "#C8402E"], in: app.pid) && cardCount(app.pid) == 6
      let descriptions = cardDescriptions(app.pid)
      check("text filter keeps plain text and color cards", filtered
        && descriptions.contains { $0.contains("记得明天下午") }
        && descriptions.contains { $0.contains("Pastable rich text sample") }
        && descriptions.contains { $0.contains("#C8402E") })
      check("text filter excludes code and links", descriptions.allSatisfy {
        !$0.contains("func fetchData") && !$0.contains("github.com/apple/swift")
      })
    }

    if let all = categoryButton("全部", in: app.pid) {
      _ = axPress(all)
      _ = waitForCardCount(app.pid, 11)
    }

    // Search by real typing.
    let searchStarted = Date()
    if typeInSearch(app, "swift") {
      let filtered = waitForCardCount(app.pid, 1)
      timings["searchMs"] = Int(Date().timeIntervalSince(searchStarted) * 1000)
      let descriptions = cardDescriptions(app.pid)
      check("search filters by real typing", filtered, "cards=\(cardCount(app.pid))")
      check("search finds the matching link card", descriptions.contains { $0.contains("github.com/apple/swift") }, "\(descriptions.map { $0.prefix(40) })")
      check("search is responsive", Date().timeIntervalSince(searchStarted) < 3, "\(timings["searchMs"] ?? 0)ms")

      if let field = searchField(app.pid) {
        check(
          "search field shows the query",
          axString(field, kAXValueAttribute).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "swift",
          axString(field, kAXValueAttribute)
        )
      }
      _ = captureWindow(pid: app.pid, layer: 25, minimumWidth: 500, name: "03-search-swift.png")

      clearSearchField(app)
      check("clearing search restores the shelf", waitForCardCount(app.pid, 11))

      _ = typeInSearch(app, "zzzz-not-found")
      let empty = waitForCardCount(app.pid, 0)
      let texts = axStaticTexts(in: app.panel() ?? axApp(app.pid))
      check("search with no results shows the empty state", empty
        && texts.contains("没有匹配结果")
        && texts.contains("换个关键词试试"), "\(texts.prefix(10))")
      _ = captureWindow(pid: app.pid, layer: 25, minimumWidth: 500, name: "04-search-empty.png")

      clearSearchField(app)
      check("search reset restores all cards", waitForCardCount(app.pid, 11))
    } else {
      fail("could not focus the search field")
    }

    // Return focus to the document, then reopen WITHOUT activating. The global
    // key tap must drive the shelf while the document keeps the keyboard.
    check("search-focused shelf closes", closePanelWithEscape(app))
    Thread.sleep(forTimeInterval: 0.45)
    check("shelf reopens for keyboard copy", setPanelVisibleViaStatus(app, true))
    postKey(18, flags: .maskCommand)
    let closedByShortcut = waitUntil(timeout: 3, interval: 0.08) { panelWindowInfo(pid: app.pid) == nil }
    check("Cmd+1 closes the shelf", closedByShortcut)
    checkEq("Cmd+1 copies the newest card", pasteboardString(), "记得明天下午3点开会讨论新项目方案")
    check("auto-paste stays off for copy-only checks", readDefault("pasteAutomatically") == false)

    // Reopen via the status item; test menu-bar toggle.
    Thread.sleep(forTimeInterval: 0.45)
    check("status item reopens the shelf", setPanelVisibleViaStatus(app, true))
    check("status item closes the shelf", setPanelVisibleViaStatus(app, false))
    check("status item opens the shelf again", setPanelVisibleViaStatus(app, true))

    // Arrow keys + Return while the document owns the keyboard.
    postKey(124)
    postKey(124)
    postKey(36)
    _ = waitUntil(timeout: 3, interval: 0.08) { panelWindowInfo(pid: app.pid) == nil }
    check("arrow + Return closes the shelf", panelWindowInfo(pid: app.pid) == nil)
    check("arrow + Return copies the second card", pasteboardString()?.contains("func fetchData") == true, "\(pasteboardString() ?? "nil")")

    // Click a link card.
    check("shelf reopens for the link card", setPanelVisibleViaStatus(app, true))
    if let linkCard = card(containing: "github.com/apple/swift", in: app.pid), clickCenter(of: linkCard) {
      _ = waitUntil(timeout: 3, interval: 0.08) { panelWindowInfo(pid: app.pid) == nil }
      checkEq("first click on a card copies its content", pasteboardString(), "https://github.com/apple/swift")
    } else {
      fail("could not click the link card")
    }

    // File card copies every file as its own pasteboard item.
    check("shelf reopens for the file card", setPanelVisibleViaStatus(app, true))
    if let fileCard = card(containing: "2 文件", in: app.pid), axPress(fileCard) == .success {
      _ = waitUntil(timeout: 3, interval: 0.08) { panelWindowInfo(pid: app.pid) == nil }
      let paths = pasteboardFilePaths()
      check("file card closes the shelf", panelWindowInfo(pid: app.pid) == nil)
      check("file card copies both files", paths.count == 2
        && paths.contains { $0.hasSuffix("Q4 launch plan.md") }
        && paths.contains { $0.hasSuffix("budget-2026.csv") }, "\(paths)")
    } else {
      fail("could not press the file card")
    }

    // Image card copies an image payload.
    check("shelf reopens for the image card", setPanelVisibleViaStatus(app, true))
    if let imageCard = card(containing: "图片", in: app.pid), axPress(imageCard) == .success {
      _ = waitUntil(timeout: 3, interval: 0.08) { panelWindowInfo(pid: app.pid) == nil }
      let hasImage = NSPasteboard.general.data(forType: .png)?.count ?? 0
      check("image card copies an image payload", hasImage > 10_000, "\(hasImage) bytes")
    } else {
      fail("could not press the image card")
    }

    // More menu: presence, settings entry, and panel closure behaviour.
    check("shelf reopens for the more menu", setPanelVisibleViaStatus(app, true))
    if let more = moreButton(app.pid) {
      _ = clickCenter(of: more)
      let menuOpened = waitUntil(timeout: 2, interval: 0.08) {
        findButton(containing: "偏好设置", in: axApp(app.pid)) != nil
      }
      check("more menu opens", menuOpened)
      let menuTexts = ["清空历史", "偏好设置", "退出"].allSatisfy {
        findButton(containing: $0, in: axApp(app.pid)) != nil
      }
      check("more menu lists history, settings and quit", menuTexts)

      if let settingsButton = findButton(containing: "偏好设置", in: axApp(app.pid)) {
        _ = axPress(settingsButton)
        check("settings opens from the more menu", app.waitForSettings())
        if settingsWindow(app.pid) != nil {
          _ = captureWindow(pid: app.pid, layer: 8, minimumWidth: 300, name: "05-settings-from-menu.png")
          check("settings window closes", closeSettingsWindow(app.pid))
        }
      } else {
        fail("settings entry not found in the more menu")
      }
    } else {
      fail("more menu button not found")
    }

    ensurePanelClosed(app)

    // Escape closes the shelf.
    check("shelf reopens for the escape check", setPanelVisibleViaStatus(app, true))
    check("escape closes the shelf", closePanelWithEscape(app))

    // Persistence and no duplicate seeding on relaunch.
    let fileTitleBefore = fileCardDescription.components(separatedBy: "、").first ?? ""
    app.terminate()
    check("seeded app exits cleanly", !app.alive)

    if let relaunched = launch(label: "main-relaunch", store: storeMain, seed: true, showPanel: true) {
      _ = relaunched.waitForPanel()
      check("history survives a relaunch", waitForCardCount(relaunched.pid, 11), "cards=\(cardCount(relaunched.pid))")
      check("seeding does not duplicate records", cardCount(relaunched.pid) == 11)
      let first = cardDescriptions(relaunched.pid).first ?? ""
      check("last copied card moves to the front", first.contains("图片"), first)

      let fileTitleAfter = cardDescriptions(relaunched.pid).first { $0.contains("2 文件") }?
        .components(separatedBy: "、").first ?? ""
      check(
        "multi-file card title is stable across relaunch",
        !fileTitleBefore.isEmpty && fileTitleBefore == fileTitleAfter,
        "before=\(fileTitleBefore.debugDescription), after=\(fileTitleAfter.debugDescription)"
      )
      relaunched.terminate()
    }
  } else {
    fail("seeded shelf never became visible")
  }
  app.terminate()
}

// MARK: - Scenario: focus preservation (core UX promise)

section("Focus preservation")

if let app = launch(label: "focus", store: storeFocus, seed: true, showPanel: false) {
  _ = waitUntil(timeout: 5, interval: 0.1) { app.alive }
  if fixture == nil {
    fixture = try? Fixture()
  }

  if let fixture {
    _ = fixture.focus()
    fixture.setText("")
    check("fixture document is frontmost", frontmostPID() == fixture.pid, "frontmost=\(frontmostPID() ?? -1)")
    typeText("BEFORE")
    _ = waitUntil(timeout: 1, interval: 0.05) { fixture.text().contains("BEFORE") }
    check("typing works before the shelf opens", fixture.text().contains("BEFORE"), fixture.text())

    let opened = setPanelVisibleViaStatus(app, true)
    check("focus scenario opens the shelf", opened)
    if opened {
      check("opening keeps the document frontmost", frontmostPID() == fixture.pid, "frontmost=\(frontmostPID() ?? -1)")

      typeText("AFTER")
      _ = waitUntil(timeout: 1, interval: 0.05) { fixture.text().contains("AFTER") }
      let document = fixture.text()
      let query = searchField(app.pid).map { axString($0, kAXValueAttribute) } ?? ""

      check(
        "typing keeps working while the shelf is open",
        document.contains("AFTER"),
        "expected the document to receive \"AFTER\" while the shelf is open; document=\(document.debugDescription), search=\(query.debugDescription), frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")"
      )

      // Clicking a category activates the panel for the click, then the
      // category action blurs and hands the keyboard back to the document.
      if let category = categoryButton("文本", in: app.pid), clickCenter(of: category) {
        Thread.sleep(forTimeInterval: 0.5)
        typeText("CAT")
        let typedAfterCategory = waitUntil(timeout: 1.5, interval: 0.05) {
          fixture.text().contains("CAT")
        }
        check(
          "category click returns keyboard focus to the document",
          typedAfterCategory && panelWindowInfo(pid: app.pid) != nil,
          "document=\(fixture.text()), panel=\(panelWindowInfo(pid: app.pid) != nil)"
        )
      } else {
        fail("could not click the text category")
      }

      _ = closePanelWithEscape(app)
      typeText("CLOSED")
      _ = waitUntil(timeout: 1, interval: 0.05) { fixture.text().contains("CLOSED") }
      check("typing resumes after the shelf closes", fixture.text().contains("CLOSED"), fixture.text())
    }
  } else {
    fail("could not launch the document fixture")
  }
  app.terminate()
}

// MARK: - Scenario: real auto-paste into the document

section("Auto paste into the document")

setDefault("pasteAutomatically", true)
if let app = launch(label: "paste", store: storePaste, seed: true, showPanel: false) {
  _ = waitUntil(timeout: 5, interval: 0.1) { app.alive }
  if fixture == nil { fixture = try? Fixture() }

  if let fixture {
    _ = fixture.focus()
    fixture.setText("")
    check("shelf opens for the auto-paste check", setPanelVisibleViaStatus(app, true))

    if let newestCard = card(containing: "记得明天下午3点开会讨论新项目方案", in: app.pid) {
      _ = axPress(newestCard)
      let pasted = waitUntil(timeout: 3, interval: 0.08) {
        panelWindowInfo(pid: app.pid) == nil && fixture.text().contains("记得明天下午3点开会讨论新项目方案")
      }
      check("selecting a card auto-pastes into the document", pasted, "document=\(fixture.text())")
      check("a successful paste is recorded for the review prompt", readDefault("review.successfulPastes") != nil)
    } else {
      fail("could not find the newest card for the paste test")
    }
  }
  app.terminate()
}
setDefault("pasteAutomatically", false)
// A successful paste arms the review prompt; clear it so later panel opens in
// this run cannot present a StoreKit sheet on top of the automation.
for key in ["review.successfulPastes", "review.lastRequestedCount", "review.lastRequestedAt"] {
  runProcess("/usr/bin/defaults", ["delete", bundleID, key])
}

// MARK: - Scenario: remove formatting

section("Remove formatting")

setDefault("removeFormatting", true)
if let app = launch(label: "format", store: storeFormat, seed: true, showPanel: true) {
  _ = app.waitForPanel()
  if let richCard = card(containing: "Pastable rich text sample", in: app.pid), axPress(richCard) == .success {
    _ = waitUntil(timeout: 3, interval: 0.08) { panelWindowInfo(pid: app.pid) == nil }
    let types = pasteboardTypes()
    checkEq("remove formatting copies plain text only", pasteboardString(), "Pastable rich text sample")
    check("remove formatting drops rich representations", !types.contains("public.html") && !types.contains("public.rtf"), "\(types)")
  } else {
    fail("could not press the rich text card")
  }
  app.terminate()
}
setDefault("removeFormatting", false)

// MARK: - Scenario: delete and persistence

section("Delete")

if let app = launch(label: "delete", store: storeDelete, seed: true, showPanel: true) {
  _ = app.waitForPanel()
  check("delete scenario starts with 11 cards", waitForCardCount(app.pid, 11))
  postKey(124) // select first (global tap; panel is not active)
  postKey(51, flags: .maskCommand) // Cmd+Delete
  check("Cmd+Delete removes the selected card", waitForCardCount(app.pid, 10), "cards=\(cardCount(app.pid))")
  check("deleted card is gone", card(containing: "记得明天下午3点开会讨论新项目方案", in: app.pid) == nil)
  app.terminate()

  if let relaunched = launch(label: "delete-relaunch", store: storeDelete, seed: true, showPanel: true) {
    _ = relaunched.waitForPanel()
    check("deletion persists across relaunch", waitForCardCount(relaunched.pid, 10), "cards=\(cardCount(relaunched.pid))")
    relaunched.terminate()
  }
}

// MARK: - Scenario: settings

section("Settings")

if let app = launch(label: "settings", store: storeSettings, seed: true, openSettings: true) {
  if check("settings window opens", app.waitForSettings()) {
    let texts = settingsTexts(app.pid)
    check("settings shows the storage tab", texts.contains("历史记录最大数量") && texts.contains("数据库大小"))
    check("settings reports the seeded history", texts.contains("11"), "\(texts)")
    check("settings reports the database size", texts.contains { $0.contains("MB") || $0.contains("KB") }, "\(texts)")
    check("iCloud explains the certificate-free build", texts.contains { $0.contains("免证书版") }, "\(texts)")
    check("settings has four tabs", ["常规", "存储", "快捷键", "关于"].allSatisfy { settingsTab($0, in: app.pid) != nil })
    _ = captureWindow(pid: app.pid, layer: 8, minimumWidth: 300, name: "06-settings-storage.png")

    if let general = settingsTab("常规", in: app.pid) {
      _ = axPress(general)
      Thread.sleep(forTimeInterval: 0.5)
      let generalTexts = settingsTexts(app.pid)
      check("general tab exposes behaviour switches", ["登录时启动", "自动粘贴", "移除格式", "播放音效"].allSatisfy { generalTexts.contains($0) }, "\(generalTexts)")
      check("general tab reports accessibility permission", generalTexts.contains("已获得辅助功能权限"), "\(generalTexts)")

      // Toggle auto-paste off -> on, verify persistence after relaunch.
      setDefault("pasteAutomatically", false)
      app.terminate()
      if let relaunched = launch(label: "settings-toggle", store: storeSettings, seed: true, openSettings: true) {
        _ = relaunched.waitForSettings()
        if let general = settingsTab("常规", in: relaunched.pid) { _ = axPress(general) }
        Thread.sleep(forTimeInterval: 0.5)
        if let value = toggleCheckbox(near: "自动粘贴", in: relaunched.pid) {
          check("settings toggle flips the value", value == true, "value=\(String(describing: value))")
        } else {
          fail("could not toggle auto paste")
        }
        relaunched.terminate()

        if let verified = launch(label: "settings-verify", store: storeSettings, seed: true, openSettings: true) {
          _ = verified.waitForSettings()
          if let general = settingsTab("常规", in: verified.pid) { _ = axPress(general) }
          Thread.sleep(forTimeInterval: 0.5)
          if let box = checkbox(near: "自动粘贴", in: verified.pid) {
            check("settings change survives relaunch", checkboxValue(box) == true, "value=\(String(describing: checkboxValue(box)))")
            _ = axPress(box) // restore off
          } else {
            fail("could not read the persisted toggle")
          }
          verified.terminate()
        }
      }
      setDefault("pasteAutomatically", false)

      // Reopen for the remaining tabs/dialog.
      if let final = launch(label: "settings-final", store: storeSettings, seed: true, openSettings: true) {
        _ = final.waitForSettings()

        if let shortcuts = settingsTab("快捷键", in: final.pid) { _ = axPress(shortcuts) }
        Thread.sleep(forTimeInterval: 0.5)
        let shortcutTexts = settingsTexts(final.pid)
        check("shortcuts tab shows the panel shortcut", shortcutTexts.contains("弹出窗口"), "\(shortcutTexts)")

        if let about = settingsTab("关于", in: final.pid) { _ = axPress(about) }
        Thread.sleep(forTimeInterval: 0.5)
        let aboutTexts = settingsTexts(final.pid)
        check("about tab shows the version", aboutTexts.contains { $0.contains("1.2.1") }, "\(aboutTexts)")

        if let storage = settingsTab("存储", in: final.pid) { _ = axPress(storage) }
        Thread.sleep(forTimeInterval: 0.5)
        if let settings = settingsWindow(final.pid),
           let clear = findButton(containing: "清空所有历史记录", in: settings) {
          _ = axPress(clear)
          let dialog = waitUntil(timeout: 2, interval: 0.08) {
            settingsTexts(final.pid).contains("清空历史记录？")
          }
          check("clear history asks for confirmation", dialog, "\(settingsTexts(final.pid))")
          check("confirmation explains the consequence", settingsTexts(final.pid).contains("将删除全部剪贴板历史，且无法撤销。"))

          if let cancel = findButton(containing: "取消", in: settings) {
            if let frame = axFrame(cancel) {
              click(CGPoint(x: frame.midX, y: frame.midY))
            } else {
              _ = axPress(cancel)
            }
          } else {
            postKey(53)
          }
          let cancelled = waitUntil(timeout: 2, interval: 0.08) {
            !settingsTexts(final.pid).contains("清空历史记录？")
          }
          check("cancelling keeps the history", cancelled && settingsTexts(final.pid).contains("11"), "\(settingsTexts(final.pid))")
        } else {
          fail("clear history button not found")
        }

        check("settings window closes", closeSettingsWindow(final.pid))
        final.terminate()
      }
    } else {
      fail("general settings tab not found")
    }
  }
  app.terminate()
}

// MARK: - Scenario: English localization and light appearance

section("Localization and appearance")

if let app = launch(label: "english", store: storeMain, seed: true, showPanel: true, language: "en") {
  if app.waitForPanel() {
    check(
      "english category labels are localized",
      ["All", "Text", "Code", "Links", "Media"].allSatisfy { categoryButton($0, in: app.pid) != nil },
      "\(cardDescriptions(app.pid).prefix(2))"
    )
    let descriptions = cardDescriptions(app.pid)
    check("english cards use localized types", descriptions.contains { $0.contains("Code") }
      && descriptions.contains { $0.contains("Link") }
      && descriptions.contains { $0.contains("File") }, "\(descriptions.prefix(6))")
    _ = captureWindow(pid: app.pid, layer: 25, minimumWidth: 500, name: "07-collection-en.png")
  } else {
    fail("english shelf did not appear")
  }
  app.terminate()
}

if let app = launch(label: "light", store: storeMain, seed: true, showPanel: true, dark: false) {
  if app.waitForPanel() {
    if let lightShot = captureWindow(pid: app.pid, layer: 25, minimumWidth: 500, name: "08-collection-light.png") {
      let darkShot = artifactsDir.appendingPathComponent("02-collection-dark.png")
      let dark = FileManager.default.fileExists(atPath: darkShot.path) ? meanLuminance(of: darkShot) : nil
      let light = meanLuminance(of: lightShot)
      check("dark and light captures exist", dark != nil && light != nil, "dark=\(String(describing: dark)), light=\(String(describing: light))")
      if let dark, let light {
        check("light appearance is visibly brighter", light > dark + 0.25, "dark=\(dark), light=\(light)")
      }
    } else {
      fail("could not capture the light shelf")
    }
  } else {
    fail("light shelf did not appear")
  }
  app.terminate()
}

// MARK: - Scenario: quit from the more menu

section("Quit from the menu")

if let app = launch(label: "quit", store: storeQuit, seed: true, showPanel: true) {
  _ = app.waitForPanel()
  if let more = moreButton(app.pid) {
    _ = clickCenter(of: more)
    _ = waitUntil(timeout: 2, interval: 0.08) { findButton(containing: "退出", in: axApp(app.pid)) != nil }
    if let quit = findButton(containing: "退出", in: axApp(app.pid)) {
      _ = axPress(quit)
      check("quit menu terminates the app", app.waitForExit(timeout: 5))
    } else {
      fail("quit menu item not found")
    }
  } else {
    fail("more menu button not found for quit")
  }
}

// MARK: - Summary

let passed = results.filter { $0.status == Status.pass.rawValue }.count
let failed = results.filter { $0.status == Status.fail.rawValue }.count
let known = results.filter { $0.status == Status.known.rawValue }.count

let report: [String: Any] = [
  "timestamp": ISO8601DateFormatter().string(from: Date()),
  "bundleID": bundleID,
  "passed": passed,
  "failed": failed,
  "knownIssues": known,
  "total": results.count,
  "timings": timings,
  "screenshots": screenshots,
  "results": results.map {
    ["name": $0.name, "status": $0.status, "detail": $0.detail, "durationMs": $0.durationMs]
  }
]

if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
  let reportURL = artifactsDir.appendingPathComponent("report.json")
  try? data.write(to: reportURL)
  print("\nReport: \(reportURL.path)")
}

print("""

== E2E summary ==
passed: \(passed)
failed: \(failed)
known issues: \(known)
total: \(results.count)
timings: \(timings)
screenshots: \(screenshots)
""")

if known > 0 {
  print("Known product issues:")
  for result in results where result.status == Status.known.rawValue {
    print("  - \(result.name): \(result.detail)")
  }
}

exit(failed > 0 ? 1 : 0)
