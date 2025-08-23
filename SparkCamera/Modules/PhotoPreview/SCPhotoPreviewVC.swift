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
import Photos

@objc class SCPhotoPreviewVC: UIViewController {
    
    // MARK: - Properties
    private let image: UIImage
    private let photoInfo: SCPhotoInfo
    private var filterView: SCFilterView!
    private var blurEffectView: UIVisualEffectView!
    private var toolbar: SCPhotoPreviewToolbar!
    private var infoView: SCPhotoInfoView!
    private var filterOptionView: SCFilterOptionView!
    private var filterAdjustView: SCFilterAdjustView!
    // 新增：参数列表与参数编辑视图
    private var parameterListView: SCParameterListView!
    private var parameterEditorView: SCParameterEditorView!
    private var currentSelectedParameter: SCFilterParameter = .presetTemplates
    private var parameterHistory: [SCFilterParameter: [Float]] = [:]
    private var parameterRedoStack: [SCFilterParameter: [Float]] = [:]
    // 基线参数：进入编辑模式时从当前图片读取，用于重置与修改判断
    private var baselineParameters: [SCFilterParameter: Float] = [:]
    private var resetAllButton: UIButton!
    // 新增：承载预置/参数编辑的容器，避免层级/命中问题
    private var editContainerView: UIView!
    private var closeButton: UIButton!
    private var isStatusBarHidden = false
    private var progressView: UIProgressView!
    private var progressBackgroundView: UIVisualEffectView?
    
    // 添加内存管理相关属性
    private var isViewVisible = false
    private var downsampledImage: UIImage?
    
    // MARK: - Editing Mode
    private var isEditingMode: Bool = false
    
