//
//  SCParameterEditorView.swift
//  SparkCamera
//
//  单一职责：在预置滤镜位置显示单个参数的编辑 UI（标题 + 滑块）
//

import UIKit
import SnapKit

protocol SCParameterEditorViewDelegate: AnyObject {
    func parameterEditorView(_ view: SCParameterEditorView, didChange value: Float, for parameter: SCFilterParameter)
    func parameterEditorViewDidTapUndo(_ view: SCParameterEditorView, for parameter: SCFilterParameter)
    func parameterEditorViewDidTapRedo(_ view: SCParameterEditorView, for parameter: SCFilterParameter)
    func parameterEditorViewDidTapSavePreset(_ view: SCParameterEditorView)
}

final class SCParameterEditorView: UIView {
    weak var delegate: SCParameterEditorViewDelegate?
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private var slider: SCScaleSlider!
    private var currentParameter: SCFilterParameter?
    private let resetButton = UIButton(type: .system)
    private let savePresetButton = UIButton(type: .system)
    // 去除多余按钮，保留界面简洁
    private var isUpdatingFromOutside = false
    private var headerStack: UIStackView!
    private var controlsStack: UIStackView!
    private let sliderContainer = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 12
        clipsToBounds = true

        // 基本文字样式
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        // 移除“当前值”标签的显示（由滑块自带气泡显示即可）
        valueLabel.isHidden = true

        // 重置按钮
        resetButton.setTitle("重置", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        resetButton.layer.cornerRadius = 8
        resetButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        resetButton.addTarget(self, action: #selector(handleReset), for: .touchUpInside)

        // 保存预设按钮
        savePresetButton.setTitle("保存预设", for: .normal)
        savePresetButton.setTitleColor(.white, for: .normal)
        savePresetButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        savePresetButton.layer.cornerRadius = 8
        savePresetButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        savePresetButton.addTarget(self, action: #selector(handleSavePreset), for: .touchUpInside)

        // 顶部：标题 | (空白) | 重置 | 保存预设
        headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), resetButton, savePresetButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8
        addSubview(headerStack)
        headerStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.right.equalToSuperview().inset(12)
            make.height.equalTo(28)
        }
        resetButton.snp.makeConstraints { make in
            make.width.equalTo(56)
            make.height.equalTo(28)
        }
        savePresetButton.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(72)
            make.height.equalTo(28)
        }

        // 去掉 - / + / 撤销 / 重做，让位给刻度尺

        // 底部：滑块容器
        addSubview(sliderContainer)
        sliderContainer.backgroundColor = .clear
        sliderContainer.snp.makeConstraints { make in
            make.top.equalTo(headerStack.snp.bottom).offset(0)
            make.left.right.equalToSuperview().inset(8)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(0)
            make.height.greaterThanOrEqualTo(52)
        }
    }
    
    func configure(parameter: SCFilterParameter, currentValue: Float) {
        // 兼容旧接口：默认值沿用参数枚举默认值
        configure(parameter: parameter, currentValue: currentValue, defaultValue: parameter.defaultValue)
    }

    /// 支持传入默认值（用于“重置”与中心刻度对齐），例如当前图片的基线参数
    func configure(parameter: SCFilterParameter, currentValue: Float, defaultValue: Float) {
        currentParameter = parameter
        titleLabel.text = parameter.displayName

        slider?.removeFromSuperview()
        let config = SCScaleSliderConfig(minValue: parameter.minValue, maxValue: parameter.maxValue, step: parameter.step, defaultValue: defaultValue)
        slider = SCScaleSlider(config: config)
        slider.style = .Style.default.style
        sliderContainer.addSubview(slider)
        slider.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
            make.bottom.equalTo(0)
            make.top.equalTo(0)
        }
        slider.setValue(currentValue, animated: false)
        slider.valueChangedHandler = { [weak self] newValue in
            guard let self, let p = self.currentParameter else { return }
            if !self.isUpdatingFromOutside {
                self.delegate?.parameterEditorView(self, didChange: newValue, for: p)
            }
        }
    }

    @objc private func handleReset() {
        guard let slider = slider else { return }
        // 使用滑块配置中的 defaultValue 作为重置目标（由外部传入基线值）
        // 回调由 slider.valueChangedHandler 统一触发，避免重复通知
        slider.resetToDefault(animated: true)
    }

    @objc private func handleSavePreset() {
        delegate?.parameterEditorViewDidTapSavePreset(self)
    }

    @objc private func handleMinus() {
        guard let p = currentParameter else { return }
        let newValue = stepValue(delta: -p.step)
        setExternalValue(newValue)
        delegate?.parameterEditorView(self, didChange: newValue, for: p)
    }

    @objc private func handlePlus() {
        guard let p = currentParameter else { return }
        let newValue = stepValue(delta: p.step)
        setExternalValue(newValue)
        delegate?.parameterEditorView(self, didChange: newValue, for: p)
    }

    @objc private func handleUndo() {
        guard let p = currentParameter else { return }
        delegate?.parameterEditorViewDidTapUndo(self, for: p)
    }

    @objc private func handleRedo() {
        guard let p = currentParameter else { return }
        delegate?.parameterEditorViewDidTapRedo(self, for: p)
    }

    private func stepValue(delta: Float) -> Float {
        guard let p = currentParameter else { return 0 }
        let current = slider.currentValue
        let raw = current + delta
        let clamped = min(max(raw, p.minValue), p.maxValue)
        let steps = round((clamped - p.minValue) / p.step)
        let aligned = p.minValue + steps * p.step
        return aligned
    }

    private func updateValueLabel(_ value: Float) { /* 已移除单独的数值标签显示 */ }

    /// 外部设置值时避免递归回调
    func setExternalValue(_ value: Float) {
        isUpdatingFromOutside = true
        slider.setValue(value, animated: true)
        updateValueLabel(value)
        isUpdatingFromOutside = false
    }
}


