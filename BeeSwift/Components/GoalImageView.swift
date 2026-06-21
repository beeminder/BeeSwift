import BeeKit
import Foundation
import OSLog
import SnapKit
import UIKit

/// Shows the current graph for a goal
/// Handles placeholders for loading and queued states, and automatically updates when the goal changes
class GoalImageView: UIView {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalImageView")

  private let imageView = UIImageView()
  private let beeLemniscateView = BeeLemniscateView()

  private var currentlyShowingGraph = false
  /// Invalidates in-flight renders so their callbacks no-op (avoids races when the goal changes or
  /// renders finish out of order).
  private var currentRenderToken: UUID? = nil
  private var currentRenderTask: Task<Void, Never>? = nil
  /// The render key currently displayed, to avoid redundant re-rendering.
  private var shownRenderKey: String? = nil
  /// The render key currently being rendered, so a burst of identical requests (e.g. repeated layout
  /// passes) starts only one render.
  private var inFlightRenderKey: String? = nil

  public let isThumbnail: Bool

  // MARK: Sizing
  //
  // GoalImageView owns the resolution it rasterizes at. Thumbnails are a fixed size (so transient
  // layout passes never change it, and thus never trigger a re-render); the detail view rasterizes
  // at whatever width its container lays it out to.

  /// The fixed point size of a thumbnail graph view.
  static let thumbnailSize = CGSize(width: Constants.thumbnailWidth, height: Constants.thumbnailHeight)

  /// The width (in points) the graph is rasterized at.
  private var renderWidth: CGFloat { isThumbnail ? Self.thumbnailSize.width : bounds.width }

  public var goal: Goal? {
    didSet {
      // If changed to a different goal, remove any current state
      if goal !== oldValue { clearGoalGraph() }
      refresh()
    }
  }

  init(isThumbnail: Bool) {
    self.isThumbnail = isThumbnail
    super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    setupView()
  }

  required init?(coder: NSCoder) {
    self.isThumbnail = false
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    if isThumbnail { self.snp.makeConstraints { (make) in make.size.equalTo(Self.thumbnailSize) } }

    self.addSubview(imageView)
    imageView.snp.makeConstraints { (make) in make.edges.equalToSuperview() }
    self.imageView.image = UIImage(named: "GraphPlaceholder")

    self.addSubview(beeLemniscateView)
    beeLemniscateView.snp.makeConstraints { (make) in make.edges.equalToSuperview() }
    beeLemniscateView.isHidden = true

    // Re-render when the user switches between light and dark mode.
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in self.refresh() }

