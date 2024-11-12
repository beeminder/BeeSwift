import Foundation
import OSLog

import Alamofire
import AlamofireImage

import BeeKit

/// Shows the current graph for a goal
/// Handles placeholders for loading and queued states, and automatically updates when the goal changes
class GoalImageView : UIView {
    private let logger = Logger(subsystem: "com.beeminder.com", category: "GoalImageView")

    private let imageView = UIImageView()
    private let beeLemniscateView = BeeLemniscateView()

    private var currentlyShowingGraph = false

    public let isThumbnail: Bool
    
    private enum Constant {
        static var placeholderImage: UIImage { UIImage(named: "GraphPlaceholder")! }
    }

    public var goal: Goal? {
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
        setUpView()
    }

    required init?(coder: NSCoder) {
        self.isThumbnail = false
        super.init(coder: coder)
        setUpView()
    }

    private func setUpView() {
        self.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        self.imageView.image = Constant.placeholderImage

        self.addSubview(beeLemniscateView)
        beeLemniscateView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        beeLemniscateView.isHidden = false

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
        imageView.af.cancelImageRequest()

        imageView.af.run(.noTransition, with: Constant.placeholderImage)
        currentlyShowingGraph = false
        beeLemniscateView.isHidden = true
    }

    private func refresh() {
        //  - Deadbeat: Placeholder, no animation
        guard !ServiceLocator.currentUserManager.isDeadbeat() else {
            clearGoalGraph()
            return
        }

        //  No Goal: Placeholder, no animation
        guard let goal else {
            clearGoalGraph()
            return
        }

        // Load the appropriate image for the goal
        let urlString = isThumbnail ? goal.cacheBustingThumbUrl : goal.cacheBustingGraphUrl
        let request = URLRequest(url: URL(string: urlString)!)
        
        // When queued, we should show a loading indicator over any existing graph,
        // but not over the placeholder image.
        beeLemniscateView.isHidden = !currentlyShowingGraph
        
        imageView.af.setImage(withURLRequest: request,
                              cacheKey: urlString,
                              placeholderImage: imageView.image == nil ? Constant.placeholderImage : nil,
                              filter: RoundedCornersFilter(radius: isThumbnail ? 2 : 4),
                              progressQueue: DispatchQueue.global(qos: .background),
                              imageTransition: .crossDissolve(0.4),
                              runImageTransitionIfCached: false)
    }
}