    private lazy var adjustButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(handleAdjustButtonTap), for: .touchUpInside)
        return button
    }()
    
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
            selector: #selector(handlePhotoSavedNotification(_:)),
            name: NSNotification.Name("PhotoSavedToAlbum"),
            object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewVisible = true
        animateAppearance()
        // 在安全区域与最终布局稳定后，按比例重新应用一次，避免初次进入时全屏铺满
        applyAspectLayout(isEditing: isEditingMode)
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        setupBackground()
        setupFilterView()
        setupToolbar()
        setupInfoView()
        setupParameterListView()
        setupEditContainerView()
        setupFilterOptionView()
        setupParameterEditorView()
        setupFilterAdjustView()
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
        
        // 默认按图片比例布局，而不是全屏铺满
        applyAspectLayout(isEditing: false)
        
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
        filterOptionView = SCFilterOptionView()
        filterOptionView.delegate = self
        // 预置 + 自定义
        let customTemplates = SCCustomFilterManager.shared.allFilters().map { $0.toTemplate() }
        filterOptionView.templates = SCFilterTemplate.templates + customTemplates
        filterOptionView.isUserInteractionEnabled = true
        print("[PhotoPreview] 设置 filterOptionView delegate: \(String(describing: filterOptionView.delegate))")
        print("[PhotoPreview] 设置 filterOptionView templates 数量: \(filterOptionView.templates.count)")
        editContainerView.addSubview(filterOptionView)
        
        filterOptionView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(120)
        }
        
        // 初始状态隐藏
        filterOptionView.alpha = 0
    }

    private func setupEditContainerView() {
        editContainerView = UIView()
        editContainerView.backgroundColor = .clear
        view.addSubview(editContainerView)
        editContainerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(parameterListView.snp.top)
            make.height.equalTo(120)
        }
    }

    private func setupParameterListView() {
        // 先添加重置全部按钮，避免与列表重叠
        resetAllButton = UIButton(type: .system)
        resetAllButton.setTitle("重置全部", for: .normal)
        resetAllButton.setTitleColor(.white, for: .normal)
        resetAllButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        resetAllButton.layer.cornerRadius = 8
        resetAllButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        resetAllButton.addTarget(self, action: #selector(handleResetAll), for: .touchUpInside)
        view.addSubview(resetAllButton)
        resetAllButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.bottom.equalTo(toolbar.snp.top).offset(-8)
            make.height.equalTo(28)
            make.width.equalTo(76)
        }
        resetAllButton.alpha = 0

        // 再添加参数列表，并让其右侧不与按钮重叠
        parameterListView = SCParameterListView(parameters: SCFilterParameter.allCases)
        parameterListView.delegate = self
        view.addSubview(parameterListView)
        parameterListView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.right.equalTo(resetAllButton.snp.left).offset(-8)
            make.bottom.equalTo(toolbar.snp.top)
            make.height.equalTo(44)
        }
        parameterListView.alpha = 0
        parameterListView.layer.zPosition = 10

        // 解决与容器/抽屉手势冲突：要求容器和抽屉的pan/tap失败后，collectionView再处理
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let gestures = self.parameterListView.gesturesForConflictResolution()
            if let editGestures = self.editContainerView.gestureRecognizers {
                for g in gestures { editGestures.forEach { g.require(toFail: $0) } }
            }
            if let adjustGestures = self.filterAdjustView.gestureRecognizers {
                for g in gestures { adjustGestures.forEach { g.require(toFail: $0) } }
            }
        }
    }

    private func setupParameterEditorView() {
        parameterEditorView = SCParameterEditorView()
        parameterEditorView.delegate = self
        parameterEditorView.isUserInteractionEnabled = true
        editContainerView.addSubview(parameterEditorView)
        parameterEditorView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.height.equalTo(120)
        }
        parameterEditorView.alpha = 0
        parameterEditorView.isHidden = true
    }
    
    private func setupFilterAdjustView() {
        filterAdjustView = SCFilterAdjustView(frame: .zero)
        filterAdjustView.delegate = self
        view.addSubview(filterAdjustView)
        
        filterAdjustView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.width.equalTo(280)
        }
        
        // 初始状态为隐藏，并设置初始位置在屏幕右侧
        filterAdjustView.isHidden = true
        
        // 在布局完成后设置初始transform
        DispatchQueue.main.async {
            self.filterAdjustView.transform = CGAffineTransform(translationX: self.filterAdjustView.bounds.width, y: 0)
        }
        
        // 添加点击手势来关闭抽屉
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tapGesture.delegate = self
        // 避免与参数列表手势冲突：只有当参数列表未处理时才触发背景点击
        if let gestures = parameterListView?.gesturesForConflictResolution() {
            gestures.forEach { tapGesture.require(toFail: $0) }
        }
        view.addGestureRecognizer(tapGesture)
        
        // 设置调整按钮
        view.addSubview(adjustButton)
        adjustButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.centerY.equalTo(view.safeAreaLayoutGuide).offset(50)  // 相对于安全区域中心偏上一点
            make.width.height.equalTo(40)
        }
        
        // 初始状态隐藏调整按钮
        adjustButton.isHidden = true
        adjustButton.alpha = 1.0
        
        // 设置按钮样式，确保更容易看到
        adjustButton.backgroundColor = SCConstants.themeColor.withAlphaComponent(0.9)
        adjustButton.layer.cornerRadius = 20
        adjustButton.layer.borderWidth = 2
        adjustButton.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        adjustButton.layer.shadowColor = UIColor.black.cgColor
        adjustButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        adjustButton.layer.shadowOpacity = 0.3
        adjustButton.layer.shadowRadius = 4
        
        print("🔧 [SETUP] 调整按钮已创建并添加到视图")
        print("🔧 [SETUP] 调整按钮约束: trailing=-16, centerY=safeArea+50")
        
        // 确保按钮在最前面
        view.bringSubviewToFront(adjustButton)
        
        // 添加左滑手势到调整按钮
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleAdjustButtonTap))
        swipeGesture.direction = .left
        adjustButton.addGestureRecognizer(swipeGesture)
        
        // 添加右滑手势到调整视图
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleRightSwipe))
        rightSwipeGesture.direction = .right
        filterAdjustView.addGestureRecognizer(rightSwipeGesture)
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
        progressView.isHidden = false
        progressView.setProgress(0.3, animated: true)
        
        // 保存图片
        filterView.saveToAlbum { [weak self] success, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if success {
                    // 更新进度
                    self.progressView.setProgress(1.0, animated: true)
                    
                    // 显示成功提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "保存成功", body: "图片已保存到相册")
                    SwiftMessages.show(view: view)
                    
                    // 刷新 FilterView
                    if let image = self.filterView.currentImage {
                        self.filterView.setImage(image)
                    }
                    
                    // 延迟隐藏进度条
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.progressView.isHidden = true
                        self.progressView.setProgress(0.0, animated: false)
                    }
                } else {
                    // 隐藏进度条
                    self.progressView.isHidden = true
                    self.progressView.setProgress(0.0, animated: false)
                    
                    // 显示错误提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.error)
                    view.configureContent(
                        title: "保存失败",
                        body: error?.localizedDescription ?? "未知错误"
                    )
                    SwiftMessages.show(view: view)
                }
            }
        }
    }
    
    // MARK: - Notification Handlers
    @objc private func handlePhotoSavedNotification(_ note: Notification) {
        // 更新保存状态
        photoInfo.isSavedToAlbum = true
        infoView?.updateSaveState(isSaved: true)
        let format = (note.userInfo?["format"] as? String) ?? ""
        let localId = (note.userInfo?["assetLocalId"] as? String) ?? ""
        // 展示带操作的提示：RAW 模式提供“导出 RAW”
        let view = MessageView.viewFromNib(layout: .cardView)
        view.configureTheme(.success)
        let title = format.isEmpty ? "保存成功" : "保存成功（\(format)）"
        view.configureContent(title: title, body: localId.isEmpty ? "照片已保存到相册" : "可以导出 RAW 原始文件")
        if format.contains("RAW"), !localId.isEmpty {
            view.button?.setTitle("导出 RAW", for: .normal)
            view.button?.isHidden = false
            view.buttonTapHandler = { [weak self] _ in
                self?.exportRawWith(localId: localId)
            }
        } else {
            view.button?.isHidden = true
        }
        var config = SwiftMessages.Config()
        config.presentationStyle = .top
        config.duration = .seconds(seconds: 3)
        SwiftMessages.show(config: config, view: view)
    }

    private func exportRawWith(localId: String) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
        guard let asset = assets.firstObject else {
            SwiftMessages.showErrorMessage("未找到 RAW 资源")
            return
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let rawRes = resources.first(where: {
            $0.type == .alternatePhoto ||
            $0.uniformTypeIdentifier.lowercased().contains("dng") ||
            $0.uniformTypeIdentifier.lowercased().contains("raw") ||
            $0.originalFilename.lowercased().hasSuffix(".dng")
        }) else {
            SwiftMessages.showErrorMessage("该资源未包含 RAW 文件")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("dng")
        let opt = PHAssetResourceRequestOptions()
        opt.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().writeData(for: rawRes, toFile: url, options: opt) { [weak self] err in
            DispatchQueue.main.async {
                if let err = err {
                    SwiftMessages.showErrorMessage("导出失败：\(err.localizedDescription)")
                } else {
                    self?.presentShareSheet(fileURL: url)
                }
            }
        }
    }

    private func presentShareSheet(fileURL: URL) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let pop = activityVC.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        present(activityVC, animated: true)
    }

    // MARK: - Editing Mode
    private func updateUIForEditingMode(_ isEditing: Bool) {
        // 计算图片宽高比
        let imageAspectRatio = image.size.width / image.size.height
        
        // 更新约束
        if isEditing {
            // 动态计算可用空间，避免硬编码
            let maxWidth = UIScreen.main.bounds.width - 40 // 左右各20点边距
            
            // 计算实际需要预留的空间
            let topMargin: CGFloat = 20 // 图片顶部边距
            let bottomMargin: CGFloat = 20 // 额外的底部安全边距
            let bottomReservedSpace = view.safeAreaInsets.bottom + 20 + 60 + 120 + bottomMargin // safeArea + toolbar边距 + toolbar高度 + filterOption高度 + 安全边距
            let availableHeight = UIScreen.main.bounds.height - view.safeAreaInsets.top - topMargin - bottomReservedSpace
            
            // 根据比例计算最佳尺寸，确保不压扁图片
            let widthBasedHeight = maxWidth / imageAspectRatio
            let heightBasedWidth = availableHeight * imageAspectRatio
            
            var finalWidth: CGFloat
            var finalHeight: CGFloat
            
            // 选择能保持比例且不超出边界的最大尺寸
            if widthBasedHeight <= availableHeight {
                // 按宽度缩放，图片不会太高
                finalWidth = maxWidth
                finalHeight = widthBasedHeight
            } else {
                // 按高度缩放，图片不会太宽
                finalWidth = heightBasedWidth
                finalHeight = availableHeight
            }
            
            // 验证比例是否正确，如果差异过大则修正
            let calculatedRatio = finalWidth / finalHeight
            if abs(imageAspectRatio - calculatedRatio) > 0.01 {
                let correctedHeight = finalWidth / imageAspectRatio
                if correctedHeight <= availableHeight {
                    finalHeight = correctedHeight
                }
            }
            
            // 使用明确的尺寸约束，避免Auto Layout混乱
            filterView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
                make.width.equalTo(finalWidth)
                make.height.equalTo(finalHeight)
            }
            
            // 立即更新布局
            view.layoutIfNeeded()
            
            // 显示抽屉视图，但保持隐藏状态，等待用户点击调整按钮
            filterAdjustView.isHidden = false
            // 确保抽屉在正确的初始位置（屏幕右侧外）- 通过transform控制
            DispatchQueue.main.async {
                self.filterAdjustView.transform = CGAffineTransform(translationX: self.filterAdjustView.bounds.width, y: 0)
            }
            
            // 添加点击空白区域关闭抽屉的手势
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
            view.addGestureRecognizer(tapGesture)
            
        } else {
            // 非编辑模式下也保持按比例展示
            applyAspectLayout(isEditing: false)
            
            // 隐藏抽屉视图
            filterAdjustView.isHidden = true
        }
        
        // 执行动画
        UIView.animate(withDuration: 0.3, animations: {
            // 更新 infoView 和背景
            self.infoView.alpha = isEditing ? 0 : 1
            self.blurEffectView.alpha = isEditing ? 0 : 1
            self.parameterListView.alpha = isEditing ? 1 : 0
            // 默认进入编辑时显示预置列表
            self.filterOptionView.alpha = isEditing ? 1 : 0
            self.parameterEditorView.alpha = 0
            
            self.view.layoutIfNeeded()
        }, completion: { _ in
            // 退出编辑模式或收起抽屉后，强制刷新预览区域布局，避免比例被错误挤压
            if !isEditing {
                self.filterView.refreshLayout()
            }
        })
    }

    /// 根据是否编辑模式，按图片原比例为 `filterView` 计算并应用合适的约束
    private func applyAspectLayout(isEditing: Bool) {
        let imageAspectRatio = image.size.width / image.size.height
        let topMargin: CGFloat = isEditing ? 20 : 0
        let bottomReservedSpace: CGFloat
        if isEditing {
            // safeArea + toolbar边距(20) + toolbar(60) + 参数列表(44) + 预置/编辑区域(120) + 额外bottom(20)
            bottomReservedSpace = view.safeAreaInsets.bottom + 20.0 + 60.0 + 44.0 + 120.0 + 20.0
        } else {
            // 非编辑模式下仅保留底部工具栏与信息视图
            // infoView(60) + 与toolbar间距(20) + toolbar(60) + safeArea bottom
            bottomReservedSpace = view.safeAreaInsets.bottom + 60.0 + 20.0 + 60.0 + 20.0
        }
        let availableHeight = view.bounds.height - view.safeAreaInsets.top - topMargin - bottomReservedSpace
        let maxWidth = view.bounds.width - (isEditing ? 40.0 : 0.0)
        let widthBasedHeight: CGFloat = maxWidth / imageAspectRatio
        let heightBasedWidth: CGFloat = availableHeight * imageAspectRatio
        let finalWidth: CGFloat = (widthBasedHeight <= availableHeight) ? maxWidth : heightBasedWidth
        let finalHeight: CGFloat = (widthBasedHeight <= availableHeight) ? widthBasedHeight : availableHeight
        filterView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(topMargin)
            make.width.equalTo(finalWidth)
            make.height.equalTo(finalHeight)
        }
        view.layoutIfNeeded()
    }

    private func showExitEditingConfirmation(completion: @escaping (Bool) -> Void) {
        // 检查是否有未保存的参数修改
        let hasModifications = filterAdjustView.hasModifiedParameters()
        
        let message = hasModifications 
            ? "确定要退出编辑模式吗？您对滤镜参数的修改将会丢失。"
            : "确定要退出编辑模式吗？"
        
        SCAlert.show(
            title: "退出编辑",
            message: message,
            style: hasModifications ? .warning : .info,
            cancelTitle: "取消",
            confirmTitle: "退出编辑",
            completion: completion
        )
    }

    private func enterEditingMode() {
        isEditingMode = true
        toolbar.setEditingMode(true)
        updateUIForEditingMode(true)
        // 捕获当前图片的参数作为本次会话的基线
        captureBaselineParameters()
        
        // 显示参数列表与预置滤镜
        print("🔧 [DEBUG] 进入编辑模式，显示调整按钮")
        print("  调整按钮当前状态: isHidden=\(adjustButton.isHidden), alpha=\(adjustButton.alpha)")
        print("  调整按钮父视图: \(adjustButton.superview != nil ? "已添加" : "未添加")")
        print("  调整按钮frame: \(adjustButton.frame)")
        print("  安全区域: \(view.safeAreaLayoutGuide.layoutFrame)")
        print("  视图bounds: \(view.bounds)")
        
        // 旧的右侧抽屉按钮不再使用，保持隐藏
        view.bringSubviewToFront(adjustButton)
        adjustButton.isHidden = true
        adjustButton.alpha = 0.0
        
        UIView.animate(withDuration: 0.3) {
            self.parameterListView.alpha = 1
            self.resetAllButton.alpha = 1
            self.filterOptionView.alpha = 1
            self.parameterEditorView.alpha = 0
            self.parameterEditorView.isHidden = true
            self.adjustButton.isHidden = true
            self.adjustButton.alpha = 0.0
        } completion: { _ in
            print("🔧 [DEBUG] 动画完成后调整按钮状态: isHidden=\(self.adjustButton.isHidden), alpha=\(self.adjustButton.alpha)")
            print("🔧 [DEBUG] 调整按钮frame: \(self.adjustButton.frame)")
            print("🔧 [DEBUG] 调整按钮在父视图中: \(self.view.subviews.contains(self.adjustButton) ? "存在" : "不存在")")
            // 保证参数列表位于最前，避免被容器遮挡导致初次无法点击
            self.view.bringSubviewToFront(self.parameterListView)
            // 初始禁用容器交互，防止抢先响应；点击参数后才切换目标视图并恢复
            self.editContainerView.isUserInteractionEnabled = false
        }

        // 默认选中“预置”，并刷新徽标
        parameterListView.select(parameter: .presetTemplates, animated: true)
        refreshModifiedParameterBadges()
        // 确保选中高亮同步
        DispatchQueue.main.async {
            self.parameterListView.select(parameter: .presetTemplates, animated: false)
        }
        // 默认选中“预置”参数项，并刷新已修改标记
        parameterListView.select(parameter: .presetTemplates, animated: true)
        refreshModifiedParameterBadges()
        
        // 验证滤镜功能
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let isValid = self.filterView.validateFilterFunctionality()
            if !isValid {
                print("⚠️ [PhotoPreview] 滤镜功能验证失败，可能影响调整效果")
            }
        }
        
        // 添加提示信息
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showFilterAdjustmentTip()
        }
    }

    private func exitEditingMode() {
        showExitEditingConfirmation { [weak self] shouldExit in
            guard let self = self, shouldExit else { return }
            
            self.isEditingMode = false
            self.toolbar.setEditingMode(false)
            self.updateUIForEditingMode(false)
            
            // 隐藏编辑相关视图
            UIView.animate(withDuration: 0.3) {
                self.filterOptionView.alpha = 0
                self.parameterListView.alpha = 0
                self.resetAllButton.alpha = 0
                self.parameterEditorView.alpha = 0
                self.adjustButton.isHidden = true
            }
            // 确保收起滤镜调整视图
            self.filterAdjustView.collapse()

            // 退出编辑模式后刷新一次预览，确保比例正确
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.filterView.refreshLayout()
            }
        }
    }

    // MARK: - Adjust Button
    private func setupAdjustButton() {
        // 设置调整按钮
        view.addSubview(adjustButton)
        adjustButton.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        // 添加左滑手势到调整按钮
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleAdjustButtonTap))
        swipeGesture.direction = .left
        adjustButton.addGestureRecognizer(swipeGesture)
        
        // 添加右滑手势到调整视图
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleRightSwipe))
        rightSwipeGesture.direction = .right
        filterAdjustView.addGestureRecognizer(rightSwipeGesture)
    }
    
    @objc private func handleAdjustButtonTap() {
        // 显示并展开滤镜调整视图
        filterAdjustView.isHidden = false
        
        // 同步当前的滤镜参数值
        let currentParameters = filterView.getCurrentParameters()
        filterAdjustView.updateParameters(currentParameters)
        
        // 展开抽屉
        filterAdjustView.expand()
        
        // 在调试模式下进行功能测试
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performBasicFilterTest()
        }
        #endif
    }
    
    @objc private func handleRightSwipe() {
        // 收起滤镜调整视图
        filterAdjustView.collapse()
    }
    
    /// 显示滤镜调整功能的使用提示
    private func showFilterAdjustmentTip() {
        // 检查是否已经显示过提示
        let hasShownTip = UserDefaults.standard.bool(forKey: "HasShownFilterAdjustmentTip")
        guard !hasShownTip else { return }
        
        // 创建提示视图
        let tipView = UIView()
        tipView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        tipView.layer.cornerRadius = 8
        
        let tipLabel = UILabel()
        tipLabel.text = "轻按右侧按钮可调整滤镜参数"
        tipLabel.textColor = .white
        tipLabel.font = .systemFont(ofSize: 14)
        tipLabel.textAlignment = .center
        
        tipView.addSubview(tipLabel)
        view.addSubview(tipView)
        
        tipLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        
        tipView.snp.makeConstraints { make in
            make.trailing.equalTo(adjustButton.snp.leading).offset(-8)
            make.centerY.equalTo(adjustButton)
        }
        
        // 动画显示
        tipView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            tipView.alpha = 1
        }
        
        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.3, animations: {
                tipView.alpha = 0
            }) { _ in
                tipView.removeFromSuperview()
            }
        }
        
        // 标记已显示
        UserDefaults.standard.set(true, forKey: "HasShownFilterAdjustmentTip")
    }
    
    /// 基本滤镜功能测试（仅调试模式）
    #if DEBUG
    private func performBasicFilterTest() {
        print("🧪 [DEBUG] 开始基本滤镜功能测试...")
        
        // 测试亮度调整
        print("  测试亮度调整: 0.0 → 0.3")
        filterView.updateParameter("亮度", value: 0.3)
        
        // 测试对比度调整
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("  测试对比度调整: 1.0 → 1.5")
            self.filterView.updateParameter("对比度", value: 1.5)
        }
        
        // 测试饱和度调整
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("  测试饱和度调整: 1.0 → 1.3")
            self.filterView.updateParameter("饱和度", value: 1.3)
        }
        
        // 恢复默认值
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("  恢复默认值...")
            self.filterView.updateParameter("亮度", value: 0.0)
            self.filterView.updateParameter("对比度", value: 1.0)
            self.filterView.updateParameter("饱和度", value: 1.0)
            print("🧪 [DEBUG] 基本滤镜功能测试完成")
        }
    }
    #endif
    
    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        
        // 如果点击位置在抽屉视图内，不处理
        if filterAdjustView.frame.contains(location) {
            return
        }
        
        // 如果抽屉是展开状态，收起抽屉
        if !filterAdjustView.isHidden {
            handleRightSwipe()
        }
    }

}

