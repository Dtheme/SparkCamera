import UIKit
import SwiftMessages
import SnapKit

@MainActor
class SCAlert {
    
    enum AlertStyle {
        case warning
        case success
        case info
        case error
    }
    
    static func show(
        title: String,
        message: String,
        style: AlertStyle = .warning,
        cancelTitle: String = "取消",
        confirmTitle: String = "确定",
        completion: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            // 创建自定义视图
            let view = MessageView.viewFromNib(layout: .cardView)
            
            // 配置主题和背景
            view.configureTheme(.info)
            view.backgroundColor = .clear
            view.iconImageView?.isHidden = true
            view.iconLabel?.isHidden = true
            view.backgroundView.backgroundColor = SCConstants.themeColor

            // 配置内容
            view.configureContent(title: title, body: message)
            view.button?.isHidden = true
            
            // 配置标题样式
            view.titleLabel?.textAlignment = .center
            view.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            view.titleLabel?.textColor = UIColor.white
            view.titleLabel?.numberOfLines = 0
            
            // 配置内容样式
            view.bodyLabel?.textAlignment = .center
            view.bodyLabel?.font = .systemFont(ofSize: 14)
            view.bodyLabel?.textColor = UIColor.white.withAlphaComponent(0.9)
            view.bodyLabel?.numberOfLines = 0
            
            // 创建内容容器
            let contentStackView = UIStackView()
            contentStackView.axis = .vertical
            contentStackView.spacing = 8
            contentStackView.alignment = .center
            view.backgroundView.addSubview(contentStackView)
            
            if let titleLabel = view.titleLabel {
                contentStackView.addArrangedSubview(titleLabel)
            }
            if let bodyLabel = view.bodyLabel {
                contentStackView.addArrangedSubview(bodyLabel)
            }
            
            // 添加分割线
            let separator = UIView()
            separator.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            view.backgroundView.addSubview(separator)
            
            // 添加自定义按钮容器
            let buttonsView = UIStackView()
            buttonsView.axis = .horizontal
            buttonsView.distribution = .fillEqually
            buttonsView.alignment = .fill
            buttonsView.spacing = 0.5
            buttonsView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            view.backgroundView.addSubview(buttonsView)
            
            // 取消按钮
            let cancelButton = UIButton(type: .system)
            cancelButton.setTitle(cancelTitle, for: .normal)
            cancelButton.setTitleColor(SCConstants.themeColor, for: .normal)
            cancelButton.titleLabel?.font = .systemFont(ofSize: 16)
            cancelButton.backgroundColor = .white
            cancelButton.addAction(.init(handler: { _ in
                Task { @MainActor in
                    SwiftMessages.hide()
                    completion(false)
                }
            }), for: .touchUpInside)
            
            // 确认按钮
            let confirmButton = UIButton(type: .system)
            confirmButton.setTitle(confirmTitle, for: .normal)
            confirmButton.setTitleColor(SCConstants.themeColor, for: .normal)
            confirmButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            confirmButton.backgroundColor = .white
            confirmButton.addAction(.init(handler: { _ in
                Task { @MainActor in
                    SwiftMessages.hide()
                    completion(true)
                }
            }), for: .touchUpInside)
            
            // 添加按钮到按钮容器（如果取消文案为空，仅居中显示“确定”按钮）
            let hasCancel = !cancelTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasCancel {
                buttonsView.distribution = .fillEqually
                buttonsView.alignment = .fill
                buttonsView.addArrangedSubview(cancelButton)
                buttonsView.addArrangedSubview(confirmButton)
            } else {
                buttonsView.distribution = .equalCentering
                buttonsView.alignment = .center
                buttonsView.addArrangedSubview(confirmButton)
                // 适度设置确认按钮宽度，便于视觉居中
                confirmButton.snp.makeConstraints { make in
                    make.width.greaterThanOrEqualTo(120)
                }
            }
            
            // 使用 SnapKit 设置约束
            contentStackView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(16)
                make.leading.trailing.equalToSuperview().inset(16)
            }
            
            separator.snp.makeConstraints { make in
                make.top.equalTo(contentStackView.snp.bottom).offset(16)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(0.5)
            }
            
            buttonsView.snp.makeConstraints { make in
                make.top.equalTo(separator.snp.bottom)
                make.leading.trailing.bottom.equalToSuperview()
                make.height.equalTo(44)
            }
            
            // 设置最大宽度
            view.backgroundView.snp.makeConstraints { make in
                make.width.lessThanOrEqualTo(270)
            }
            
            // 配置显示参数
            var config = SwiftMessages.defaultConfig
            config.presentationStyle = .center
            config.duration = .forever
            config.dimMode = .gray(interactive: false)
            config.interactiveHide = false
            config.preferredStatusBarStyle = .default
            
