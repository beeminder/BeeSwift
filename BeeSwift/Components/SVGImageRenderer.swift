import Foundation
import OSLog
import UIKit
import WebKit

/// Renders Beeminder goal graph SVGs into `UIImage`s.
///
/// iOS has no native SVG rasterizer, so the SVG is loaded into an off-screen `WKWebView` and
/// snapshotted. That also lets the dark-mode theme be applied as CSS.
@MainActor final class SVGImageRenderer {
  static let shared = SVGImageRenderer()

  enum RenderError: Error {
    case emptyURL
    case invalidURL
    case zeroSize
    case snapshotFailed
    case webContentProcessTerminated
    case loadTimedOut
  }

  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SVGImageRenderer")

  /// Downloaded SVG documents, keyed by cache-busting URL.
  private let dataCache = NSCache<NSString, NSData>()
  /// Rendered bitmaps, keyed by URL, size and appearance.
  private let imageCache = NSCache<NSString, UIImage>()

  /// Shared so that concurrent requests for the same goal download it once.
  private var inFlightDownloads: [String: Task<Data, Error>] = [:]

  private init() { imageCache.totalCostLimit = 64 * 1024 * 1024 }

  /// The graph SVG's viewBox size. The SVG is always laid out at this size and the snapshot downscaled,
  /// because laying it out directly in a small (thumbnail-sized) viewport is unreliable: WebKit falls
  /// back to a larger default viewport and the snapshot captures only a corner of it.
  private static let naturalSize = CGSize(width: Constants.graphWidth, height: Constants.graphHeight)

  /// Renders the graph for `darkMode`, passing the image to `primaryReady` as soon as it is captured,
  /// then also renders and caches the opposite appearance so a later light/dark switch is instant.
  ///
  /// `cropToPlot` restricts the image to the plot box (no axis labels or margins), as thumbnails need.
  func renderBothAppearances(
    urlString: String,
    outputWidth: CGFloat,
    darkMode: Bool,
    cropToPlot: Bool,
    primaryReady: @escaping (UIImage) -> Void,
  ) async throws {
    guard !urlString.isEmpty else { throw RenderError.emptyURL }
    guard outputWidth > 0 else { throw RenderError.zeroSize }

    let primaryKey = Self.imageCacheKey(
      urlString: urlString,
      outputWidth: outputWidth,
      darkMode: darkMode,
      cropToPlot: cropToPlot,
    )
    let secondaryKey = Self.imageCacheKey(
      urlString: urlString,
      outputWidth: outputWidth,
      darkMode: !darkMode,
      cropToPlot: cropToPlot,
    )

    // Typically already rendered as the opposite appearance of an earlier render.
    if let cached = imageCache.object(forKey: primaryKey) {
      primaryReady(cached)
      return
    }

    let data = try await svgData(for: urlString)

    // Rendering must be serialized on the shared web view.
    await renderLock.acquire()
    defer { renderLock.release() }

    // The requester may have given up (e.g. its cell scrolled off-screen) while we were queued.
    try Task.checkCancellation()

    // Another waiter may have rendered the same thing while we were queued.
    if let cached = imageCache.object(forKey: primaryKey) {
      primaryReady(cached)
      return
    }

    let secondary = try await rasterizeBoth(
      svgData: data,
      outputWidth: outputWidth,
      primaryDarkMode: darkMode,
      cropToPlot: cropToPlot,
    ) { [weak self] primary in
      self?.imageCache.setObject(primary, forKey: primaryKey, cost: Self.cost(of: primary))
      primaryReady(primary)
    }
    imageCache.setObject(secondary, forKey: secondaryKey, cost: Self.cost(of: secondary))
  }

  /// Synchronous cache lookup, so a hit can be shown in the same runloop without a placeholder flash.
  func cachedImage(urlString: String, outputWidth: CGFloat, darkMode: Bool, cropToPlot: Bool) -> UIImage? {
    let key = Self.imageCacheKey(
      urlString: urlString,
      outputWidth: outputWidth,
      darkMode: darkMode,
      cropToPlot: cropToPlot,
    )
    return imageCache.object(forKey: key)
  }

  // MARK: - Downloading

  /// Downloads and caches the SVG document at `urlString`. Concurrent callers share one download.
  func svgData(for urlString: String) async throws -> Data {
    if let cached = dataCache.object(forKey: urlString as NSString) { return cached as Data }
    if let existing = inFlightDownloads[urlString] { return try await existing.value }

    guard let url = URL(string: urlString) else { throw RenderError.invalidURL }

    let task = Task<Data, Error> {
      let (data, _) = try await URLSession.shared.data(from: url)
      return data
    }
    inFlightDownloads[urlString] = task
    defer { inFlightDownloads[urlString] = nil }

    let data = try await task.value
    dataCache.setObject(data as NSData, forKey: urlString as NSString, cost: data.count)
    return data
  }

