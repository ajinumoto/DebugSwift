//
//  NetworkDebugSettingsController.swift
//  DebugSwift
//
//  Created by Adjie Satryo Pamungkas on 02/10/2026.
//

import UIKit

final class NetworkDebugSettingsController: BaseTableController {
    private var debugConfig: NetworkDebugConfig {
        NetworkInjectionManager.shared.getDebugConfig()
    }

    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText: String = ""
    private var heroHeaderView: HeroHeaderView?

    private var isSearching: Bool {
        searchController.isActive
    }

    private var filteredRules: [NetworkDebugRule] {
        let rules = debugConfig.rules
        guard !searchText.isEmpty else { return rules }
        return rules.filter { rule in
            let patternMatch = rule.urlPattern.localizedCaseInsensitiveContains(searchText)
            let methodMatch = rule.httpMethod?.rawValue.localizedCaseInsensitiveContains(searchText) == true
            return patternMatch || methodMatch
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableHeader()
        setupSearchController()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        updateHeaderView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderViewHeight()
    }

    private func setupUI() {
        title = "Network Debug"
        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RuleCell")

        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addRuleTapped)
        )
        let clearButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(clearAllTapped)
        )
        navigationItem.rightBarButtonItems = [addButton, clearButton]
    }

    private func setupTableHeader() {
        let header = HeroHeaderView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 120))
        header.configure(
            title: "Network Debug",
            description: "Pause and inspect requests & responses matching rules.",
            isEnabled: debugConfig.isEnabled
        )
        header.onMasterToggleChanged = { [weak self] isEnabled in
            guard let self = self else { return }
            var config = self.debugConfig
            config.isEnabled = isEnabled
            NetworkInjectionManager.shared.setDebugConfig(config)
            self.updateHeaderView()
        }
        self.heroHeaderView = header
        tableView.tableHeaderView = header
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Debug Rules..."
        searchController.searchBar.searchTextField.textColor = .white
        searchController.searchBar.barStyle = .black

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func updateHeaderView() {
        if isSearching {
            tableView.tableHeaderView = nil
        } else {
            guard let header = heroHeaderView else { return }
            header.configure(
                title: "Network Debug",
                description: "Pause and inspect requests & responses matching rules.",
                isEnabled: debugConfig.isEnabled
            )
            tableView.tableHeaderView = header
            updateHeaderViewHeight()
        }
    }

    private func updateHeaderViewHeight() {
        guard !isSearching, let headerView = tableView.tableHeaderView as? HeroHeaderView else { return }
        headerView.frame.size.width = tableView.bounds.width

        let targetSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let size = headerView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        if headerView.frame.size.height != size.height {
            headerView.frame.size.height = size.height
            tableView.tableHeaderView = headerView
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(filteredRules.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "RuleCell")
        cell.backgroundColor = .black
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = .lightGray

        let rules = filteredRules
        guard !rules.isEmpty else {
            if !searchText.isEmpty {
                cell.textLabel?.text = "No Rules Found"
                cell.detailTextLabel?.text = "No rules match \"\(searchText)\""
            } else {
                cell.textLabel?.text = "No Network Debug Rules"
                cell.detailTextLabel?.text = "Tap + to add a rule"
            }
            cell.selectionStyle = .none
            cell.accessoryView = nil
            return cell
        }

        let rule = rules[indexPath.row]
        cell.textLabel?.text = rule.urlPattern
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.lineBreakMode = .byTruncatingHead

        let method = rule.httpMethod?.rawValue ?? "All Methods"
        cell.detailTextLabel?.text = "\(method) • Breakpoint Active"

        let toggle = UISwitch()
        toggle.isOn = rule.isEnabled
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(ruleToggleChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Strictly no navigation to detail URL debug screen
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !filteredRules.isEmpty
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, !filteredRules.isEmpty else { return }
        let ruleToDelete = filteredRules[indexPath.row]
        var config = debugConfig
        config.rules.removeAll { $0.id == ruleToDelete.id }
        NetworkInjectionManager.shared.setDebugConfig(config)
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func ruleToggleChanged(_ sender: UISwitch) {
        let row = sender.tag
        guard row < filteredRules.count else { return }
        let targetRule = filteredRules[row]
        var config = debugConfig
        if let index = config.rules.firstIndex(where: { $0.id == targetRule.id }) {
            config.rules[index].isEnabled = sender.isOn
            NetworkInjectionManager.shared.setDebugConfig(config)
        }
    }

    @objc private func addRuleTapped() {
        let alert = UIAlertController(
            title: "Add Network Debug Rule",
            message: "Enter URL pattern to pause on request and response.",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "URL Pattern (e.g. *users* or api.com/*)"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }

        alert.addTextField { textField in
            textField.placeholder = "Method (Optional, e.g. GET, POST)"
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
        }

        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let pattern = alert?.textFields?[0].text?.trimmingCharacters(in: .whitespaces),
                  !pattern.isEmpty else { return }

            let rawMethod = alert?.textFields?[1].text?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
            let method = HTTPMethod(rawValue: rawMethod)

            var config = self.debugConfig
            let newRule = NetworkDebugRule(urlPattern: pattern, httpMethod: method, isEnabled: true)
            config.rules.append(newRule)
            config.isEnabled = true
            NetworkInjectionManager.shared.setDebugConfig(config)

            self.tableView.reloadData()
            self.updateHeaderView()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func clearAllTapped() {
        guard !debugConfig.rules.isEmpty else { return }
        let alert = UIAlertController(
            title: "Clear All Debug Rules?",
            message: "This will remove all breakpoint rules.",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            var config = self.debugConfig
            config.rules.removeAll()
            NetworkInjectionManager.shared.setDebugConfig(config)
            self.tableView.reloadData()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(alert, animated: true)
    }
}

extension NetworkDebugSettingsController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        updateHeaderView()
        tableView.reloadData()
    }
}
