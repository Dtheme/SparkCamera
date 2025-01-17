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
    private var zoomView: SCPhotoZoomView!
    private var blurEffectView: UIVisualEffectView!
    private var toolbar: SCPhotoPreviewToolbar!
    private var infoView: SCPhotoInfoView!
    private var isStatusBarHidden = false
    private var progressView: UIProgressView!
    private var progressBackgroundView: UIVisualEffectView?  // 添加背景视图引用
    
    // 添加内存管理相关属性
    private var isViewVisible = false
    private var downsampledImage: UIImage?
    
    // MARK: - Initialization
    init(image: UIImage, photoInfo: SCPhotoInfo) {
        self.image = image
        self.photoInfo = photoInfo
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // 确保释放资源
        zoomView.image = nil
        downsampledImage = nil
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置基本UI
        view.backgroundColor = .black
        setupUI()
        setupGestures()
        
        // 立即开始处理图片
        processImageInBackground()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewVisible = true
        animateAppearance()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewVisible = false
        // 释放内存
        if !isBeingDismissed {
            downsampledImage = nil
            zoomView.image = nil
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        setupBackground()
        setupZoomView()
        setupToolbar()
        setupInfoView()
        setupProgressView()
    }
    
    private func setupBackground() {
        let blurEffect = UIBlurEffect(style: .dark)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        view.addSubview(blurEffectView)
        
        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupZoomView() {
        zoomView = SCPhotoZoomView()
        zoomView.delegate = self
        zoomView.image = image
        view.addSubview(zoomView)
        
        zoomView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupToolbar() {
        toolbar = SCPhotoPreviewToolbar()
        toolbar.delegate = self
        view.addSubview(toolbar)
        
        toolbar.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(60)
            make.width.equalTo(300)
        }
    }
    
    private func setupInfoView() {
        infoView = SCPhotoInfoView(image: image, photoInfo: photoInfo)
        view.addSubview(infoView)
        
        infoView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalTo(toolbar.snp.top).offset(-20)
            make.height.equalTo(60)
        }
    }
    
    private func setupProgressView() {
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.progressTintColor = SCConstants.themeColor
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.isHidden = true
        view.addSubview(progressView)
        
        progressView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(4)
        }
        
        // 添加模糊背景
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 8
        blurView.clipsToBounds = true
        blurView.isHidden = true
        view.insertSubview(blurView, belowSubview: progressView)
        
        // 保存对背景视图的引用，以便后续控制显示/隐藏
        self.progressBackgroundView = blurView
        
        blurView.snp.makeConstraints { make in
            make.center.equalTo(progressView)
            make.width.equalTo(progressView).offset(40)
            make.height.equalTo(40)
        }
    }
    
    private func showProgressView() {
        progressView.isHidden = false
        progressBackgroundView?.isHidden = false
    }
    
    private func hideProgressView() {
        progressView.isHidden = true
        progressBackgroundView?.isHidden = true
    }
    
    // MARK: - Gestures
    private func setupGestures() {
        // 平移手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // 如果图片处于放大状态，不响应下滑手势
        if zoomView.isZoomed {
            return
        }
        
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            // 计算垂直和水平移动的比例
            let verticalRatio = abs(translation.y / view.bounds.height)
            let horizontalRatio = abs(translation.x / view.bounds.width)
            
            // 如果水平移动比垂直移动大，不处理
            if horizontalRatio > verticalRatio {
                return
            }
            
            // 计算缩放和透明度
            let scale = max(0.5, 1 - verticalRatio)
            let alpha = max(0, 1 - verticalRatio * 2)
            
            // 应用变换
            zoomView.transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: translation.x, y: translation.y)
            
            // 更新界面透明度
            view.backgroundColor = UIColor.black.withAlphaComponent(alpha)
            blurEffectView.alpha = alpha
            toolbar.alpha = alpha
            infoView.alpha = alpha
            
        case .ended, .cancelled:
            // 判断是否需要关闭预览
            let shouldDismiss = abs(translation.y) > view.bounds.height * 0.3 || abs(velocity.y) > 500
            
            if shouldDismiss {
                // 继续移动方向的动画
                let translationDirection = translation.y > 0 ? 1.0 : -1.0
                UIView.animate(withDuration: 0.2, animations: {
                    self.zoomView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                        .translatedBy(x: 0, y: self.view.bounds.height * translationDirection)
                    self.view.backgroundColor = .clear
                    self.blurEffectView.alpha = 0
                    self.toolbar.alpha = 0
                    self.infoView.alpha = 0
                }) { _ in
                    self.dismiss(animated: false)
                }
            } else {
                // 恢复原状
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseOut) {
                    self.zoomView.transform = .identity
                    self.view.backgroundColor = .black
                    self.blurEffectView.alpha = 1
                    self.toolbar.alpha = 1
                    self.infoView.alpha = 1
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Animations
    private func animateAppearance() {
        view.alpha = 0
        zoomView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.alpha = 1
            self.zoomView.transform = .identity
        }
    }
    
    private func animateDismissal(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.view.alpha = 0
            self.zoomView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            completion()
        }
    }
    
    // MARK: - Actions
    @objc private func confirm() {
        // 显示进度条
        progressView.isHidden = false
        progressView.progress = 0
        
        // 添加触觉反馈
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        
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
                feedbackGenerator.impactOccurred()
                
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
    
    private func shareImage() {
        // 准备分享的内容
        var itemsToShare: [Any] = []
        
        // 添加图片
        if let jpegData = image.jpegData(compressionQuality: 1.0) {
            itemsToShare.append(jpegData)
        } else {
            itemsToShare.append(image)
        }
        
        // 创建分享控制器
        let activityVC = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        
        // 排除一些不需要的分享类型
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .postToVimeo,
            .postToWeibo,
            .postToFlickr,
            .postToTencentWeibo
        ]
        
        // 设置回调
        activityVC.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
            guard let self = self else { return }
            
            if let error = error {
                // 显示错误信息
                let view = MessageView.viewFromNib(layout: .statusLine)
                view.configureTheme(.error)
                view.configureContent(title: "分享失败", body: error.localizedDescription)
                SwiftMessages.show(view: view)
                return
            }
            
            if completed {
                // 显示成功信息
                let view = MessageView.viewFromNib(layout: .statusLine)
                view.configureTheme(.success)
                view.configureContent(title: "分享成功", body: "图片已分享")
                SwiftMessages.show(view: view)
                
                // 触觉反馈
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        }
        
        // 在 iPad 上设置弹出位置
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // 显示分享控制器
        present(activityVC, animated: true)
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
            view.configureContent(title: "保存失败", body: error.localizedDescription)
            SwiftMessages.show(view: view)
        } else {
            // 显示成功信息
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.success)
            view.configureContent(title: "已保存", body: "照片已保存到相册")
            SwiftMessages.show(view: view)
            
            // 触觉反馈
            let feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator.notificationOccurred(.success)
            
            // 延迟关闭页面
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.animateDismissal {
                    self.dismiss(animated: false)
                }
            }
        }
    }
    
    // MARK: - Image Processing
    private func processImageInBackground() {
        // 计算合适的缩放比例
        let scale = calculateOptimalScale()
        
        // 在后台线程处理图片
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 对图片进行降采样
            if let downsampledImage = self.downsample(image: self.image, to: scale) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 更新图片视图
                    self.zoomView.image = downsampledImage
                    self.downsampledImage = downsampledImage
                }
            }
        }
    }
    
    private func calculateOptimalScale() -> CGFloat {
        let screenScale = UIScreen.main.scale
        let screenSize = UIScreen.main.bounds.size
        
        // 计算图片在屏幕上的显示尺寸
        let imageSize = image.size
        let widthRatio = screenSize.width / imageSize.width
        let heightRatio = screenSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio) * screenScale
        
        // 确保缩放后的图片尺寸不会太小
        return max(scale, 1.0)
    }
    
    private func downsample(image: UIImage, to scale: CGFloat) -> UIImage? {
        // 创建绘图上下文
        let size = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // 绘制图片
        image.draw(in: CGRect(origin: .zero, size: size))
        
        // 获取结果
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - Memory Management
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // 如果视图不可见,释放内存
        if !isViewVisible {
            downsampledImage = nil
        }
    }
    
    private func toggleInterfaceVisibility() {
        let newAlpha: CGFloat = toolbar.alpha > 0 ? 0 : 1
        
        UIView.animate(withDuration: 0.25) {
            self.toolbar.alpha = newAlpha
            self.infoView.alpha = newAlpha
            self.blurEffectView.alpha = newAlpha
            self.isStatusBarHidden.toggle()
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    private func saveImageToAlbum() {
        // 显示进度条
        showProgressView()
        progressView.progress = 0
        
        // 触觉反馈
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()
        
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
                feedback.impactOccurred()
                
                // 保存图片
                UIImageWriteToSavedPhotosAlbum(self.image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                
                // 隐藏进度条
                self.hideProgressView()
            }
        }
    }

}