  // MARK: - Rasterization

  private lazy var webView: WKWebView = {
    let configuration = WKWebViewConfiguration()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.isUserInteractionEnabled = false
    // Off-screen rendering surface; keep VoiceOver out of it.
    webView.accessibilityElementsHidden = true
    // Otherwise the scroll view insets the content for the safe area and the snapshot loses the
    // graph's bottom axis labels.
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.navigationDelegate = navigationDelegate
    return webView
  }()

  private let navigationDelegate = NavigationDelegate()
  private let renderLock = AsyncLock()

  /// Loads the SVG once and snapshots both appearances: `primaryDarkMode` first (passed to
  /// `onPrimary`), then the opposite, which is returned. Swapping the theme stylesheet is only a
  /// recolor, so the second snapshot avoids a second load and layout of the large SVG.
  private func rasterizeBoth(
    svgData: Data,
    outputWidth: CGFloat,
    primaryDarkMode: Bool,
    cropToPlot: Bool,
    onPrimary: @escaping (UIImage) -> Void,
  ) async throws -> UIImage {
    let svg = String(decoding: svgData, as: UTF8.self)
    let html = Self.htmlDocument(svg: svg, pointSize: Self.naturalSize)

    attachToWindowIfNeeded()
    // Laid out at natural size (see naturalSize) and parked off-screen. Snapshot rects are in the web
    // view's own coordinates, so its position is irrelevant.
    webView.frame = CGRect(x: -20000, y: -20000, width: Self.naturalSize.width, height: Self.naturalSize.height)

    try await load(html: html)

    // Theme and measure the plot box in one round-trip.
    let measurement = try await evaluateJavaScript(
      Self.themeAndMeasureJS(css: Self.appearanceCSS(darkMode: primaryDarkMode))
    )
    let plotRect = Self.rect(from: measurement)

    // The SVG renders 1:1 with its viewBox, so the plot box is also the snapshot rect in points.
    let snapshotRect = (cropToPlot ? plotRect : nil) ?? CGRect(origin: .zero, size: Self.naturalSize)

    // Let the theme (and, right after load, the initial layout) paint before snapshotting.
    try await waitForPaint()
    let primary = try await snapshot(rect: snapshotRect, outputWidth: outputWidth)
    onPrimary(primary)

    // Recolor only; no reload.
    _ = try await evaluateJavaScript(Self.setThemeJS(css: Self.appearanceCSS(darkMode: !primaryDarkMode)))
    try await waitForPaint()
    return try await snapshot(rect: snapshotRect, outputWidth: outputWidth)
  }

  /// Guards against a load that never reports completion, which would hold the render lock forever.
  private static let loadTimeout: Duration = .seconds(15)

