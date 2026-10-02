//
//  NetworkRuleItemCell.swift
//  DebugSwift
//
//  Created by Adjie Satryo Pamungkas on 02/10/2026.
//

import UIKit

final class NetworkRuleItemCell: UITableViewCell {
    static let identifier = "NetworkRuleItemCell"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let toggleSwitch = UISwitch()
    private let labelsStack = UIStackView()

    var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .black
        selectionStyle = .none

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingHead

        subtitleLabel.textColor = .lightGray
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)

        labelsStack.axis = .vertical
        labelsStack.spacing = 4
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        labelsStack.addArrangedSubview(titleLabel)
        labelsStack.addArrangedSubview(subtitleLabel)

        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch.addTarget(self, action: #selector(toggleValueChanged(_:)), for: .valueChanged)

        contentView.addSubview(labelsStack)
        contentView.addSubview(toggleSwitch)

        NSLayoutConstraint.activate([
            labelsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            labelsStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            labelsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            labelsStack.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -12),

            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(
        title: String,
        subtitle: String,
        isOn: Bool,
        isSelectable: Bool = false,
        onToggle: ((Bool) -> Void)? = nil
    ) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        toggleSwitch.isOn = isOn
        self.onToggle = onToggle
        selectionStyle = isSelectable ? .default : .none
    }

    @objc private func toggleValueChanged(_ sender: UISwitch) {
        onToggle?(sender.isOn)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggle = nil
    }
}
