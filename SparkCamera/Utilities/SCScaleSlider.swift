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
                    thumbTintColor: SCConstants.themeColor,
                    mainScaleTextColor: .systemGray,
                    centerLineColor: SCConstants.themeColor,
                    valueLabelBackgroundColor: SCConstants.themeColor,
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
                    scaleColor: .systemGray3,  // 改为更明显的颜色
                    thumbColor: .systemGray6,
                    thumbTintColor: SCConstants.themeColor,
                    mainScaleTextColor: .white,
                    centerLineColor: .clear,
                    valueLabelBackgroundColor: SCConstants.themeColor,
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
        view.backgroundColor = SCConstants.themeColor
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
        innerCircle.backgroundColor = SCConstants.themeColor
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
        label.backgroundColor = SCConstants.themeColor
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
        
        // 初始化时更新值标签
        updateValueLabel()
        // 注意：位置更新在drawScales完成后自动执行
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        // 设置裁剪属性，确保内容不会超出视图范围
        clipsToBounds = true
        
        addSubview(contentView)
        contentView.addSubview(sliderTrack)
        contentView.addSubview(scaleView)
        
        addSubview(centerLine)
        addSubview(thumbView)
        addSubview(valueLabel)
        
        // 设置contentView约束
        contentView.snp.makeConstraints { make in
            make.height.equalToSuperview()
            make.centerY.equalToSuperview()
            
            let totalSteps = Int((config.maxValue - config.minValue) / config.step)
            let stepSize = style.scaleWidth
            let totalSize = CGFloat(totalSteps) * stepSize
            
            // 总宽度 = 刻度总宽度 + 两边缓冲区（确保两端有足够空间滑动）
            make.width.equalTo(totalSize + UIScreen.main.bounds.width * 2)
            
            // 从左边开始布局，为transform提供简单的基准点
            make.leading.equalToSuperview()
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
        
        // 延迟绘制刻度，确保布局完成
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isDrawingScales = false  // 确保可以绘制
            self.drawScales()
        }
    }
    
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        contentView.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        contentView.addGestureRecognizer(tapGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleThumbPress(_:)))
        longPressGesture.minimumPressDuration = 0.1
        thumbView.addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Drawing
    
    /// 调用计数器，用于调试
    private var drawScalesCallCount = 0
    /// 防止重复绘制的标志
    private var isDrawingScales = false
    
    /// 绘制刻度线和标签
    /// 使用简化的坐标系：刻度从左边缓冲区开始线性排列
    private func drawScales() {
        // 防止重复调用
        guard !isDrawingScales else { return }
        
        isDrawingScales = true
        drawScalesCallCount += 1
        
        // 清除现有的刻度
        scaleView.subviews.forEach { $0.removeFromSuperview() }
        scaleLabels.removeAll()
        
        let totalSteps = Int((config.maxValue - config.minValue) / config.step)
        let stepWidth = style.scaleWidth
        
        // 确保scaleView有正确的frame
        if scaleView.frame.width == 0 {
            isDrawingScales = false
            return
        }
        
        // 刻度从左边缓冲区开始绘制，计算简单明确
        let totalScaleWidth = CGFloat(totalSteps) * stepWidth
        let screenWidth = UIScreen.main.bounds.width
        let scaleStartOffset = screenWidth  // 左边留一个屏幕宽度的缓冲区

        // 计算“合理”的主刻度间隔：目标标签数量约 10
        func niceNumber(_ range: Float, round: Bool) -> Float {
            guard range > 0 else { return 1 }
            let exponent = floor(log10(range))
            let fraction = range / pow(10.0, exponent)
            let nice: Float
            if round {
                if fraction < 1.5 { nice = 1 }
                else if fraction < 3 { nice = 2 }
                else if fraction < 7 { nice = 5 }
                else { nice = 10 }
            } else {
                if fraction <= 1 { nice = 1 }
                else if fraction <= 2 { nice = 2 }
                else if fraction <= 5 { nice = 5 }
                else { nice = 10 }
            }
            return nice * pow(10.0, exponent)
        }

        let valueRange = config.maxValue - config.minValue
        let targetLabels: Float = 10
        let rawInterval = max(valueRange / targetLabels, config.step)
        let mainInterval = max(niceNumber(rawInterval, round: true), config.step)
        let stepsPerLabel = max(1, Int(round(mainInterval / config.step)))

        // 根据主刻度间隔决定小刻度间隔（可见性适中）
        let stepsPerMinor = max(1, stepsPerLabel / 5)

        // 修正：确保刻度数量正确，不超过最大值
        for i in 0...totalSteps {
            let value = config.minValue + Float(i) * config.step

            if value > config.maxValue { break }

            let isMainScale = (i % stepsPerLabel == 0) || (i == totalSteps)
            let isMinorScale = !isMainScale && (i % stepsPerMinor == 0)

            let scaleLine = UIView()
            scaleLine.backgroundColor = style.scaleColor
            scaleView.addSubview(scaleLine)

            let scaleX = scaleStartOffset + CGFloat(i) * stepWidth
            let height: CGFloat = isMainScale ? style.mainScaleHeight : (isMinorScale ? style.subScaleHeight : (style.subScaleHeight * 0.6))
            let scaleY = (scaleView.bounds.height - height) / 2

            scaleLine.frame = CGRect(
                x: scaleX,
                y: scaleY,
                width: 1,
                height: height
            )

            if isMainScale {
                let label = UILabel()
                // 标签格式：根据主间隔决定小数位
                let absInterval = abs(mainInterval)
                let decimals: Int
                if absInterval >= 10 { decimals = 0 }
                else if absInterval >= 1 { decimals = 0 }
                else if absInterval >= 0.1 { decimals = 1 }
                else { decimals = 2 }
                label.text = String(format: "%0.*f", decimals, value)
                label.font = .systemFont(ofSize: style.labelFontSize)
                label.textColor = style.mainScaleTextColor
                label.textAlignment = .center
                scaleView.addSubview(label)
                scaleLabels.append(label)

                let labelSize = label.sizeThatFits(CGSize(width: 50, height: 20))
                label.frame = CGRect(
                    x: scaleX - labelSize.width / 2,
                    y: scaleLine.frame.maxY + 2,
                    width: labelSize.width,
                    height: labelSize.height
                )
            }
        }
        
        // 强制布局更新以确保刻度可见
        scaleView.setNeedsLayout()
        scaleView.layoutIfNeeded()
        
        // 绘制完成，重置防护标志
        isDrawingScales = false
        
        // 绘制完成后，在下一个运行循环中对齐到中心线
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.alignCurrentValueToCenter()
        }
    }
    
    // MARK: - Alignment
    
    /// 让当前值对应的刻度位置对齐到中心线
    /// 
    /// 核心对齐逻辑：
    /// 1. 计算当前值在contentView中的绝对位置
    /// 2. 计算需要的transform偏移量，使该位置对齐到视图中心
    /// 3. 应用CGAffineTransform实现对齐
    /// 
    /// - Parameter animated: 是否使用动画过渡
    private func alignCurrentValueToCenter(animated: Bool = false) {
        guard bounds.width > 0 else { return }
        guard !scaleLabels.isEmpty else { return }
        
        // 使用与drawScales相同的坐标系计算
        let stepWidth = style.scaleWidth
        let screenWidth = UIScreen.main.bounds.width
        let scaleStartOffset = screenWidth  // 刻度从左边缓冲区开始
        
        // 计算当前值在contentView中的位置
        let currentStepsFromMin = (currentValue - config.minValue) / config.step
        let currentValuePositionInContentView = scaleStartOffset + CGFloat(currentStepsFromMin) * stepWidth
        
        // 计算视图中心位置
        let viewCenter = bounds.width / 2
        
        // 核心计算：计算让当前值对齐到中心所需的transform偏移
        let requiredTransformOffset = viewCenter - currentValuePositionInContentView
        
        // 应用transform让当前值对齐到中心
        let alignTransform = CGAffineTransform(translationX: requiredTransformOffset, y: 0)
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
                self.contentView.transform = alignTransform
            }
        } else {
            contentView.transform = alignTransform
        }
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
            
            // 交互逻辑：左滑增值，右滑减值（负号实现正确的方向映射）
            let valueChange = -Float(translation.x / stepWidth) * config.step * Float(sensitivity)
            
            var newValue = currentValue + valueChange
            newValue = min(config.maxValue, max(config.minValue, newValue))
            
            if newValue != currentValue {
                currentValue = newValue
                updateScalePosition(animated: true)
                updateValueLabel()
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
    
    /// 将当前值对齐到最近的步长
    private func snapToNearestStep() {
        // 计算最接近的步数并对齐
        let stepsFromMin = round((currentValue - config.minValue) / config.step)
        let newValue = config.minValue + Float(stepsFromMin) * config.step
        let oldValue = currentValue
        currentValue = min(config.maxValue, max(config.minValue, newValue))
        
        updateScalePosition(animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.animationDuration) {
            self.updateValueLabel()
            if oldValue != self.currentValue {
                self.valueChangedHandler?(self.currentValue)
            }
        }
        
        Constants.impactFeedback.impactOccurred()
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let centerX = bounds.width / 2
        
        let hitTestRect = CGRect(x: location.x - 20, y: 0, width: 40, height: bounds.height)
        guard hitTestRect.contains(CGPoint(x: location.x, y: location.y)) else { return }
        
        // 使用新的值计算方法
        let newValue = getValueAtPosition(location.x)
        
        if newValue != currentValue {
            currentValue = newValue
            updateScalePosition(animated: true)
            updateValueLabel()
            valueChangedHandler?(currentValue)
            snapToNearestStep()
        }
    }
    
    private func updateScalePosition(animated: Bool) {
        // 直接使用对齐方法
        alignCurrentValueToCenter(animated: animated)
    }
    
    // 根据屏幕位置计算对应的值
    private func getValueAtPosition(_ position: CGFloat) -> Float {
        let stepWidth = style.scaleWidth
        let screenWidth = UIScreen.main.bounds.width
        let scaleStartOffset = screenWidth  // 刻度从左边缓冲区开始
        
        // 获取当前contentView的transform偏移量
        let currentTransformOffset = contentView.transform.tx
        
        // 计算在contentView坐标系中的位置
        let positionInContentView = position - currentTransformOffset
        
        // 计算在刻度坐标系中的位置
        let positionInScale = positionInContentView - scaleStartOffset
        
        // 计算对应的步数
        let steps = positionInScale / stepWidth
        
        // 计算对应的值
        let value = config.minValue + Float(steps) * config.step
        
        // 确保值在范围内
        let clampedValue = min(config.maxValue, max(config.minValue, value))
        
        return clampedValue
    }
    
    // 根据值计算对应的位置
    private func getPositionForValue(_ value: Float) -> CGFloat {
        // 对于当前的设计，特定值对应的刻度总是显示在屏幕中心
        // 因为我们通过transform移动contentView来实现这一点
        let centerPosition = bounds.width / 2
        
        return centerPosition
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
        
        // 确保刻度在布局完成后重新绘制（仅在需要时）
        let needsRedraw = scaleView.subviews.isEmpty && bounds.width > 0 && scaleView.frame.width > 0
        
        if needsRedraw {
            isDrawingScales = false  // 确保可以绘制
            drawScales()
        } else if !scaleLabels.isEmpty && bounds.width > 0 {
            alignCurrentValueToCenter()
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
            make.width.equalTo(totalSize + UIScreen.main.bounds.width * 2)  // 两边缓冲区
        }
        
        // 重新绘制和对齐（在下次layoutSubviews中生效）
        setNeedsLayout()
        
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
            
            // 如果刻度已经绘制，直接重新对齐到中心
            if !scaleLabels.isEmpty && bounds.width > 0 {
                alignCurrentValueToCenter(animated: animated)
            }
            
            updateValueLabel()
            valueChangedHandler?(currentValue)
        }
    }
    
    /// 重置到默认值
    /// - Parameter animated: 是否动画过渡
    func resetToDefault(animated: Bool) {
        setValue(config.defaultValue, animated: animated)
    }
    
    /// 更新配置
    /// - Parameter newConfig: 新的配置
    func updateConfig(_ newConfig: SCScaleSliderConfig) {
        config = newConfig
        currentValue = newConfig.defaultValue
        
        // 重新设置UI
        let totalSteps = Int((config.maxValue - config.minValue) / config.step)
        let totalSize = CGFloat(totalSteps) * style.scaleWidth
        
        contentView.snp.updateConstraints { make in
            make.width.equalTo(totalSize + UIScreen.main.bounds.width * 2)  // 两边缓冲区
        }
        
        // 重新计算初始位置（在下次layoutSubviews中生效）
        setNeedsLayout()
        
        // 重新绘制刻度
        drawScales()
        updateScalePosition(animated: false)
        updateValueLabel()
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

/*
 MARK: - 使用说明
 
 SCScaleSlider 是一个通用的刻度滑块调节组件，主要用于精确调节数值的场景。
 
 ## 核心功能：
 1. 刻度显示：支持主刻度和副刻度，主刻度显示数值标签
 2. 滑块交互：支持拖拽、点击、长按等手势操作
 3. 数值调节：支持设置最小值、最大值、步长和默认值
 4. 样式定制：支持多种预定义样式（默认、暗色、竖条）
 5. 触感反馈：提供触觉反馈增强用户体验
 
 ## 交互逻辑：
 1. 竖线标尺固定位置：中心线始终固定在视图中心
 2. 左滑刻度值增大，尺子左移；右滑值减小，尺子右移
 3. 支持外部设置默认值，尺子范围，最大最小值和尺子步长
 
 ## 使用示例：
 
 ```swift
 // 创建默认配置的滑块
 let slider = SCScaleSlider()
 
 // 创建自定义配置的滑块
 let config = SCScaleSliderConfig(
     minValue: -1.0,
     maxValue: 1.0,
     step: 0.1,
     defaultValue: 0.0
 )
 let customSlider = SCScaleSlider(config: config)
 
 // 设置值变化回调
 slider.valueChangedHandler = { value in
     print("当前值: \(value)")
 }
 
 // 设置样式
 slider.style = .Style.dark.style
 
 // 设置当前值
 slider.setValue(0.5, animated: true)
 
 // 重置到默认值
 slider.resetToDefault(animated: true)
 
 // 更新配置
 let newConfig = SCScaleSliderConfig(
     minValue: -2.0,
     maxValue: 2.0,
     step: 0.2,
     defaultValue: 0.0
 )
 slider.updateConfig(newConfig)
 ```
 
 ## 注意事项：
 1. 确保在视图布局完成后使用，否则刻度可能不显示
 2. 交互逻辑：左滑值增大，右滑值减小
 3. 刻度会自动对齐到最近的步长
 4. 支持触觉反馈和无障碍访问
 */