  /// Loads `html` into the shared web view and returns once the document has finished loading.
  private func load(html: String) async throws {
    let timeout = Task { [weak self] in
      try await Task.sleep(for: Self.loadTimeout)
      guard let self else { return }
      self.logger.error("SVG document load timed out")
      self.navigationDelegate.finish(.failure(RenderError.loadTimedOut))
      self.webView.stopLoading()
    }
    defer { timeout.cancel() }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      navigationDelegate.onComplete = { result in continuation.resume(with: result) }
      navigationDelegate.expectedNavigation = webView.loadHTMLString(html, baseURL: nil)
    }
  }

  /// Returns once the web view has painted the current DOM. The first requestAnimationFrame callback
  /// runs before the next frame renders; the second runs after it has been committed. The timer is a
  /// fallback in case frames are throttled for the off-screen view.
  private func waitForPaint() async throws {
    let winner = try await callAsyncJavaScript(
      """
      return await Promise.race([
        new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve('frame')))),
        new Promise(resolve => setTimeout(() => resolve('timeout'), 250)),
      ]);
      """
    )
    if winner as? String != "frame" {
      logger.debug("Paint wait fell back to the timer (animation frames not delivered)")
    }
  }

  /// Snapshots the current web-view content within `rect`, downscaled to `outputWidth` points wide.
  private func snapshot(rect: CGRect, outputWidth: CGFloat) async throws -> UIImage {
    let config = WKSnapshotConfiguration()
    config.rect = rect
    config.snapshotWidth = NSNumber(value: Double(outputWidth))

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
      webView.takeSnapshot(with: config) { [weak self] image, error in
        if let image {
          continuation.resume(returning: image)
        } else {
          self?.logger.error("SVG snapshot failed: \(String(describing: error))")
          continuation.resume(throwing: error ?? RenderError.snapshotFailed)
        }
      }
    }
  }

  /// `WKWebView` only reliably renders (and so snapshots) when it is part of a window.
  private func attachToWindowIfNeeded() {
    guard webView.window == nil else { return }
    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first {
      $0.isKeyWindow
    }
    window?.addSubview(webView)
  }

  /// Runs JavaScript and returns its result. Uses the completion-handler API: the async overload can
  /// crash bridging a `null`/`undefined` result.
  private func evaluateJavaScript(_ js: String) async throws -> Any? {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any?, Error>) in
      webView.evaluateJavaScript(js) { result, error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: result) }
      }
    }
  }

  /// Runs an async JavaScript function body and returns its result, which must be non-null (see
  /// `evaluateJavaScript`).
  private func callAsyncJavaScript(_ functionBody: String) async throws -> Any {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any, Error>) in
      webView.callAsyncJavaScript(functionBody, arguments: [:], in: nil, in: .page) { result in
        continuation.resume(with: result)
      }
    }
  }

  // MARK: - HTML / CSS

  /// Dark-mode theme for the graph, overriding bgraph's SVG classes. Only the neutrals are inverted
  /// (canvas, axes, text, grid, safe region); the meaningful datapoint and line colors are kept. A
  /// blanket inversion would turn the red line pink and the safe region black. If bgraph renames a
  /// class, the affected elements keep their light-mode colors.
  ///
  /// `GoalGraphView` applies the same CSS behind a `prefers-color-scheme: dark` media query.
  static let darkThemeCSS = """
    /* page / plot background */
    html, body { background: #000000; }

    /* neutrals: flip light <-> dark */
    .axis path, .axis line { stroke: #8e8e93 !important; }
    .axis .minor line { stroke: #48484a !important; }
    .grid line { stroke: #1a1a1c !important; }
    .axis text, .axislabel, .tick text,
    .pasttext, .ctxtodaytext, .ctxhortext, .hashtag { fill: #c7c7cc !important; }
    .waterbuf, .waterbux { fill: #ffffff !important; }
    /* The ∞ watermark is a <use> of #inf: a black ∞ with the loop holes painted white on top. Its
       paths set their own fills, so the .waterbuf rule above doesn't reach them. */
    #inf path[fill="black"] { fill: #ffffff !important; }
    #inf path[fill="white"] { fill: #000000 !important; }
    /* Black datapoint outlines would vanish, merging dense dots into a blob. */
    #svg1 .dp, circle.dots, #svg1 .autophages { stroke: #c7c7cc !important; }
    circle.hp { fill: #cfcfd4 !important; }

    /* akrasia-horizon lockout band: was a light pink hatch -> subtle dark maroon */
    .pinkregion { fill: #2c1a1a !important; }

    /* Safe region. Match by fill value: which .halfplaneN is yellow varies per goal, and the unused
       ones are fill="none". */
    .ybhp[fill="#ffff88"] { fill: #26210e !important; }
    .ybhp[fill="#ffffbd"] { fill: #322c16 !important; }
    .guides { stroke: #2f2a18 !important; }
    #svg1 .maxflux, #svg1 .stdflux { stroke: #6e5e1c !important; }

    /* meaningful colors: keep; nudge the dark ones brighter on black */
    #svg1 .razr, .razr { stroke: #ff3b30 !important; }
    .dp.red, .ap.red, .autophages.red, .derails { fill: #ff453a !important; }
    .dp.blu, .ap.blu, .autophages.blu { fill: #5e7bff !important; }
    .horizontext { fill: #6b8cff !important; }

    /* Rare in practice but would render wrong on black (see bgraph dotcolor/arcregion): black
       datapoints, the autophage slash, and the archived-road region. */
    .dp.blk, .ap.blk, .autophages.blk { fill: #c7c7cc !important; }
    .autophage-slash { stroke: #6e6e73 !important; }
    .arcregion { fill: #2a2a2a !important; }
    /* odometer tare/restart/archive markers */
    .tarings, .restarts, .archives { stroke: #48484a !important; }
    """

  /// The CSS applied to the loaded SVG for an appearance.
  static func appearanceCSS(darkMode: Bool) -> String {
    darkMode ? darkThemeCSS : "html, body { background: #ffffff; }"
  }

  /// Wraps the SVG in a document whose viewport and SVG are pinned to `pointSize` (CSS px = points).
  /// Without this WebKit lays the SVG out at a default viewport width and the snapshot captures only
  /// its top-left corner.
  private static func htmlDocument(svg: String, pointSize: CGSize) -> String {
    let width = Int(pointSize.width.rounded())
    let height = Int(pointSize.height.rounded())

    return """
      <!DOCTYPE html>
      <html>
      <head>
      <meta name="viewport" content="width=\(width), initial-scale=1, maximum-scale=1, user-scalable=no">
      <style>
        html, body { margin: 0; padding: 0; width: \(width)px; height: \(height)px; overflow: hidden; }
        svg { display: block; width: \(width)px; height: \(height)px; }
      </style>
      </head>
      <body>\(svg)</body>
      </html>
      """
  }

  /// JavaScript that installs `css` as the `#bm-theme` stylesheet and returns the `.zoomarea` plot box
  /// in viewBox coordinates (mapped through its CTM to account for ancestor transforms), or an empty
  /// object if there is none. Always returns an object so the bridged result is well-defined.
  private static func themeAndMeasureJS(css: String) -> String {
    return """
      (function() {
        var style = document.getElementById('bm-theme');
        if (!style) { style = document.createElement('style'); style.id = 'bm-theme'; \
      document.head.appendChild(style); }
        style.textContent = \(jsStringLiteral(css));

        var z = document.querySelector('.zoomarea');
        if (!z || !z.getBBox) { return {}; }
        var b = z.getBBox();
        var m = z.getCTM();
        if (!m) { return { x: b.x, y: b.y, width: b.width, height: b.height }; }
        var xs = [b.x, b.x + b.width], ys = [b.y, b.y + b.height], px = [], py = [];
        for (var i = 0; i < 2; i++) {
          for (var j = 0; j < 2; j++) {
            px.push(m.a * xs[i] + m.c * ys[j] + m.e);
            py.push(m.b * xs[i] + m.d * ys[j] + m.f);
          }
        }
        var minx = Math.min.apply(null, px), maxx = Math.max.apply(null, px);
        var miny = Math.min.apply(null, py), maxy = Math.max.apply(null, py);
        return { x: minx, y: miny, width: maxx - minx, height: maxy - miny };
      })();
      """
  }

  /// JavaScript that replaces the `#bm-theme` stylesheet's contents.
  private static func setThemeJS(css: String) -> String {
    return """
      (function() {
        var style = document.getElementById('bm-theme');
        if (!style) { style = document.createElement('style'); style.id = 'bm-theme'; \
      document.head.appendChild(style); }
        style.textContent = \(jsStringLiteral(css));
        return {};
      })();
      """
  }

  /// Encodes a Swift string as a JS string literal (a JSON string is also a valid JS string).
  private static func jsStringLiteral(_ string: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: string, options: [.fragmentsAllowed]),
      let literal = String(data: data, encoding: .utf8)
    else { return "\"\"" }
    return literal
  }

  /// Parses a `{x, y, width, height}` object returned from JavaScript into a `CGRect`.
  private static func rect(from value: Any?) -> CGRect? {
    guard let dict = value as? [String: Any], let x = (dict["x"] as? NSNumber)?.doubleValue,
      let y = (dict["y"] as? NSNumber)?.doubleValue, let w = (dict["width"] as? NSNumber)?.doubleValue,
      let h = (dict["height"] as? NSNumber)?.doubleValue, w > 0, h > 0
    else { return nil }
    return CGRect(x: x, y: y, width: w, height: h)
  }

  // MARK: - Cache keys

  private static func imageCacheKey(urlString: String, outputWidth: CGFloat, darkMode: Bool, cropToPlot: Bool)
    -> NSString
  {
    let scale = UITraitCollection.current.displayScale
    return
      "\(urlString)|w\(Int(outputWidth.rounded()))@\(scale)|\(darkMode ? "dark" : "light")|\(cropToPlot ? "plot" : "full")"
      as NSString
  }

  private static func cost(of image: UIImage) -> Int {
    Int(image.size.width * image.scale * image.size.height * image.scale * 4)
  }
}

