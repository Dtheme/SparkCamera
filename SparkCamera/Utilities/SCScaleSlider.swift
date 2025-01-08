import UIKit
import SnapKit

/// 刻度滑块配置
struct SCScaleSliderConfig {
    /// 最小值
    var minValue: Float
    /// 最大值
    var maxValue: Float
    /// 步长
    var step: Float
    /// 默认值
    var defaultValue: Float
    
    /// 初始化配置
    /// - Parameters:
    ///   - minValue: 最小值
    ///   - maxValue: 最大值
    ///   - step: 步长
    ///   - defaultValue: 默认值
    init(minValue: Float, maxValue: Float, step: Float, defaultValue: Float) {
        assert(maxValue > minValue, "最大值必须大于最小值")
        assert(step > 0, "步长必须大于0")
        assert(defaultValue >= minValue && defaultValue <= maxValue, "默认值必须在最大值和最小值之间")
        
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.defaultValue = defaultValue
    }
    
    /// 默认配置
    static var `default`: SCScaleSliderConfig {
        return SCScaleSliderConfig(minValue: -2.0, maxValue: 2.0, step: 0.1, defaultValue: 0.0)
    }
}

/// 刻度滑块样式配置
struct SCScaleSliderStyle {
    /// 轨道颜色
    var trackColor: UIColor
    /// 刻度颜色
    var scaleColor: UIColor
    /// 滑块颜色
    var thumbColor: UIColor
    /// 滑块着色
    var thumbTintColor: UIColor
    /// 标签颜色
    var mainScaleTextColor: UIColor
    /// 中心线颜色
    var centerLineColor: UIColor
    /// 数值标签背景色
    var valueLabelBackgroundColor: UIColor
    /// 数值标签文字颜色
    var valueLabelTextColor: UIColor
    /// 滑块形状
    var thumbShape: ThumbShape
    
    /// 主刻度高度
    var mainScaleHeight: CGFloat
    /// 副刻度高度
    var subScaleHeight: CGFloat
    /// 标签字体大小
    var labelFontSize: CGFloat
    /// 刻度间距
    var scaleWidth: CGFloat
    
    /// 滑块形状
    enum ThumbShape {
        case circle
        case vertical
    }
    
    /// 预定义样式
    enum Style {
        /// 默认样式（透明轨道）
        case `default`
        /// 暗色样式
        case dark
        /// 竖条滑块样式
        case vertical
        
        var style: SCScaleSliderStyle {
            switch self {
            case .default:
                return SCScaleSliderStyle(
                    trackColor: .clear,
                    scaleColor: .systemGray3,
                    thumbColor: .white,
                    thumbTintColor: .systemBlue,
                    mainScaleTextColor: .systemGray,
                    centerLineColor: .systemBlue,
                    valueLabelBackgroundColor: .systemBlue,
                    valueLabelTextColor: .white,
                    thumbShape: .circle,
                    mainScaleHeight: Constants.mainScaleHeight,
                    subScaleHeight: Constants.subScaleHeight,
                    labelFontSize: Constants.labelFontSize,
                    scaleWidth: Constants.stepWidth
                )
            case .dark:
                return SCScaleSliderStyle(
                    trackColor: .systemGray6,
                    scaleColor: .systemGray4,
                    thumbColor: .black,
                    thumbTintColor: .black,
                    mainScaleTextColor: .black,
                    centerLineColor: .black,
                    valueLabelBackgroundColor: .black,
                    valueLabelTextColor: .white,
                    thumbShape: .circle,
                    mainScaleHeight: Constants.mainScaleHeight,
                    subScaleHeight: Constants.subScaleHeight,
                    labelFontSize: Constants.labelFontSize,
                    scaleWidth: Constants.stepWidth
                )
            case .vertical:
                return SCScaleSliderStyle(
                    trackColor: .clear,
                    scaleColor: .systemGray3,
                    thumbColor: .white,
                    thumbTintColor: .systemBlue,
                    mainScaleTextColor: .systemGray,
                    centerLineColor: .clear,
                    valueLabelBackgroundColor: .systemBlue,
                    valueLabelTextColor: .white,
                    thumbShape: .vertical,
                    mainScaleHeight: Constants.mainScaleHeight,
                    subScaleHeight: Constants.subScaleHeight,
                    labelFontSize: Constants.labelFontSize,
                    scaleWidth: Constants.stepWidth
                )
            }
        }
    }
}

