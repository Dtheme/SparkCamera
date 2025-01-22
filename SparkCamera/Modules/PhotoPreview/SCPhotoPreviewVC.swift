//
//  SCPhotoPreviewVC.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/14.
//

import UIKit
import SwiftMessages
import SnapKit
import GPUImage

@objc class SCPhotoPreviewVC: UIViewController {
    
    // MARK: - Properties
    private let image: UIImage
    private let photoInfo: SCPhotoInfo
    private var filterView: SCFilterView!
    private var blurEffectView: UIVisualEffectView!
    private var toolbar: SCPhotoPreviewToolbar!
    private var infoView: SCPhotoInfoView!
    private var filterOptionView: SCFilterOptionView!
    private var closeButton: UIButton!
    private var isStatusBarHidden = false
    private var progressView: UIProgressView!
    private var progressBackgroundView: UIVisualEffectView?
    
    // 添加内存管理相关属性
    private var isViewVisible = false
    private var downsampledImage: UIImage?
    
    // MARK: - Editing Mode
    private var isEditingMode: Bool = false
    
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
        downsampledImage = nil
        NotificationCenter.default.removeObserver(self)
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
        
        // 添加通知监听，用于自动保存成功后更新状态
        NotificationCenter.default.addObserver(self,
            selector: #selector(handlePhotoSaved),
            name: NSNotification.Name("PhotoSavedToAlbum"),
            object: nil)
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
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        setupBackground()
        setupFilterView()
        setupToolbar()
        setupInfoView()
        setupFilterOptionView()
        setupProgressView()
        setupCloseButton()
    }
    
    private func setupBackground() {
        let blurEffect = UIBlurEffect(style: .dark)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        view.addSubview(blurEffectView)
        
        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupFilterView() {
        filterView = SCFilterView()
        filterView.delegate = self
        view.addSubview(filterView)
        
        filterView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 设置图片
        filterView.setImage(image)
    }
    
    private func setupCloseButton() {
        closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        view.addSubview(closeButton)
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.left.equalToSuperview().offset(16)
            make.width.height.equalTo(44)
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
        
        // 确保约束立即生效
        view.layoutIfNeeded()
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
    
    private func setupFilterOptionView() {
        filterOptionView = SCFilterOptionView(templates: SCFilterTemplate.templates)
        filterOptionView.delegate = self
        view.addSubview(filterOptionView)
        
        filterOptionView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(toolbar.snp.top)
            make.height.equalTo(100)
        }
        
        // 初始状态隐藏
        filterOptionView.alpha = 0
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
        // 移除下拉退出手势的设置
    }
    
    @objc private func handleClose() {
        animateDismissal {
            self.dismiss(animated: false)
        }
    }
    
    // MARK: - Animations
    private func animateAppearance() {
        view.alpha = 0
        filterView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.alpha = 1
            self.filterView.transform = .identity
        }
    }
    
    private func animateDismissal(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.view.alpha = 0
            self.filterView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
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
        if isEditingMode {
            exitEditingMode()
        } else {
            enterEditingMode()
            // 显示编辑功能提示
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.info)
            view.configureContent(title: "提示", body: "后续会开发滤镜等图片编辑操作")
            SwiftMessages.show(view: view)
        }
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
            print("⚠️ [Photo Save] 保存照片失败: \(error.localizedDescription)")
            // 显示错误提示
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.error)
            view.configureContent(title: "保存失败", body: error.localizedDescription)
            SwiftMessages.show(view: view)
        } else {
            print("✅ [Photo Save] 照片保存成功")
            // 更新保存状态
            photoInfo.isSavedToAlbum = true
            // 发送通知
            self.dismiss(animated: true)
            // 显示成功提示
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.success)
            view.configureContent(title: "保存成功", body: "照片已保存到相册")
            SwiftMessages.show(view: view)
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
                    self.filterView.setImage(downsampledImage)
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
        // 如果在编辑模式下，不允许显示信息视图
        if isEditingMode {
            let newAlpha: CGFloat = toolbar.alpha > 0 ? 0 : 1
            UIView.animate(withDuration: 0.25) {
                self.toolbar.alpha = newAlpha
                self.isStatusBarHidden.toggle()
                self.setNeedsStatusBarAppearanceUpdate()
            }
        } else {
            let newAlpha: CGFloat = toolbar.alpha > 0 ? 0 : 1
            UIView.animate(withDuration: 0.25) {
                self.toolbar.alpha = newAlpha
                self.infoView.alpha = newAlpha
                self.blurEffectView.alpha = newAlpha
                self.isStatusBarHidden.toggle()
                self.setNeedsStatusBarAppearanceUpdate()
            }
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
    
    // MARK: - Notification Handlers
    @objc private func handlePhotoSaved() {
        // 更新保存状态
        photoInfo.isSavedToAlbum = true
        // 更新信息视图
        infoView?.updateSaveState(isSaved: true)
    }

    // MARK: - Editing Mode
    private func updateUIForEditingMode(_ isEditing: Bool) {
        // 计算图片宽高比
        let imageAspectRatio = image.size.width / image.size.height
        
        // 更新约束
        if isEditing {
            filterView.snp.remakeConstraints { make in
                make.left.right.equalToSuperview()
                make.top.equalTo(view.safeAreaLayoutGuide)
                
                // 根据图片宽高比设置高度
                let width = UIScreen.main.bounds.width
                let height = width / imageAspectRatio
                make.height.equalTo(height)
                
                // 确保不超出 filterOptionView
                make.bottom.lessThanOrEqualTo(filterOptionView.snp.top)
            }
            
            // 居中显示
            filterView.snp.makeConstraints { make in
                make.centerY.equalTo(view.safeAreaLayoutGuide).priority(.high)
            }
        } else {
            filterView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        // 执行动画
        UIView.animate(withDuration: 0.3) {
            // 更新 infoView 和背景
            self.infoView.alpha = isEditing ? 0 : 1
            self.blurEffectView.alpha = isEditing ? 0 : 1
            self.filterOptionView.alpha = isEditing ? 1 : 0
            
            self.view.layoutIfNeeded()
        }
    }

    private func showExitEditingConfirmation(completion: @escaping (Bool) -> Void) {
        SCAlert.show(
            title: "退出编辑",
            message: "确定要退出编辑模式吗？未保存的修改将会丢失。",
            style: .warning,
            cancelTitle: "取消",
            confirmTitle: "退出编辑",
            completion: completion
        )
    }

    private func enterEditingMode() {
        isEditingMode = true
        toolbar.setEditingMode(true)
        updateUIForEditingMode(true)
        
        // 等待布局更新完成后重新加载图片
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            if let downsampledImage = self.downsampledImage {
                self.filterView.setImage(downsampledImage)
            } else {
                self.filterView.setImage(self.image)
            }
        }
    }

    private func exitEditingMode() {
        showExitEditingConfirmation { [weak self] shouldExit in
            guard let self = self, shouldExit else { return }
            
            self.isEditingMode = false
            self.toolbar.setEditingMode(false)
            self.updateUIForEditingMode(false)
            
            // 等待布局更新完成后重新加载图片
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                if let downsampledImage = self.downsampledImage {
                    self.filterView.setImage(downsampledImage)
                } else {
                    self.filterView.setImage(self.image)
                }
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
        if isEditingMode {
            exitEditingMode()
        } else {
            animateDismissal {
                self.dismiss(animated: false)
            }
        }
    }
    
    func toolbarDidTapEdit(_ toolbar: SCPhotoPreviewToolbar) {
        if !isEditingMode {
            enterEditingMode()
        }
    }
    
    func toolbarDidTapConfirm(_ toolbar: SCPhotoPreviewToolbar) {
        if isEditingMode {
            // TODO: 保存编辑效果
            isEditingMode = false
            updateUIForEditingMode(false)
        } else {
            // 原有的保存逻辑
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
}

// MARK: - SCFilterViewDelegate
extension SCPhotoPreviewVC: SCFilterViewDelegate {
    func filterViewDidTap(_ filterView: SCFilterView) {
        toggleInterfaceVisibility()
    }
    
    func filterViewDidDoubleTap(_ filterView: SCFilterView) {
        // 双击时不需要特殊处理
    }
    
    func filterViewDidLongPress(_ filterView: SCFilterView) {
        // 在编辑模式下不响应长按手势
        if isEditingMode { return }
        
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
    
    func filterView(_ filterView: SCFilterView, didChangeFilter template: SCFilterTemplate?) {
        // 处理滤镜变化
    }
}

// MARK: - SCFilterOptionViewDelegate
extension SCPhotoPreviewVC: SCFilterOptionViewDelegate {
    func filterOptionView(_ view: SCFilterOptionView, didSelectTemplate template: SCFilterTemplate) {
        // 应用滤镜
        filterView.filterTemplate = template
    }
} 