/// Bridges `WKNavigationDelegate` callbacks into a single completion closure.
private final class NavigationDelegate: NSObject, WKNavigationDelegate {
  var onComplete: ((Result<Void, Error>) -> Void)?
  /// Callbacks for other navigations are ignored, in particular the failure WebKit reports for a load
  /// we timed out and stopped, which can arrive after the next load has started.
  var expectedNavigation: WKNavigation?

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(.success(()), for: navigation) }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    finish(.failure(error), for: navigation)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    finish(.failure(error), for: navigation)
  }

  private func finish(_ result: Result<Void, Error>, for navigation: WKNavigation?) {
    if let navigation, let expectedNavigation, navigation !== expectedNavigation { return }
    finish(result)
  }

  /// No didFinish/didFail arrives when the content process dies; fail the load so the render lock is
  /// released.
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    finish(.failure(SVGImageRenderer.RenderError.webContentProcessTerminated))
  }

  /// Completes the pending load regardless of navigation (process termination, timeout).
  func finish(_ result: Result<Void, Error>) {
    let completion = onComplete
    onComplete = nil
    expectedNavigation = nil
    completion?(result)
  }
}

/// A minimal FIFO async mutex used to serialize access to the shared rendering web view.
@MainActor private final class AsyncLock {
  private var isLocked = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func acquire() async {
    if !isLocked {
      isLocked = true
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  func release() { if waiters.isEmpty { isLocked = false } else { waiters.removeFirst().resume() } }
}