// MARK: - UIGestureRecognizerDelegate
extension SCPhotoPreviewVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 如果点击了工具栏，不触发手势
        if touch.view?.isDescendant(of: toolbar) == true {
            return false
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许平移手势和滚动视图同时工作
        return true
    }
}

// MARK: - SCPhotoPreviewToolbarDelegate
extension SCPhotoPreviewVC: SCPhotoPreviewToolbarDelegate {
    func toolbarDidTapCancel(_ toolbar: SCPhotoPreviewToolbar) {
        animateDismissal {
            self.dismiss(animated: false)
        }
    }
    
    func toolbarDidTapEdit(_ toolbar: SCPhotoPreviewToolbar) {
        // 显示编辑功能提示
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.info)
        view.configureContent(title: "提示", body: "后续会开发滤镜等图片编辑操作")
        SwiftMessages.show(view: view)
    }
    
    func toolbarDidTapConfirm(_ toolbar: SCPhotoPreviewToolbar) {
        // 显示进度条
        showProgressView()
        progressView.progress = 0
        
        // 添加触觉反馈
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        
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
                feedbackGenerator.impactOccurred()
                
                // 保存照片到相册
                UIImageWriteToSavedPhotosAlbum(self.image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                
                // 隐藏进度条
                self.hideProgressView()
            }
        }
    }
}

