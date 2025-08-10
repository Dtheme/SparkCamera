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
}

final class SCParameterEditorView: UIView {
    weak var delegate: SCParameterEditorViewDelegate?
    private let titleLabel = UILabel()
    private var slider: SCScaleSlider!
    private var currentParameter: SCFilterParameter?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 12
        clipsToBounds = true
        
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(24)
        }
    }
    
    func configure(parameter: SCFilterParameter, currentValue: Float) {
        currentParameter = parameter
        titleLabel.text = parameter.displayName
        
        slider?.removeFromSuperview()
        let config = SCScaleSliderConfig(minValue: parameter.minValue, maxValue: parameter.maxValue, step: parameter.step, defaultValue: parameter.defaultValue)
        slider = SCScaleSlider(config: config)
        slider.style = .Style.default.style
        addSubview(slider)
        slider.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-12)
            make.height.equalTo(60)
        }
        slider.setValue(currentValue, animated: false)
        slider.valueChangedHandler = { [weak self] newValue in
            guard let self, let p = self.currentParameter else { return }
            self.delegate?.parameterEditorView(self, didChange: newValue, for: p)
        }
    }
}