            // 显示弹窗
            SwiftMessages.show(config: config, view: view)
        }
     }

     /// 显示带输入框的弹窗
     /// - Parameters:
     ///   - title: 标题
     ///   - message: 副标题/说明
     ///   - placeholder: 输入占位
     ///   - defaultText: 默认文本
     ///   - cancelTitle: 取消按钮标题
     ///   - confirmTitle: 确认按钮标题
     ///   - completion: 回调 (确认/取消, 文本)
     static func promptForText(
         title: String,
         message: String,
         placeholder: String = "请输入名称",
         defaultText: String? = nil,
         cancelTitle: String = "取消",
         confirmTitle: String = "保存",
         completion: @escaping (Bool, String?) -> Void
      ) {
         Task { @MainActor in
             let view = MessageView.viewFromNib(layout: .cardView)
             view.configureTheme(.info)
             view.backgroundColor = .clear
             view.iconImageView?.isHidden = true
             view.iconLabel?.isHidden = true
             view.backgroundView.backgroundColor = SCConstants.themeColor

             view.configureContent(title: title, body: message)
             view.button?.isHidden = true

             view.titleLabel?.textAlignment = .center
             view.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
             view.titleLabel?.textColor = UIColor.white
             view.titleLabel?.numberOfLines = 0

             view.bodyLabel?.textAlignment = .center
             view.bodyLabel?.font = .systemFont(ofSize: 14)
             view.bodyLabel?.textColor = UIColor.white.withAlphaComponent(0.9)
             view.bodyLabel?.numberOfLines = 0

             // 容器
             let contentStackView = UIStackView()
             contentStackView.axis = .vertical
             contentStackView.spacing = 12
             contentStackView.alignment = .fill
             view.backgroundView.addSubview(contentStackView)

             if let titleLabel = view.titleLabel { contentStackView.addArrangedSubview(titleLabel) }
             if let bodyLabel = view.bodyLabel { contentStackView.addArrangedSubview(bodyLabel) }

             // 输入框
             let textField = UITextField()
             textField.placeholder = placeholder
             textField.text = defaultText
             textField.clearButtonMode = .whileEditing
             textField.borderStyle = .roundedRect
             textField.backgroundColor = .white
             textField.textColor = SCConstants.themeColor
             textField.returnKeyType = .done
             contentStackView.addArrangedSubview(textField)

             // 分割线
             let separator = UIView()
             separator.backgroundColor = UIColor.white.withAlphaComponent(0.2)
             view.backgroundView.addSubview(separator)

             // 按钮容器
             let buttonsView = UIStackView()
             buttonsView.axis = .horizontal
             buttonsView.distribution = .fillEqually
             buttonsView.spacing = 0.5
             buttonsView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
             view.backgroundView.addSubview(buttonsView)

             let cancelButton = UIButton(type: .system)
             cancelButton.setTitle(cancelTitle, for: .normal)
             cancelButton.setTitleColor(SCConstants.themeColor, for: .normal)
             cancelButton.titleLabel?.font = .systemFont(ofSize: 16)
             cancelButton.backgroundColor = .white
             cancelButton.addAction(.init(handler: { _ in
                 Task { @MainActor in
                     SwiftMessages.hide()
                     completion(false, nil)
                 }
             }), for: .touchUpInside)

             let confirmButton = UIButton(type: .system)
             confirmButton.setTitle(confirmTitle, for: .normal)
             confirmButton.setTitleColor(SCConstants.themeColor, for: .normal)
             confirmButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
             confirmButton.backgroundColor = .white
             confirmButton.addAction(.init(handler: { _ in
                 Task { @MainActor in
                     SwiftMessages.hide()
                     let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                     completion(true, text.isEmpty ? nil : text)
                 }
             }), for: .touchUpInside)

             buttonsView.addArrangedSubview(cancelButton)
             buttonsView.addArrangedSubview(confirmButton)

             // 约束
             contentStackView.snp.makeConstraints { make in
                 make.top.equalToSuperview().offset(16)
                 make.leading.trailing.equalToSuperview().inset(16)
             }
             textField.snp.makeConstraints { make in
                 make.height.equalTo(36)
             }
             separator.snp.makeConstraints { make in
                 make.top.equalTo(contentStackView.snp.bottom).offset(16)
                 make.leading.trailing.equalToSuperview()
                 make.height.equalTo(0.5)
             }
             buttonsView.snp.makeConstraints { make in
                 make.top.equalTo(separator.snp.bottom)
                 make.leading.trailing.bottom.equalToSuperview()
                 make.height.greaterThanOrEqualTo(44)
             }
             view.backgroundView.snp.makeConstraints { make in
                 make.width.lessThanOrEqualTo(320)
             }

             var config = SwiftMessages.defaultConfig
             config.presentationStyle = .center
             config.duration = .forever
             config.dimMode = .gray(interactive: false)
             config.interactiveHide = false
             config.preferredStatusBarStyle = .default
             SwiftMessages.show(config: config, view: view)
          }
      }
    }
 
