//
//  SCPhotoPreviewToolbar.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/18.
//
//  图片预览界面的底部工具栏，包含取消、编辑、分享和确认按钮

import UIKit
import SnapKit

protocol SCPhotoPreviewToolbarDelegate: AnyObject {
    func toolbarDidTapCancel(_ toolbar: SCPhotoPreviewToolbar)
    func toolbarDidTapEdit(_ toolbar: SCPhotoPreviewToolbar)
    func toolbarDidTapConfirm(_ toolbar: SCPhotoPreviewToolbar)
}

class SCPhotoPreviewToolbar: UIView {
    
    // MARK: - Properties
    weak var delegate: SCPhotoPreviewToolbarDelegate?
    private var cancelButton: UIButton!
    private var editButton: UIButton!
    private var confirmButton: UIButton!
    
    private var isEditingMode: Bool = false {
        didSet {
            updateButtonsForEditingMode()
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 取消按钮
        cancelButton = createButton(title: "取消", icon: UIImage(systemName: "xmark"))
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        addSubview(cancelButton)
        
        // 编辑按钮
        editButton = createButton(title: "编辑", icon: UIImage(systemName: "slider.horizontal.3"))
        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
        addSubview(editButton)
        
        // 确认按钮
        confirmButton = createButton(title: "完成", icon: UIImage(systemName: "checkmark"))
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        addSubview(confirmButton)
        
        // 使用 SnapKit 设置约束
        cancelButton.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(80)
            make.height.equalTo(60)  // 增加按钮高度
        }
        
        editButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(80)
            make.height.equalTo(60)  // 增加按钮高度
        }
        
        confirmButton.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(80)
            make.height.equalTo(60)  // 增加按钮高度
        }
    }
    
    private func createButton(title: String, icon: UIImage?) -> UIButton {
        let button = UIButton(type: .custom)  // 改为 custom 类型
        button.backgroundColor = .clear  // 清除背景色
        button.isUserInteractionEnabled = true  // 确保按钮可以接收事件
        
        // 创建垂直堆叠视图
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false  // 禁用堆栈视图的用户交互
        button.addSubview(stackView)
        
        // 添加图标
        if let icon = icon {
            let imageView = UIImageView(image: icon.withRenderingMode(.alwaysTemplate))  // 使用 template 模式
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = false  // 禁用图片视图的用户交互
            stackView.addArrangedSubview(imageView)
            
            imageView.snp.makeConstraints { make in
                make.width.height.equalTo(24)  // 增加图标大小
            }
        }
        
        // 添加标题
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)  // 增加字体大小
        label.isUserInteractionEnabled = false  // 禁用标签的用户交互
        stackView.addArrangedSubview(label)
        
        // 设置堆叠视图约束
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        // 添加触摸反馈
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }
    
    // MARK: - Public Methods
    func setEditingMode(_ editing: Bool) {
        isEditingMode = editing
    }
    
    private func updateButtonsForEditingMode() {
        // 移除所有按钮的子视图
        [cancelButton, editButton, confirmButton].forEach { button in
            button?.subviews.forEach { $0.removeFromSuperview() }
        }
        
        if isEditingMode {
            // 编辑模式下的按钮状态
            let cancelStack = createButtonStackView(title: "取消", icon: nil)
            let editStack = createButtonStackView(title: "编辑", icon: nil)
            let confirmStack = createButtonStackView(title: "保存", icon: nil)
            
            cancelButton.addSubview(cancelStack)
            editButton.addSubview(editStack)
            confirmButton.addSubview(confirmStack)
            
            cancelStack.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            editStack.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            confirmStack.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        } else {
            // 恢复原始状态
            let cancelStack = createButtonStackView(
                title: "取消",
                icon: UIImage(systemName: "xmark")?.withRenderingMode(.alwaysTemplate)
            )
            let editStack = createButtonStackView(
                title: "编辑",
                icon: UIImage(systemName: "slider.horizontal.3")?.withRenderingMode(.alwaysTemplate)
            )
            let confirmStack = createButtonStackView(
                title: "完成",
                icon: UIImage(systemName: "checkmark")?.withRenderingMode(.alwaysTemplate)
            )
            
            cancelButton.addSubview(cancelStack)
            editButton.addSubview(editStack)
            confirmButton.addSubview(confirmStack)
            
            cancelStack.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            editStack.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            confirmStack.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
    }
    
    private func createButtonStackView(title: String, icon: UIImage?) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        
        if let icon = icon {
            let imageView = UIImageView(image: icon)
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = false
            stackView.addArrangedSubview(imageView)
            
            imageView.snp.makeConstraints { make in
                make.width.height.equalTo(24)
            }
        }
        
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)
        label.isUserInteractionEnabled = false
        stackView.addArrangedSubview(label)
        
        return stackView
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        print("取消按钮被点击")  // 添加调试日志
        buttonTouchDown(cancelButton)
        delegate?.toolbarDidTapCancel(self)
    }
    
    @objc private func editButtonTapped() {
        print("编辑按钮被点击")  // 添加调试日志
        buttonTouchDown(editButton)
        delegate?.toolbarDidTapEdit(self)
    }
    
    @objc private func confirmButtonTapped() {
        print("完成按钮被点击")  // 添加调试日志
        buttonTouchDown(confirmButton)
        delegate?.toolbarDidTapConfirm(self)
    }
    
    @objc private func buttonTouchDown(_ button: UIButton) {
        // 添加触觉反馈
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
        
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            button.alpha = 0.7
        }
    }
    
    @objc private func buttonTouchUp(_ button: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            button.transform = .identity
            button.alpha = 1.0
        }
    }
} 
