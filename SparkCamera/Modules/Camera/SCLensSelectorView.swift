//
//  SCLensSelectorView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/14.
//

import UIKit
import SnapKit

class SCLensSelectorView: UIView {
    
    private var lensOptions: [SCLensModel] = []
    private var buttons: [UIButton] = []
    private let stackView = UIStackView()
    private let blurEffectView: UIVisualEffectView
    
    var onLensSelected: ((String) -> Void)?
    
    override init(frame: CGRect) {
        let blurEffect = UIBlurEffect(style: .light)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        let blurEffect = UIBlurEffect(style: .light)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.backgroundColor = UIColor.clear
        self.layer.cornerRadius = 20
        self.clipsToBounds = true
        
        // 添加高斯模糊效果
        blurEffectView.layer.cornerRadius = 20
        blurEffectView.clipsToBounds = true
        addSubview(blurEffectView)
        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 确保 translatesAutoresizingMaskIntoConstraints 被设置为 false
        translatesAutoresizingMaskIntoConstraints = false
        
        // 设置 stackView
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        addSubview(stackView)
        
        // 使用 SnapKit 设置约束
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
        }
        
        // 设置明确的宽度和高度约束
        snp.makeConstraints { make in
            make.height.equalTo(50)
            make.width.equalTo(200)
        }
    }
    
    func updateLensOptions(_ options: [SCLensModel], currentLens: SCLensModel?) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        
        for option in options {
            let button = UIButton(type: .system)
            button.setTitle(option.name, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.profont(ofSize: 16)
            button.backgroundColor = .clear
            button.layer.cornerRadius = 15
            button.addTarget(self, action: #selector(lensButtonTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        // 根据当前镜头状态设置默认选中
        if let currentLens = currentLens, let index = options.firstIndex(where: { $0.name == currentLens.name }) {
            selectButton(buttons[index])
        } else if let firstButton = buttons.first {
            selectButton(firstButton)
        }
    }
    
    @objc private func lensButtonTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        
        // 触觉反馈
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
        
        // 动画效果
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            sender.setTitleColor(SCConstants.themeColor, for: .normal)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }
        
        // 高亮选中按钮
        selectButton(sender)
        
        onLensSelected?(title)
    }
    
    private func selectButton(_ button: UIButton) {
        buttons.forEach { $0.setTitleColor(.white, for: .normal) }
        button.setTitleColor(SCConstants.themeColor, for: .normal)
    }

} 