// MARK: - UIGestureRecognizerDelegate
extension SCPhotoPreviewVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 如果点击的是可交互区域（抽屉、参数列表、编辑容器），不响应背景点击手势
        if touch.view?.isDescendant(of: filterAdjustView) ?? false {
            return false
        }
        if let parameterListView = self.parameterListView, touch.view?.isDescendant(of: parameterListView) ?? false {
            return false
        }
        if let editContainerView = self.editContainerView, touch.view?.isDescendant(of: editContainerView) ?? false {
            return false
        }
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
            // 退出编辑模式
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

            // 显示进度条
            progressView.isHidden = false
            progressView.setProgress(0.3, animated: true)
            
            // 添加触觉反馈
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator.prepare()
            
            // 保存图片
            filterView.saveToAlbum { [weak self] success, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if success {
                        // 更新进度
                        self.progressView.setProgress(1.0, animated: true)
                        
                        // 触觉反馈
                        feedbackGenerator.impactOccurred()
                        
                        // 更新保存状态
                        self.photoInfo.isSavedToAlbum = true
                        
                        // 显示成功提示
                        let view = MessageView.viewFromNib(layout: .statusLine)
                        view.configureTheme(.success)
                        view.configureContent(title: "保存成功", body: "图片已保存到相册")
                        
                        // 配置消息显示
                        var config = SwiftMessages.Config()
                        config.presentationStyle = .top
                        config.duration = .seconds(seconds: 1.5)
                        
                        // 显示消息
                        SwiftMessages.show(config: config, view: view)
                        
                        // 延迟隐藏进度条并关闭页面
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.progressView.isHidden = true
                            self.progressView.setProgress(0.0, animated: false)
                            self.dismiss(animated: true)
                        }
                    } else {
                        // 隐藏进度条
                        self.progressView.isHidden = true
                        self.progressView.setProgress(0.0, animated: false)
                        
                        // 显示错误提示
                        let view = MessageView.viewFromNib(layout: .statusLine)
                        view.configureTheme(.error)
                        view.configureContent(
                            title: "保存失败",
                            body: error?.localizedDescription ?? "未知错误"
                        )
                        SwiftMessages.show(view: view)
                    }
                }
            }
        } else {
            // 显示进度条
            progressView.isHidden = false
            progressView.setProgress(0.3, animated: true)
            
            // 添加触觉反馈
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator.prepare()
            
            // 保存图片
            filterView.saveToAlbum { [weak self] success, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if success {
                        // 更新进度
                        self.progressView.setProgress(1.0, animated: true)
                        
                        // 触觉反馈
                        feedbackGenerator.impactOccurred()
                        
                        // 更新保存状态
                        self.photoInfo.isSavedToAlbum = true
                        
                        // 显示成功提示
                        let view = MessageView.viewFromNib(layout: .statusLine)
                        view.configureTheme(.success)
                        view.configureContent(title: "保存成功", body: "图片已保存到相册")
                        
                        // 配置消息显示
                        var config = SwiftMessages.Config()
                        config.presentationStyle = .top
                        config.duration = .seconds(seconds: 1.5)
                        
                        // 显示消息
                        SwiftMessages.show(config: config, view: view)
                        
                        // 延迟隐藏进度条并关闭页面
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.progressView.isHidden = true
                            self.progressView.setProgress(0.0, animated: false)
                            self.dismiss(animated: true)
                        }
                    } else {
                        // 隐藏进度条
                        self.progressView.isHidden = true
                        self.progressView.setProgress(0.0, animated: false)
                        
                        // 显示错误提示
                        let view = MessageView.viewFromNib(layout: .statusLine)
                        view.configureTheme(.error)
                        view.configureContent(
                            title: "保存失败",
                            body: error?.localizedDescription ?? "未知错误"
                        )
                        SwiftMessages.show(view: view)
                    }
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
            .init(title: "保存为预设滤镜", icon: UIImage(systemName: "tray.and.arrow.down.fill"), style: .default) { [weak self] in
                guard let self = self else { return }
                let params = self.filterView.getCurrentParameters()
                SCAlert.promptForText(
                    title: "保存为预设滤镜",
                    message: "请输入滤镜名称",
                    placeholder: "自定义滤镜",
                    defaultText: nil,
                    cancelTitle: "取消",
                    confirmTitle: "保存"
                ) { confirmed, text in
                    guard confirmed, let name = text, !name.isEmpty else { return }
                    do {
                        let saved = try SCCustomFilterManager.shared.saveFilter(name: name, parameters: params)
                        // 刷新预设列表：将自定义模板追加到展示中
                        let customTemplates = SCCustomFilterManager.shared.allFilters().map { $0.toTemplate() }
                        self.filterOptionView.templates = SCFilterTemplate.templates + customTemplates
                        // 成功提示改为 SwiftMessages
                        SwiftMessages.showSuccessMessage("已保存为预设滤镜：\(name)", title: "保存成功")
                    } catch {
                        SCAlert.show(title: "保存失败", message: error.localizedDescription, style: .error, cancelTitle: "", confirmTitle: "确定") { _ in }
                    }
                }
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
        print("[PhotoPreview] 选择滤镜模板: \(template.name)")
        
        // 1) 仅将模板参数写入自定义参数链，不长期保留模板链，确保自定义参数依然可用
        filterView.filterTemplate = nil

        // 2) 写入模板参数到引擎参数，作为新基线的值
        let templateParams = template.toParameters() // 引擎值
        for (k, v) in templateParams { filterView.updateParameter(k, value: v) }

        // 3) 更新基线：将 baselineParameters 设置为此次模板对应的引擎值
        var newBaseline: [SCFilterParameter: Float] = [:]
        for p in SCFilterParameter.allCases {
            guard let key = p.key else { continue }
            let engineDefault = p.uiToEngine(p.defaultValue)
            newBaseline[p] = templateParams[key] ?? engineDefault
        }
        baselineParameters = newBaseline

        // 4) 更新调整视图与参数编辑器的参数（引擎值 → UI 值）
        let params = templateParams
        filterAdjustView.updateParameters(params)
        if let key = currentSelectedParameter.key, let engineValue = params[key] {
            let baselineEngine = baselineParameters[currentSelectedParameter] ?? currentSelectedParameter.uiToEngine(currentSelectedParameter.defaultValue)
            let uiValue = currentSelectedParameter.engineToUi(engineValue)
            let uiBaseline = currentSelectedParameter.engineToUi(baselineEngine)
            parameterEditorView.configure(parameter: currentSelectedParameter, currentValue: uiValue, defaultValue: uiBaseline)
        }
        
        // 如果调整视图是展开状态，更新其显示的值
        if filterAdjustView.isExpanded {
            filterAdjustView.reloadData()
        }
        // 模板应用后基线已更新，清空修改标记
        refreshModifiedParameterBadges()
    }
}

