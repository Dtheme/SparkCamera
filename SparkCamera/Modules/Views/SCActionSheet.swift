import UIKit
import SwiftMessages

class SCActionSheet {
    
    // MARK: - 数据模型
    struct Action {
        let title: String
        let icon: UIImage?
        let style: Style
        let handler: (() -> Void)?
        
        enum Style {
            case `default`
            case cancel
            case destructive
        }
    }
    
    // MARK: - 配置
    struct Config {
        let backgroundColor: UIColor
        let cornerRadius: CGFloat
        let buttonHeight: CGFloat
        let contentInsets: UIEdgeInsets
        let spacing: CGFloat
        let dimAlpha: CGFloat
        
        static let `default` = Config(
            backgroundColor: UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0),
            cornerRadius: 16,
            buttonHeight: 50,
            contentInsets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16),
            spacing: 12,
            dimAlpha: 0.6
        )
    }
    
    // MARK: - 属性
    private let config: Config
    private let customView: UIView?
    private var actions: [Action] = []
    
    // MARK: - 初始化
    init(customView: UIView? = nil, config: Config = .default) {
        self.customView = customView
        self.config = config
    }
    
    // MARK: - 公共方法
    func addAction(_ action: Action) {
        actions.append(action)
    }
    
    static func show(title: String? = nil, 
                    message: String? = nil, 
                    actions: [Action],
                    config: Config = .default) {
        let actionSheet = SCActionSheet(config: config)
        actions.forEach { actionSheet.addAction($0) }
        actionSheet.show(title: title, message: message)
    }
    
    // MARK: - 私有方法
    private func show(title: String?, message: String?) {
        let containerView = UIView()
        containerView.backgroundColor = config.backgroundColor
        containerView.layer.cornerRadius = config.cornerRadius
        containerView.clipsToBounds = true
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = config.spacing
        stackView.isUserInteractionEnabled = true
        
        // 添加标题和消息
        if let title = title {
            let titleLabel = createLabel(text: title, isBold: true)
            stackView.addArrangedSubview(titleLabel)
        }
        
        if let message = message {
            let messageLabel = createLabel(text: message, isBold: false)
            stackView.addArrangedSubview(messageLabel)
        }
        
        // 添加自定义视图
        if let customView = customView {
            stackView.addArrangedSubview(customView)
        }
        
        // 添加按钮
        actions.forEach { action in
            let button = createActionButton(action)
            stackView.addArrangedSubview(button)
        }
        
        containerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: config.contentInsets.top),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: config.contentInsets.left),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -config.contentInsets.right),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -config.contentInsets.bottom)
        ])
        
        // 配置 SwiftMessages
        var messageConfig = SwiftMessages.Config()
        messageConfig.presentationStyle = .bottom
        messageConfig.duration = .forever
        messageConfig.dimMode = .gray(interactive: true)
        messageConfig.interactiveHide = true
        messageConfig.preferredStatusBarStyle = .lightContent
        
        DispatchQueue.main.async {
            SwiftMessages.show(config: messageConfig, view: containerView)
        }
    }
    
    private func createActionButton(_ action: Action) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.heightAnchor.constraint(equalToConstant: config.buttonHeight).isActive = true
        
        // 创建内容容器
        let contentStack = UIStackView()
        contentStack.axis = .horizontal
        contentStack.spacing = 8
        contentStack.alignment = .center
        contentStack.isUserInteractionEnabled = false
        
        // 添加图标
        if let icon = action.icon {
            let imageView = UIImageView(image: icon.withRenderingMode(.alwaysTemplate))
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = getTintColor(for: action.style)
            contentStack.addArrangedSubview(imageView)
            
            imageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        }
        
        // 添加标题
        let titleLabel = UILabel()
        titleLabel.text = action.title
        titleLabel.textColor = getTintColor(for: action.style)
        titleLabel.font = .systemFont(ofSize: 17)
        contentStack.addArrangedSubview(titleLabel)
        
        button.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        // 添加点击效果
        let highlightView = UIView()
        highlightView.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        highlightView.isHidden = true
        button.insertSubview(highlightView, at: 0)
        
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            highlightView.topAnchor.constraint(equalTo: button.topAnchor),
            highlightView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            highlightView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        // 使用闭包处理按钮事件
        button.addAction(UIAction { [weak self] _ in
            // 点击效果
            highlightView.isHidden = true
            
            // 触觉反馈
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.prepare()
            feedback.impactOccurred()
            
            // 执行操作
            DispatchQueue.main.async {
                SwiftMessages.hide()
                action.handler?()
            }
        }, for: .touchUpInside)
        
        // 按下效果
        button.addAction(UIAction { _ in
            highlightView.isHidden = false
        }, for: .touchDown)
        
        // 取消效果
        button.addAction(UIAction { _ in
            highlightView.isHidden = true
        }, for: .touchUpOutside)
        
        return button
    }
    
    private func getTintColor(for style: Action.Style) -> UIColor {
        switch style {
        case .default:
            return .white
        case .cancel:
            return .lightGray
        case .destructive:
            return .systemRed
        }
    }
    
    private func createLabel(text: String, isBold: Bool) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = isBold ? .boldSystemFont(ofSize: 17) : .systemFont(ofSize: 15)
        return label
    }
} 
    
