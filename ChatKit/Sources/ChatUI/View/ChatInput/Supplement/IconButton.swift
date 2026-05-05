//
//  IconButton.swift
//  ChatUI
//

import UIKit

final class IconButton: UIView {
    let imageView = UIImageView()
    var imageInsets: UIEdgeInsets = .init(top: 2, left: 2, bottom: 2, right: 2) {
        didSet { setNeedsLayout() }
    }

    var tapAction: () -> Void = {}

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        let tap = UITapGestureRecognizer(target: self, action: #selector(buttonAction))
        addGestureRecognizer(tap)

        isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    convenience init(icon: String) {
        self.init(frame: .zero)
        imageView.image = UIImage.chatInputIcon(named: icon)
    }

    func change(icon: String, animated: Bool = true) {
        if animated {
            UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
                self.change(icon: icon, animated: false)
            }, completion: nil)
        } else {
            imageView.image = UIImage.chatInputIcon(named: icon)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds.inset(by: imageInsets)
    }

    @objc private func buttonAction() {
        guard !isHidden else { return }
        guard alpha > 0 else { return }
        puddingAnimate()
        tapAction()
    }
}

final class ContextUsageButton: UIView {
    let imageView = UIImageView()
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let ringDiameter: CGFloat = 18
    private let ringLineWidth: CGFloat = 2.5
    private let ringTrackColor = ChatUIDesign.Color.black60.withAlphaComponent(0.18)
    private let ringProgressColor = ChatUIDesign.Color.black60.withAlphaComponent(0.82)

    var imageInsets: UIEdgeInsets = .init(top: 5, left: 5, bottom: 5, right: 5) {
        didSet { setNeedsLayout() }
    }

    var tapAction: () -> Void = {}

    var progress: CGFloat = 0 {
        didSet {
            let clamped = min(max(progress, 0), 1)
            progressLayer.strokeEnd = clamped
            accessibilityValue = "\(Int(round(clamped * 100)))%"
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = ringTrackColor.cgColor
        trackLayer.lineWidth = ringLineWidth
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = ringProgressColor.cgColor
        progressLayer.lineWidth = ringLineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)

        addSubview(imageView)
        imageView.isHidden = true
        imageView.tintColor = .clear
        imageView.contentMode = .scaleAspectFit

        let tap = UITapGestureRecognizer(target: self, action: #selector(buttonAction))
        addGestureRecognizer(tap)

        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = String.localized("Context usage")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    convenience init(icon _: String) {
        self.init(frame: .zero)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds.inset(by: imageInsets)

        let ringFrame = CGRect(
            x: bounds.midX - ringDiameter / 2,
            y: bounds.midY - ringDiameter / 2,
            width: ringDiameter,
            height: ringDiameter
        )
        let radius = (ringDiameter - ringLineWidth) / 2
        let path = UIBezierPath(
            arcCenter: CGPoint(x: ringFrame.midX, y: ringFrame.midY),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        progressLayer.strokeColor = ringProgressColor.cgColor
        trackLayer.strokeColor = ringTrackColor.cgColor
    }

    @objc private func buttonAction() {
        guard !isHidden else { return }
        guard alpha > 0 else { return }
        puddingAnimate()
        tapAction()
    }
}
