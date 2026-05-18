//
//  MessageListView.swift
//  ChatUI
//
//  High-performance message list using ListViewKit.
//  Adapted from FlowDown's MessageListView.
//

import ListViewKit
import Litext
import MarkdownView
import SnapKit
import UIKit

public final class MessageListView: UIView {
    private lazy var listView: ListViewKit.ListView = .init()
    private var renderedMessages: [ConversationMessage] = []
    private var renderedEntries: [Entry] = []
    private var loadingMessage: String?
    private var lastRenderScrolling = false
    var expandedSubAgentMessageIDs: Set<String> = []

    private enum RenderInvalidation {
        case content
        case loading
        case messageState
        case layoutState

        var requiresLayoutReload: Bool {
            switch self {
            case .layoutState:
                return true
            case .content, .loading, .messageState:
                return false
            }
        }
    }

    public var contentSize: CGSize {
        listView.contentSize
    }

    lazy var dataSource: ListViewDiffableDataSource<Entry> = .init(listView: listView)
    /// Per-entry horizontal content inset computed when building entries.
    /// Keyed by `Entry.id`; decoupled from message identity.
    var entryLeadingInsets: [String: CGFloat] = [:]
    let toolResultSectionMetricsCache: NSCache<NSString, NSValue> = {
        let cache = NSCache<NSString, NSValue>()
        cache.countLimit = 256
        return cache
    }()

