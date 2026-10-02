//
//  NetworkDebugSettingsController.swift
//  DebugSwift
//
//  Created by Adjie Satryo Pamungkas on 02/10/2026.
//

import UIKit

final class NetworkDebugSettingsController: BaseTableController {
    private let viewModel: NetworkDebugSettingsViewModel
    private let searchController = UISearchController(searchResultsController: nil)
    private var heroHeaderView: HeroHeaderView?

    init(viewModel: NetworkDebugSettingsViewModel = NetworkDebugSettingsViewModel()) {
        self.viewModel = viewModel
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableHeader()
        setupSearchController()
        bindViewModel()
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

    private func bindViewModel() {
        viewModel.onStateUpdated = { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            self.updateHeaderView()
        }
    }

    private func setupUI() {
        title = "Network Debug"
        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
        tableView.register(NetworkRuleItemCell.self, forCellReuseIdentifier: NetworkRuleItemCell.identifier)
        tableView.register(NetworkRuleEmptyCell.self, forCellReuseIdentifier: NetworkRuleEmptyCell.identifier)

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
            isEnabled: viewModel.isMasterEnabled
        )
        header.onMasterToggleChanged = { [weak self] isEnabled in
            self?.viewModel.setMasterEnabled(isEnabled)
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
        if viewModel.isSearching {
            tableView.tableHeaderView = nil
        } else {
            guard let header = heroHeaderView else { return }
            header.configure(
                title: "Network Debug",
                description: "Pause and inspect requests & responses matching rules.",
                isEnabled: viewModel.isMasterEnabled
            )
            tableView.tableHeaderView = header
            updateHeaderViewHeight()
        }
    }

    private func updateHeaderViewHeight() {
        guard !viewModel.isSearching, let headerView = tableView.tableHeaderView as? HeroHeaderView else { return }
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

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(viewModel.numberOfRules, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard viewModel.numberOfRules > 0 else {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: NetworkRuleEmptyCell.identifier,
                for: indexPath
            ) as? NetworkRuleEmptyCell else {
                return UITableViewCell()
            }

            if viewModel.isSearching {
                cell.configure(
                    title: "No Rules Found",
                    subtitle: "No rules match \"\(viewModel.searchText)\""
                )
            } else {
                cell.configure(
                    title: "No Network Debug Rules",
                    subtitle: "Tap + to add a rule"
                )
            }
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: NetworkRuleItemCell.identifier,
            for: indexPath
        ) as? NetworkRuleItemCell,
              let rule = viewModel.rule(at: indexPath.row) else {
            return UITableViewCell()
        }

        let method = rule.httpMethod?.rawValue ?? "All Methods"
        cell.configure(
            title: rule.urlPattern,
            subtitle: "\(method) • Breakpoint Active",
            isOn: rule.isEnabled,
            isSelectable: false
        ) { [weak self] isOn in
            self?.viewModel.setRuleEnabled(at: indexPath.row, isEnabled: isOn)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Strictly no navigation to detail URL debug screen
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return viewModel.numberOfRules > 0
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, viewModel.numberOfRules > 0 else { return }
        viewModel.deleteRule(at: indexPath.row)
    }

    // MARK: - Actions

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
                  let pattern = alert?.textFields?[0].text,
                  !pattern.trimmingCharacters(in: .whitespaces).isEmpty else { return }

            let rawMethod = alert?.textFields?[1].text?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
            let method = HTTPMethod(rawValue: rawMethod)

            self.viewModel.addRule(urlPattern: pattern, method: method)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func clearAllTapped() {
        guard viewModel.allRules.count > 0 else { return }
        let alert = UIAlertController(
            title: "Clear All Debug Rules?",
            message: "This will remove all breakpoint rules.",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            self?.viewModel.clearAllRules()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

extension NetworkDebugSettingsController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.updateSearch(text: searchController.searchBar.text ?? "")
    }
}
