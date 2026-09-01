import BeeKit
import Foundation
import OSLog
import SnapKit
import UIKit

/// The graph thumbnail shown for a goal in the gallery. Shows a placeholder until the graph is
/// rendered and a loading indicator while the goal is queued, and updates when the goal or the
/// appearance changes. The goal-detail screen uses `GoalGraphView` instead.
class GoalThumbnailView: UIView {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalThumbnailView")

  private let imageView = UIImageView()
  private let beeLemniscateView = BeeLemniscateView()

  private var currentlyShowingGraph = false
  /// Identifies the latest render so that callbacks from superseded ones are ignored.
  private var currentRenderToken: UUID? = nil
  private var currentRenderTask: Task<Void, Never>? = nil
  /// Key of the render currently displayed.
  private var shownRenderKey: String? = nil
  /// Key of the render in progress, so repeated refreshes don't start duplicate renders.
  private var inFlightRenderKey: String? = nil

  /// Fixed size, which is also the rasterization resolution, so layout passes never trigger a render.
  static let size = CGSize(width: Constants.thumbnailWidth, height: Constants.thumbnailHeight)

  public var goal: Goal? {
    didSet {
      // If changed to a different goal, remove any current state
      if goal !== oldValue { clearGoalGraph() }
      refresh()
    }
  }

  init() {
    super.init(frame: CGRect(origin: .zero, size: Self.size))
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    self.snp.makeConstraints { (make) in make.size.equalTo(Self.size) }

    self.addSubview(imageView)
    imageView.snp.makeConstraints { (make) in make.edges.equalToSuperview() }
    self.imageView.image = UIImage(named: "GraphPlaceholder")

    self.addSubview(beeLemniscateView)
    beeLemniscateView.snp.makeConstraints { (make) in make.edges.equalToSuperview() }
    beeLemniscateView.isHidden = true

    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in self.refresh() }

    // Renders are skipped while backgrounded (see refresh), so re-check on activation.
    NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification,
      object: nil,
      queue: OperationQueue.main,
    ) { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }

    NotificationCenter.default.addObserver(
      forName: .NSManagedObjectContextObjectsDidChange,
      object: ServiceLocator.persistentContainer.viewContext,
      queue: OperationQueue.main,
    ) { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
    refresh()
  }

  @MainActor private func clearGoalGraph() {
    currentRenderTask?.cancel()
    currentRenderTask = nil
    // The cancelled render never displays, so drop its key too: a later request for the same key
    // (e.g. a reused cell re-bound to the same goal) must start afresh.
    currentRenderToken = nil
    inFlightRenderKey = nil
    shownRenderKey = nil
    imageView.image = UIImage(named: "GraphPlaceholder")
    currentlyShowingGraph = false
    beeLemniscateView.isHidden = true
    updateBorder()
  }

  @MainActor private func updateBorder() {
    imageView.layer.borderColor = goal?.countdownColor.cgColor
    imageView.layer.borderWidth = goal == nil ? 0 : 1
  }

  @MainActor private func showGraphImage(image: UIImage) {
    // Not animated: with cell re-use a transition can briefly show the previous goal's graph.
    imageView.image = image
    beeLemniscateView.isHidden = goal == nil || goal?.queued == false
    updateBorder()
    currentlyShowingGraph = true
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

    let outputWidth = Self.size.width
    let urlString = goal.cacheBustingSvgUrl
    guard !urlString.isEmpty else {
      // Goals cached before svgUrl existed have none until the next refresh; keep the placeholder.
      return
    }

    let darkMode = traitCollection.userInterfaceStyle == .dark
    let renderKey = "\(urlString)|w\(Int(outputWidth))|\(darkMode)"

    // refresh() runs on every Core Data change; bail if nothing relevant changed.
    if renderKey == shownRenderKey || renderKey == inFlightRenderKey { return }

    // When backgrounding, iOS briefly flips the appearance to capture an app-switcher snapshot for
    // the other mode. A render started then would show the wrong appearance on return, so skip it;
    // the scene-activation observer refreshes once active again.
    if window?.windowScene?.activationState == .background { return }

    // Show cache hits synchronously so a reused cell doesn't flash the placeholder.
    if let cached = SVGImageRenderer.shared.cachedImage(
      urlString: urlString,
      outputWidth: outputWidth,
      darkMode: darkMode,
      cropToPlot: true,
    ) {
      currentRenderTask?.cancel()
      currentRenderToken = UUID()
      inFlightRenderKey = nil
      shownRenderKey = renderKey
      showGraphImage(image: cached)
      return
    }

    let token = UUID()
    currentRenderToken = token
    inFlightRenderKey = renderKey
    currentRenderTask?.cancel()

    currentRenderTask = Task { [weak self] in
      guard let self else { return }
      defer { if token == self.currentRenderToken { self.inFlightRenderKey = nil } }
      do {
        try await SVGImageRenderer.shared.renderBothAppearances(
          urlString: urlString,
          outputWidth: outputWidth,
          darkMode: darkMode,
          cropToPlot: true,
        ) { [weak self] image in
          guard let self, !Task.isCancelled, token == self.currentRenderToken else { return }
          self.shownRenderKey = renderKey
          self.showGraphImage(image: image)
        }
      } catch is CancellationError {
        // Superseded by a newer render.
      } catch {
        if token != self.currentRenderToken { return }
        self.logger.error("Error rendering goal graph: \(error)")
      }
    }
  }
}
