//
//  SCFilterAdjustView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/18.
//
//

import UIKit
import SnapKit

public protocol SCFilterAdjustViewDelegate: AnyObject {
    func filterAdjustView(_ view: SCFilterAdjustView, didUpdateParameter parameter: String, value: Float)
    func filterAdjustView(_ view: SCFilterAdjustView, didChangeExpandState isExpanded: Bool)
}

public class SCFilterAdjustView: UIView {
    
    // MARK: - Properties
    public weak var delegate: SCFilterAdjustViewDelegate?
    public private(set) var isExpanded: Bool = false
    private var tableView: UITableView!
    private var handleView: UIView!
    private var expandedWidth: CGFloat = 280
    private var initialX: CGFloat = 0
    private var isDragging: Bool = false
    
    // 添加右边距常量
    private let rightMargin: CGFloat = 0
    
    // 添加重置按钮
    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重置", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(handleReset), for: .touchUpInside)
        return button
    }()
    
    // 参数配置
    private let parameters: [(name: String, range: ClosedRange<Float>, step: Float, defaultValue: Float)] = [
        ("亮度", -1.0...1.0, 0.05, 0.0),      // Brightness
        ("对比度", 0.0...4.0, 0.1, 1.0),      // Contrast
        ("饱和度", 0.0...2.0, 0.05, 1.0),     // Saturation
        ("曝光", -4.0...4.0, 0.1, 0.0),       // Exposure
        ("高光", 0.0...1.0, 0.05, 1.0),       // Highlights
        ("阴影", 0.0...1.0, 0.05, 1.0),       // Shadows
        ("锐度", 0.0...4.0, 0.1, 1.0),        // Sharpness
        ("模糊", 0.0...2.0, 0.05, 0.0),       // Blur
        ("颗粒感", 0.0...1.0, 0.05, 0.0),     // Grain
        ("光晕", 0.0...1.0, 0.05, 0.0),       // Glow
        ("边缘强度", 0.0...1.0, 0.05, 0.0),   // Edge Strength
        ("红色", 0.0...2.0, 0.05, 1.0),       // Red Channel
        ("绿色", 0.0...2.0, 0.05, 1.0),       // Green Channel
        ("蓝色", 0.0...2.0, 0.05, 1.0)        // Blue Channel
    ]
    
    private var currentValues: [String: Float] = [:]
    
    // MARK: - Initialization
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
        
        // 初始化当前值
        for parameter in parameters {
            currentValues[parameter.name] = parameter.defaultValue
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        clipsToBounds = true
        
        // 添加阴影效果
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: -2, height: 0)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        
        setupViews()
        setupConstraints()
    }
    
    private func setupViews() {
        handleView = UIView()
        handleView.backgroundColor = .white
        handleView.layer.cornerRadius = 2
        addSubview(handleView)
        
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SCFilterAdjustCell.self, forCellReuseIdentifier: "AdjustCell")
        addSubview(tableView)
        
        resetButton.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        addSubview(resetButton)
    }
    
    private func setupConstraints() {
        handleView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.equalTo(4)
            make.height.equalTo(40)
        }
        
        resetButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(44)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.bottom.equalTo(resetButton.snp.top).offset(-10)
        }
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        handleView.addGestureRecognizer(tapGesture)
        handleView.isUserInteractionEnabled = true
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)  // 将手势添加到整个视图
        
        // 添加右滑手势
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleRightSwipe))
        rightSwipeGesture.direction = .right
        addGestureRecognizer(rightSwipeGesture)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }
    
    @objc private func handleReset() {
        // 触发震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 显示确认对话框
        SCAlert.show(
            title: "重置滤镜参数",
            message: "确定要将所有滤镜参数重置为默认值吗？",
            style: .warning,
            cancelTitle: "取消",
            confirmTitle: "重置"
        ) { [weak self] confirmed in
            guard let self = self, confirmed else { return }
            
            // 重置所有参数到默认值
            for parameter in self.parameters {
                self.currentValues[parameter.name] = parameter.defaultValue
                self.delegate?.filterAdjustView(self, didUpdateParameter: parameter.name, value: parameter.defaultValue)
            }
            
            // 刷新表格
            self.tableView.reloadData()
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        
        let translation = gesture.translation(in: superview)
        let velocity = gesture.velocity(in: superview)
        
        switch gesture.state {
        case .began:
            isDragging = true
            initialX = frame.origin.x
            
        case .changed:
            let newX = initialX + translation.x
            // 限制拖动范围在收起和展开位置之间
            let collapsedX = superview.bounds.width - rightMargin
            let expandedX = collapsedX - expandedWidth
            
            if newX <= collapsedX && newX >= expandedX {
                frame.origin.x = newX
                
                // 根据拖动位置调整透明度
                let progress = (collapsedX - newX) / expandedWidth
                backgroundColor = UIColor(white: 0.1, alpha: 0.95 * max(0.5, progress))
            }
            
        case .ended, .cancelled:
            isDragging = false
            let finalVelocity = velocity.x
            
            // 根据速度和位置决定展开或收起
            if abs(finalVelocity) > 500 {
                if finalVelocity > 0 {
                    collapse()
                } else {
                    expand()
                }
            } else {
                let collapsedX = superview.bounds.width - rightMargin
                let expandedX = collapsedX - expandedWidth
                let middleX = expandedX + (expandedWidth / 2)
                
                if frame.origin.x < middleX {
                    expand()
                } else {
                    collapse()
                }
            }
            
        default:
            break
        }
    }
    
    @objc private func handleRightSwipe(_ gesture: UISwipeGestureRecognizer) {
        if isExpanded {
            collapse()
        }
    }
    
    // MARK: - Animation Methods
    public func expand() {
        isExpanded = true
        let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.8) {
            // 计算展开时的 x 坐标：屏幕宽度减去展开宽度和右边距
            if let superview = self.superview {
                self.frame.origin.x = superview.bounds.width - self.expandedWidth - self.rightMargin
            }
            self.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        }
        animator.addCompletion { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.filterAdjustView(self, didChangeExpandState: true)
        }
        animator.startAnimation()
    }
    
    public func collapse() {
        isExpanded = false
        let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.8) {
            // 计算收起时的 x 坐标：屏幕宽度减去右边距
            if let superview = self.superview {
                self.frame.origin.x = superview.bounds.width - self.rightMargin
            }
            self.backgroundColor = UIColor(white: 0.1, alpha: 0.5)
        }
        animator.addCompletion { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.filterAdjustView(self, didChangeExpandState: false)
        }
        animator.startAnimation()
    }
    
    // MARK: - Public Methods
    public func updateParameters(_ parameters: [String: Float]) {
        // 添加动画效果
        UIView.animate(withDuration: 0.2) {
            for (key, value) in parameters {
                self.currentValues[key] = value
            }
            self.tableView.reloadData()
        }
    }
    
    public func reloadData() {
        tableView.reloadData()
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension SCFilterAdjustView: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return parameters.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AdjustCell", for: indexPath) as! SCFilterAdjustCell
        let parameter = parameters[indexPath.row]
        cell.configure(
            name: parameter.name,
            value: currentValues[parameter.name] ?? parameter.defaultValue,
            range: parameter.range,
            step: parameter.step
        ) { [weak self] value in
            guard let self = self else { return }
            self.currentValues[parameter.name] = value
            self.delegate?.filterAdjustView(self, didUpdateParameter: parameter.name, value: value)
        }
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}

