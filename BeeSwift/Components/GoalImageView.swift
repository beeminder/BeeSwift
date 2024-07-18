import Foundation
import OSLog

import Alamofire
import AlamofireImage

import BeeKit

/// Shows the current graph for a goal
/// Handles placeholders for loading and queued states, and automatically updates when the goal changes
class GoalImageView : UIView {
    private static let downloader = ImageDownloader(imageCache: AutoPurgingImageCache())
    private let logger = Logger(subsystem: "com.beeminder.com", category: "GoalImageView")

    private let imageView = UIImageView()
    private let beeLemniscateView = BeeLemniscateView()

    private var currentlyShowingGraph = false
    private var inProgressDownload: RequestReceipt? = nil
    private var currentDownloadToken: UUID? = nil

    public let isThumbnail: Bool

    public var goal: GoalProtocol? {
        didSet {
            // If changed to a different goal, remove any current state
            if goal !== oldValue {
                clearGoalGraph()
            }
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
        imageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        self.imageView.image = UIImage(named: "GraphPlaceholder")

        self.addSubview(beeLemniscateView)
        beeLemniscateView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        beeLemniscateView.isHidden = true

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: GoalManager.goalsUpdatedNotificationName),
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            self?.refresh()
        }

        refresh()
    }

    private func clearGoalGraph() {
        imageView.image = UIImage(named: "GraphPlaceholder")
        currentlyShowingGraph = false
        beeLemniscateView.isHidden = true
    }

    private func showGraphImage(image: UIImage) {
        imageView.image = image
        currentlyShowingGraph = true
        beeLemniscateView.isHidden = !(goal?.queued ?? false)
    }

    private func refresh() {
        // Invalidate the download token, meaning that any queued download callbacks
        // will no-op. This avoids race conditions with downloads finishing out of order.
        let newDownloadToken = UUID()
        self.currentDownloadToken = newDownloadToken

        if let downloadReceipt = inProgressDownload {
            GoalImageView.downloader.cancelRequest(with: downloadReceipt)
            inProgressDownload = nil
        }

        //  - Deadbeat: Placeholder, no animation
        if ServiceLocator.currentUserManager.isDeadbeat() {
            clearGoalGraph()
            return
        }

        //  No Goal: Placeholder, no animation
        guard let goal = self.goal else {
            clearGoalGraph()
            return
        }

        // When queued, we should show a loading indicator over any existing graph,
        // but not over the placeholder image.
        if goal.queued {
            beeLemniscateView.isHidden = !currentlyShowingGraph
        }

        // Load the approppriate iamge for the goal
        let urlString = if isThumbnail {
            goal.cacheBustingThumbUrl
        } else {
            goal.cacheBustingGraphUrl
        }
        let request = URLRequest(url: URL(string: urlString)!)

        // Explicitly check the cache to see if the image is already present, and if so set it directly
        // This avoids flicker when showing images from the cache, which will otherwise briefly show
        // the placeholder while waiting for the async download callback
        if let image = GoalImageView.downloader.imageCache?.image(for: request, withIdentifier: nil) {
            showGraphImage(image: image)
            return
        }

        // Download the image and show it once downloaded
        inProgressDownload = GoalImageView.downloader.download(request, completion: { response in
            if newDownloadToken != self.currentDownloadToken {
                // Another refresh has happend since we were enqueued. Skip performing any updates
                return
            }

            switch(response.result) {
            case .success(let image):
                // Image downloaded. Show it, and have loading indicator match queued state
                self.showGraphImage(image: image)
                break;
            case .failure(let error):
                self.logger.error("Error downloading goal graph: \(error)")
                self.clearGoalGraph()
            }
        })
    }
}
