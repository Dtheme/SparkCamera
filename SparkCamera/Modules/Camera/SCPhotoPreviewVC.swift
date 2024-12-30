import UIKit
import SwiftMessages

class SCPhotoPreviewVC: UIViewController {
    
    private var imageView: UIImageView!
    private var image: UIImage
    private var blurEffectView: UIVisualEffectView!
    
    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBackground()
        setupImageView()
        setupButtons()
        animateAppearance()
    }
    
    private func setupBackground() {
        let blurEffect = UIBlurEffect(style: .dark)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        view.addSubview(blurEffectView)
    }
    
    private func setupImageView() {
        imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 10
        imageView.clipsToBounds = true
        view.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7)
        ])
    }
    
    private func setupButtons() {
        let confirmButton = createButton(withTitle: "确认", iconName: "checkmark.circle")
        confirmButton.addTarget(self, action: #selector(confirm), for: .touchUpInside)
        
        let cancelButton = createButton(withTitle: "取消", iconName: "xmark.circle")
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        
        let editButton = createButton(withTitle: "编辑", iconName: "pencil.circle")
        editButton.addTarget(self, action: #selector(edit), for: .touchUpInside)
        
        let stackView = UIStackView(arrangedSubviews: [cancelButton, editButton, confirmButton])
        stackView.axis = .horizontal
        stackView.spacing = 20
        stackView.distribution = .fillEqually
        view.addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stackView.heightAnchor.constraint(equalToConstant: 60),
            stackView.widthAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    private func createButton(withTitle title: String, iconName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.setImage(UIImage(systemName: iconName), for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 30
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.5
        button.layer.shadowRadius = 4
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -10, bottom: 0, right: 0)
        return button
    }
    
    private func animateAppearance() {
        view.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1
        }
    }
    
    @objc private func confirm() {
        // 保存照片到相册
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func cancel() {
        // 取消操作
        dismiss(animated: true)
    }
    
    @objc private func edit() {
        // 显示编辑功能提示
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.info)
        view.configureContent(title: "提示", body: "后续会开发滤镜等图片编辑操作")
        SwiftMessages.show(view: view)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // 显示错误信息
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.error)
            view.configureContent(title: "错误", body: error.localizedDescription)
            SwiftMessages.show(view: view)
        } else {
            // 显示成功信息并关闭页面
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.success)
            view.configureContent(title: "成功", body: "照片已保存到相册")
            SwiftMessages.show(view: view)
            
            // 触觉反馈
            let feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator.notificationOccurred(.success)
            
            dismiss(animated: true)
        }
    }
} 