// MARK: - SCFilterAdjustViewDelegate
extension SCPhotoPreviewVC: SCFilterAdjustViewDelegate {
    func filterAdjustView(_ view: SCFilterAdjustView, didUpdateParameter parameter: String, value: Float) {
        // 任意手动调整后，退出模板链，切回自定义链（保证参数调整立即生效）
        if filterView.filterTemplate != nil {
            filterView.filterTemplate = nil
        }
        // 使用统一的参数更新方法
        filterView.updateParameter(parameter, value: value)
        // 同步参数编辑器
        if let p = SCFilterParameter.allCases.first(where: { $0.key == parameter }) {
            currentSelectedParameter = p
            let baselineEngine = baselineParameters[p] ?? p.uiToEngine(p.defaultValue)
            let uiValue = p.engineToUi(value)
            let uiBaseline = p.engineToUi(baselineEngine)
            parameterEditorView.configure(parameter: p, currentValue: uiValue, defaultValue: uiBaseline)
        }
        refreshModifiedParameterBadges()
    }
    
    func filterAdjustView(_ view: SCFilterAdjustView, didChangeExpandState isExpanded: Bool) {
        // 更新调整按钮的显示状态
        adjustButton.isHidden = isExpanded
        
        // 展开/收起时同步 UI 层级与可交互性
        if isExpanded {
            let currentParameters = filterView.getCurrentParameters()
            filterAdjustView.updateParameters(currentParameters)
            // 抽屉展开：避免上方容器抢占触摸
            editContainerView.isUserInteractionEnabled = false
            editContainerView.alpha = 1.0
        } else {
            // 抽屉收起：恢复上方容器与当前视图
            filterAdjustView.isHidden = true
            editContainerView.isUserInteractionEnabled = true
            self.view.bringSubviewToFront(self.editContainerView)
            if currentSelectedParameter == .presetTemplates {
                self.editContainerView.bringSubviewToFront(self.filterOptionView)
                self.filterOptionView.isHidden = false
                self.parameterEditorView.isHidden = true
            } else {
                self.editContainerView.bringSubviewToFront(self.parameterEditorView)
                self.parameterEditorView.isHidden = false
                self.filterOptionView.isHidden = true
            }
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }
} 

// MARK: - SCParameterListViewDelegate
extension SCPhotoPreviewVC: SCParameterListViewDelegate {
    func parameterListView(_ view: SCParameterListView, didSelect parameter: SCFilterParameter) {
        currentSelectedParameter = parameter
        // 调试打印，确认命中逻辑
        print("[ParameterList] select: \(parameter.displayName)")
        print("[Container] editContainer frame=\(editContainerView.frame), filterOption alpha=\(filterOptionView.alpha) hidden=\(filterOptionView.isHidden), editor alpha=\(parameterEditorView.alpha) hidden=\(parameterEditorView.isHidden)")
        if parameter == .presetTemplates {
            // 展示预置滤镜列表
            self.view.bringSubviewToFront(self.parameterListView)
            self.view.bringSubviewToFront(self.editContainerView)
            self.editContainerView.bringSubviewToFront(self.filterOptionView)
            UIView.animate(withDuration: 0.25) {
                self.parameterEditorView.alpha = 0
                self.parameterEditorView.isHidden = true
                self.filterOptionView.alpha = 1
            }
            self.filterOptionView.isHidden = false
            self.filterOptionView.isUserInteractionEnabled = true
            self.filterOptionView.layer.zPosition = 0
            self.parameterEditorView.layer.zPosition = -1
            print("[ParameterList] show presets")
            self.editContainerView.isUserInteractionEnabled = true
        } else {
            // 切换到参数编辑视图（占据原预置滤镜区域）
            let key = parameter.key
            let currentParams = self.filterView.getCurrentParameters()
            // 引擎值 -> UI 值
            let engineDefault = parameter.uiToEngine(parameter.defaultValue)
            let engineCurrent: Float = (key != nil) ? (currentParams[key!] ?? engineDefault) : engineDefault
            let engineBaseline: Float = baselineParameters[parameter] ?? engineDefault
            let uiCurrent = parameter.engineToUi(engineCurrent)
            let uiBaseline = parameter.engineToUi(engineBaseline)
            parameterEditorView.configure(parameter: parameter, currentValue: uiCurrent, defaultValue: uiBaseline)
            // 确保编辑器在最前
            self.view.bringSubviewToFront(self.editContainerView)
            self.editContainerView.bringSubviewToFront(self.parameterEditorView)
            UIView.animate(withDuration: 0.25) {
                self.filterOptionView.alpha = 0
                self.parameterEditorView.isHidden = false
                self.parameterEditorView.alpha = 1
            }
            self.filterOptionView.isHidden = true
            self.filterOptionView.isUserInteractionEnabled = false
            self.filterOptionView.layer.zPosition = -1
            self.parameterEditorView.layer.zPosition = 1
            print("[ParameterList] show editor for: \(parameter.displayName), value=\(uiCurrent)")
            self.editContainerView.isUserInteractionEnabled = true
        }
        // 每次点击后保持参数列表在最前，保证命中
        self.view.bringSubviewToFront(self.parameterListView)
        print("[Z] parameterList top, z=\(parameterListView.layer.zPosition), filterOption z=\(filterOptionView.layer.zPosition), editor z=\(parameterEditorView.layer.zPosition)")
    }
    
