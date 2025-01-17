//
//  SCPhotoPreviewVC.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/14.
//

import UIKit
import SwiftMessages
import SnapKit

@objc class SCPhotoPreviewVC: UIViewController {
    
    // MARK: - Properties
    private let image: UIImage
    private let photoInfo: SCPhotoInfo
    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    private var blurEffectView: UIVisualEffectView!
    private var buttonsStackView: UIStackView!
    private var isStatusBarHidden = false
    private var initialTouchPoint: CGPoint = .zero
    private var progressView: UIProgressView!
    
    // MARK: - Initialization
    init(image: UIImage, photoInfo: SCPhotoInfo) {
        self.image = image
        self.photoInfo = photoInfo
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        animateAppearance()
    }
    
    override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        setupBackground()
        setupScrollView()
        setupImageView()
        setupButtons()
        setupMetadataLabels()
        setupProgressView()
    }
    
    private func setupBackground() {
        let blurEffect = UIBlurEffect(style: .dark)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurEffectView)
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupImageView() {
        imageView = UIImageView(image: image)
//        imageView.contentMode = .scaleAspectFit
//        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        updateImageViewConstraints()
    }
    
    private func updateImageViewConstraints() {
        // 移除现有约束
        imageView.snp.removeConstraints()
        
        // 获取屏幕尺寸
        let screenSize = UIScreen.main.bounds.size
        
        print("📸 [Preview] 图片信息:")
        print(photoInfo.description)
        
        // 计算图片在屏幕上的显示尺寸
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        
        // 计算屏幕和图片的宽高比
        let screenRatio = screenSize.width / screenSize.height
        let imageRatio = photoInfo.width / photoInfo.height
        
        // 根据图片方向和屏幕方向来决定显示尺寸
        if imageRatio > screenRatio {
            // 图片比例比屏幕更宽，以屏幕宽度为基准
            displayWidth = screenSize.width
            displayHeight = screenSize.width * (photoInfo.height / photoInfo.width)
        } else {
            // 图片比例比屏幕更高，以屏幕高度为基准
            displayHeight = screenSize.height
            displayWidth = screenSize.height * (photoInfo.width / photoInfo.height)
        }
        
        print("📸 [Preview] 显示尺寸:")
        print("📸 [Preview] - 宽度: \(displayWidth)")
        print("📸 [Preview] - 高度: \(displayHeight)")
        
        // 使用 SnapKit 设置约束
        imageView.snp.makeConstraints { make in
            make.width.equalTo(displayWidth)
            make.height.equalTo(displayHeight)
            make.center.equalTo(scrollView)
        }
        
        // 更新滚动视图的内容大小
        scrollView.contentSize = CGSize(width: displayWidth, height: displayHeight)
        
        // 设置最小/最大缩放比例
        let minScale = min(screenSize.width / displayWidth, screenSize.height / displayHeight)
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = 4.0 // 允许放大到4倍
        
        // 初始缩放以适应屏幕
        scrollView.zoomScale = minScale
    }
    
    private func setupButtons() {
        let confirmButton = createButton(withTitle: "确认", iconName: "checkmark.circle.fill")
        confirmButton.addTarget(self, action: #selector(confirm), for: .touchUpInside)
        
        let cancelButton = createButton(withTitle: "取消", iconName: "xmark.circle.fill")
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        
        let editButton = createButton(withTitle: "编辑", iconName: "slider.horizontal.3")
        editButton.addTarget(self, action: #selector(edit), for: .touchUpInside)
        
        let shareButton = createButton(withTitle: "分享", iconName: "square.and.arrow.up")
        shareButton.addTarget(self, action: #selector(share), for: .touchUpInside)
        
        buttonsStackView = UIStackView(arrangedSubviews: [cancelButton, editButton, shareButton, confirmButton])
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 20
        buttonsStackView.distribution = .fillEqually
        view.addSubview(buttonsStackView)
        
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            buttonsStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonsStackView.heightAnchor.constraint(equalToConstant: 60),
            buttonsStackView.widthAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    private func setupMetadataLabels() {
        let metadataView = UIView()
        metadataView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.addSubview(metadataView)
        
        let resolutionLabel = UILabel()
        resolutionLabel.text = String(format: "%.0f × %.0f", image.size.width, image.size.height)
        resolutionLabel.textColor = .white
        resolutionLabel.font = .systemFont(ofSize: 12)
        
        let ratioLabel = UILabel()
        // 根据宽高比显示标准比例格式
        let ratio = photoInfo.aspectRatio
        let ratioText: String
        if abs(ratio - 1.0) < 0.01 {
            ratioText = "1:1"
        } else if abs(ratio - 4.0/3.0) < 0.01 {
            ratioText = "4:3"
        } else if abs(ratio - 16.0/9.0) < 0.01 {
            ratioText = "16:9"
        } else {
            ratioText = String(format: "%.2f:1", ratio)
        }
        
        ratioLabel.text = ratioText
        ratioLabel.textColor = .white
        ratioLabel.font = .systemFont(ofSize: 12)
        
        let sizeLabel = UILabel()
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            let size = Double(imageData.count) / 1024.0 / 1024.0 // Convert to MB
            sizeLabel.text = String(format: "%.1f MB", size)
        }
        sizeLabel.textColor = .white
        sizeLabel.font = .systemFont(ofSize: 12)
        
        let labelsStack = UIStackView(arrangedSubviews: [resolutionLabel, ratioLabel, sizeLabel])
        labelsStack.axis = .horizontal
        labelsStack.spacing = 15
        labelsStack.distribution = .equalSpacing
        metadataView.addSubview(labelsStack)
        
        metadataView.translatesAutoresizingMaskIntoConstraints = false
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            metadataView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metadataView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metadataView.bottomAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: -20),
            metadataView.heightAnchor.constraint(equalToConstant: 30),
            
            labelsStack.centerXAnchor.constraint(equalTo: metadataView.centerXAnchor),
            labelsStack.centerYAnchor.constraint(equalTo: metadataView.centerYAnchor)
        ])
    }
    
    private func setupProgressView() {
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.progressTintColor = SCConstants.themeColor
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.isHidden = true
        view.addSubview(progressView)
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.bottomAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: -40),
            progressView.widthAnchor.constraint(equalToConstant: 200),
            progressView.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    private func createButton(withTitle title: String, iconName: String) -> UIButton {
        let button = UIButton(type: .system)
        
        // 创建垂直布局的 UIStackView
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        
        // 配置图标
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let image = UIImage(systemName: iconName, withConfiguration: imageConfig)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit

        // 配置标题
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        
        // 将图标和标题添加到 stackView
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(label)
        
        // 将 stackView 添加到按钮
        button.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // 设置按钮背景
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 30
        
        // 添加按压效果
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        return button
    }
    
    // MARK: - Gestures
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // 添加双击手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
        
        // 确保单击手势在双击手势失败后才触发
        tapGesture.require(toFail: doubleTapGesture)
        
        // 添加滑动关闭手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
    }
    
    // MARK: - Animations
    private func animateAppearance() {
        view.alpha = 0
        imageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.alpha = 1
            self.imageView.transform = .identity
        }
    }
    
    private func animateDismissal(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.view.alpha = 0
            self.imageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            completion()
        }
    }
    
    // MARK: - Actions
    @objc private func confirm() {
        // 显示进度条
        progressView.isHidden = false
        progressView.progress = 0
        
        // 模拟保存进度
        var progress: Float = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            progress += 0.1
            self.progressView.progress = min(progress, 1.0)
            
            if progress >= 1.0 {
                timer.invalidate()
                // 保存照片到相册
                UIImageWriteToSavedPhotosAlbum(self.image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    @objc private func cancel() {
        animateDismissal {
            self.dismiss(animated: false)
        }
    }
    
    @objc private func edit() {
        // 显示编辑功能提示
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.info)
        view.configureContent(title: "提示", body: "后续会开发滤镜等图片编辑操作")
        SwiftMessages.show(view: view)
    }
    
    @objc private func share() {
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        present(activityViewController, animated: true)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        isStatusBarHidden.toggle()
        
        UIView.animate(withDuration: 0.3) {
            self.setNeedsStatusBarAppearanceUpdate()
            self.buttonsStackView.alpha = self.isStatusBarHidden ? 0 : 1
            self.blurEffectView.alpha = self.isStatusBarHidden ? 0 : 1
        }
    }
    
    @objc private func buttonTouchDown(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            button.alpha = 0.8
        }
    }
    
    @objc private func buttonTouchUp(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = .identity
            button.alpha = 1.0
        }
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
            
            // 延迟关闭页面
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.dismiss(animated: true)
            }
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: imageView)
        
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            // 如果已经放大，则缩小回原始大小
            UIView.animate(withDuration: 0.3) {
                self.scrollView.setZoomScale(self.scrollView.minimumZoomScale, animated: false)
            }
        } else {
            // 放大到双击的位置
            let zoomRect = CGRect(
                x: location.x - (scrollView.bounds.size.width / 4.0),
                y: location.y - (scrollView.bounds.size.height / 4.0),
                width: scrollView.bounds.size.width / 2.0,
                height: scrollView.bounds.size.height / 2.0
            )
            scrollView.zoom(to: zoomRect, animated: true)
            
            // 触觉反馈
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator.impactOccurred()
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let touchPoint = gesture.location(in: view)
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .began:
            initialTouchPoint = touchPoint
            
        case .changed:
            // 计算垂直移动距离
            let verticalMovement = translation.y
            
            // 应用缩放和透明度效果
            let scale = max(1 - abs(verticalMovement) / 1000, 0.85)
            let alpha = max(1 - abs(verticalMovement) / 500, 0.5)
            
            imageView.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.backgroundColor = view.backgroundColor?.withAlphaComponent(alpha)
            blurEffectView.alpha = alpha
            
        case .ended, .cancelled:
            let verticalMovement = translation.y
            let verticalVelocity = velocity.y
            
            // 如果移动距离或速度超过阈值，关闭页面
            if abs(verticalMovement) > 100 || abs(verticalVelocity) > 500 {
                let isMovingDown = verticalMovement > 0 || verticalVelocity > 0
                let duration = 0.3
                
                UIView.animate(withDuration: duration, animations: {
                    self.imageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                    self.view.backgroundColor = self.view.backgroundColor?.withAlphaComponent(0)
                    self.blurEffectView.alpha = 0
                    self.imageView.frame.origin.y += isMovingDown ? 200 : -200
                }) { _ in
                    self.dismiss(animated: false)
                }
            } else {
                // 恢复原始状态
                UIView.animate(withDuration: 0.3) {
                    self.imageView.transform = .identity
                    self.view.backgroundColor = self.view.backgroundColor?.withAlphaComponent(1)
                    self.blurEffectView.alpha = 1
                }
            }
            
        default:
            break
        }
    }
}

// MARK: - UIScrollViewDelegate
extension SCPhotoPreviewVC: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 确保图片在缩放时保持居中
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        
        imageView.center = CGPoint(
            x: scrollView.contentSize.width * 0.5 + offsetX,
            y: scrollView.contentSize.height * 0.5 + offsetY
        )
    }
} 