// MARK: - SCFilterAdjustCell
class SCFilterAdjustCell: UITableViewCell {
    
    // MARK: - Properties
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.9)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        return label
    }()
    
    private lazy var slider: SCScaleSlider = {
        let config = SCScaleSliderConfig(minValue: -1.0, maxValue: 1.0, step: 0.1, defaultValue: 0.0)
        let slider = SCScaleSlider(config: config)
        slider.style = .Style.vertical.style
        return slider
    }()
    
    private var valueChanged: ((Float) -> Void)?
    private var defaultValue: Float = 0.0
    private var currentRange: ClosedRange<Float> = -1.0...1.0
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(valueLabel)
        contentView.addSubview(slider)
        contentView.addSubview(titleLabel)
        contentView.bringSubviewToFront(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.height.equalTo(30)
            make.right.equalTo(valueLabel.snp.left).offset(-8)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.right.equalToSuperview().offset(-16)
            make.width.equalTo(64)
            make.height.equalTo(26)
        }
        
        slider.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.top).offset(8)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-8)
        }
    }
    
    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        contentView.addGestureRecognizer(doubleTap)
    }
    
    // MARK: - Actions
    @objc private func handleDoubleTap() {
        // 触发震动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 重置滑块值
        slider.setValue(defaultValue, animated: true)
        updateValueLabel(defaultValue)
        valueChanged?(defaultValue)
    }
    
    // MARK: - Configuration
    func configure(name: String, value: Float, range: ClosedRange<Float>, step: Float, valueChanged: @escaping (Float) -> Void) {
        titleLabel.text = name
        defaultValue = value
        currentRange = range
        
        // 创建新的配置
        let config = SCScaleSliderConfig(
            minValue: range.lowerBound,
            maxValue: range.upperBound,
            step: step,
            defaultValue: value
        )
        
        // 重新配置滑块
        slider = SCScaleSlider(config: config)
        slider.style = .Style.vertical.style
        slider.valueChangedHandler = { [weak self] value in
            self?.updateValueLabel(value)
            valueChanged(value)
        }
        
        // 设置初始值
        slider.setValue(value, animated: false)
        updateValueLabel(value)
        
        self.valueChanged = valueChanged
    }
    
    private func updateValueLabel(_ value: Float) {
        // 根据值的范围和类型调整显示格式
        let format: String
        if abs(currentRange.upperBound - currentRange.lowerBound) <= 2.0 {
            // 小范围值使用更精确的格式
            format = "%.2f"
        } else if abs(value) < 10 {
            format = "%.1f"
        } else {
            format = "%.0f"
        }
        
        valueLabel.text = String(format: format, value)
        
        // 根据值是否为默认值调整显示样式
        if abs(value - defaultValue) < Float.ulpOfOne {
            valueLabel.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        } else {
            valueLabel.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
        }
    }
} 
