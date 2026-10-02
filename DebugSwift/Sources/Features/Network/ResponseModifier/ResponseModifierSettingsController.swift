//
//  ResponseModifierSettingsController.swift
//  DebugSwift
//
//  Created by Adjie Satryo Pamungkas on 13/04/26.
//

import UIKit
import UniformTypeIdentifiers

final class ResponseModifierSettingsController: BaseTableController, UIDocumentPickerDelegate {
    private enum Section: Int, CaseIterable {
        case rules
        case preferences
        case data
        case apiRules
    }

    private let viewModel: ResponseModifierSettingsViewModel
    private let searchController = UISearchController(searchResultsController: nil)
    private var heroHeaderView: HeroHeaderView?

    init(viewModel: ResponseModifierSettingsViewModel = ResponseModifierSettingsViewModel()) {
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
        title = "Response Modifier"
        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
        tableView.register(SettingCell.self, forCellReuseIdentifier: "SettingCell")
        tableView.register(NetworkRuleItemCell.self, forCellReuseIdentifier: NetworkRuleItemCell.identifier)
        tableView.register(NetworkRuleEmptyCell.self, forCellReuseIdentifier: NetworkRuleEmptyCell.identifier)

        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addRuleTapped)
        )
        let menuButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showMoreMenu)
        )
        navigationItem.rightBarButtonItems = [addButton, menuButton]
    }

    private func setupTableHeader() {
        let header = HeroHeaderView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 120))
        header.onMasterToggleChanged = { [weak self] isEnabled in
            self?.viewModel.isMasterEnabled = isEnabled
        }
        self.heroHeaderView = header
        tableView.tableHeaderView = header
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search API Rules..."
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
            header.configure(isEnabled: viewModel.isMasterEnabled)
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.isSearching ? 1 : Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if viewModel.isSearching {
            return max(viewModel.filteredRules.count, 1)
        }
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .rules:
            return 3
        case .preferences:
            return 1
        case .data:
            return 1
        case .apiRules:
            return max(viewModel.allRules.count, 1)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if viewModel.isSearching {
            return "API RULES"
        }
        guard let sectionType = Section(rawValue: section) else { return nil }
        switch sectionType {
        case .rules: return "RULES"
        case .preferences: return "PREFERENCES"
        case .data: return "DATA"
        case .apiRules: return "API RULES"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if viewModel.isSearching { return nil }
        guard let sectionType = Section(rawValue: section), sectionType == .rules else { return nil }
        return "Warning: Broad wildcard patterns (such as *) and many response modifier rules can reduce network matching performance."
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if viewModel.isSearching {
            return section == Section.apiRules.rawValue ? UITableView.automaticDimension : CGFloat.leastNormalMagnitude
        }
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if viewModel.isSearching {
            return CGFloat.leastNormalMagnitude
        }
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if viewModel.isSearching {
            return apiRuleCell(for: indexPath.row, in: tableView, indexPath: indexPath)
        }
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .rules, .preferences, .data:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath) as? SettingCell else {
                return UITableViewCell()
            }
            if section == .rules {
                if indexPath.row == 0 {
                    let toggle = UISwitch()
                    toggle.isOn = viewModel.areAllRulesEnabled
                    toggle.isEnabled = !viewModel.allRules.isEmpty
                    toggle.addTarget(self, action: #selector(allRulesToggleChanged(_:)), for: .valueChanged)
                    cell.configure(
                        title: "Enable All Rules",
                        iconName: "slider.horizontal.3",
                        iconBgColor: .systemPurple,
                        detailText: viewModel.enabledRuleCountSummary,
                        accessoryView: toggle
                    )
                } else if indexPath.row == 1 {
                    let toggle = UISwitch()
                    toggle.isOn = viewModel.isShortCircuitEnabled
                    toggle.addTarget(self, action: #selector(shortCircuitToggleChanged(_:)), for: .valueChanged)
                    cell.configure(
                        title: "Short-circuit Mode",
                        iconName: "bolt.fill",
                        iconBgColor: .systemOrange,
                        accessoryView: toggle
                    )
                } else {
                    let toggle = UISwitch()
                    toggle.isOn = viewModel.isMultipleMatchEnabled
                    toggle.addTarget(self, action: #selector(multipleMatchToggleChanged(_:)), for: .valueChanged)
                    cell.configure(
                        title: "Enable Multiple Match",
                        iconName: "doc.on.doc.fill",
                        iconBgColor: .systemBlue,
                        accessoryView: toggle
                    )
                }
            } else if section == .preferences {
                let toggle = UISwitch()
                toggle.isOn = viewModel.isAutoEnableOnRunEnabled
                toggle.addTarget(self, action: #selector(autoEnableToggleChanged(_:)), for: .valueChanged)
                cell.configure(
                    title: "Auto-enable Every Run",
                    iconName: "gearshape.fill",
                    iconBgColor: UIColor(red: 0.15, green: 0.35, blue: 0.6, alpha: 1.0),
                    accessoryView: toggle
                )
            } else {
                cell.configure(
                    title: "Import / Export CSV",
                    iconName: "arrow.down.doc.fill",
                    iconBgColor: .systemTeal
                )
            }
            return cell

        case .apiRules:
            return apiRuleCell(for: indexPath.row, in: tableView, indexPath: indexPath)
        }
    }

    private func apiRuleCell(for row: Int, in tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let rules = viewModel.filteredRules
        guard !rules.isEmpty else {
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
                    title: "No Response Modifier Rules",
                    subtitle: "Tap + to add a rule"
                )
            }
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: NetworkRuleItemCell.identifier,
            for: indexPath
        ) as? NetworkRuleItemCell else {
            return UITableViewCell()
        }

        let rule = rules[row]
        let method = rule.httpMethod?.rawValue ?? "All Methods"
        let subtitle: String
        if let statusCode = rule.responseStatusCode {
            subtitle = "\(method) • \(statusCode)"
        } else {
            subtitle = method
        }

        cell.configure(
            title: rule.urlPattern,
            subtitle: subtitle,
            isOn: rule.isEnabled,
            isSelectable: true
        ) { [weak self] isOn in
            self?.viewModel.setRuleEnabled(at: row, isEnabled: isOn)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if viewModel.isSearching {
            selectApiRule(at: indexPath.row)
            return
        }
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .rules:
            if indexPath.row == 0 {
                showInfoAlert(
                    title: "Enable All Rules",
                    message: "Quickly enable or disable all existing rules at once."
                )
            } else if indexPath.row == 1 {
                showInfoAlert(
                    title: "Short-circuit Matched Rules",
                    message: "When enabled, matched rules return mocked responses immediately from local data. This works offline and skips the real network request for matched rules."
                )
            } else {
                showInfoAlert(
                    title: "Multiple Match Selection",
                    message: "When enabled, if a request matches more than one rule, you can choose which rule to apply. Default is first-match behavior when disabled."
                )
            }
        case .preferences:
            showInfoAlert(
                title: "Auto-enable Every Run",
                message: "If enabled, response modifier will automatically be active each time the app starts."
            )
        case .data:
            showImportExportMenu()
        case .apiRules:
            selectApiRule(at: indexPath.row)
        }
    }

    private func selectApiRule(at row: Int) {
        guard let ruleToEdit = viewModel.rule(at: row) else { return }
        let editIndex = viewModel.allRules.firstIndex(where: { $0.urlPattern == ruleToEdit.urlPattern && $0.httpMethod == ruleToEdit.httpMethod })
        showRewriteRuleEditor(existingRule: ruleToEdit, editIndex: editIndex)
    }

    @objc private func addRuleTapped() {
        showRewriteRuleEditor()
    }

    @objc private func showMoreMenu() {
        let alert = UIAlertController(title: "More", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Reset All", style: .destructive) { [weak self] _ in
            self?.confirmResetAll()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(alert, animated: true)
    }

    private func confirmResetAll() {
        let alert = UIAlertController(
            title: "Reset All Response Modifier Settings?",
            message: "This will disable Response Modifier, disable Auto-enable, disable Multiple Match, keep Short-circuit Mode enabled, and remove all rules.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Reset All", style: .destructive) { [weak self] _ in
            self?.performResetAll()
        })
        present(alert, animated: true)
    }

    private func performResetAll() {
        viewModel.resetAll()
    }

    @objc private func autoEnableToggleChanged(_ sender: UISwitch) {
        viewModel.isAutoEnableOnRunEnabled = sender.isOn
    }

    @objc private func shortCircuitToggleChanged(_ sender: UISwitch) {
        viewModel.isShortCircuitEnabled = sender.isOn
    }

    @objc private func multipleMatchToggleChanged(_ sender: UISwitch) {
        viewModel.isMultipleMatchEnabled = sender.isOn
    }

    private func showInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func allRulesToggleChanged(_ sender: UISwitch) {
        let loading = UIAlertController(title: nil, message: "Updating rules...", preferredStyle: .alert)
        present(loading, animated: true)

        viewModel.setAllRulesEnabled(sender.isOn)

        DispatchQueue.main.async { [weak self] in
            loading.dismiss(animated: true) {
                self?.tableView.reloadData()
                self?.updateHeaderView()
            }
        }
    }

    private func showImportExportMenu() {
        let alert = UIAlertController(title: "Response Modifier CSV", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Export CSV", style: .default) { [weak self] _ in
            self?.exportRewriteRulesCSV()
        })
        alert.addAction(UIAlertAction(title: "Import CSV", style: .default) { [weak self] _ in
            self?.importRewriteRulesCSV()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showRewriteRuleEditor(existingRule: ResponseBodyRewriteRule? = nil, editIndex: Int? = nil) {
        let editor = RewriteRuleEditViewController(rule: existingRule) { [weak self] updatedRule in
            self?.viewModel.saveRule(updatedRule, editIndex: editIndex)
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard viewModel.isSearching || Section(rawValue: indexPath.section) == .apiRules else { return nil }
        return deleteSwipeAction(for: indexPath.row)
    }

    private func deleteSwipeAction(for row: Int) -> UISwipeActionsConfiguration? {
        guard !viewModel.filteredRules.isEmpty else { return nil }
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.viewModel.deleteRule(at: row)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func exportRewriteRulesCSV() {
        guard let export = viewModel.exportCSVData() else { return }
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(export.fileName)
        do {
            try export.data.write(to: fileURL, options: [.atomic])
        } catch {
            showMessageAlert(title: "Export Error", message: error.localizedDescription)
            return
        }

        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 1, width: 1, height: 1)
        }
        present(activityVC, animated: true)
    }

    private func importRewriteRulesCSV() {
        if #available(iOS 14.0, *) {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText, .plainText])
            picker.delegate = self
            picker.allowsMultipleSelection = false
            present(picker, animated: true)
        } else {
            let picker = UIDocumentPickerViewController(documentTypes: ["public.comma-separated-values-text", "public.plain-text"], in: .import)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            present(picker, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: fileURL)
            guard let csvText = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "DebugSwift.NetworkInjection", code: 1, userInfo: [NSLocalizedDescriptionKey: "CSV file must be UTF-8 encoded."])
            }
            let importedRules = try RewriteRulesCSV.parse(csvText)
            let merged = viewModel.applyImportedRules(importedRules)
            showMessageAlert(title: "Import Complete", message: "Created \(merged.created) rule(s), updated \(merged.updated) rule(s).")
        } catch {
            showMessageAlert(title: "Import Error", message: error.localizedDescription)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}

    private func showMessageAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ResponseModifierSettingsController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.updateSearch(text: searchController.searchBar.text ?? "")
    }
}
