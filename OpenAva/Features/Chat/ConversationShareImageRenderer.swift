import ChatUI
import UIKit

enum ConversationShareImageRendererError: LocalizedError {
    case emptyMessages
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .emptyMessages:
            return String.localized("Select at least one message.")
        case .imageEncodingFailed:
            return String.localized("Failed to generate share image.")
        }
    }
}

@MainActor
final class ConversationShareImageRenderer {
    private struct ShareItem {
        let role: MessageRole
        let sender: String
        let text: String
        let createdAt: Date
    }

    private let title: String
    private let subtitle: String?

    private let canvasWidth: CGFloat = 860
    private let horizontalInset: CGFloat = 40
    private let topInset: CGFloat = 60
    private let bottomInset: CGFloat = 80
    private let bubbleVerticalPadding: CGFloat = 24
    private let bubbleHorizontalPadding: CGFloat = 28
    private let itemSpacing: CGFloat = 24

    init(title: String, subtitle: String?) {
        self.title = title
        self.subtitle = subtitle
    }

    func render(messages: [ConversationMessage]) throws -> UIImage {
        let items = messages.compactMap(makeShareItem)
        guard !items.isEmpty else { throw ConversationShareImageRendererError.emptyMessages }

        var layouts: [ShareItemLayout] = []
        var cursorY = topInset + headerHeight

        for item in items {
            let itemLayout = layout(for: item, y: cursorY)
            layouts.append(itemLayout)
            cursorY = itemLayout.frame.maxY + itemSpacing
        }

        let contentHeight = layouts.map(\.frame.maxY).max() ?? (topInset + headerHeight)
        let height = max(contentHeight + bottomInset, 720)
        return try renderPage(layouts, height: height)
    }

    private var headerHeight: CGFloat {
        subtitle == nil ? 68 : 98
    }

    private struct ShareItemLayout {
        let item: ShareItem
        let frame: CGRect
        let textRect: CGRect
        let senderRect: CGRect
        let timeRect: CGRect
    }

    private func makeShareItem(from message: ConversationMessage) -> ShareItem? {
        let text = shareableText(for: message)
        guard !text.isEmpty else { return nil }

        let sender: String
        switch message.role {
        case .user:
            sender = message.metadata["teamSender"]?.nilIfBlank ?? String.localized("User")
        case .assistant:
            sender = message.metadata["agentName"]?.nilIfBlank ?? String.localized("Assistant")
        case .tool:
            sender = String.localized("Tool")
        case .system:
            sender = String.localized("System")
        default:
            sender = String.localized("Message")
        }

        return ShareItem(role: message.role, sender: sender, text: text, createdAt: message.createdAt)
    }

    private func shareableText(for message: ConversationMessage) -> String {
        let text = message.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }

        if let reasoning = message.reasoningContent?.trimmingCharacters(in: .whitespacesAndNewlines), !reasoning.isEmpty {
            return reasoning
        }

        let attachmentNames = message.parts.compactMap { part -> String? in
            switch part {
            case let .image(image): return image.name ?? String.localized("Image")
            case let .audio(audio): return audio.name ?? String.localized("Audio")
            case let .file(file): return file.name ?? String.localized("Document")
            case .text, .reasoning, .toolCall, .toolResult: return nil
            }
        }
        return attachmentNames.joined(separator: "\n")
    }

    private func layout(for item: ShareItem, y: CGFloat) -> ShareItemLayout {
        let isUser = item.role == .user
        let maxBubbleWidth = canvasWidth * 0.72
        let textWidth = maxBubbleWidth - bubbleHorizontalPadding * 2
        let senderHeight: CGFloat = 20
        let timeHeight: CGFloat = 18
        let textHeight = attributedText(item.text).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height.rounded(.up)
        let bubbleHeight = senderHeight + 8 + textHeight + 10 + timeHeight + bubbleVerticalPadding * 2
        let bubbleWidth = min(
            maxBubbleWidth,
            max(260, attributedText(item.text).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).width + bubbleHorizontalPadding * 2)
        )
        let x = isUser ? canvasWidth - horizontalInset - bubbleWidth : horizontalInset
        let frame = CGRect(x: x, y: y, width: bubbleWidth, height: bubbleHeight)
        let senderRect = CGRect(
            x: frame.minX + bubbleHorizontalPadding,
            y: frame.minY + bubbleVerticalPadding,
            width: frame.width - bubbleHorizontalPadding * 2,
            height: senderHeight
        )
        let textRect = CGRect(
            x: senderRect.minX,
            y: senderRect.maxY + 8,
            width: senderRect.width,
            height: textHeight
        )
        let timeRect = CGRect(
            x: senderRect.minX,
            y: textRect.maxY + 10,
            width: senderRect.width,
            height: timeHeight
        )
        return ShareItemLayout(item: item, frame: frame, textRect: textRect, senderRect: senderRect, timeRect: timeRect)
    }

    private func renderPage(
        _ layouts: [ShareItemLayout],
        height: CGFloat
    ) throws -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: height), format: format)
        let image = renderer.image { context in
            ChatUIDesign.Color.warmCream.setFill()
            context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: height))

            drawHeader()
            for layout in layouts {
                draw(layout)
            }
            drawFooter(in: CGRect(x: 0, y: 0, width: canvasWidth, height: height))
        }

        guard image.pngData() != nil else { throw ConversationShareImageRendererError.imageEncodingFailed }
        return image
    }

    private func drawHeader() {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .semibold),
            .foregroundColor: ChatUIDesign.Color.offBlack,
            .kern: -0.8,
        ]
        (title as NSString).draw(in: CGRect(x: horizontalInset, y: topInset, width: canvasWidth - horizontalInset * 2, height: 44), withAttributes: titleAttributes)

        if let subtitle = subtitle {
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: ChatUIDesign.Color.black50,
            ]
            (subtitle as NSString).draw(in: CGRect(x: horizontalInset, y: topInset + 54, width: canvasWidth - horizontalInset * 2, height: 28), withAttributes: metaAttributes)
        }
    }

    private func draw(_ layout: ShareItemLayout) {
        let isUser = layout.item.role == .user
        let bubbleColor = isUser ? ChatUIDesign.Color.offBlack : ChatUIDesign.Color.pureWhite
        let textColor = isUser ? ChatUIDesign.Color.pureWhite : ChatUIDesign.Color.offBlack
        let secondaryColor = isUser ? ChatUIDesign.Color.pureWhite.withAlphaComponent(0.64) : ChatUIDesign.Color.black50

        let path = UIBezierPath(roundedRect: layout.frame, cornerRadius: ChatUIDesign.Radius.card)
        bubbleColor.setFill()
        path.fill()

        if !isUser {
            ChatUIDesign.Color.oatBorder.setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        (layout.item.sender as NSString).draw(in: layout.senderRect, withAttributes: [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: secondaryColor,
        ])

        attributedText(layout.item.text, color: textColor).draw(in: layout.textRect)

        (timeFormatter.string(from: layout.item.createdAt) as NSString).draw(in: layout.timeRect, withAttributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: secondaryColor,
        ])
    }

    private func drawFooter(in rect: CGRect) {
        let footer = "Generated by OpenAva"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: ChatUIDesign.Color.black50,
        ]
        let size = (footer as NSString).size(withAttributes: attributes)
        (footer as NSString).draw(
            at: CGPoint(x: rect.midX - size.width / 2, y: rect.maxY - bottomInset + 20),
            withAttributes: attributes
        )
    }

    private func attributedText(_ text: String, color: UIColor = .label) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 8
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .regular),
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
}

