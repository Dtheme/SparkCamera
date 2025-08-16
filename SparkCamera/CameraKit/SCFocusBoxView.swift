import UIKit

class SCFocusBoxView: UIView {
    
    // MARK: - Properties
    private let focusBox = UIView()
    private let animationDuration: TimeInterval = 0.25
    private let boxSize: CGFloat = 80
    private let cornerLength: CGFloat = 18
    private let lineWidth: CGFloat = 2
    private let cornerLayer = CAShapeLayer()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        focusBox.frame = bounds
        updateCornerPath()
    }
    
    // MARK: - Setup
    private func setupView() {
        // 容器
        focusBox.frame = CGRect(x: 0, y: 0, width: boxSize, height: boxSize)
        focusBox.backgroundColor = .clear
        focusBox.isHidden = true
        addSubview(focusBox)
        
        // 角标描边
        cornerLayer.fillColor = UIColor.clear.cgColor
        cornerLayer.strokeColor = UIColor.white.cgColor
        cornerLayer.lineWidth = lineWidth
        cornerLayer.lineCap = .round
        cornerLayer.lineJoin = .round
        focusBox.layer.addSublayer(cornerLayer)
        
        updateCornerPath()
    }
    
    private func updateCornerPath() {
        var rect = focusBox.bounds.insetBy(dx: lineWidth/2, dy: lineWidth/2)
        // 兼容性校验：CGRect 无 isFinite，可使用 isNull/isInfinite + 宽高 NaN/无效判断
        if rect.isNull || rect.isInfinite || rect.width.isNaN || rect.height.isNaN || rect.width.isInfinite || rect.height.isInfinite || rect.width <= 0 || rect.height <= 0 {
            // 回退到固定尺寸，避免传入 NaN/无效值导致 CoreGraphics 报错
            rect = CGRect(x: 0, y: 0, width: boxSize - lineWidth, height: boxSize - lineWidth)
        }
        let path = UIBezierPath()
        let cl = cornerLength
        
        // 左上
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cl))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cl, y: rect.minY))
        // 右上
        path.move(to: CGPoint(x: rect.maxX - cl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cl))
        // 右下
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cl))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cl, y: rect.maxY))
        // 左下
        path.move(to: CGPoint(x: rect.minX + cl, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cl))
        
        cornerLayer.path = path.cgPath
    }
    
    // MARK: - Public Methods
    func animate(for state: SCFocusState) {
        switch state {
        case .focusing:
            animateFocusing()
        case .focused:
            animateFocused()
        case .failed:
            animateFailed()
        case .locked:
            animateLocked()
        }
    }
    
    // MARK: - Private Methods
    private func animateFocusing() {
        focusBox.isHidden = false
        focusBox.alpha = 1
        focusBox.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        cornerLayer.strokeColor = UIColor.yellow.cgColor
        
        UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseOut]) {
            self.focusBox.transform = .identity
        }
    }
    
    private func animateFocused() {
        cornerLayer.strokeColor = UIColor.green.cgColor
        UIView.animate(withDuration: animationDuration, delay: 0.45, options: [.curveEaseIn]) {
            self.focusBox.alpha = 0
        } completion: { _ in
            self.focusBox.isHidden = true
            self.focusBox.alpha = 1
            self.cornerLayer.strokeColor = UIColor.white.cgColor
        }
    }
    
    private func animateFailed() {
        cornerLayer.strokeColor = UIColor.red.cgColor
        let pulse1 = CGAffineTransform(scaleX: 1.1, y: 1.1)
        UIView.animate(withDuration: animationDuration) {
            self.focusBox.transform = pulse1
        } completion: { _ in
            UIView.animate(withDuration: self.animationDuration) {
                self.focusBox.transform = .identity
            }
        }
    }
    
    private func animateLocked() {
        cornerLayer.strokeColor = UIColor.white.cgColor
        focusBox.isHidden = false
        focusBox.alpha = 1
        UIView.animate(withDuration: animationDuration) {
            self.focusBox.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
    }
    
    func reset() {
        focusBox.isHidden = true
        focusBox.transform = .identity
        focusBox.alpha = 1
        cornerLayer.strokeColor = UIColor.white.cgColor
    }
}
