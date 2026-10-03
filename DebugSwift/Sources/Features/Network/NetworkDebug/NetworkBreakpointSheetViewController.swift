//
//  NetworkBreakpointSheetViewController.swift
//  DebugSwift
//
//  Created by Adjie Satryo Pamungkas on 02/10/2026.
//

import UIKit

public enum BreakpointPhase: Sendable {
    case request
    case response
}

public enum BreakpointAction: Sendable {
    case resume(statusCode: Int?, modifiedHeaders: [String: String]?, modifiedBody: Data?)
    case mock(statusCode: Int, headers: [String: String], body: Data)
    case abort
}

final class NetworkBreakpointSheetViewController: BaseController, UIAdaptivePresentationControllerDelegate {
    private let phase: BreakpointPhase
    private let requestURL: URL?
    private let httpMethod: String
    private let initialStatusCode: Int?
    private let initialHeaders: [String: String]
    private let initialBody: String

    private let coordinator: BreakpointSheetCoordinator

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let headerCard = UIView()
    private let phaseBadge = UILabel()
    private let methodLabel = UILabel()
    private let urlLabel = UILabel()

    private let codeTitleLabel = UILabel()
    private let codeTextField = UITextField()

    private let headerTitleLabel = UILabel()
    private let headerTextView = UITextView()

    private let bodyTitleLabel = UILabel()
    private let bodyTextView = UITextView()

    private let actionsTitleLabel = UILabel()
    private let buttonsStack = UIStackView()
    private let resumeButton = UIButton(type: .system)
    private let mockButton = UIButton(type: .system)
    private let abortButton = UIButton(type: .system)

    init(
        phase: BreakpointPhase,
        url: URL?,
        method: String,
        statusCode: Int?,
        headers: [String: String],
        body: String,
        onAction: @escaping @Sendable (BreakpointAction) -> Void
    ) {
        self.phase = phase
        self.requestURL = url
        self.httpMethod = method
        self.initialStatusCode = statusCode
        self.initialHeaders = headers
        self.initialBody = body
        self.coordinator = BreakpointSheetCoordinator(
            defaultAction: .resume(statusCode: statusCode, modifiedHeaders: nil, modifiedBody: nil),
            onAction: onAction
        )
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
        populateData()
    }

    private func setupUI() {
        title = phase == .request ? "Request Breakpoint" : "Response Breakpoint"
        view.backgroundColor = .black
        presentationController?.delegate = self
        isModalInPresentation = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        setupHeaderCard()
        setupCodeSection()
        setupHeaderSection()
        setupBodySection()
        setupActionsSection()
    }

