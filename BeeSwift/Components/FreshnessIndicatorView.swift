// Part of BeeSwift. Copyright Beeminder

import UIKit
import BeeKit

class FreshnessIndicatorView: UIView {
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textAlignment = .center
        return label
    }()
    
    private var updateTimer: Timer?
    private var lastUpdateDate: Date?
    private var leadingLabelConstraint: NSLayoutConstraint?
    private var leadingIndicatorConstraint: NSLayoutConstraint?
    
    // Time thresholds for different styles (in seconds)
    private struct TimeThreshold {
        static let recent: TimeInterval = 60 * 60
        // Anything beyond will be considered "old"
    }
    
    private struct Style {
        let backgroundColor: UIColor
        let textColor: UIColor
    }
    
    private let styles: [Style] = [
        // ones we consider recent
        Style(
            backgroundColor: .Beeminder.gray,
            textColor: .label
        ),
        // and the old ones
        Style(
            backgroundColor: .Beeminder.red,
            textColor: .label
        )
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupView() {
        addSubview(activityIndicator)
        addSubview(label)
        
        leadingLabelConstraint = label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        leadingIndicatorConstraint = label.leadingAnchor.constraint(equalTo: activityIndicator.trailingAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            activityIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            leadingLabelConstraint!,
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(activityDidStart), name: ActivityIndicatorTracker.NotificationName.activityDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(activityDidEnd), name: ActivityIndicatorTracker.NotificationName.activityDidEnd, object: nil)
    }
    
    private func fuzzyTimeString(for elapsed: TimeInterval) -> String {
        let minute: TimeInterval = 60
        let hour: TimeInterval = 60 * 60
        let day: TimeInterval = 24 * 60 * 60
        
        switch elapsed {
        case 0..<minute:
            return "Less than a minute ago"
        case minute..<(2 * minute):
            return "Less than 2 minutes ago"
        case (2 * minute)..<(5 * minute):
            return "Less than 5 minutes ago"
        case (5 * minute)..<(10 * minute):
            return "Less than 10 minutes ago"
        case (10 * minute)..<(15 * minute):
            return "Less than 15 minutes ago"
        case (15 * minute)..<(30 * minute):
            return "Less than 30 minutes ago"
        case (30 * minute)..<hour:
            return "Less than an hour ago"
        case hour..<(2 * hour):
            return "Less than 2 hours ago"
        case (2 * hour)..<day:
            let hours = Int(elapsed / hour) + 1
            return "Less than \(hours) hours ago"
        default:
            let days = Int(elapsed / day)
            if days == 1 {
                return "1 day ago"
            } else {
                return "\(days) days ago"
            }
        }
    }
    
    
    @objc private func timerFired() {
        if let date = lastUpdateDate {
            updateDisplay(for: date)
        }
    }
    
    private func updateDisplay(for date: Date) {
        let elapsed = -date.timeIntervalSinceNow
        let style: Style = {
            let index = elapsed < TimeThreshold.recent ? 0 : 1
            return styles[index]
        }()

        let labelText = "Last updated: \(fuzzyTimeString(for: elapsed))"
        
        UIView.animate(withDuration: 0.2) {
            self.backgroundColor = style.backgroundColor
            self.label.textColor = style.textColor
            self.label.text = labelText
        }
        
        // Schedule next update: every second for first minute, then every minute
        updateTimer?.invalidate()
        let interval: TimeInterval = elapsed < 125 ? 1.0 : 60.0
        updateTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timerFired), userInfo: nil, repeats: false)
    }
    
    func update(with date: Date) {
        lastUpdateDate = date
        updateDisplay(for: date)
    }
    
    @objc private func activityDidStart() {
        activityIndicator.startAnimating()
        UIView.animate(withDuration: 0.2) {
            self.leadingLabelConstraint?.isActive = false
            self.leadingIndicatorConstraint?.isActive = true
            self.layoutIfNeeded()
        }
    }
    
    @objc private func activityDidEnd() {
        activityIndicator.stopAnimating()
        UIView.animate(withDuration: 0.2) {
            self.leadingIndicatorConstraint?.isActive = false
            self.leadingLabelConstraint?.isActive = true
            self.layoutIfNeeded()
        }
    }
}
