import BeeKit
import Foundation
import OSLog
import UIKit
import WebKit

/// Live, zoomable graph for the goal-detail screen.
///
/// Unlike the gallery thumbnails (`GoalThumbnailView`, which snapshots the SVG to a `UIImage`), this
/// hosts the SVG in a live `WKWebView`, so pinch- and double-tap-zoom re-rasterize the vector
/// crisply rather than upscaling a bitmap. Light/dark is handled natively via a
/// `@media (prefers-color-scheme: dark)` query (WebKit re-themes when the trait collection flips,
/// in step with the rest of the UI — no JavaScript round-trip), reusing the exact same theme and
/// download cache as `SVGImageRenderer`.
@MainActor final class GoalGraphView: UIView {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalGraphView")

  private let webView: WKWebView

  /// The graph URL currently loaded, to avoid redundant reloads.
  private var loadedURL: String?

  var goal: Goal? {
    didSet {
      if goal?.id != oldValue?.id { loadedURL = nil }
      refresh()
    }
  }

  override init(frame: CGRect) {
    webView = WKWebView(frame: .zero, configuration: Self.makeConfiguration())
    super.init(frame: frame)
    setupView()
  }

  required init?(coder: NSCoder) {
    webView = WKWebView(frame: .zero, configuration: Self.makeConfiguration())
    super.init(coder: coder)
    setupView()
  }

  /// The graph is static markup — nothing in it needs to run script — so content JavaScript is off.
  /// (The SVG is fetched from the CDN, so this also limits what a tampered asset could do.) Zooming is
  /// handled by the web view's scroll view natively and does not depend on script.
  private static func makeConfiguration() -> WKWebViewConfiguration {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    return configuration
  }

  private func setupView() {
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .systemBackground  // matches the graph's themed canvas
    webView.scrollView.bounces = false
    webView.scrollView.isDirectionalLockEnabled = false  // allow free (diagonal) panning when zoomed
    webView.scrollView.showsHorizontalScrollIndicator = false
    webView.scrollView.showsVerticalScrollIndicator = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.scrollView.minimumZoomScale = 1
    webView.scrollView.maximumZoomScale = Self.maxZoom

    addSubview(webView)
    webView.snp.makeConstraints { (make) in make.edges.equalToSuperview() }

    // Our own double-tap zoom. WebKit's built-in one is disabled from the document side with
    // `touch-action: manipulation` (see htmlDocument) because it zooms to the top-left of an SVG
    // rather than to the tapped point.
    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    doubleTap.numberOfTapsRequired = 2
    webView.addGestureRecognizer(doubleTap)

    // Reload when the goal's data changes (e.g. a new datapoint regenerates the graph, changing its
    // cache-busting URL). refresh() is a no-op when nothing relevant changed. (Light/dark needs no
    // handling here — the @media query re-themes natively.)
    NotificationCenter.default.addObserver(
      forName: .NSManagedObjectContextObjectsDidChange,
      object: ServiceLocator.persistentContainer.viewContext,
      queue: OperationQueue.main,
    ) { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
  }

  private func refresh() {
    guard let goal else { return }
    let urlString = goal.cacheBustingSvgUrl
    guard !urlString.isEmpty, urlString != loadedURL else { return }

    loadedURL = urlString
    Task { [weak self] in
      guard let self else { return }
      do {
        let data = try await SVGImageRenderer.shared.svgData(for: urlString)
        // A newer goal may have been set while we were downloading.
        guard urlString == self.loadedURL else { return }
        let svg = String(decoding: data, as: UTF8.self)
        self.webView.loadHTMLString(Self.htmlDocument(svg: svg), baseURL: nil)
      } catch {
        self.logger.error("Error loading goal graph: \(error)")
        if urlString == self.loadedURL { self.loadedURL = nil }
      }
    }
  }

  // MARK: - Zoom

  private static let maxZoom: CGFloat = 3

  /// Double-tap toggles between fit (1x) and zoomed-in, centered on the tapped point.
  @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
    let scrollView = webView.scrollView
    if scrollView.zoomScale > scrollView.minimumZoomScale {
      scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
      return
    }
    let targetScale = min(2.5, scrollView.maximumZoomScale)
    let point = recognizer.location(in: webView)  // content coords (== view coords at 1x)
    let size = CGSize(width: scrollView.bounds.width / targetScale, height: scrollView.bounds.height / targetScale)
    let rect = CGRect(
      x: point.x - size.width / 2,
      y: point.y - size.height / 2,
      width: size.width,
      height: size.height,
    )
    scrollView.zoom(to: rect, animated: true)
  }

  // MARK: - HTML

  private static func htmlDocument(svg: String) -> String {
    // Both appearances are baked in: light is the default, the dark overrides live behind a
    // prefers-color-scheme media query so WebKit applies them automatically with the trait change.
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=\(Int(maxZoom))">
    <meta name="color-scheme" content="light dark">
    <style>
      :root { color-scheme: light dark; }
      /* `manipulation` keeps panning and pinch-zoom but turns off WebKit's double-tap-to-zoom, which
         GoalGraphView replaces with its own tap-centred zoom. */
      html, body { margin: 0; padding: 0; background: #ffffff; touch-action: manipulation; }
      svg { display: block; width: 100%; height: auto; touch-action: manipulation; }
      @media (prefers-color-scheme: dark) {
        \(SVGImageRenderer.darkThemeCSS)
      }
    </style>
    </head>
    <body>\(svg)</body>
    </html>
    """
  }
}
