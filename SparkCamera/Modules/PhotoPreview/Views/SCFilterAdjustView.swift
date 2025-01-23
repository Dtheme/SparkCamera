//
//  SCFilterAdjustView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/18.
//
//

import UIKit
import SnapKit

protocol SCFilterAdjustViewDelegate: AnyObject {
    func filterAdjustView(_ view: SCFilterAdjustView, didUpdateParameter parameter: String, value: Float)
}

class SCFilterAdjustView: UIView {
    
    // MARK: - Properties
    weak var delegate: SCFilterAdjustViewDelegate?
    private var isExpanded: Bool = false
    private var tableView: UITableView!
    private var handleView: UIView!
    private var expandedWidth: CGFloat = 280
    
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
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
        
        // 初始化所有参数的当前值为默认值
        for parameter in parameters {
            currentValues[parameter.name] = parameter.defaultValue
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: -2, height: 0)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 5
        
        // 设置圆角
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        clipsToBounds = true
        
        // 设置手柄视图
        setupHandleView()
        
        // 设置表格视图
        setupTableView()
    }
    
    private func setupHandleView() {
        handleView = UIView()
        handleView.backgroundColor = .white
        handleView.layer.cornerRadius = 2
        addSubview(handleView)
        
        handleView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.equalTo(4)
            make.height.equalTo(40)
        }
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SCFilterAdjustCell.self, forCellReuseIdentifier: "AdjustCell")
        addSubview(tableView)
        
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalTo(handleView.snp.right).offset(12)
            make.right.bottom.equalToSuperview()
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
    
    // MARK: - Public Methods
    func toggleDrawer() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }
    
    func expand() {
        isExpanded = true
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.frame.origin.x = -self.expandedWidth
        }
    }
    
    func collapse() {
        isExpanded = false
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.frame.origin.x = 0
        }
    }
    
    func updateParameters(_ parameters: [String: Float]) {
        for (key, value) in parameters {
            currentValues[key] = value
        }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension SCFilterAdjustView: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return parameters.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
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
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
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
        contentView.addSubview(slider)
        
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
            make.top.equalTo(titleLabel.snp.top).offset(0)
//            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
        }
    }
    
    // MARK: - Configuration
    func configure(name: String, value: Float, range: ClosedRange<Float>, step: Float, valueChanged: @escaping (Float) -> Void) {
        titleLabel.text = name
        
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
    }
    
    private func updateValueLabel(_ value: Float) {
        // 根据值的范围调整显示的小数位数
        let format = abs(value) < 10 ? "%.2f" : "%.1f"
        valueLabel.text = String(format: format, value)
    }
} 
