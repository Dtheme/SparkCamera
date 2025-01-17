import UIKit
import SwiftMessages

class SCActionSheet {
    
    // MARK: - Static Properties
    private static var activeInstances: [SCActionSheet] = []
    
    // MARK: - Action
    struct Action {
        let title: String
        let icon: UIImage?
        let style: Style
        let handler: (() -> Void)?
        
        var description: String {
            return "Action(title: \(title), style: \(style), hasIcon: \(icon != nil))"
        }
        
        enum Style {
            case `default`
            case cancel
            case destructive
            
            var textColor: UIColor {
                switch self {
                case .default:
                    return .white
                case .cancel:
                    return .gray
                case .destructive:
                    return .red
                }
            }
            
            var backgroundColor: UIColor {
                switch self {
                case .default, .cancel:
                    return .clear
                case .destructive:
                    return UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.1)
                }
            }
        }
        
        init(title: String, icon: UIImage? = nil, style: Style = .default, handler: (() -> Void)? = nil) {
            self.title = title
            self.icon = icon
            self.style = style
            self.handler = handler
        }
    }
    
    // MARK: - Properties
    private let title: String?
    private let message: String?
    private let customView: UIView?
    private var actions: [Action] = []
    private var config: Config
    
    // MARK: - Config
    struct Config {
        var backgroundColor: UIColor
        var cornerRadius: CGFloat
        var buttonHeight: CGFloat
        var contentInset: UIEdgeInsets
        var spacing: CGFloat
        var dimColor: UIColor
        var dimAlpha: CGFloat
        var animation: Animation
        
        enum Animation {
            case slide
            case fade
            case scale
            
            var duration: TimeInterval {
                switch self {
                case .slide: return 0.3
                case .fade: return 0.25
                case .scale: return 0.2
                }
            }
        }
        
        static var `default`: Config {
            Config(
                backgroundColor: UIColor(white: 0.2, alpha: 1.0),
                cornerRadius: 12,
                buttonHeight: 56,
                contentInset: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16),
                spacing: 8,
                dimColor: .black,
                dimAlpha: 0.5,
                animation: .slide
            )
        }
    }
    
    // MARK: - Initialization
    init(title: String? = nil, message: String? = nil, customView: UIView? = nil, config: Config = .default) {
        self.title = title
        self.message = message
        self.customView = customView
        self.config = config
    }
    
    func addAction(_ action: Action) {
        actions.append(action)
    }
    
    func show() {
        print("\n📱 [ActionSheet] 开始显示")
        print("📱 [ActionSheet] - 标题: \(title ?? "无")")
        print("📱 [ActionSheet] - 消息: \(message ?? "无")")
        print("📱 [ActionSheet] - 动作数量: \(actions.count)")
        actions.forEach { action in
            print("📱 [ActionSheet] - 动作: \(action.description)")
        }
        
        // 将当前实例添加到活动实例数组中
        SCActionSheet.activeInstances.append(self)
        print("📱 [ActionSheet] 当前活动实例数量: \(SCActionSheet.activeInstances.count)")
        
        let view = createActionSheetView()
        
        var config = SwiftMessages.Config()
        config.presentationStyle = .bottom
        config.presentationContext = .window(windowLevel: .normal)
        config.duration = .forever
        config.dimMode = .gray(interactive: true)
        config.interactiveHide = true
        config.preferredStatusBarStyle = .lightContent
        
        switch self.config.animation {
        case .slide:
            config.presentationStyle = .bottom
        case .fade:
            config.presentationStyle = .center
        case .scale:
            config.presentationStyle = .center
        }
        
        // 添加消失回调
        config.eventListeners.append { event in
            if case .didHide = event {
                // 从活动实例数组中移除
                if let index = SCActionSheet.activeInstances.firstIndex(where: { $0 === self }) {
                    SCActionSheet.activeInstances.remove(at: index)
                }
            }
        }
        
        DispatchQueue.main.async {
            SwiftMessages.show(config: config, view: view)
        }
    }
    
    // MARK: - View Creation
    private func createActionSheetView() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = config.backgroundColor
        containerView.layer.cornerRadius = config.cornerRadius
        containerView.clipsToBounds = true
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = config.spacing
        containerView.addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: config.contentInset.top),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: config.contentInset.left),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -config.contentInset.right),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -config.contentInset.bottom)
        ])
        
        // 添加标题
        if let title = title {
            let titleLabel = createLabel(text: title, style: .title)
            stackView.addArrangedSubview(titleLabel)
        }
        
        // 添加消息
        if let message = message {
            let messageLabel = createLabel(text: message, style: .message)
            stackView.addArrangedSubview(messageLabel)
        }
        
        // 添加自定义视图
        if let customView = customView {
            stackView.addArrangedSubview(customView)
        }
        
        // 如果有标题、消息或自定义视图，添加分隔线
        if title != nil || message != nil || customView != nil {
            addSeparator(to: stackView)
        }
        
        // 添加操作按钮
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 1
        stackView.addArrangedSubview(buttonStackView)
        
        // 先添加非取消按钮
        let normalActions = actions.filter { $0.style != .cancel }
        for (index, action) in normalActions.enumerated() {
            let button = createActionButton(action)
            buttonStackView.addArrangedSubview(button)
            
            if index < normalActions.count - 1 {
                addSeparator(to: buttonStackView, color: UIColor(white: 1.0, alpha: 0.1))
            }
        }
        
        // 添加取消按钮（如果有）
        let cancelActions = actions.filter { $0.style == .cancel }
        if !cancelActions.isEmpty {
            // 添加间隔
            let spacer = UIView()
            spacer.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            stackView.addArrangedSubview(spacer)
            
            // 添加取消按钮
            for (index, action) in cancelActions.enumerated() {
                let button = createActionButton(action)
                stackView.addArrangedSubview(button)
                
                if index < cancelActions.count - 1 {
                    addSeparator(to: stackView)
                }
            }
        }
        
        return containerView
    }
    
    private func createLabel(text: String, style: LabelStyle) -> UIView {
        let container = UIView()
        
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        
        switch style {
        case .title:
            label.font = .systemFont(ofSize: 16, weight: .medium)
            label.textColor = .white
        case .message:
            label.font = .systemFont(ofSize: 14)
            label.textColor = .lightGray
        }
        
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        return container
    }
    
    private enum LabelStyle {
        case title
        case message
    }
    
    private func createActionButton(_ action: Action) -> UIView {
        print("\n🔘 [ActionSheet] 创建按钮")
        print("🔘 [ActionSheet] - 标题: \(action.title)")
        print("🔘 [ActionSheet] - 样式: \(action.style)")
        print("🔘 [ActionSheet] - 是否有图标: \(action.icon != nil)")
        
        let container = UIView()
        container.backgroundColor = action.style.backgroundColor
        container.isUserInteractionEnabled = true
        
        // 创建水平堆叠视图来容纳图标和标题
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.isUserInteractionEnabled = false  // 禁用堆栈视图的事件响应
        container.addSubview(stackView)
        
        // 如果有图标，添加图标视图
        if let icon = action.icon {
            let iconView = UIImageView(image: icon.withRenderingMode(.alwaysTemplate))
            iconView.tintColor = action.style.textColor
            iconView.contentMode = .scaleAspectFit
            iconView.isUserInteractionEnabled = false  // 禁用图标的事件响应
            stackView.addArrangedSubview(iconView)
            
            // 设置图标大小约束
            iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        }
        
        // 添加标题标签
        let titleLabel = UILabel()
        titleLabel.text = action.title
        titleLabel.textColor = action.style.textColor
        titleLabel.font = action.style == .cancel ? 
            .systemFont(ofSize: 16, weight: .medium) : 
            .systemFont(ofSize: 16)
        titleLabel.isUserInteractionEnabled = false  // 禁用标签的事件响应
        stackView.addArrangedSubview(titleLabel)
        
        // 设置堆叠视图约束
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: config.buttonHeight)
        ])
        
        // 添加点击效果
        let highlightView = UIView()
        highlightView.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        highlightView.isHidden = true
        container.insertSubview(highlightView, at: 0)
        
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            highlightView.topAnchor.constraint(equalTo: container.topAnchor),
            highlightView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            highlightView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        container.addGestureRecognizer(tapGesture)
        print("🔘 [ActionSheet] - 添加点击手势")
        
        // 存储 action 和 highlightView 的引用
        objc_setAssociatedObject(container, AssociatedKeys.actionKey, action, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(container, AssociatedKeys.highlightViewKey, highlightView, .OBJC_ASSOCIATION_RETAIN)
        print("🔘 [ActionSheet] - 设置关联对象完成")
        
        return container
    }
    
    private func addSeparator(to stackView: UIStackView, color: UIColor = UIColor(white: 1.0, alpha: 0.1)) {
        let separator = UIView()
        separator.backgroundColor = color
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separator)
    }
    
    // MARK: - Action Handling
    private struct AssociatedKeys {
        static let actionKey = UnsafeRawPointer(bitPattern: "com.sparkcamera.actionsheet.action".hashValue)!
        static let highlightViewKey = UnsafeRawPointer(bitPattern: "com.sparkcamera.actionsheet.highlight".hashValue)!
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        print("\n👆 [ActionSheet] 点击事件触发")
        
        guard let container = gesture.view else {
            print("⚠️ [ActionSheet] 无法获取手势视图")
            return
        }
        
        // 获取关联的 action 和 highlightView
        guard let action = objc_getAssociatedObject(container, AssociatedKeys.actionKey) as? Action else {
            print("⚠️ [ActionSheet] 无法获取关联的 Action 对象")
            return
        }
        
        guard let highlightView = objc_getAssociatedObject(container, AssociatedKeys.highlightViewKey) as? UIView else {
            print("⚠️ [ActionSheet] 无法获取关联的 HighlightView 对象")
            return
        }
        
        print("✅ [ActionSheet] 成功获取关联对象")
        print("✅ [ActionSheet] - 动作标题: \(action.title)")
        print("✅ [ActionSheet] - 动作样式: \(action.style)")
        
        // 添加触觉反馈
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
        print("✅ [ActionSheet] 触发触觉反馈")
        
        // 显示点击效果
        highlightView.isHidden = false
        print("✅ [ActionSheet] 开始动画效果")
        
        UIView.animate(withDuration: 0.1, animations: {
            container.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                container.transform = .identity
                highlightView.isHidden = true
            }) { _ in
                // 先执行操作
                if let handler = action.handler {
                    print("✅ [ActionSheet] 执行操作处理器: \(action.title)")
                    DispatchQueue.main.async {
                        handler()
                        print("✅ [ActionSheet] 操作处理器执行完成: \(action.title)")
                    }
                } else {
                    print("⚠️ [ActionSheet] 操作处理器为空: \(action.title)")
                }
                
                // 然后关闭 ActionSheet
                DispatchQueue.main.async {
                    print("🔄 [ActionSheet] 准备关闭菜单")
                    SwiftMessages.hide()
                    print("🔄 [ActionSheet] 菜单关闭命令已发送")
                }
            }
        }
    }
}

// MARK: - Convenience Methods
extension SCActionSheet {
    static func show(
        title: String? = nil,
        message: String? = nil,
        customView: UIView? = nil,
        config: Config = .default,
        actions: [Action]
    ) {
        let actionSheet = SCActionSheet(title: title, message: message, customView: customView, config: config)
        actions.forEach { actionSheet.addAction($0) }
        actionSheet.show()
    }
} 