    let userContentHeightCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 256
        return cache
    }()

    private var entryCount = 0
    private var isFirstLoad: Bool = true
    private let autoScrollTolerance: CGFloat = 2

    public var onRollbackUserQuery: ((String, String) -> Void)?
    public var onPartialCompact: ((String, PartialCompactDirection) -> Void)?
    public var onToggleReasoningCollapse: ((String) -> Void)?
    public var onToggleToolResultCollapse: ((String, String) -> Void)?
    public var onOpenAttachment: ((ChatInputAttachment) -> Bool)?
    public var onRetryInterruptedMessageSubmission: (() -> Void)?
    public var onSelectionChange: ((Set<String>) -> Void)?
    public private(set) var selectedMessageIDs: Set<String> = [] {
        didSet {
            guard oldValue != selectedMessageIDs else { return }
            onSelectionChange?(selectedMessageIDs)
        }
    }

    public var isSelectionModeEnabled = false {
        didSet {
            guard oldValue != isSelectionModeEnabled else { return }
            if !isSelectionModeEnabled {
                selectedMessageIDs.removeAll()
            }
            let previouslyRendered = renderedMessages
            updateFromUpstreamPublisher(previouslyRendered, false, isLoading: loadingMessage, invalidation: .layoutState)
        }
    }

    public var isRetryingInterruptedSubmission = false {
        didSet {
            guard oldValue != isRetryingInterruptedSubmission else { return }
            updateFromUpstreamPublisher(renderedMessages, lastRenderScrolling, isLoading: loadingMessage, invalidation: .messageState)
        }
    }

    public var showsInterruptedRetryAction = false {
        didSet {
            if !showsInterruptedRetryAction {
                isRetryingInterruptedSubmission = false
            }
            guard oldValue != showsInterruptedRetryAction else { return }
            updateFromUpstreamPublisher(renderedMessages, lastRenderScrolling, isLoading: loadingMessage, invalidation: .messageState)
        }
    }

    public var isTeamChat: Bool = false {
        didSet {
            guard oldValue != isTeamChat else { return }
            listView.reloadData()
        }
    }

    private var isAutoScrollingToBottom: Bool = true

    public var contentSafeAreaInsets: UIEdgeInsets = .zero {
        didSet { setNeedsLayout() }
    }

    static let listRowInsets: UIEdgeInsets = .init(top: 0, left: 20, bottom: 16, right: 20)

    public var theme: MarkdownTheme = .default {
        didSet {
            toolResultSectionMetricsCache.removeAllObjects()
            userContentHeightCache.removeAllObjects()
            listView.reloadData()
        }
    }

    public var emptyStateTitle: String? {
        get { emptyStateView.title }
        set { emptyStateView.title = newValue }
    }

    public var emptyStateSubtitle: String? {
        get { emptyStateView.subtitle }
        set { emptyStateView.subtitle = newValue }
    }

    private(set) lazy var labelForSizeCalculation: LTXLabel = .init()
    private(set) lazy var markdownViewForSizeCalculation: MarkdownTextView = .init()
    private(set) lazy var markdownPackageCache: MarkdownPackageCache = .init()

    private lazy var emptyStateView = ChatEmptyStateView()

    public init() {
        super.init(frame: .zero)

        listView.delegate = self
        listView.adapter = self
        listView.alwaysBounceVertical = true
        listView.alwaysBounceHorizontal = false
        listView.contentInsetAdjustmentBehavior = .never
        listView.showsVerticalScrollIndicator = false
        listView.showsHorizontalScrollIndicator = false
        addSubview(listView)
        listView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        emptyStateView.isHidden = true

        listView.gestureRecognizers?.forEach {
            guard $0 is UIPanGestureRecognizer else { return }
            $0.cancelsTouchesInView = false
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override public func layoutSubviews() {
        let wasNearBottom = isContentOffsetNearBottom()
        super.layoutSubviews()

        listView.contentInset = contentSafeAreaInsets

        if isAutoScrollingToBottom || wasNearBottom {
            let targetOffset = listView.maximumContentOffset
            if abs(listView.contentOffset.y - targetOffset.y) > autoScrollTolerance {
                listView.scroll(to: targetOffset)
            }
            if wasNearBottom {
                isAutoScrollingToBottom = true
            }
        }
    }

    private func updateAutoScrolling() {
        if isContentOffsetNearBottom() {
            isAutoScrollingToBottom = true
        }
    }

    private func isContentOffsetNearBottom(tolerance: CGFloat? = nil) -> Bool {
        let tolerance = tolerance ?? autoScrollTolerance
        return abs(listView.contentOffset.y - listView.maximumContentOffset.y) <= tolerance
    }

    public func prepareForNewSession() {
        renderedMessages = []
        renderedEntries = []
        loadingMessage = nil
        lastRenderScrolling = false
        expandedSubAgentMessageIDs.removeAll()
        isAutoScrollingToBottom = true
        isRetryingInterruptedSubmission = false
        showsInterruptedRetryAction = false
        isSelectionModeEnabled = false
        selectedMessageIDs.removeAll()
        isFirstLoad = true
        alpha = 0
        dataSource.applySnapshot(using: [], animatingDifferences: false)
    }

    public func markNextUpdateAsUserInitiated() {
        isAutoScrollingToBottom = true
    }

    public func render(messages: [ConversationMessage], scrolling: Bool) {
        renderedMessages = messages
        lastRenderScrolling = scrolling
        updateFromUpstreamPublisher(messages, scrolling, isLoading: loadingMessage, invalidation: .content)
    }

    public func loading(with message: String = .init()) {
        loadingMessage = message
        updateFromUpstreamPublisher(renderedMessages, lastRenderScrolling, isLoading: loadingMessage, invalidation: .loading)
    }

    public func stopLoading() {
        loadingMessage = nil
        updateFromUpstreamPublisher(renderedMessages, lastRenderScrolling, isLoading: nil, invalidation: .loading)
    }

    /// Render with fresh messages and clear loading state in a single pass.
    public func renderAndStopLoading(messages: [ConversationMessage], scrolling: Bool) {
        renderedMessages = messages
        lastRenderScrolling = scrolling
        loadingMessage = nil
        updateFromUpstreamPublisher(messages, scrolling, isLoading: nil, invalidation: .content)
    }

    func toggleSubAgentTaskExpansion(messageID: String) {
        if expandedSubAgentMessageIDs.contains(messageID) {
            expandedSubAgentMessageIDs.remove(messageID)
        } else {
            expandedSubAgentMessageIDs.insert(messageID)
        }
        updateFromUpstreamPublisher(renderedMessages, false, isLoading: loadingMessage, invalidation: .messageState)
    }

    public func toggleMessageSelection(messageID: String) {
        guard isSelectionModeEnabled else { return }
        if selectedMessageIDs.contains(messageID) {
            selectedMessageIDs.remove(messageID)
        } else {
            selectedMessageIDs.insert(messageID)
        }
        updateVisibleSelectionRows()
    }

    public func selectAllVisibleMessages() {
        selectedMessageIDs = Set(renderedMessages.map(\.id))
        updateVisibleSelectionRows()
    }

    public func clearSelection() {
        selectedMessageIDs.removeAll()
        updateVisibleSelectionRows()
    }

    func configureSelectionState(for messageRowView: MessageListRowView, entry: Entry) {
        let leadingInset = entryLeadingInsets[entry.id] ?? 0
        if messageRowView.contentLeadingInset != leadingInset {
            messageRowView.contentLeadingInset = leadingInset
        }

        if let messageID = entry.selectableMessageID {
            messageRowView.isSelectionModeEnabled = isSelectionModeEnabled
            messageRowView.isMessageSelected = selectedMessageIDs.contains(messageID)
            messageRowView.selectionToggleHandler = { [weak self] in
                self?.toggleMessageSelection(messageID: messageID)
            }
        } else {
            messageRowView.isSelectionModeEnabled = false
            messageRowView.isMessageSelected = false
            messageRowView.selectionToggleHandler = nil
        }
    }

    private func updateVisibleSelectionRows() {
        let snapshot = dataSource.snapshot()
        for index in listView.indicesForVisibleRows {
            guard let entry = snapshot.item(at: index),
                  let messageRowView = listView.rowView(at: index) as? MessageListRowView
            else {
                continue
            }
            configureSelectionState(for: messageRowView, entry: entry)
        }
    }

    private func updateFromUpstreamPublisher(
        _ messages: [ConversationMessage],
        _ scrolling: Bool,
        isLoading: String?,
        invalidation: RenderInvalidation = .content
    ) {
        renderedMessages = messages
        var entries = entries(from: messages)

        for entry in entries {
            switch entry {
            case let .responseContent(_, messageRepresentation):
                _ = markdownPackageCache.package(for: messageRepresentation, theme: theme)
            default: break
            }
        }

        if let isLoading { entries.append(.activityReporting(isLoading)) }

        let shouldScrolling = scrolling && isAutoScrollingToBottom

        entryCount = entries.count

        let isListEmpty = entryCount == 0 && isLoading == nil
        emptyStateView.isHidden = !isListEmpty

        if isFirstLoad || alpha == 0 {
            isFirstLoad = false
            renderedEntries = entries
            dataSource.applySnapshot(using: entries, animatingDifferences: false)
            listView.setContentOffset(.init(x: 0, y: listView.maximumContentOffset.y), animated: false)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                UIView.animate(withDuration: 0.25) { self.alpha = 1 }
            }
        } else {
            let didChangeEntries = renderedEntries != entries
            renderedEntries = entries

            if didChangeEntries {
                dataSource.applySnapshot(using: entries, animatingDifferences: false)
            }

            if invalidation.requiresLayoutReload {
                listView.reloadData()
            }

            if shouldScrolling {
                listView.scroll(to: listView.maximumContentOffset)
            }
        }
    }
}

extension MessageListView: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_: UIScrollView) {
        isAutoScrollingToBottom = false
    }

    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        updateAutoScrolling()
    }

    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateAutoScrolling()
        }
    }
}
