//
//  MermaidMessageView.swift
//  ChatUI
//
//  Renders Mermaid diagram segments extracted from markdown messages.
//

import MarkdownView
import UIKit
import WebKit

final class MermaidMessageView: MessageListRowView {
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        return webView
    }()

    private var source: String = ""
    private var lastRenderedSource: String?
    private var lastRenderedIsDark: Bool?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
        themeDidUpdate()
    }

    @available(*, unavailable)
    @MainActor required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func themeDidUpdate() {
        titleLabel.textColor = theme.colors.body

        let cardBackground = UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 0.82)
            }
            return UIColor(red: 0.985, green: 0.982, blue: 0.972, alpha: 0.98)
        }
        cardView.backgroundColor = cardBackground
        renderIfNeeded()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        source = ""
        lastRenderedSource = nil
        lastRenderedIsDark = nil
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    func configure(with source: String) {
        self.source = source
        titleLabel.text = String.localized("Mermaid Diagram")
        renderIfNeeded()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let contentFrame = contentView.bounds
        cardView.frame = contentFrame

        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 10
        let titleHeight: CGFloat = 22

        titleLabel.frame = CGRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: cardView.bounds.width - horizontalPadding * 2,
            height: titleHeight
        )

        webView.frame = CGRect(
            x: horizontalPadding,
            y: verticalPadding + titleHeight + 6,
            width: cardView.bounds.width - horizontalPadding * 2,
            height: max(0, cardView.bounds.height - verticalPadding * 2 - titleHeight - 6)
        )
    }

    static func contentHeight(for source: String, containerWidth: CGFloat) -> CGFloat {
        let lineCount = max(1, source.split(whereSeparator: \.isNewline).count)
        let lineBasedHeight = CGFloat(lineCount) * 18 + 96
        let widthBasedHeight = max(220, min(380, containerWidth * 0.72))
        return ceil(min(520, max(lineBasedHeight, widthBasedHeight)))
    }

    private func configureSubviews() {
        contentView.addSubview(cardView)
        cardView.layer.cornerRadius = ChatUIDesign.Radius.card
        cardView.layer.cornerCurve = .continuous
        cardView.clipsToBounds = true

        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleLabel.numberOfLines = 1
        cardView.addSubview(titleLabel)

        cardView.addSubview(webView)
    }

    private func renderIfNeeded() {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let isDark = traitCollection.userInterfaceStyle == .dark
        guard source != lastRenderedSource || isDark != lastRenderedIsDark else { return }
        lastRenderedSource = source
        lastRenderedIsDark = isDark

        webView.loadHTMLString(Self.html(for: source, isDark: isDark), baseURL: nil)
    }

    private static func html(for source: String, isDark: Bool) -> String {
        let sourceLiteral = javaScriptStringLiteral(source)
        let mermaidTheme = isDark ? "dark" : "default"
        let textColor = isDark ? "#f4f4f5" : "#1f2328"
        let mutedTextColor = isDark ? "#a1a1aa" : "#6b7280"
        let errorBackground = isDark ? "rgba(127, 29, 29, 0.28)" : "rgba(254, 226, 226, 0.9)"

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
              background: transparent;
              color: \(textColor);
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            }
            #diagram {
              box-sizing: border-box;
              width: 100%;
              height: 100%;
              display: flex;
              align-items: center;
              justify-content: center;
              overflow: hidden;
            }
            #diagram svg {
              max-width: 100%;
              max-height: 100%;
              width: auto;
              height: auto;
            }
            #error {
              box-sizing: border-box;
              display: none;
              width: 100%;
              height: 100%;
              padding: 12px;
              border-radius: 10px;
              background: \(errorBackground);
              color: \(textColor);
              font-size: 13px;
              line-height: 1.45;
              overflow: hidden;
              white-space: pre-wrap;
            }
            #error .title {
              font-weight: 600;
              margin-bottom: 6px;
            }
            #error .detail {
              color: \(mutedTextColor);
            }
          </style>
        </head>
        <body>
          <div id="diagram"></div>
          <div id="error"><div class="title">Unable to render Mermaid diagram</div><div class="detail"></div></div>
          <script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.3/dist/mermaid.min.js"></script>
          <script>
            const source = \(sourceLiteral);
            const diagram = document.getElementById('diagram');
            const errorBox = document.getElementById('error');
            const errorDetail = errorBox.querySelector('.detail');

            function showError(message) {
              diagram.style.display = 'none';
              errorDetail.textContent = message || 'Unknown Mermaid render error.';
              errorBox.style.display = 'block';
            }

            window.addEventListener('load', async () => {
              try {
                if (!window.mermaid) {
                  showError('Mermaid.js could not be loaded. Check the network connection and try again.');
                  return;
                }
                mermaid.initialize({
                  startOnLoad: false,
                  securityLevel: 'strict',
                  theme: '\(mermaidTheme)'
                });
                const result = await mermaid.render('openava-mermaid-diagram', source);
                diagram.innerHTML = result.svg;
              } catch (error) {
                showError(error && error.message ? error.message : String(error));
              }
            });
          </script>
        </body>
        </html>
        """
    }

    private static func javaScriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }
        return literal
    }
}
