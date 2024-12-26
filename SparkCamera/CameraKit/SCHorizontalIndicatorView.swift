import UIKit

class SCHorizontalIndicatorView: UIView {
    
    private let indicatorLine: UIView = {
        let line = UIView()
        line.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        line.layer.cornerRadius = 2
        line.layer.shadowColor = UIColor.black.cgColor
        line.layer.shadowOpacity = 0.2
        line.layer.shadowOffset = CGSize(width: 0, height: 1)
        line.layer.shadowRadius = 2
        return line
    }()
    
    private var lastHighlightTime: TimeInterval = 0
    private let highlightInterval: TimeInterval = 1.0 // 1秒的间隔
    private var isHighlighted = false
    private let verticalThreshold: CGFloat = 0.15 // 误差范围

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.addSubview(indicatorLine)
        indicatorLine.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicatorLine.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            indicatorLine.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            indicatorLine.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 0.6),
            indicatorLine.heightAnchor.constraint(equalToConstant: 3)
        ])
    }
    
    func updateRotation(angle: CGFloat) {
        self.transform = CGAffineTransform(rotationAngle: angle)
        
        // 检测是否接近垂直方向，增加吸附范围
        if abs(angle) < verticalThreshold || abs(angle - .pi) < verticalThreshold {
            if !isHighlighted {
                triggerHighlightAnimation()
                isHighlighted = true
            }
        } else {
            if isHighlighted {
                resetHighlight()
                isHighlighted = false
            }
        }
    }
    
    private func triggerHighlightAnimation() {
        // 高亮动画
        UIView.animate(withDuration: 0.2) {
            self.indicatorLine.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.9)
        }
        
        // 触觉反馈
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
    }
    
    private func resetHighlight() {
        // 恢复正常状态
        UIView.animate(withDuration: 0.2) {
            self.indicatorLine.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        }
    }
} 
