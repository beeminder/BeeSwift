import BeeKit
import HealthKit
import UIKit

class WorkoutTypeSelectionViewController: UIViewController {
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private let cellReuseIdentifier = "workoutTypeCell"

  private var selectedTypes: Set<String>
  var onSelectionChanged: (([String]) -> Void)?

  init(initialSelection: [String]) {
    self.selectedTypes = Set(initialSelection)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Workout Types"
    self.view.backgroundColor = .systemBackground

    view.addSubview(tableView)
    tableView.delegate = self
    tableView.dataSource = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
    tableView.snp.makeConstraints { make in make.edges.equalTo(view.safeAreaLayoutGuide) }
  }

  private var isAllTypesSelected: Bool { return selectedTypes.isEmpty }
}

extension WorkoutTypeSelectionViewController: UITableViewDelegate, UITableViewDataSource {
  // Section 0: "All Types" option
  // Sections 1-N: One section per WorkoutCategory

  func numberOfSections(in tableView: UITableView) -> Int { return 1 + WorkoutCategory.allCases.count }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if section == 0 { return nil }
    return WorkoutCategory.allCases[section - 1].rawValue
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 { return 1 }
    let category = WorkoutCategory.allCases[section - 1]
    return WorkoutMinutesHealthKitMetric.workoutTypes(forCategory: category).count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
    cell.selectionStyle = .none

    if indexPath.section == 0 {
      cell.textLabel?.text = "All Types"
      cell.accessoryType = isAllTypesSelected ? .checkmark : .none
    } else {
      let category = WorkoutCategory.allCases[indexPath.section - 1]
      let types = WorkoutMinutesHealthKitMetric.workoutTypes(forCategory: category)
      let workoutType = types[indexPath.row]
      cell.textLabel?.text = workoutType.displayName
      cell.accessoryType = selectedTypes.contains(workoutType.identifier) ? .checkmark : .none
    }

    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section == 0 {
      // "All Types" selected - clear specific selections
      selectedTypes.removeAll()
    } else {
      let category = WorkoutCategory.allCases[indexPath.section - 1]
      let types = WorkoutMinutesHealthKitMetric.workoutTypes(forCategory: category)
      let workoutType = types[indexPath.row]

      if selectedTypes.contains(workoutType.identifier) {
        selectedTypes.remove(workoutType.identifier)
      } else {
        selectedTypes.insert(workoutType.identifier)
      }
    }

    tableView.reloadData()
    onSelectionChanged?(Array(selectedTypes))
  }
}