    func parameterListView(_ view: SCParameterListView, didLongPress parameter: SCFilterParameter) {
        guard let key = parameter.key else { return }
        // 恢复单个参数为默认值
        let baseline = baselineParameters[parameter] ?? parameter.uiToEngine(parameter.defaultValue)
        filterView.updateParameter(key, value: baseline)
        if currentSelectedParameter == parameter {
            let uiBaseline = parameter.engineToUi(baseline)
            parameterEditorView.setExternalValue(uiBaseline)
        }
        // 清理历史/重做栈对应项
        parameterHistory[parameter] = []
        parameterRedoStack[parameter] = []
        refreshModifiedParameterBadges()
    }
}

// MARK: - SCParameterEditorViewDelegate
extension SCPhotoPreviewVC: SCParameterEditorViewDelegate {
    func parameterEditorView(_ view: SCParameterEditorView, didChange value: Float, for parameter: SCFilterParameter) {
        guard let key = parameter.key else { return }
        // value 为 UI 值，需转换为引擎值
        let engineNew = parameter.uiToEngine(value)
        // 入栈历史（存引擎值），清空重做栈
        var history = parameterHistory[parameter] ?? []
        let current = filterView.getCurrentParameters()[key] ?? 0
        if history.last != current { history.append(current) }
        parameterHistory[parameter] = history
        parameterRedoStack[parameter] = []
        // 应用
        filterView.updateParameter(key, value: engineNew)
    }