/// 通用刻度滑块调节组件
/// 用于精确调节数值的场景（如曝光、音量、速度、亮度等参数调整）
class SCScaleSlider: UIView {
    
    // MARK: - Public Properties
    
    /// 当前值
    private(set) var currentValue: Float
    
    /// 值变化回调
    var valueChangedHandler: ((Float) -> Void)?
    
    /// 布局方向
    var orientation: NSLayoutConstraint.Axis = .horizontal {
        didSet {
            setNeedsLayout()
        }
    }
    
    /// 值格式化器
    var valueFormatter: ((Float) -> String)? {
        didSet {
            updateValueLabel()
        }
    }
    
    /// 样式配置
    var style: SCScaleSliderStyle = .Style.default.style {
        didSet {
            updateStyle()
        }
    }
    
    // MARK: - Private Properties
    private var config: SCScaleSliderConfig
    
    // 添加触感反馈
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    // 添加刻度标签缓存
    private var scaleLabels: [UILabel] = []
    private var displayLink: CADisplayLink?
    
    // MARK: - UI Components
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var sliderTrack: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.layer.cornerRadius = Constants.trackHeight / 2
        return view
    }()
    
    private lazy var scaleView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var centerLine: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        return view
    }()
    
    private lazy var thumbView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = Constants.thumbSize / 2
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 4
        
        // 添加内部蓝色圆圈
        let innerCircle = UIView()
        innerCircle.backgroundColor = .systemBlue
        innerCircle.layer.cornerRadius = 8
        view.addSubview(innerCircle)
        innerCircle.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        return view
    }()
    
    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.backgroundColor = .systemBlue
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.frame = CGRect(x: 0, y: 0, width: 50, height: 20)
        return label
    }()
    
    // MARK: - Initialization
    init(config: SCScaleSliderConfig = .default) {
        self.config = config
        self.currentValue = config.defaultValue
        super.init(frame: .zero)
        setupUI()
        setupGestures()
        setupAccessibility()
        updateScalePosition(animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        addSubview(contentView)
        contentView.addSubview(sliderTrack)
        contentView.addSubview(scaleView)
        addSubview(centerLine)
        addSubview(thumbView)
        addSubview(valueLabel)
        
        // 设置约束
        contentView.snp.makeConstraints { make in
            make.height.equalToSuperview()
            make.centerY.equalToSuperview()
            
            let totalSteps = Int((config.maxValue - config.minValue) / config.step)
            let stepSize = style.scaleWidth
            let totalSize = CGFloat(totalSteps) * stepSize
            
            // 总宽度 = 刻度总宽度 + 屏幕宽度（确保两端有足够空间）
            make.width.equalTo(totalSize + UIScreen.main.bounds.width)
            // 初始位置居中
            make.centerX.equalToSuperview()
        }
        
        sliderTrack.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.right.equalToSuperview()
            make.height.equalTo(Constants.trackHeight)
        }
        
        scaleView.snp.makeConstraints { make in
            make.left.right.equalTo(sliderTrack)
            make.centerY.equalTo(sliderTrack)
            make.height.equalTo(40)
        }
        
        centerLine.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(2)
            make.height.equalTo(24)
        }
        
        thumbView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Constants.thumbSize)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.centerX.equalTo(thumbView)
            make.bottom.equalTo(thumbView.snp.top).offset(-5)
            make.width.equalTo(50)
            make.height.equalTo(20)
        }
        
        drawScales()
        updateValueLabel()
    }
    
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        contentView.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        contentView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Drawing
    private func drawScales() {
        // 清除现有的刻度
        scaleView.subviews.forEach { $0.removeFromSuperview() }
        scaleLabels.removeAll()
        
        let totalSteps = Int((config.maxValue - config.minValue) / config.step)
        let stepWidth = style.scaleWidth
        let screenWidth = UIScreen.main.bounds.width
        
        // 计算0点位置
        let zeroPosition = screenWidth / 2
        
        for i in 0...totalSteps {
            let value = config.minValue + Float(i) * config.step
            let isMainScale = abs(value.truncatingRemainder(dividingBy: 0.5)) < .ulpOfOne
            
            let scaleView = UIView()
            scaleView.backgroundColor = style.scaleColor
            self.scaleView.addSubview(scaleView)
            
            // 计算x位置：从最小值开始
            let x = CGFloat(i) * stepWidth + zeroPosition
            let height: CGFloat = isMainScale ? style.mainScaleHeight : style.subScaleHeight
            
            scaleView.snp.makeConstraints { make in
                make.centerX.equalTo(self.scaleView.snp.left).offset(x)
                make.centerY.equalTo(self.scaleView)
                make.width.equalTo(1)
                make.height.equalTo(height)
            }
            
            if isMainScale {
                let label = UILabel()
                label.text = String(format: "%.1f", value)
                label.font = .systemFont(ofSize: style.labelFontSize)
                label.textColor = style.mainScaleTextColor
                label.textAlignment = .center
                self.scaleView.addSubview(label)
                scaleLabels.append(label)
                
                label.snp.makeConstraints { make in
                    make.centerX.equalTo(scaleView)
                    make.top.equalTo(scaleView.snp.bottom).offset(2)
                }
            }
        }
        
        // 计算初始偏移：将0点对准中心
        let stepsFromZero = -config.minValue / config.step
        let initialOffset = CGFloat(stepsFromZero) * stepWidth
        contentView.transform = CGAffineTransform(translationX: initialOffset, y: 0)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .began:
            Constants.impactFeedback.impactOccurred()
            UIView.animate(withDuration: 0.2) {
                self.thumbView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }
            
        case .changed:
            let stepWidth = style.scaleWidth
            let sensitivity = min(abs(gesture.velocity(in: self).x) / 1000, 2.0)
            // 左滑尺子向左移动，数值增加
            let valueChange = Float(translation.x / stepWidth) * config.step * Float(sensitivity)
            
            var newValue = currentValue - valueChange  // 注意这里改为减法
            newValue = min(config.maxValue, max(config.minValue, newValue))
            
            if newValue != currentValue {
                currentValue = newValue
                updateScalePosition(animated: true)
                valueChangedHandler?(currentValue)
            }
            gesture.setTranslation(.zero, in: self)
            
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                self.thumbView.transform = .identity
                self.snapToNearestStep()
            }
            
        default:
            break
        }
    }
    
    private func snapToNearestStep() {
        let steps = round(currentValue / config.step)
        let newValue = steps * config.step
        currentValue = min(config.maxValue, max(config.minValue, newValue))
        
        updateScalePosition(animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.animationDuration) {
            self.updateValueLabel()
        }
        valueChangedHandler?(currentValue)
        Constants.impactFeedback.impactOccurred()
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let centerX = bounds.width / 2
        
        let hitTestRect = CGRect(x: location.x - 20, y: 0, width: 40, height: bounds.height)
        guard hitTestRect.contains(CGPoint(x: location.x, y: location.y)) else { return }
        
        let stepWidth = style.scaleWidth
        // 点击右侧，尺子向左移动（值增大）；点击左侧，尺子向右移动（值减小）
        let steps = (location.x - centerX) / stepWidth
        let valueChange = Float(steps) * config.step
        
        var newValue = currentValue + valueChange  // 点击右侧值增大，点击左侧值减小
        newValue = min(config.maxValue, max(config.minValue, newValue))
        currentValue = newValue
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.snapToNearestStep()
        }
    }
    
    // 新增：计算标尺中心位置对应的值
    private func getCurrentScaleValue() -> Float {
        let transform = contentView.transform.tx
        let totalSteps = Int((config.maxValue - config.minValue) / config.step)
        let stepWidth = style.scaleWidth
        let totalSize = CGFloat(totalSteps) * stepWidth
        
        // 反转计算方向：保持与移动方向一致
        let progress = transform / totalSize
        return config.minValue + Float(progress) * (config.maxValue - config.minValue)
    }
    
    // 修改：计算游标对应的刻度值
    private func getScaleValueAtCursor() -> Float {
        let stepWidth: CGFloat = 40.0
        let transform = contentView.transform.tx
        let totalSteps = Int((config.maxValue - config.minValue) / config.step)
        let totalWidth = CGFloat(totalSteps) * stepWidth
        
        // 计算进度
        let progress = -transform / totalWidth
        // 计算对应的值
        let value = config.minValue + Float(progress) * (config.maxValue - config.minValue)
        
        print("===== 游标位置分析 =====")
        print("transform: \(transform)")
        print("totalWidth: \(totalWidth)")
        print("progress: \(progress)")
        print("计算值: \(value)")
        print("====================")
        
        return value
    }
    
    private func updateScalePosition(animated: Bool) {
        let stepWidth = style.scaleWidth
        
        // 计算当前值相对于0点的步数
        let stepsFromZero = -currentValue / config.step
        let offset = CGFloat(stepsFromZero) * stepWidth
        
        let transform = CGAffineTransform(translationX: offset, y: 0)
        
        if animated {
            UIView.animate(withDuration: Constants.animationDuration, delay: 0, options: [.curveEaseOut], animations: {
                self.contentView.transform = transform
            })
        } else {
            contentView.transform = transform
        }
    }
    
    private func updateValueLabel() {
        let absValue = abs(currentValue)
        let format = absValue >= 10 ? "%.0f" : (absValue >= 1 ? "%.1f" : "%.2f")
        let text = String(format: format, currentValue)
        
        if let oldText = valueLabel.text, oldText != text {
            let transition = CATransition()
            transition.type = .push
            transition.subtype = Float(text) ?? 0 > (Float(oldText) ?? 0) ? .fromTop : .fromBottom
            transition.duration = 0.2
            valueLabel.layer.add(transition, forKey: "valueChange")
        }
        
        valueLabel.text = text
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 只在第一次或尺寸改变时重绘刻度
        if scaleView.subviews.isEmpty {
            drawScales()
            updateScalePosition(animated: false)
        }
    }
    
    @objc private func handleThumbPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            UIView.animate(withDuration: 0.2) {
                self.thumbView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2) {
                self.thumbView.transform = .identity
            }
        default:
            break
        }
    }
    
    // MARK: - Accessibility
    private func setupAccessibility() {
        isAccessibilityElement = true
        accessibilityLabel = "刻度滑块"
        accessibilityTraits = .adjustable
        
        // 支持VoiceOver调整
        accessibilityValue = valueFormatter?(currentValue) ?? String(format: "%.1f", currentValue)
    }
    
    override func accessibilityIncrement() {
        var newValue = currentValue + config.step
        newValue = min(config.maxValue, newValue)
        if newValue != currentValue {
            currentValue = newValue
            feedbackGenerator.selectionChanged()
            updateScalePosition(animated: true)
            updateValueLabel()
            valueChangedHandler?(currentValue)
        }
    }
    
    override func accessibilityDecrement() {
        var newValue = currentValue - config.step
        newValue = max(config.minValue, newValue)
        if newValue != currentValue {
            currentValue = newValue
            feedbackGenerator.selectionChanged()
            updateScalePosition(animated: true)
            updateValueLabel()
            valueChangedHandler?(currentValue)
        }
    }
    
    // MARK: - Display Link
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        // 优化动画性能
        updateVisibleScaleLabels()
    }
    
    private func updateVisibleScaleLabels() {
        // 只更新可见区域的刻度标签
        let visibleRect = convert(bounds, to: scaleView)
        for label in scaleLabels {
            let labelFrame = label.convert(label.bounds, to: scaleView)
            label.isHidden = !visibleRect.intersects(labelFrame)
        }
    }
    
    // MARK: - Memory Management
    deinit {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func updateStyle() {
        sliderTrack.backgroundColor = style.trackColor
        centerLine.backgroundColor = style.centerLineColor
        
        // 更新滑块样式
        setupThumbView()
        
        // 更新刻度样式
        scaleView.subviews.forEach { view in
            if let scale = view as? UIView, !(view is UILabel) {
                scale.backgroundColor = style.scaleColor
            }
            if let label = view as? UILabel {
                label.textColor = style.mainScaleTextColor
                label.font = .systemFont(ofSize: style.labelFontSize)
            }
        }
        
        // 更新数值标签样式
        valueLabel.backgroundColor = style.valueLabelBackgroundColor
        valueLabel.textColor = style.valueLabelTextColor
        
        // 重新绘制刻度
        drawScales()
        
        // 更新内容视图宽度
        let totalSteps = Int((config.maxValue - config.minValue) / config.step)
        let totalSize = CGFloat(totalSteps) * style.scaleWidth
        contentView.snp.updateConstraints { make in
            make.width.equalTo(totalSize + UIScreen.main.bounds.width)
        }
        
        // 更新位置
        updateScalePosition(animated: false)
    }
    
    private func setupThumbView() {
        // 移除现有的子视图
        thumbView.subviews.forEach { $0.removeFromSuperview() }
        
        switch style.thumbShape {
        case .circle:
            // 圆形滑块样式
            thumbView.backgroundColor = style.thumbColor
            thumbView.layer.cornerRadius = Constants.thumbSize / 2
            thumbView.snp.updateConstraints { make in
                make.width.height.equalTo(Constants.thumbSize)
            }
            
            let tintView = UIView()
            tintView.backgroundColor = style.thumbTintColor
            thumbView.addSubview(tintView)
            tintView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(Constants.thumbSize - 8)
            }
            tintView.layer.cornerRadius = (Constants.thumbSize - 8) / 2
            
        case .vertical:
            // 竖条滑块样式
            let width: CGFloat = 3
            let height: CGFloat = 40
            
            thumbView.backgroundColor = style.thumbTintColor  // 竖条模式直接使用 tintColor
            thumbView.layer.cornerRadius = width / 2
            thumbView.snp.updateConstraints { make in
                make.width.equalTo(width)
                make.height.equalTo(height)
            }
        }
        
        // 通用阴影设置
        thumbView.layer.shadowColor = UIColor.black.cgColor
        thumbView.layer.shadowOffset = CGSize(width: 0, height: 2)
        thumbView.layer.shadowOpacity = 0.2
        thumbView.layer.shadowRadius = 2
    }
    
    // MARK: - Public Methods
    
    /// 设置当前值
    /// - Parameters:
    ///   - value: 目标值
    ///   - animated: 是否动画过渡
    func setValue(_ value: Float, animated: Bool) {
        let newValue = min(config.maxValue, max(config.minValue, value))
        if newValue != currentValue {
            currentValue = newValue
            updateScalePosition(animated: animated)
            updateValueLabel()
            valueChangedHandler?(currentValue)
        }
    }
    
    /// 重置到默认值
    /// - Parameter animated: 是否动画过渡
    func resetToDefault(animated: Bool) {
        setValue(config.defaultValue, animated: animated)
    }
}

// MARK: - Constants
private enum Constants {
    /// 默认步宽
    static let stepWidth: CGFloat = 20.0
    /// 滑块大小
    static let thumbSize: CGFloat = 24.0
    /// 轨道高度
    static let trackHeight: CGFloat = 2.0
    /// 主刻度高度
    static let mainScaleHeight: CGFloat = 10.0
    /// 副刻度高度
    static let subScaleHeight: CGFloat = 5.0
    /// 标签字体大小
    static let labelFontSize: CGFloat = 10.0
    /// 动画时长
    static let animationDuration: TimeInterval = 0.2
    /// 触感反馈
    static let impactFeedback = UIImpactFeedbackGenerator(style: .light)
}