// MARK: - SCPhotoZoomViewDelegate
extension SCPhotoPreviewVC: SCPhotoZoomViewDelegate {
    func zoomViewDidTap(_ zoomView: SCPhotoZoomView) {
        // 如果图片处于放大状态，先恢复原始大小
        if zoomView.isZoomed {
            zoomView.resetZoom()
            return
        }
        
        // 切换界面元素显示状态
        toggleInterfaceVisibility()
    }
    
    func zoomViewDidDoubleTap(_ zoomView: SCPhotoZoomView) {
        // 双击时不需要额外处理，缩放逻辑在 ZoomView 内部已处理
    }
    
    func zoomViewDidLongPress(_ zoomView: SCPhotoZoomView) {
        // 显示操作菜单
        SCActionSheet.show(actions: [
            .init(title: "保存到相册", icon: UIImage(systemName: "square.and.arrow.down"), style: .default) { [weak self] in
                self?.saveImageToAlbum()
            },
            .init(title: "分享", icon: UIImage(systemName: "square.and.arrow.up"), style: .default) { [weak self] in
                self?.shareImage()
            },
            .init(title: "取消", icon: nil, style: .cancel, handler: nil)
        ])
    }
    
    func zoomView(_ zoomView: SCPhotoZoomView, didPanWithProgress progress: CGFloat) {
        // 更新背景透明度
        view.backgroundColor = UIColor.black.withAlphaComponent(1 - progress)
        
        // 同时更新工具栏的透明度
        toolbar.alpha = 1 - progress
    }
    
    func zoomViewDidEndPan(_ zoomView: SCPhotoZoomView, shouldDismiss: Bool) {
        if shouldDismiss {
            // 关闭预览
            cancel()
        } else {
            // 恢复背景和工具栏透明度
            UIView.animate(withDuration: 0.3) {
                self.view.backgroundColor = .black
                self.toolbar.alpha = 1
            }
        }
    }
} 