final class ConversationSharePreviewController: UIViewController {
    private let image: UIImage
    private let onSave: (UIImage, UIView) -> Void
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let actionBar = UIView()
    private let saveButton = UIButton(type: .custom)

    init(image: UIImage, onSave: @escaping (UIImage, UIView) -> Void) {
        self.image = image
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChatUIDesign.Color.warmCream
        title = String.localized("Share Preview")
        configureNavigationBar()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: String.localized("Cancel"),
            style: .plain,
            target: self,
            action: #selector(close)
        )

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = ChatUIDesign.Color.warmCream
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = ChatUIDesign.Color.pureWhite
        imageView.layer.cornerRadius = ChatUIDesign.Radius.card
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = ChatUIDesign.Color.oatBorder.cgColor
        imageView.clipsToBounds = true
        stackView.addArrangedSubview(imageView)
        imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: image.size.height / max(1, image.size.width)).isActive = true

        actionBar.backgroundColor = ChatUIDesign.Color.warmCream
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(actionBar)

        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = ChatUIDesign.Color.offBlack
        saveButton.tintColor = ChatUIDesign.Color.pureWhite
        configureSaveButtonTitle()
        saveButton.layer.cornerRadius = ChatUIDesign.Radius.button
        saveButton.layer.cornerCurve = .continuous
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        actionBar.addSubview(saveButton)

        let topDivider = UIView()
        topDivider.backgroundColor = ChatUIDesign.Color.oatBorder
        topDivider.translatesAutoresizingMaskIntoConstraints = false
        actionBar.addSubview(topDivider)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: actionBar.topAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            actionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            topDivider.topAnchor.constraint(equalTo: actionBar.topAnchor),
            topDivider.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor),
            topDivider.trailingAnchor.constraint(equalTo: actionBar.trailingAnchor),
            topDivider.heightAnchor.constraint(equalToConstant: 1),
            saveButton.leadingAnchor.constraint(equalTo: actionBar.leadingAnchor, constant: 24),
            saveButton.trailingAnchor.constraint(equalTo: actionBar.trailingAnchor, constant: -24),
            saveButton.topAnchor.constraint(equalTo: actionBar.topAnchor, constant: 16),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ChatUIDesign.Color.warmCream
        appearance.shadowColor = ChatUIDesign.Color.oatBorder
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: ChatUIDesign.Color.offBlack,
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = ChatUIDesign.Color.offBlack
    }

    private func configureSaveButtonTitle() {
        let title = String.localized("Save")
        setSaveButtonTitle(title, color: ChatUIDesign.Color.pureWhite, for: .normal)
        setSaveButtonTitle(title, color: ChatUIDesign.Color.pureWhite.withAlphaComponent(0.72), for: .highlighted)
        setSaveButtonTitle(title, color: ChatUIDesign.Color.pureWhite.withAlphaComponent(0.5), for: .disabled)
    }

    private func setSaveButtonTitle(_ title: String, color: UIColor, for state: UIControl.State) {
        saveButton.setAttributedTitle(
            NSAttributedString(
                string: title,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: color,
                ]
            ),
            for: state
        )
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func save() {
        onSave(image, saveButton)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