    // Re-check appearance when the scene becomes active again — catches genuine light/dark changes
    // made while we were backgrounded or inactive (where we deliberately skip rendering; see refresh).
    NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification,
      object: nil,
      queue: OperationQueue.main,
    ) { [weak self] _ in self?.refresh() }

    NotificationCenter.default.addObserver(
      forName: .NSManagedObjectContextObjectsDidChange,
      object: ServiceLocator.persistentContainer.viewContext,
      queue: OperationQueue.main,
    ) { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
    refresh()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // The detail view rasterizes at its laid-out width (often zero until the first layout pass), so
    // re-render when that changes. Thumbnails render at a fixed width and don't depend on layout.
    if !isThumbnail { refresh() }
  }

  @MainActor private func clearGoalGraph() {
    currentRenderTask?.cancel()
    currentRenderTask = nil
    shownRenderKey = nil
    imageView.image = UIImage(named: "GraphPlaceholder")
    currentlyShowingGraph = false
    beeLemniscateView.isHidden = true
    updateBorder()
  }

  @MainActor private func updateBorder() {
    if isThumbnail {
      imageView.layer.borderColor = goal?.countdownColor.cgColor
      imageView.layer.borderWidth = goal == nil ? 0 : 1
    } else {
      imageView.layer.borderColor = nil
      imageView.layer.borderWidth = 0
    }
  }

  @MainActor private func showGraphImage(image: UIImage) {
    // Animating the thumbnail view interacts badly with cell re-use in the gallery
    // e.g. it would cause us to show the image from a different goal before animating
    // to the corrent one.
    let duration = isThumbnail ? 0 : 0.4

    UIView.transition(
      with: imageView,
      duration: duration,
      options: .transitionCrossDissolve,
      animations: { [weak self] in
        self?.imageView.image = image
        self?.beeLemniscateView.isHidden = self?.goal == nil || self?.goal?.queued == false
        self?.updateBorder()
      },
    ) { [weak self] _ in self?.currentlyShowingGraph = true }
  }

  @MainActor private func refresh() {
    //  No Goal: Placeholder, no animation
    guard let goal = self.goal else {
      clearGoalGraph()
      return
    }

    //  - Deadbeat: Placeholder, no animation
    if goal.owner.deadbeat {
      clearGoalGraph()
      return
    }

    // When queued, we should show a loading indicator over any existing graph,
    // but not over the placeholder image.
    if goal.queued { beeLemniscateView.isHidden = !currentlyShowingGraph }

    // The detail view needs a laid-out width before it can rasterize; layoutSubviews calls us again
    // once it has one. (Thumbnails use a fixed renderWidth, so this is always satisfied for them.)
    let outputWidth = renderWidth
    guard outputWidth > 0 else { return }

    let urlString = goal.cacheBustingSvgUrl
    guard !urlString.isEmpty else {
      // No SVG URL yet (e.g. a goal cached before this field existed); leave the placeholder until
      // the next data refresh populates it.
      return
    }

    let darkMode = traitCollection.userInterfaceStyle == .dark
    let renderKey = "\(urlString)|w\(Int(outputWidth))|\(darkMode)"

    // Already showing — or already rendering — exactly this; nothing to do. (refresh() is called
    // frequently via Core Data change notifications and, for the detail view, layout passes.)
    if renderKey == shownRenderKey || renderKey == inFlightRenderKey { return }

    // Don't start a render while the scene is backgrounded. When backgrounding, iOS re-renders the
    // app in the opposite appearance to cache an app-switcher snapshot, transiently flipping our
    // trait collection; any refresh() during that window (trait change, layout pass, or Core Data
    // notification) would otherwise render a wrong-appearance graph that briefly flashes on return.
    // UIScene.didActivateNotification re-runs refresh() once we're active again.
    if window?.windowScene?.activationState == .background { return }

    // Synchronous cache hit: display in this same runloop so a reused cell's placeholder is replaced
    // immediately rather than flashing until an async render completes.
    if let cached = SVGImageRenderer.shared.cachedImage(
      urlString: urlString,
      outputWidth: outputWidth,
      darkMode: darkMode,
      cropToPlot: isThumbnail,
    ) {
      currentRenderTask?.cancel()
      currentRenderToken = UUID()
      inFlightRenderKey = nil
      shownRenderKey = renderKey
      showGraphImage(image: cached)
      return
    }

    // Invalidate any in-flight render and start a new one.
    let token = UUID()
    currentRenderToken = token
    inFlightRenderKey = renderKey
    currentRenderTask?.cancel()

    currentRenderTask = Task { [weak self] in
      guard let self else { return }
      defer { if token == self.currentRenderToken { self.inFlightRenderKey = nil } }
      do {
        // Renders the current appearance (displayed via the callback as soon as it's ready) and, from
        // the same page load, also caches the opposite appearance so a light/dark switch is instant.
        try await SVGImageRenderer.shared.renderBothAppearances(
          urlString: urlString,
          outputWidth: outputWidth,
          darkMode: darkMode,
          cropToPlot: isThumbnail,
        ) { [weak self] image in
          guard let self, !Task.isCancelled, token == self.currentRenderToken else { return }
          self.shownRenderKey = renderKey
          self.showGraphImage(image: image)
        }
      } catch is CancellationError {
        // Superseded by a newer render; ignore.
      } catch {
        if token != self.currentRenderToken { return }
        self.logger.error("Error rendering goal graph: \(error)")
      }
    }
  }
}
