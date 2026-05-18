//
//  Created by ktiays on 2025/2/7.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import ListViewKit
import Litext
import MarkdownView
import SnapKit
import UIKit

/// Base row view intended for specialized message row subclasses.
class MessageListRowView: ListRowView, UIContextMenuInteractionDelegate {
    var theme: MarkdownTheme = .default {
        didSet {
            themeDidUpdate()
            setNeedsLayout()
        }
    }

    static let agentAvatarSize: CGFloat = 32
    static let agentAvatarSpacing: CGFloat = 10
    static let agentHeaderHeight: CGFloat = agentAvatarSize
    static let agentContentLeadingOffset = agentAvatarSize + agentAvatarSpacing

    let contentView = UIView()
    var contextMenuProvider: ((CGPoint) -> UIMenu?)?
    var selectionToggleHandler: (() -> Void)?

    var isSelectionModeEnabled: Bool = false {
        didSet {
            guard oldValue != isSelectionModeEnabled else { return }
            updateSelectionPresentation()
        }
    }

    var isMessageSelected: Bool = false {
        didSet {
            guard oldValue != isMessageSelected else { return }
            updateSelectionPresentation()
        }
    }

    /// Horizontal inset applied to `contentView` within the row's safe area.
    /// Set by the data source per entry; decoupled from message identity.
    var contentLeadingInset: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    /// Tiny transparent anchor used as UITargetedPreview target so no content
    /// is lifted/zoomed during context menu presentation.
    private let contextMenuAnchor: UIView = {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }()

    private let selectionButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = ChatUIDesign.Color.brandOrange
        button.backgroundColor = ChatUIDesign.Color.pureWhite
        button.layer.cornerRadius = 11
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1
        button.layer.borderColor = ChatUIDesign.Color.oatBorder.cgColor
        button.isUserInteractionEnabled = false
        button.alpha = 0
        return button
    }()

    private lazy var selectionTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSelectionTap))

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false // tool tip will extend out

        addSubview(contentView)
        addSubview(selectionButton)
        contentView.isUserInteractionEnabled = true
        contentView.addSubview(contextMenuAnchor)

        contentView.addInteraction(UIContextMenuInteraction(delegate: self))
        selectionTapGesture.cancelsTouchesInView = true
        addGestureRecognizer(selectionTapGesture)
        updateSelectionPresentation()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        themeDidUpdate()
        super.layoutSubviews()

        let insets = MessageListView.listRowInsets
        let leftOffset = contentLeadingInset

        contentView.frame = CGRect(
            x: insets.left + leftOffset,
            y: 0,
            width: bounds.width - insets.horizontal - leftOffset,
            height: max(0, bounds.height - insets.bottom)
        )
        selectionButton.frame = CGRect(
            x: insets.left,
            y: max(0, min(8, (contentView.frame.height - 22) / 2)),
            width: 22,
            height: 22
        )
    }

    func themeDidUpdate() {}

    override func prepareForReuse() {
        super.prepareForReuse()
        contextMenuProvider = nil
        selectionToggleHandler = nil
        isSelectionModeEnabled = false
        isMessageSelected = false
        contentLeadingInset = 0

        // clear any LTXLabel selection
        var queue = subviews
        while let v = queue.first {
            queue.removeFirst()
            queue.append(contentsOf: v.subviews)
            (v as? LTXLabel)?.clearSelection()
        }
    }

    @objc private func handleSelectionTap() {
        guard isSelectionModeEnabled else { return }
        selectionToggleHandler?()
    }

    private func updateSelectionPresentation() {
        selectionTapGesture.isEnabled = isSelectionModeEnabled
        selectionButton.alpha = isSelectionModeEnabled ? 1 : 0

        if isMessageSelected {
            let config = UIImage.SymbolConfiguration(pointSize: 22)
            selectionButton.setImage(UIImage(systemName: "checkmark.circle.fill", withConfiguration: config), for: .normal)
            selectionButton.backgroundColor = .clear
            selectionButton.layer.borderWidth = 0
        } else {
            selectionButton.setImage(nil, for: .normal)
            selectionButton.backgroundColor = ChatUIDesign.Color.pureWhite
            selectionButton.layer.borderWidth = 1
        }
    }

    // MARK: - UIContextMenuInteractionDelegate

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let menu = contextMenuProvider?(location) else { return nil }
        // Move the invisible anchor to the touch location so the menu appears there.
        contextMenuAnchor.frame = CGRect(origin: location, size: CGSize(width: 1, height: 1))
        return .init(previewProvider: nil) { _ in menu }
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration _: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        // Suppress the lift/zoom highlight by using a clear background preview.
        suppressedTargetedPreview()
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration _: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        suppressedTargetedPreview()
    }

    private func suppressedTargetedPreview() -> UITargetedPreview {
        let params = UIPreviewParameters()
        params.backgroundColor = .clear
        params.shadowPath = UIBezierPath()
        // Target the 1×1 anchor so the system animates nothing visible.
        return UITargetedPreview(view: contextMenuAnchor, parameters: params)
    }
}