    private func setupHeaderCard() {
        headerCard.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        headerCard.layer.cornerRadius = 10
        headerCard.layer.borderWidth = 1
        headerCard.layer.borderColor = UIColor(white: 0.22, alpha: 1.0).cgColor
        headerCard.translatesAutoresizingMaskIntoConstraints = false

        phaseBadge.font = .systemFont(ofSize: 11, weight: .bold)
        phaseBadge.textAlignment = .center
        phaseBadge.layer.cornerRadius = 4
        phaseBadge.clipsToBounds = true
        phaseBadge.translatesAutoresizingMaskIntoConstraints = false

        if phase == .request {
            phaseBadge.text = " REQUEST "
            phaseBadge.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.25)
            phaseBadge.textColor = .systemOrange
        } else {
            phaseBadge.text = " RESPONSE "
            phaseBadge.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.25)
            phaseBadge.textColor = .systemTeal
        }

        methodLabel.font = .systemFont(ofSize: 13, weight: .bold)
        methodLabel.textColor = .white
        methodLabel.text = httpMethod.uppercased()
        methodLabel.translatesAutoresizingMaskIntoConstraints = false

        urlLabel.font = .systemFont(ofSize: 12, weight: .regular)
        urlLabel.textColor = .lightGray
        urlLabel.numberOfLines = 2
        urlLabel.lineBreakMode = .byTruncatingMiddle
        urlLabel.text = requestURL?.absoluteString ?? "Unknown URL"
        urlLabel.translatesAutoresizingMaskIntoConstraints = false

        headerCard.addSubview(phaseBadge)
        headerCard.addSubview(methodLabel)
        headerCard.addSubview(urlLabel)

        NSLayoutConstraint.activate([
            phaseBadge.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 10),
            phaseBadge.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 10),
            phaseBadge.heightAnchor.constraint(equalToConstant: 20),

            methodLabel.centerYAnchor.constraint(equalTo: phaseBadge.centerYAnchor),
            methodLabel.leadingAnchor.constraint(equalTo: phaseBadge.trailingAnchor, constant: 8),

            urlLabel.topAnchor.constraint(equalTo: phaseBadge.bottomAnchor, constant: 8),
            urlLabel.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 10),
            urlLabel.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -10),
            urlLabel.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -10)
        ])

        contentStack.addArrangedSubview(headerCard)
    }

    private func setupCodeSection() {
        codeTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        codeTitleLabel.textColor = .systemGray
        codeTitleLabel.text = phase == .request ? "Status Code (for Mock)" : "Status Code"

        codeTextField.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        codeTextField.textColor = .white
        codeTextField.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        codeTextField.layer.cornerRadius = 8
        codeTextField.layer.borderWidth = 1
        codeTextField.layer.borderColor = UIColor(white: 0.22, alpha: 1.0).cgColor
        codeTextField.keyboardType = .numberPad
        codeTextField.placeholder = "200"

        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 40))
        codeTextField.leftView = padding
        codeTextField.leftViewMode = .always
        codeTextField.heightAnchor.constraint(equalToConstant: 40).isActive = true

        contentStack.addArrangedSubview(codeTitleLabel)
        contentStack.addArrangedSubview(codeTextField)
    }

    private func setupHeaderSection() {
        headerTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerTitleLabel.textColor = .systemGray
        headerTitleLabel.text = "Headers (Free Text: Key: Value)"

        headerTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        headerTextView.textColor = .white
        headerTextView.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        headerTextView.layer.cornerRadius = 8
        headerTextView.layer.borderWidth = 1
        headerTextView.layer.borderColor = UIColor(white: 0.22, alpha: 1.0).cgColor
        headerTextView.autocapitalizationType = .none
        headerTextView.autocorrectionType = .no
        headerTextView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        contentStack.addArrangedSubview(headerTitleLabel)
        contentStack.addArrangedSubview(headerTextView)
    }

    private func setupBodySection() {
        bodyTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        bodyTitleLabel.textColor = .systemGray
        bodyTitleLabel.text = "Body (Free Text)"

        bodyTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        bodyTextView.textColor = .white
        bodyTextView.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        bodyTextView.layer.cornerRadius = 8
        bodyTextView.layer.borderWidth = 1
        bodyTextView.layer.borderColor = UIColor(white: 0.22, alpha: 1.0).cgColor
        bodyTextView.autocapitalizationType = .none
        bodyTextView.autocorrectionType = .no
        bodyTextView.heightAnchor.constraint(equalToConstant: 160).isActive = true

        contentStack.addArrangedSubview(bodyTitleLabel)
        contentStack.addArrangedSubview(bodyTextView)
    }

    private func setupActionsSection() {
        actionsTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        actionsTitleLabel.textColor = .systemGray
        actionsTitleLabel.text = "Breakpoint Actions"

        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 8
        buttonsStack.distribution = .fillEqually
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false

        styleActionButton(
            resumeButton,
            title: "Resume",
            bgColor: UIColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1.0),
            action: #selector(resumeTapped)
        )

        styleActionButton(
            mockButton,
            title: "Mock",
            bgColor: UIColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1.0),
            action: #selector(mockTapped)
        )

        styleActionButton(
            abortButton,
            title: "Abort",
            bgColor: UIColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1.0),
            action: #selector(abortTapped)
        )

        buttonsStack.addArrangedSubview(resumeButton)
        if phase == .request {
            buttonsStack.addArrangedSubview(mockButton)
        }
        buttonsStack.addArrangedSubview(abortButton)

        contentStack.addArrangedSubview(actionsTitleLabel)
        contentStack.addArrangedSubview(buttonsStack)
    }

    private func styleActionButton(_ button: UIButton, title: String, bgColor: UIColor, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = bgColor
        button.layer.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func setupKeyboardDismiss() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.barStyle = .black
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.items = [flex, done]

        codeTextField.inputAccessoryView = toolbar
        headerTextView.inputAccessoryView = toolbar
        bodyTextView.inputAccessoryView = toolbar

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            scrollView.contentInset.bottom = frame.height + 20
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
    }

    private func populateData() {
        if let code = initialStatusCode {
            codeTextField.text = "\(code)"
        } else if phase == .request {
            codeTextField.text = "200"
        }

        headerTextView.text = Self.headersToString(initialHeaders)
        bodyTextView.text = Self.prettyPrintedJSON(initialBody)
    }

    // MARK: - Actions

    deinit {
        NotificationCenter.default.removeObserver(self)
        coordinator.fallbackAction()
    }

    @objc private func resumeTapped() {
        let statusCode = Int(codeTextField.text?.trimmingCharacters(in: .whitespaces) ?? "")
        let headers = Self.stringToHeaders(headerTextView.text)
        let bodyData = bodyTextView.text.data(using: .utf8)

        coordinator.handleAction(.resume(statusCode: statusCode, modifiedHeaders: headers.isEmpty ? nil : headers, modifiedBody: bodyData))
        dismiss(animated: true)
    }

    @objc private func mockTapped() {
        let statusCode = Int(codeTextField.text?.trimmingCharacters(in: .whitespaces) ?? "") ?? 200
        let headers = Self.stringToHeaders(headerTextView.text)
        let bodyData = bodyTextView.text.data(using: .utf8) ?? Data()

        coordinator.handleAction(.mock(statusCode: statusCode, headers: headers, body: bodyData))
        dismiss(animated: true)
    }

    @objc private func abortTapped() {
        coordinator.handleAction(.abort)
        dismiss(animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let statusCode = Int(codeTextField.text?.trimmingCharacters(in: .whitespaces) ?? "")
        let headers = Self.stringToHeaders(headerTextView.text)
        let bodyData = bodyTextView.text.data(using: .utf8)

        coordinator.handleAction(.resume(statusCode: statusCode, modifiedHeaders: headers.isEmpty ? nil : headers, modifiedBody: bodyData))
    }

    // MARK: - Header Parsing Helpers

    static func headersToString(_ headers: [String: String]) -> String {
        headers.sorted(by: { $0.key.lowercased() < $1.key.lowercased() })
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    static func stringToHeaders(_ text: String) -> [String: String] {
        var dict = [String: String]()
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    dict[key] = value
                }
            }
        }
        return dict
    }

    static func prettyPrintedJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return raw
        }
        return prettyString
    }
}

private final class BreakpointSheetCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private var hasHandled = false
    private let defaultAction: BreakpointAction
    private let onAction: (@Sendable (BreakpointAction) -> Void)?

    init(defaultAction: BreakpointAction, onAction: (@Sendable (BreakpointAction) -> Void)?) {
        self.defaultAction = defaultAction
        self.onAction = onAction
    }

    func handleAction(_ action: BreakpointAction) {
        lock.lock()
        guard !hasHandled else {
            lock.unlock()
            return
        }
        hasHandled = true
        lock.unlock()
        onAction?(action)
    }

    func fallbackAction() {
        lock.lock()
        guard !hasHandled else {
            lock.unlock()
            return
        }
        hasHandled = true
        lock.unlock()
        onAction?(defaultAction)
    }
}
