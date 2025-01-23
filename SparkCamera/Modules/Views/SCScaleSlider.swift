import UIKit

class SCScaleSlider: UISlider {
    
    // MARK: - Properties
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 设置滑块大小
        let thumbSize = CGSize(width: 16, height: 16)
        
        // 创建圆形滑块
        let thumbView = UIView(frame: CGRect(origin: .zero, size: thumbSize))
        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = thumbSize.width / 2
        
        // 添加投影效果
        thumbView.layer.shadowColor = UIColor.black.cgColor
        thumbView.layer.shadowOffset = CGSize(width: 0, height: 2)
        thumbView.layer.shadowRadius = 4
        thumbView.layer.shadowOpacity = 0.2
        
        // 将视图转换为图片
        UIGraphicsBeginImageContextWithOptions(thumbSize, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            thumbView.layer.render(in: context)
            let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            // 设置滑块图片
            setThumbImage(thumbImage, for: .normal)
            setThumbImage(thumbImage, for: .highlighted)
        }
        
        // 设置轨道高度
        let trackHeight: CGFloat = 2
        let trackRect = CGRect(x: 0, y: (thumbSize.height - trackHeight) / 2,
                             width: thumbSize.width, height: trackHeight)
        
        // 创建轨道图片
        UIGraphicsBeginImageContextWithOptions(thumbSize, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            // 绘制轨道
            context.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            context.fill(trackRect)
            
            let trackImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            // 设置轨道图片
            setMinimumTrackImage(trackImage, for: .normal)
            setMaximumTrackImage(trackImage, for: .normal)
        }
    }
    
    // MARK: - Touch Handling
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        feedbackGenerator.prepare()
        return super.beginTracking(touch, with: event)
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let result = super.continueTracking(touch, with: event)
        if result {
            feedbackGenerator.impactOccurred()
        }
        return result
    }
    
    // MARK: - Layout
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        // 自定义轨道高度
        var newBounds = super.trackRect(forBounds: bounds)
        newBounds.size.height = 2
        return newBounds
    }
    
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        // 调整滑块位置，使其垂直居中
        var newRect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        newRect.origin.y = bounds.midY - newRect.size.height / 2
        return newRect
    }
} 