    func parameterEditorViewDidTapUndo(_ view: SCParameterEditorView, for parameter: SCFilterParameter) {
        guard let key = parameter.key else { return }
        var history = parameterHistory[parameter] ?? []
        guard let last = history.popLast() else { return }
        // 将当前值推入 redo 栈
        let current = filterView.getCurrentParameters()[key] ?? 0
        var redo = parameterRedoStack[parameter] ?? []
        redo.append(current)
        parameterRedoStack[parameter] = redo
        parameterHistory[parameter] = history
        // 应用撤销值
        let uiValue = parameter.engineToUi(last)
        parameterEditorView.setExternalValue(uiValue)
        filterView.updateParameter(key, value: last)
    }

    func parameterEditorViewDidTapRedo(_ view: SCParameterEditorView, for parameter: SCFilterParameter) {
        guard let key = parameter.key else { return }
        var redo = parameterRedoStack[parameter] ?? []
        guard let value = redo.popLast() else { return }
        // 当前值入历史
        let current = filterView.getCurrentParameters()[key] ?? 0
        var history = parameterHistory[parameter] ?? []
        history.append(current)
        parameterHistory[parameter] = history
        parameterRedoStack[parameter] = redo
        // 应用重做值
        let uiValue = parameter.engineToUi(value)
        parameterEditorView.setExternalValue(uiValue)
        filterView.updateParameter(key, value: value)
    }

