// Part of BeeSwift. Copyright Beeminder

import UIKit
import BeeKit

class FreshnessIndicatorView: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)
        label.textAlignment = .center
        return label
    }()
    
    private let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }()
    
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
    
    private func setupView() {
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
    
    func update(with date: Date) {
        let elapsed = -date.timeIntervalSinceNow
        let style: Style = {
            let index = elapsed < TimeThreshold.recent ? 0 : 1
            return styles[index]
        }()

        let relativeDuration = formatter.localizedString(for: date, relativeTo: Date())
        let labelText = "Last updated: \(relativeDuration)"
        
        UIView.animate(withDuration: 0.2) {
            self.backgroundColor = style.backgroundColor
            self.label.textColor = style.textColor
            self.label.text = labelText
        }
    }
}
