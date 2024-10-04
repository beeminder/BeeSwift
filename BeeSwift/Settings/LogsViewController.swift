//  LogsViewController.swift
//  BeeSwift
//
//  A screen to view and share application logs

import Foundation
import OSLog
import OrderedCollections


@available(iOS 15.0, *)
class LogsViewController: UIViewController {

    let logTextView = UITextView()
    let systemLogsToggle = UIButton(type: .system)
    let errorLevelButton = UIButton(type: .system)

    let logReader = LogReader()

    var showSystemMessages = false
    var errorLevel = OSLogEntryLog.Level.debug

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black
        self.title = "Logs"

        // Add a share link to the navigationcontroller which shares the contents of the log when clicked
        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareLogs))
        self.navigationItem.rightBarButtonItem = shareButton

        view.addSubview(systemLogsToggle)
        systemLogsToggle.setTitle("App Only", for: .normal)
        systemLogsToggle.configuration = .gray()
        systemLogsToggle.snp.makeConstraints{ (make) in
            make.left.equalTo(view.safeAreaLayoutGuide.snp.leftMargin).offset(10)
            make.top.equalTo(view)
        }
        systemLogsToggle.addTarget(self, action: #selector(systemMessagesToggleTapped), for: .touchUpInside)

        view.addSubview(errorLevelButton)
        errorLevelButton.setTitle("Debug", for: .normal)
        errorLevelButton.configuration = .gray()
        errorLevelButton.snp.makeConstraints{ (make) in
            make.left.equalTo(systemLogsToggle.snp.right).offset(10)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.rightMargin).offset(-10)
            make.top.equalTo(view)
            make.bottom.equalTo(systemLogsToggle.snp.bottom)
            make.width.equalTo(systemLogsToggle.snp.width)
        }
        errorLevelButton.addTarget(self, action: #selector(errorLevelButtonTapped), for: .touchUpInside)

        view.addSubview(logTextView)
        logTextView.isEditable = false
        logTextView.isScrollEnabled = true
        logTextView.snp.makeConstraints { (make) in
            make.top.equalTo(systemLogsToggle.snp.bottom).offset(10)
            make.left.right.bottom.equalTo(view)
        }

        loadLogs()
    }

    func loadLogs() {
        Task { @MainActor in
            let hud = MBProgressHUD.showAdded(to: view, animated: false)
            self.logTextView.text = await self.logReader.getLogMessages(showSystemMessages: showSystemMessages, errorLevel: errorLevel)
            hud.hide(animated: false)
        }
    }

    @objc
    func shareLogs() {
        Task { @MainActor in
            let logFile = await logReader.saveLogsToFile(showSystemMessages: showSystemMessages, errorLevel: errorLevel)
            let activityViewController = UIActivityViewController(activityItems: [logFile], applicationActivities: nil)
            activityViewController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
            activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                try? FileManager.default.removeItem(at: logFile)
            }
            self.present(activityViewController, animated: true, completion: nil)
        }
    }

    @objc
    func systemMessagesToggleTapped() {
        showSystemMessages = !showSystemMessages
        if showSystemMessages {
            systemLogsToggle.setTitle("App and System", for: .normal)
        } else {
            systemLogsToggle.setTitle("App Only", for: .normal)
        }
        loadLogs()
    }

    @objc
    func errorLevelButtonTapped() {
        let errorLevelAlert = UIAlertController(title: "Choose Error Level", message: nil, preferredStyle: .actionSheet)

        let errorLevels: OrderedDictionary<String, OSLogEntryLog.Level> = [
            "Debug": .debug,
            "Info": .info,
            "Notice": .notice,
            "Error": .error,
            "Fault": .fault
        ]

        for (title, level) in errorLevels {
            let action = UIAlertAction(title: title, style: .default) { _ in
                self.errorLevel = level
                self.errorLevelButton.setTitle(title, for: .normal)
                self.loadLogs()
            }
            errorLevelAlert.addAction(action)
        }
        errorLevelAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(errorLevelAlert, animated: true, completion: nil)
    }
}