    func parameterEditorViewDidTapSavePreset(_ view: SCParameterEditorView) {
        // 以当前所有参数保存为预设
        let params = filterView.getCurrentParameters()
        SCAlert.promptForText(
            title: "保存为预设",
            message: "请输入滤镜名称",
            placeholder: "自定义滤镜",
            defaultText: nil,
            cancelTitle: "取消",
            confirmTitle: "保存"
        ) { [weak self] confirmed, text in
            guard let self = self, confirmed, let name = text, !name.isEmpty else { return }
            do {
                _ = try SCCustomFilterManager.shared.saveFilter(name: name, parameters: params)
                let customTemplates = SCCustomFilterManager.shared.allFilters().map { $0.toTemplate() }
                self.filterOptionView.templates = SCFilterTemplate.templates + customTemplates
                SwiftMessages.showSuccessMessage("已保存为预设滤镜：\(name)", title: "保存成功")
            } catch {
                SCAlert.show(title: "保存失败", message: error.localizedDescription, style: .error, cancelTitle: "", confirmTitle: "确定") { _ in }
            }
        }
    }
}

// MARK: - Modified badges
private extension SCPhotoPreviewVC {
    /// 捕获当前图片的参数作为基线
    func captureBaselineParameters() {
        let currentParams = filterView.getCurrentParameters() // 引擎值
        var map: [SCFilterParameter: Float] = [:]
        for p in SCFilterParameter.allCases {
            guard let key = p.key else { continue }
            let engineDefault = p.uiToEngine(p.defaultValue)
            map[p] = currentParams[key] ?? engineDefault
        }
        baselineParameters = map
    }
    func refreshModifiedParameterBadges() {
        let params = filterView.getCurrentParameters()
        var modified = Set<SCFilterParameter>()
        for p in SCFilterParameter.allCases {
            guard let key = p.key else { continue }
            let currentEngine = params[key] ?? 0
            let baselineEngine = baselineParameters[p] ?? 0
            if abs(currentEngine - baselineEngine) > Float.ulpOfOne { modified.insert(p) }
        }
        parameterListView.setModifiedParameters(modified)
    }

    @objc func handleResetAll() {
        // 将所有参数恢复到基线
        for p in SCFilterParameter.allCases {
            guard let key = p.key else { continue }
            let baseline = baselineParameters[p] ?? p.uiToEngine(p.defaultValue)
            filterView.updateParameter(key, value: baseline)
            // 清理历史/重做
            parameterHistory[p] = []
            parameterRedoStack[p] = []
        }
        // 同步当前编辑器
        if let key = currentSelectedParameter.key {
            let baseline = baselineParameters[currentSelectedParameter] ?? currentSelectedParameter.uiToEngine(currentSelectedParameter.defaultValue)
            let uiBaseline = currentSelectedParameter.engineToUi(baseline)
            parameterEditorView.setExternalValue(uiBaseline)
        }
        refreshModifiedParameterBadges()
    }
}
