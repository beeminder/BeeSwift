import BeeKit
import Foundation
import Kingfisher
import OSLog

/// Shows the current graph for a goal
/// Handles placeholders for loading and queued states, and automatically updates when the goal changes
class GoalImageView: UIView {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GoalImageView")

  private let imageView = UIImageView()
  private let beeLemniscateView = BeeLemniscateView()

  public let isThumbnail: Bool

  public var goal: Goal? {
    didSet {
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
    self.addSubview(imageView)
    imageView.snp.makeConstraints { (make) in make.edges.equalToSuperview() }
    self.imageView.image = UIImage(named: "GraphPlaceholder")

    self.addSubview(beeLemniscateView)
    beeLemniscateView.snp.makeConstraints { (make) in make.edges.equalToSuperview() }
    beeLemniscateView.isHidden = true

    NotificationCenter.default.addObserver(
      forName: .NSManagedObjectContextObjectsDidChange,
      object: ServiceLocator.persistentContainer.viewContext,
      queue: OperationQueue.main
    ) { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
    refresh()
  }

  @MainActor private func clearGoalGraph() {
    imageView.image = UIImage(named: "GraphPlaceholder")
    beeLemniscateView.isHidden = true
  }

  @MainActor private func showGraphImage(image: UIImage) {
    let duration = isThumbnail ? 0 : 0.4

    UIView.transition(
      with: imageView,
      duration: duration,
      options: .transitionCrossDissolve,
      animations: { [weak self] in
        self?.imageView.image = image
        self?.beeLemniscateView.isHidden = self?.goal == nil || self?.goal?.queued == false

        if self?.isThumbnail == true {
          self?.imageView.layer.borderColor = self?.goal?.countdownColor.cgColor
          self?.imageView.layer.borderWidth = self?.goal == nil ? 0 : 1
        } else {
          self?.imageView.layer.borderColor = nil
          self?.imageView.layer.borderWidth = 0
        }
      }
    )
  }

  @MainActor private func refresh() {
    guard let goal = self.goal else {
      clearGoalGraph()
      return
    }

    if goal.owner.deadbeat {
      clearGoalGraph()
      return
    }

    if goal.queued { beeLemniscateView.isHidden = true }

    let urlString = isThumbnail ? goal.cacheBustingThumbUrl : goal.cacheBustingGraphUrl
    let options: KingfisherOptionsInfo = [
      .transition(.fade(0.2)),
      .cacheSerializer(FormatIndicatedCacheSerializer.png)
    ]

    if let url = URL(string: urlString) {
      imageView.kf.setImage(
        with: url,
        placeholder: nil,
        options: options,
        completionHandler: { [weak self] result in
          switch result {
          case .success(let value):
            self?.showGraphImage(image: value.image)
          case .failure(let error):
            self?.logger.error("Error downloading goal graph: \(error)")
            self?.clearGoalGraph()
          }
        }
      )
    }
  }
}
