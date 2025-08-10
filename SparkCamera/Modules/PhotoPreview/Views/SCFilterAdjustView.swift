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
    func filterAdjustView(_ view: SCFilterAdjustView, didChangeExpandState state: Bool)
}

// 滤镜参数结构体
struct FilterParameter {
    let name: String
    let minValue: Float
    let maxValue: Float
    let defaultValue: Float
    let step: Float
}

public class SCFilterAdjustView: UIView {
    
    // MARK: - Properties
    public weak var delegate: SCFilterAdjustViewDelegate?
    public private(set) var isExpanded: Bool = false
    private var tableView: UITableView!
    private var handleView: UIView!
    private var expandedWidth: CGFloat = 280
    
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
    
    // 滤镜参数配置 - 根据GPUImage滤镜特性设计的合理范围和步长
    private let parameters: [FilterParameter] = [
        // 基础色彩调整
        FilterParameter(name: "亮度", minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.05),
        FilterParameter(name: "对比度", minValue: 0.5, maxValue: 4.0, defaultValue: 1.0, step: 0.1),
        FilterParameter(name: "饱和度", minValue: 0.0, maxValue: 2.0, defaultValue: 1.0, step: 0.05),
        FilterParameter(name: "曝光", minValue: -3.0, maxValue: 3.0, defaultValue: 0.0, step: 0.1),
        
        // 高光阴影调整
        FilterParameter(name: "高光", minValue: 0.0, maxValue: 1.0, defaultValue: 1.0, step: 0.05),
        FilterParameter(name: "阴影", minValue: 0.0, maxValue: 1.0, defaultValue: 1.0, step: 0.05),
        
        // 纹理效果
        FilterParameter(name: "颗粒感", minValue: 0.0, maxValue: 1.0, defaultValue: 0.0, step: 0.05),
        FilterParameter(name: "锐度", minValue: -4.0, maxValue: 4.0, defaultValue: 0.0, step: 0.1),
        FilterParameter(name: "模糊", minValue: 0.0, maxValue: 2.0, defaultValue: 0.0, step: 0.05),
        
        // 艺术效果
        FilterParameter(name: "光晕", minValue: 0.0, maxValue: 1.0, defaultValue: 0.0, step: 0.05),
        FilterParameter(name: "边缘强度", minValue: 0.0, maxValue: 4.0, defaultValue: 0.0, step: 0.1),
        
        // RGB颜色通道调整
        FilterParameter(name: "红色", minValue: 0.0, maxValue: 2.0, defaultValue: 1.0, step: 0.05),
        FilterParameter(name: "绿色", minValue: 0.0, maxValue: 2.0, defaultValue: 1.0, step: 0.05),
        FilterParameter(name: "蓝色", minValue: 0.0, maxValue: 2.0, defaultValue: 1.0, step: 0.05)
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
        
        // 先添加所有子视图
        setupViews()
        // 然后设置约束
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
        tableView.delaysContentTouches = false
        tableView.canCancelContentTouches = true
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
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(resetButton.snp.top).offset(-10)
        }
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        handleView.addGestureRecognizer(tapGesture)
        handleView.isUserInteractionEnabled = true
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        handleView.addGestureRecognizer(panGesture)
    }
    
    // MARK: - Actions
    @objc private func handleTap() {
        toggleDrawer()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .changed:
            let newX = frame.origin.x + translation.x
            if newX <= 0 && newX >= -expandedWidth {
                frame.origin.x = newX
                gesture.setTranslation(.zero, in: self)
                
                // 根据拖动进度更新状态
                isExpanded = frame.origin.x < -expandedWidth/2
                delegate?.filterAdjustView(self, didChangeExpandState: isExpanded)
            }
        case .ended:
            let velocity = gesture.velocity(in: self)
            if velocity.x > 500 {
                // 快速右滑，收起抽屉
                collapse()
            } else if velocity.x < -500 {
                // 快速左滑，展开抽屉
                expand()
            } else {
                // 根据当前位置决定展开或收起
                if frame.origin.x < -expandedWidth/2 {
                    expand()
                } else {
                    collapse()
                }
            }
        default:
            break
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
    
    // MARK: - Public Methods
    public func toggleDrawer() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }
    
    public func expand() {
        isExpanded = true
        print("🔧 [FilterAdjustView] 开始展开抽屉")
        print("  当前transform: \(self.transform)")
        print("  当前frame: \(self.frame)")
        
        let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
            // 滑入到正常位置（贴着屏幕右边）
            self.transform = CGAffineTransform.identity
        }
        animator.addCompletion { [weak self] _ in
            guard let self = self else { return }
            print("🔧 [FilterAdjustView] 抽屉展开完成")
            print("  最终transform: \(self.transform)")
            print("  最终frame: \(self.frame)")
            self.delegate?.filterAdjustView(self, didChangeExpandState: true)
        }
        animator.startAnimation()
    }
    
    public func collapse() {
        isExpanded = false
        print("🔧 [FilterAdjustView] 开始收起抽屉")
        print("  当前transform: \(self.transform)")
        print("  当前frame: \(self.frame)")
        
        let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeOut) {
            // 滑出到屏幕右侧外面
            self.transform = CGAffineTransform(translationX: self.bounds.width, y: 0)
        }
        animator.addCompletion { [weak self] _ in
            guard let self = self else { return }
            print("🔧 [FilterAdjustView] 抽屉收起完成")
            print("  最终transform: \(self.transform)")
            print("  最终frame: \(self.frame)")
            self.delegate?.filterAdjustView(self, didChangeExpandState: false)
        }
        animator.startAnimation()
    }
    
    public func updateParameters(_ parameters: [String: Float]) {
        // 更新当前值
        for (key, value) in parameters {
            // 确保值在有效范围内
            if let parameter = self.parameters.first(where: { $0.name == key }) {
                let clampedValue = min(max(value, parameter.minValue), parameter.maxValue)
                currentValues[key] = clampedValue
            } else {
                currentValues[key] = value
            }
        }
        // 刷新表格
        tableView.reloadData()
    }
    
    public func resetParameters() {
        // 重置所有参数到默认值
        for parameter in parameters {
            currentValues[parameter.name] = parameter.defaultValue
            delegate?.filterAdjustView(self, didUpdateParameter: parameter.name, value: parameter.defaultValue)
        }
        // 刷新表格
        tableView.reloadData()
    }
    
    public func reloadData() {
        tableView.reloadData()
    }
    
    /// 获取当前所有参数的值
    public func getCurrentParameterValues() -> [String: Float] {
        return currentValues
    }
    
    /// 检查是否有参数被修改过
    public func hasModifiedParameters() -> Bool {
        for parameter in parameters {
            let currentValue = currentValues[parameter.name] ?? parameter.defaultValue
            if abs(currentValue - parameter.defaultValue) > Float.ulpOfOne {
                return true
            }
        }
        return false
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
        // 配置滤镜参数

        // 获取当前值，如果不存在则使用默认值
        let currentValue = currentValues[parameter.name] ?? parameter.defaultValue
        
        // 使用新的configure方法
        cell.configure(parameter: parameter, currentValue: currentValue)
        
        // 配置值变化回调
        cell.valueChanged = { [weak self] value in
            guard let self = self else { return }
            // 更新当前值
            self.currentValues[parameter.name] = value
            // 通知代理
            self.delegate?.filterAdjustView(self, didUpdateParameter: parameter.name, value: value)
        }
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 160  
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 当滚动时，如果有正在编辑的滑块，结束其编辑状态
        if let visibleCells = tableView.visibleCells as? [SCFilterAdjustCell] {
            for cell in visibleCells {
                if let slider = cell.contentView.subviews.first(where: { $0 is SCScaleSlider }) as? SCScaleSlider {
                    slider.endEditing(true)
                }
            }
        }
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
    
    private var slider: SCScaleSlider!
    public var valueChanged: ((Float) -> Void)?
    private var defaultValue: Float = 0.0
    private var parameter: FilterParameter?  // 添加参数属性
    
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
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.height.equalTo(30)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.right.equalToSuperview().offset(-16)
            make.width.equalTo(64)
            make.height.equalTo(26)
            make.left.equalTo(titleLabel.snp.right).offset(8)
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
    
    private func updateValueLabel(_ value: Float) {
        guard let parameter = parameter else { return }
        
        // 根据参数范围选择合适的显示格式
        let absValue = abs(value)
        let format: String
        if parameter.maxValue >= 10 {
            format = "%.0f"  // 大范围值（如对比度）使用整数
        } else if parameter.maxValue >= 2 {
            format = "%.1f"  // 中等范围值（如饱和度）保留一位小数
        } else {
            format = "%.2f"  // 小范围值（如亮度）保留两位小数
        }
        valueLabel.text = String(format: format, value)
        
        // 根据值是否为默认值调整显示样式
        let isDefaultValue = abs(value - parameter.defaultValue) < Float.ulpOfOne
        valueLabel.backgroundColor = isDefaultValue
            ? UIColor(white: 1.0, alpha: 0.15)
            : SCConstants.themeColor.withAlphaComponent(0.8)
        
        // 添加轻微动画效果
        UIView.animate(withDuration: 0.1) {
            self.valueLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.valueLabel.transform = .identity
            }
        }
    }
    
    // MARK: - Configuration
    func configure(parameter: FilterParameter, currentValue: Float) {
        self.parameter = parameter  // 保存参数
        titleLabel.text = parameter.name
        defaultValue = parameter.defaultValue
        
        // 移除旧的滑块
        slider?.removeFromSuperview()

        // 创建新的滑块
        let config = SCScaleSliderConfig(
            minValue: parameter.minValue,
            maxValue: parameter.maxValue,
            step: parameter.step,
            defaultValue: parameter.defaultValue
        )
        
        slider = SCScaleSlider(config: config)
        slider.style = .Style.default.style
        contentView.addSubview(slider)
        
        // 设置滑块约束
        slider.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(70)
            // 使用 <= 以适配被 UITableView 固定的行高，避免约束冲突
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }
        
        // 确保当前值在有效范围内
        let clampedValue = min(max(currentValue, parameter.minValue), parameter.maxValue)
        
        // 设置初始值
        slider.setValue(clampedValue, animated: false)
        updateValueLabel(clampedValue)
        
        // 配置回调
        slider.valueChangedHandler = { [weak self] value in
            guard let self = self else { return }
            // 确保值在有效范围内
            let clampedValue = min(max(value, parameter.minValue), parameter.maxValue)
            // 根据步长对齐值
            let steps = round(clampedValue / parameter.step)
            let alignedValue = steps * parameter.step
            
            self.updateValueLabel(alignedValue)
            self.valueChanged?(alignedValue)
            
            // 添加触觉反馈（仅在值改变时）
            if abs(alignedValue - clampedValue) < Float.ulpOfOne {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
        
        // 设置滑块样式为竖条模式，更适合滤镜调整
        slider.style = .Style.vertical.style
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        slider?.removeFromSuperview()
        slider = nil
        parameter = nil  // 清理参数
        valueChanged = nil
    }
} 
