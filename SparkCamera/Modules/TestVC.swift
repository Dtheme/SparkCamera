//
//  TestVC.swift
//  SparkCamera
//
//  Created by [Your Name] on [Date].
//

import UIKit
import SnapKit

class TestVC: UIViewController {
    
    // MARK: - UI Components
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "相机实验室"
        label.textColor = .black
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.text = "当前值：0.0"
        label.textColor = .black
        label.font = .systemFont(ofSize: 18)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var scaleSlider: SCScaleSlider = {
        let config = SCScaleSliderConfig(minValue: -2.0,
                                       maxValue: 2.0,
                                       step: 0.1,
                                       defaultValue: 0.0)
        let slider = SCScaleSlider(config: config)
        slider.style = .Style.default.style
        slider.backgroundColor = UIColor.orange.withAlphaComponent(0.1)
        return slider
    }()
    
    private lazy var styleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private lazy var defaultStyleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("默认", for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(defaultStyleTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var darkStyleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("暗色", for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(darkStyleTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var verticalStyleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("竖条", for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(verticalStyleTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(valueLabel)
        view.addSubview(scaleSlider)
        view.addSubview(styleStackView)
        
        styleStackView.addArrangedSubview(defaultStyleButton)
        styleStackView.addArrangedSubview(darkStyleButton)
        styleStackView.addArrangedSubview(verticalStyleButton)
    }
    
    private func setupConstraints() {
        closeButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.width.height.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(40)
        }
        
        scaleSlider.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(valueLabel.snp.bottom).offset(40)
            make.height.equalTo(60)
        }
        
        styleStackView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.top.equalTo(scaleSlider.snp.bottom).offset(40)
            make.height.equalTo(44)
        }
    }
    
    private func setupActions() {
        scaleSlider.valueChangedHandler = { [weak self] value in
            self?.valueLabel.text = String(format: "当前值：%.1f", value)
        }
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func defaultStyleTapped() {
        scaleSlider.style = .Style.default.style
        updateButtonStates(selectedButton: defaultStyleButton)
    }
    
    @objc private func darkStyleTapped() {
        scaleSlider.style = .Style.dark.style
        updateButtonStates(selectedButton: darkStyleButton)
    }
    
    @objc private func verticalStyleTapped() {
        scaleSlider.style = .Style.vertical.style
        updateButtonStates(selectedButton: verticalStyleButton)
    }
    
    private func updateButtonStates(selectedButton: UIButton) {
        [defaultStyleButton, darkStyleButton, verticalStyleButton].forEach { button in
            button.backgroundColor = button == selectedButton ? .systemBlue : .systemGray6
            button.setTitleColor(button == selectedButton ? .white : .systemBlue, for: .normal)
        }
    }
} 
