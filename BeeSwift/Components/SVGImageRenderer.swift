import Foundation
import OSLog
import UIKit
import WebKit

/// Renders Beeminder goal graph SVGs into `UIImage`s.
///
/// SVGs cannot be rasterized natively on iOS, so we render them faithfully with a `WKWebView` and
/// snapshot the result. Using a web view also lets us inject CSS overrides (e.g. for dark mode).
///
/// Rendering goes through a single, reused web view (web views are main-thread only and relatively
/// expensive), so the actual rasterization is serialized. Downloads run concurrently and both the
/// downloaded SVG data and the rendered bitmaps are cached so that re-rendering at a new size or for
/// a different appearance does not hit the network again.
@MainActor final class SVGImageRenderer {
  static let shared = SVGImageRenderer()

  enum RenderError: Error {
    case emptyURL
    case invalidURL
    case zeroSize
    case snapshotFailed
  }

  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "SVGImageRenderer")

  /// Cache of downloaded SVG documents, keyed by their (cache-busting) URL string.
  private let dataCache = NSCache<NSString, NSData>()
  /// Cache of rendered bitmaps, keyed by URL + size + appearance.
  private let imageCache = NSCache<NSString, UIImage>()

  /// In-flight downloads, so two views requesting the same goal share a single network request.
  private var inFlightDownloads: [String: Task<Data, Error>] = [:]

  private init() {
    imageCache.totalCostLimit = 64 * 1024 * 1024  // ~64MB of rendered graphs
  }

  /// The natural size of a Beeminder graph SVG (its viewBox). We always lay the SVG out at this size
  /// — which renders reliably — and downscale the snapshot to the requested output width. Rendering
  /// directly into a small (e.g. thumbnail-sized) viewport is unreliable: WebKit lays the SVG out at
  /// a larger default viewport and the snapshot captures only a corner of it.
  private static let naturalSize = CGSize(width: Constants.graphWidth, height: Constants.graphHeight)

  /// Renders the graph for `darkMode` and, from the *same* page load, also renders and caches the
  /// opposite appearance, so a later light/dark switch is an instant cache hit. Loading and laying
  /// out the (large) SVG is the expensive step; the dark theme is a pure recolor, so rather than
  /// loading the SVG twice we load once, snapshot, swap the theme stylesheet in the DOM, and snapshot
  /// again.
  ///
  /// `primaryReady` is called (on the main actor) with the `darkMode` image as soon as it has been
  /// captured — before the opposite appearance is rendered — so display latency is unchanged.
  ///
  /// When `cropToPlot` is true the snapshot is cropped to just the graph's plot box (no axis labels,
  /// dates, or margins) — used for thumbnails, matching the old dedicated thumbnail images.
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

    // Toggle path: the requested appearance was already rendered (as the opposite of an earlier
    // render), so display it immediately with no web-view work.
    if let cached = imageCache.object(forKey: primaryKey) {
      primaryReady(cached)
      return
    }

    let data = try await svgData(for: urlString)

    // Rendering must be serialized on the shared web view.
    await renderLock.acquire()
    defer { renderLock.release() }

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

  /// Synchronous cache lookup, so a cache hit can be displayed in the same runloop — avoiding a
  /// placeholder flash when, for example, a reused collection-view cell re-requests a graph it has
  /// already rendered. Returns nil on a miss, in which case `renderBothAppearances` should be used.
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

  private func svgData(for urlString: String) async throws -> Data {
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
    // Stop the web view's scroll view from inadvertently insetting (and so shifting/clipping) the
    // content for safe areas — otherwise the snapshot loses the graph's bottom axis labels.
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.navigationDelegate = navigationDelegate
    return webView
  }()

  private let navigationDelegate = NavigationDelegate()
  private let renderLock = AsyncLock()

  /// Loads the SVG once and captures both appearances: snapshots `primaryDarkMode` (invoking
  /// `onPrimary` with it), then swaps the theme stylesheet in the DOM and snapshots the opposite
  /// appearance, which is returned. Colours change but geometry doesn't, so the second snapshot only
  /// costs a recalc + repaint rather than another full load.
  private func rasterizeBoth(
    svgData: Data,
    outputWidth: CGFloat,
    primaryDarkMode: Bool,
    cropToPlot: Bool,
    onPrimary: @escaping (UIImage) -> Void,
  ) async throws -> UIImage {
    let svg = String(decoding: svgData, as: UTF8.self)
    // The document loads with only structural CSS (sizing). Appearance (background + theme) and the
    // plot-box measurement are applied via the DOM after load — see `themeAndMeasureJS`.
    let html = Self.htmlDocument(svg: svg, pointSize: Self.naturalSize)

    attachToWindowIfNeeded()
    // The SVG is always laid out at its natural size; the snapshot is downscaled to the requested
    // output width. The web view's own content lives at (0, 0); its frame is positioned off-screen so
    // it is never visible. takeSnapshot's rect is in the web view's coordinate space, so the
    // off-screen position does not affect it.
    webView.frame = CGRect(x: -20000, y: -20000, width: Self.naturalSize.width, height: Self.naturalSize.height)

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      navigationDelegate.onComplete = { result in continuation.resume(with: result) }
      webView.loadHTMLString(html, baseURL: nil)
    }

    // Apply the primary appearance and read the plot box (in viewBox coordinates, mapped through the
    // element's CTM so it's robust to transforms) in a single round-trip.
    let measurement = try await evaluateJavaScript(
      Self.themeAndMeasureJS(css: Self.appearanceCSS(darkMode: primaryDarkMode))
    )
    let plotRect = Self.rect(from: measurement)

    // For thumbnails, capture only the plot box (no axis labels/margins). The SVG renders 1:1 with
    // its viewBox, so the plot rect is also the snapshot rect in web-view points.
    let snapshotRect = (cropToPlot ? plotRect : nil) ?? CGRect(origin: .zero, size: Self.naturalSize)

    // The style was just applied; give the web view a moment to repaint before snapshotting (this
    // also covers the paint lag of a large, complex graph SVG).
    try? await Task.sleep(for: .milliseconds(80))
    let primary = try await snapshot(rect: snapshotRect, outputWidth: outputWidth)
    onPrimary(primary)

    // Swap to the opposite appearance — only the colours change, so this is a recalc + repaint, not
    // a reload. A short delay lets that repaint land before the second snapshot.
    _ = try await evaluateJavaScript(Self.setThemeJS(css: Self.appearanceCSS(darkMode: !primaryDarkMode)))
    try? await Task.sleep(for: .milliseconds(50))
    return try await snapshot(rect: snapshotRect, outputWidth: outputWidth)
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

  /// Runs JavaScript in the web view and returns its result. Uses the completion-handler API (rather
  /// than the async overload, which can crash bridging a `null`/`undefined` result).
  private func evaluateJavaScript(_ js: String) async throws -> Any? {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any?, Error>) in
      webView.evaluateJavaScript(js) { result, error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: result) }
      }
    }
  }

  // MARK: - HTML / CSS

  /// Dark-mode theme for the graph. Rather than blanket-inverting the image (which turns the bright
  /// red line pink, the yellow safe region black, etc.), we override Beeminder's own `bgraph` SVG
  /// classes: invert only the neutrals (dark canvas, light axes/text, dimmed gridlines, dimmed amber
  /// safe region) and keep the meaningful datapoint/line colors, nudging the darker ones brighter on
  /// black. Note this couples us to those class names — if they change, affected elements fall back
  /// to their light-mode colors until updated.
  private static let darkThemeCSS = """
    /* page / plot background */
    html, body { background: #000000; }

    /* neutrals: flip light <-> dark */
    .axis path, .axis line { stroke: #8e8e93 !important; }
    .axis .minor line { stroke: #48484a !important; }
    .grid line { stroke: #1a1a1c !important; }
    .axis text, .axislabel, .tick text,
    .pasttext, .ctxtodaytext, .ctxhortext, .hashtag { fill: #c7c7cc !important; }
    .waterbuf, .waterbux { fill: #ffffff !important; }
    #svg1 .dp, circle.dots, #svg1 .autophages { stroke: #000000 !important; }
    circle.hp { fill: #cfcfd4 !important; }

    /* akrasia-horizon lockout band: was a light pink hatch -> subtle dark maroon */
    .pinkregion { fill: #2c1a1a !important; }

    /* Yellow safe region (bright on white) -> subtle dark on black. Match by fill VALUE, not the
       `.halfplaneN` index: the yellow half-planes use different indices per goal, and the unused
       ones are `fill="none"` (which we must leave transparent rather than paint a phantom region). */
    .ybhp[fill="#ffff88"] { fill: #26210e !important; }
    .ybhp[fill="#ffffbd"] { fill: #322c16 !important; }
    .guides { stroke: #2f2a18 !important; }
    #svg1 .maxflux, #svg1 .stdflux { stroke: #6e5e1c !important; }

    /* meaningful colors: keep; nudge the dark ones brighter on black */
    #svg1 .razr, .razr { stroke: #ff3b30 !important; }
    .dp.red, .ap.red, .autophages.red, .derails { fill: #ff453a !important; }
    .dp.blu, .ap.blu, .autophages.blu { fill: #5e7bff !important; }
    .horizontext { fill: #6b8cff !important; }

    /* Defensive: elements that are invisible-on-white in light mode but would render wrong on black.
       None occur in common goals, so these are added pre-emptively (see bgraph dotcolor/arcregion):
       - black datapoints (dotcolor returns BLCK for points before the goal's start) -> light dot
       - autophage slash (black) -> light stroke
       - archived-road region (light gray, only removed in the editor) -> dark gray */
    .dp.blk, .ap.blk, .autophages.blk { fill: #c7c7cc !important; }
    .autophage-slash { stroke: #6e6e73 !important; }
    .arcregion { fill: #2a2a2a !important; }
    /* odometer tare/restart/archive markers: light-gray zigzag lines (drawn in the static graph) -> dim gray */
    .tarings, .restarts, .archives { stroke: #48484a !important; }
    """

  /// The appearance (background + dark theme) that is injected into the DOM after load.
  private static func appearanceCSS(darkMode: Bool) -> String {
    darkMode ? darkThemeCSS : "html, body { background: #ffffff; }"
  }

  /// The structural document: pins the layout viewport and the SVG to exactly the target size (in CSS
  /// px == points). Without this the web view lays the SVG out at a default viewport width and the
  /// snapshot only captures its top-left corner. Appearance is applied separately via the DOM.
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

  /// JavaScript that applies the appearance stylesheet (creating the reusable `#bm-theme` style
  /// element) and returns the `.zoomarea` plot box in viewBox coordinates (mapped through its CTM, so
  /// it survives ancestor transforms). Returns an empty object if there is no plot box. Always
  /// returns an object (never `undefined`) to keep the bridged result well-defined.
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

  /// JavaScript that swaps the `#bm-theme` stylesheet's contents — a recalc + repaint, no reload —
  /// used to re-theme the already-loaded SVG for its opposite appearance.
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

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(.success(())) }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    finish(.failure(error))
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    finish(.failure(error))
  }

  private func finish(_ result: Result<Void, Error>) {
    let completion = onComplete
    onComplete = nil
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
