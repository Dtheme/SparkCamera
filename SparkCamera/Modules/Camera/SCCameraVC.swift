//
//  SCCameraVC.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import SnapKit
import SwiftMessages
import AVFoundation
import CoreMotion

class SCCameraVC: UIViewController {
    
    // MARK: - Properties
    private var photoSession: SCPhotoSession!
    private var previewView: SCPreviewView!
    private var cameraManager: SCCameraManager!
    private lazy var lensSelectorView = SCLensSelectorView()
    private let motionManager = CMMotionManager()
    private var horizontalIndicator = SCHorizontalIndicatorView()
    private var isHorizontalIndicatorVisible = false
    private var lastScale: CGFloat = 1.0
    
    // 新增属性来存储可用镜头选项
    private var availableLensOptions: [SCLensModel] = []
    
    private var loadingView: SCLoadingView?
    private var isConfiguring = false
    
    // MARK: - UI Components
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        return button
    }()
    
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.systemBlue.cgColor
        return button
    }()
    
    private lazy var switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        return button
    }()
    
    private lazy var focusView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.yellow.cgColor
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    private lazy var zoomIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.layer.cornerRadius = 15
        view.isHidden = true
        return view
    }()
    
    private lazy var zoomLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 15
        label.clipsToBounds = true
        return label
    }()
    
    private lazy var livePhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "livephoto"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(toggleLivePhoto), for: .touchUpInside)
        return button
    }()
    
    private lazy var toolBar: SCCameraToolBar = {
        let toolBar = SCCameraToolBar()
        toolBar.delegate = self
        return toolBar
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        // 显示加载状态
        showLoading()
        
        // 初始化预览视图
        previewView = SCPreviewView(frame: view.bounds)
        view.addSubview(previewView)
        
        // 设置 UI
        setupUI()
        setupConstraints()
        
        // 设置水平指示器和手势
        setupHorizontalIndicator()
        setupGestures()
        
        // 设置按钮事件
        setupActions()
        
        // 检查相机权限
        checkCameraPermission()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 在视图完全显示后启动会话
        if photoSession?.session.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.photoSession?.startSession()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        photoSession?.stopSession()
    }
    
    private func setupHorizontalIndicator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 确保水平指示器在最上层
            self.previewView.bringSubviewToFront(self.horizontalIndicator)
            
            // 更新约束
            self.horizontalIndicator.snp.remakeConstraints { make in
                make.center.equalToSuperview()  // 相对于预览视图居中
                make.width.equalTo(200)
                make.height.equalTo(4)
            }
            
            if self.motionManager.isDeviceMotionAvailable {
                self.motionManager.deviceMotionUpdateInterval = 0.1
            }
        }
    }

    private func setupGestures() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.toggleHorizontalIndicator))
            doubleTapGesture.numberOfTapsRequired = 2
            self.view.addGestureRecognizer(doubleTapGesture)
            
            let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleSingleTap))
            singleTapGesture.require(toFail: doubleTapGesture)
            self.view.addGestureRecognizer(singleTapGesture)
            
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch))
            self.view.addGestureRecognizer(pinchGesture)
        }
    }

    @objc private func handleSingleTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: view)
        showFocusAnimation(at: location)
        
        if let focusPoint = previewView.previewLayer?.captureDevicePointConverted(fromLayerPoint: location) {
            photoSession.focus(at: focusPoint)
        }
    }

    @objc private func handlePinch(recognizer: UIPinchGestureRecognizer) {
        guard let device = photoSession.videoInput?.device else { return }
        
        switch recognizer.state {
        case .began:
            lastScale = previewView.currentZoomFactor
        case .changed:
            let scale = recognizer.scale
            let newZoomFactor = min(previewView.maxZoomFactor, max(1.0, lastScale * scale))
            print("Attempting to set new zoom factor: \(newZoomFactor)")

            //打印photoSession.videoInput的信息
            print("videoInput: \(String(describing: photoSession.videoInput))")
            print("videoInput.device: \(String(describing: photoSession.videoInput?.device))")
            print("videoInput.device.position: \(String(describing: photoSession.videoInput?.device.position))")
            print("videoInput.device.focusMode: \(String(describing: photoSession.videoInput?.device.focusMode))")
            print("videoInput.device.exposureMode: \(String(describing: photoSession.videoInput?.device.exposureMode))")
            print("videoInput.device.focusPointOfInterest: \(String(describing: photoSession.videoInput?.device.focusPointOfInterest))")
            print("videoInput.device.exposurePointOfInterest: \(String(describing: photoSession.videoInput?.device.exposurePointOfInterest))")
            print("videoInput.device.focusMode: \(String(describing: photoSession.videoInput?.device.focusMode))")
            print("videoInput.device.exposureMode: \(String(describing: photoSession.videoInput?.device.exposureMode))")
            print("videoInput.device.focusPointOfInterest: \(String(describing: photoSession.videoInput?.device.focusPointOfInterest))")
            print("videoInput.device.exposurePointOfInterest: \(String(describing: photoSession.videoInput?.device.exposurePointOfInterest))")

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoomFactor
                device.unlockForConfiguration()
                
                previewView.currentZoomFactor = newZoomFactor
                DispatchQueue.main.async {
                    self.zoomLabel.text = String(format: "%.1fx", self.previewView.currentZoomFactor)
                    print("Pinch gesture changed, new zoom factor: \(self.previewView.currentZoomFactor)")
                }
                
                photoSession.delegate?.didChangeValue(session: photoSession, value: previewView.currentZoomFactor, key: "zoom")
            } catch {
                print("Error setting zoom: \(error.localizedDescription)")
            }
        default:
            break
        }
    }

    @objc private func toggleHorizontalIndicator() {
        isHorizontalIndicatorVisible.toggle()
        horizontalIndicator.isHidden = !isHorizontalIndicatorVisible

        if isHorizontalIndicatorVisible {
            // 开启水平仪时开始更新
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let motion = motion else { return }
                let rotation = atan2(motion.gravity.x, motion.gravity.y) - .pi
                self?.horizontalIndicator.updateRotation(angle: CGFloat(rotation))
            }
        } else {
            // 关闭水平仪时停止更新
            motionManager.stopDeviceMotionUpdates()
        }

        let message = isHorizontalIndicatorVisible ? "水平仪已开启" : "水平仪已关闭"
        print(message)
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(isHorizontalIndicatorVisible ? .success : .warning)
        view.configureContent(title: "提示", body: message)
        SwiftMessages.show(view: view)
        
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
    }
    
    // MARK: - Setup
    private func checkCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            if granted {
                DispatchQueue.main.async {
                    self?.setupCamera()
                }
            } else {
                DispatchQueue.main.async {
                    self?.showPermissionDeniedAlert()
                }
            }
        }
    }
    
    private func setupCamera() {
        let startTime = Date()
        print("⏱️ [Camera Setup] Starting camera setup")
        
        // 1. 初始化相机会话
        photoSession = SCPhotoSession()
        photoSession.delegate = self
        print("⏱️ [Camera Setup] PhotoSession initialized: +\(Date().timeIntervalSince(startTime))s")
        
        // 2. 初始化相机管理器
        cameraManager = SCCameraManager(session: photoSession, photoSession: photoSession)
        print("⏱️ [Camera Setup] CameraManager initialized: +\(Date().timeIntervalSince(startTime))s")
        
        // 3. 配置预览视图
        previewView.session = photoSession
        previewView.autorotate = true
        print("⏱️ [Camera Setup] PreviewView configured: +\(Date().timeIntervalSince(startTime))s")
        
        // 4. 设置镜头选择器
        setupLensSelector()
        print("⏱️ [Camera Setup] Lens selector setup: +\(Date().timeIntervalSince(startTime))s")
        
        // 5. 启动相机会话
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.photoSession.startSession()
            
            // 确保在主线程更新 UI
            DispatchQueue.main.async {
                self.hideLoading()
                print("⏱️ [Camera Setup] Setup completed: +\(Date().timeIntervalSince(startTime))s")
            }
        }
    }
    
    private func setupUI() {
        // 1. 添加预览视图
        view.addSubview(previewView)
        
        // 2. 添加关闭按钮
        view.addSubview(closeButton)
        
        // 3. 添加工具栏
        view.addSubview(toolBar)
        
        // 初始化工具栏项目
        let toolItems: [SCToolItem] = [
            SCToolItem(type: .flash),
            SCToolItem(type: .ratio),
            SCToolItem(type: .whiteBalance),
            SCToolItem(type: .exposure),
            SCToolItem(type: .iso),
            SCToolItem(type: .timer)
        ]
        toolBar.setItems(toolItems)
        
        // 4. 添加切换相机按钮
        view.addSubview(switchCameraButton)
        
        // 5. 添加实况照片按钮
        view.addSubview(livePhotoButton)
        
        // 6. 添加拍照按钮
        view.addSubview(captureButton)
        
        // 7. 添加变焦指示器和标签
        view.addSubview(zoomIndicatorView)
        zoomIndicatorView.addSubview(zoomLabel)
        
        // 8. 添加对焦框
        view.addSubview(focusView)
        
        // 9. 添加镜头选择器
        view.addSubview(lensSelectorView)
        
        // 10. 添加水平指示器 - 确保添加到预览视图上
        previewView.addSubview(horizontalIndicator)
        
        // 设置初始状态
        zoomIndicatorView.isHidden = true
        focusView.isHidden = true
        horizontalIndicator.isHidden = !isHorizontalIndicatorVisible
    }
    
    private func setupConstraints() {
        // 1. 基础控制按钮
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.left.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.width.height.equalTo(44)
        }
        
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-30)
            make.width.height.equalTo(70)
        }
        
        switchCameraButton.snp.makeConstraints { make in
            make.right.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.centerY.equalTo(captureButton)
            make.width.height.equalTo(44)
        }
        
        // 2. 工具栏
        toolBar.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(captureButton.snp.top).offset(-20)
            make.width.equalTo(UIScreen.main.bounds.width)
            make.height.equalTo(80)
        }
        
        // 3. 预览视图
        previewView.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(20)
            make.left.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(-10)
            make.bottom.equalTo(toolBar.snp.top).offset(-10)
            // 设置 4:3 比例
            make.height.equalTo(previewView.snp.width).multipliedBy(4.0/3.0).priority(.high)
        }
        
        // 4. 功能按钮
        livePhotoButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)  // 与 closeButton 同高
            make.right.equalTo(view.safeAreaLayoutGuide).offset(-20)  // 右边距
            make.width.height.equalTo(44)  // 保持原有尺寸
        }
        
        // 5. 指示器
        zoomIndicatorView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
        
        zoomLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5))
        }
        
        // 6. 水平指示器
        horizontalIndicator.snp.makeConstraints { make in
            make.center.equalTo(previewView)
            make.width.equalTo(200)
            make.height.equalTo(4)
        }
    }
    
    private func setupActions() {
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        livePhotoButton.addTarget(self, action: #selector(toggleLivePhoto), for: .touchUpInside)
    }
    
    private func setupLensSelector() {
        let startTime = Date()
        print("⏱️ [Lens Setup] Started at: \(startTime)")
        
        cameraManager.getAvailableLensOptions { [weak self] lensOptions in
            print("⏱️ [Lens Setup] Options received: +\(Date().timeIntervalSince(startTime))s")
            guard let self = self else { return }
            
            // 更新 availableLensOptions 属性
            self.availableLensOptions = lensOptions
            
            // 确保有可用的镜头选项
            guard !self.availableLensOptions.isEmpty else {
                print("⏱️ [Lens Setup] No available options: +\(Date().timeIntervalSince(startTime))s")
                return
            }
            
            // 对镜头选项进行排序：超广角、广角、长焦
            self.availableLensOptions.sort { (lens1, lens2) -> Bool in
                let order: [AVCaptureDevice.DeviceType] = [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera]
                guard let index1 = order.firstIndex(of: lens1.type),
                      let index2 = order.firstIndex(of: lens2.type) else {
                    return false
                }
                return index1 < index2
            }
            print("⏱️ [Lens Setup] Options sorted: +\(Date().timeIntervalSince(startTime))s")
            
            // 打印获取到的镜头信息
            for lens in self.availableLensOptions {
                print("⏱️ [Lens Setup] Found lens: \(lens.name), Type: \(lens.type)")
            }
            
            // 设置默认选中的镜头为 1.0x
            let defaultLens = self.availableLensOptions.first(where: { $0.name == "1x" })
            
            // 更新 lensSelectorView 的显示内容并设置默认选中
            self.lensSelectorView.updateLensOptions(self.availableLensOptions, currentLens: defaultLens)
            print("⏱️ [Lens Setup] UI updated: +\(Date().timeIntervalSince(startTime))s")
            
            // 更新布局
            self.view.addSubview(self.lensSelectorView)
            self.lensSelectorView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalTo(self.previewView.snp.bottom).offset(-20)
                make.height.equalTo(50)
                make.width.equalTo(200)
            }
            print("⏱️ [Lens Setup] Layout completed: +\(Date().timeIntervalSince(startTime))s")
            
            // 设置镜头选择回调
            self.lensSelectorView.onLensSelected = { [weak self] lensName in
                guard let self = self else { return }
                guard let lens = self.availableLensOptions.first(where: { $0.name == lensName }) else { return }
                self.handleLensSelection(lens)
            }
        }
    }
    
    private func handleLensSelection(_ lens: SCLensModel) {
        cameraManager.switchCamera(to: lens) { [weak self] message in
            DispatchQueue.main.async {
                self?.showCameraSwitchMessage(message)
            }
        }
    }
    
    // MARK: - Actions
    @objc private func close() {
        dismiss(animated: true)
    }
    
    @objc private func capturePhoto() {
        // 拍照并处理结果
        self.photoSession.capture({ [weak self] image, _ in
            guard let self = self else { return }
            
            // 在拍照完成后执行按钮的缩放动画
            UIView.animate(withDuration: 0.1, animations: {
                self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    self.captureButton.transform = .identity
                }
            }
            
            // 创建一个白色的闪光视图
            let flashView = UIView(frame: self.view.bounds)
            flashView.backgroundColor = .white
            flashView.alpha = 0
            self.view.addSubview(flashView)
            
            // 淡入淡出和缩放动画
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: {
                flashView.alpha = 0.8
                flashView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }) { _ in
                UIView.animate(withDuration: 0.2, delay: 0.1, options: [.curveEaseInOut], animations: {
                    flashView.alpha = 0
                    flashView.transform = .identity
                }) { _ in
                    flashView.removeFromSuperview()
                    
                    // 跳转到预览页
                    self.handleCapturedImage(image)
                }
            }
        }, { [weak self] error in
            self?.showError(error)
        })
    }
    
    @objc private func switchCamera() {
        let isCurrentlyBackCamera = cameraManager.currentCameraPosition == .back
        let newLens: SCLensModel
        
        if isCurrentlyBackCamera {
            newLens = SCLensModel(name: "Front", type: .builtInWideAngleCamera)
        } else {
            // 切换回后置摄像头时，恢复到前一次选中的镜头
            newLens = cameraManager.getLastSelectedLens() ?? SCLensModel(name: "1x", type: .builtInWideAngleCamera)
        }
        
        cameraManager.switchCamera(to: newLens) { [weak self] message in
            DispatchQueue.main.async {
                self?.showCameraSwitchMessage(message)
                
                // 触觉反馈
                let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
                feedbackGenerator.impactOccurred()
                
                // 只有在成功切换到前置摄像头时才隐藏 lensSelectorView
                if newLens.name == "Front" {
                    UIView.animate(withDuration: 0.3, animations: {
                        self?.lensSelectorView.alpha = 0
                        self?.lensSelectorView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                    }) { _ in
                        self?.lensSelectorView.isHidden = true
                    }
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        self?.lensSelectorView.alpha = 1
                        self?.lensSelectorView.transform = .identity
                    }) { _ in
                        self?.lensSelectorView.isHidden = false
                    }
                }
            }
        }
    }
    
    @objc private func toggleLivePhoto() {
        // 实现实况照片功能
        let item = SCToolItem(type: .livePhoto)
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.info)
        view.configureContent(title: "提示", body: "Live Photo 功能待开发")
        SwiftMessages.show(view: view)
    }
    
    // MARK: - Helpers
    private func handleCapturedImage(_ image: UIImage) {
        let photoPreviewVC = SCPhotoPreviewVC(image: image)
        photoPreviewVC.modalPresentationStyle = .fullScreen
        
        // 使用自定义转场动画
        let transition = CATransition()
        transition.duration = 0.5
        transition.type = .fade
        transition.subtype = .fromRight
        view.window?.layer.add(transition, forKey: kCATransition)
        
        present(photoPreviewVC, animated: false)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showError(error)
        } else {
            showSuccess("照片已保存到相册")
        }
    }
    
    private func showPermissionDeniedAlert() {
        let alert = UIAlertController(
            title: "无法访问相机",
            message: "请在设置中允许访问相机",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.error)
        view.configureContent(title: "错误", body: error.localizedDescription)
        SwiftMessages.show(view: view)
    }
    
    private func showSuccess(_ message: String) {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.success)
        view.configureContent(title: "成功", body: message)
        SwiftMessages.show(view: view)
    }
    
    private func showFocusAnimation(at point: CGPoint) {
        focusView.center = point
        focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusView.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            self.focusView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0.5) {
                self.focusView.isHidden = true
            }
        }
    }
    
    private func showCameraSwitchMessage(_ message: String) {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.success)
        view.configureContent(title: "镜头切换", body: message)
        SwiftMessages.show(view: view)
    }
    
    // 禁用所有控件
    private func setControlsEnabled(_ enabled: Bool) {
        [captureButton, switchCameraButton, livePhotoButton].forEach {
            $0.isEnabled = enabled
            $0.alpha = enabled ? 1.0 : 0.5
        }
    }
    
    private func showLoading() {
        loadingView = SCLoadingView(message: "Camera configuration loading...")
        loadingView?.show(in: view)
        setControlsEnabled(false)
        // 保持关闭按钮可用
        closeButton.isEnabled = true
        closeButton.alpha = 1.0
    }
    
    private func hideLoading() {
        loadingView?.dismiss()
        loadingView = nil
        setControlsEnabled(true)
    }
    
    // MARK: - Animation Helpers
    private func animateToolBarExpand() {
        UIView.animate(withDuration: 0.3, animations: {
            self.toolBar.transform = .identity
            self.toolBar.alpha = 1
        })
    }
    
    private func animateToolBarCollapse() {
        UIView.animate(withDuration: 0.3, animations: {
            self.toolBar.transform = CGAffineTransform(translationX: 0, y: 100)
            self.toolBar.alpha = 0
        })
    }
    
    private func animateControlsForToolBarExpand() {
        UIView.animate(withDuration: 0.3, animations: {
            self.captureButton.transform = .identity
            self.switchCameraButton.transform = .identity
            self.livePhotoButton.transform = .identity
            self.captureButton.alpha = 1
            self.switchCameraButton.alpha = 1
            self.livePhotoButton.alpha = 1
        })
    }
    
    private func animateControlsForToolBarCollapse() {
        UIView.animate(withDuration: 0.3, animations: {
            self.captureButton.transform = CGAffineTransform(translationX: 0, y: 100)
            self.switchCameraButton.transform = CGAffineTransform(translationX: 0, y: 100)
            self.livePhotoButton.transform = CGAffineTransform(translationX: 0, y: 100)
            self.captureButton.alpha = 0
            self.switchCameraButton.alpha = 0
            self.livePhotoButton.alpha = 0
        })
    }
}

// MARK: - SCSessionDelegate
extension SCCameraVC: SCSessionDelegate {
    func didChangeValue(session: SCSession, value: Any, key: String) {
        if key == "zoom", let zoomValue = value as? Double {
            // 更新变焦指示器
            zoomLabel.text = String(format: "%.1fx", zoomValue)
            
            // 显示变焦指示器
            if zoomIndicatorView.isHidden {
                zoomIndicatorView.alpha = 0
                zoomIndicatorView.isHidden = false
                UIView.animate(withDuration: 0.2) {
                    self.zoomIndicatorView.alpha = 1
                }
            }
            
            // 延迟隐藏变焦指示器
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideZoomIndicator), object: nil)
            perform(#selector(hideZoomIndicator), with: nil, afterDelay: 1.5)
        }
    }
    
    // 将 hideZoomIndicator 方法移到 extension 内部
    @objc private func hideZoomIndicator() {
        UIView.animate(withDuration: 0.2) {
            self.zoomIndicatorView.alpha = 0
        } completion: { _ in
            self.zoomIndicatorView.isHidden = true
        }
    }
}

// MARK: - SCCameraToolBarDelegate
extension SCCameraVC: SCCameraToolBarDelegate {
    func toolBar(_ toolBar: SCCameraToolBar, didSelect item: SCToolItem) {
        // 处理工具项选择
        switch item.type {
        case .flash:
            if let flashState = item.state as? SCFlashState {
                photoSession.setFlashMode(flashState.avFlashMode)
            }
        case .livePhoto:
            // 实况照片功能待实现
            SwiftMessages.showInfoMessage("实况照片功能待开发")
        default:
            break
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didExpand item: SCToolItem) {
        // 处理工具项展开
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
            // 隐藏拍照按钮和其他控制按钮
            self.captureButton.transform = CGAffineTransform(translationX: 0, y: 100)
            self.switchCameraButton.transform = CGAffineTransform(translationX: 0, y: 100)
            self.livePhotoButton.transform = CGAffineTransform(translationX: 0, y: 100)
            
            self.captureButton.alpha = 0
            self.switchCameraButton.alpha = 0
            self.livePhotoButton.alpha = 0
        })
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didCollapse item: SCToolItem) {
        // 处理工具项收起
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
            // 显示拍照按钮和其他控制按钮
            self.captureButton.transform = .identity
            self.switchCameraButton.transform = .identity
            self.livePhotoButton.transform = .identity
            
            self.captureButton.alpha = 1
            self.switchCameraButton.alpha = 1
            self.livePhotoButton.alpha = 1
        })
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, willAnimate item: SCToolItem) {
        // 处理工具项动画开始
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didFinishAnimate item: SCToolItem) {
        // 处理工具项动画结束
        // 可以在这里添加额外的动画完成后的逻辑
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didSelect option: String, for item: SCToolItem) {
        // 处理选项选择
        switch item.type {
        case .flash:
            if let flashState = item.state as? SCFlashState {
                photoSession.setFlashMode(flashState.avFlashMode)
                SwiftMessages.showInfoMessage("闪光灯模式：\(option)")
            }
        case .livePhoto:
            // 实况照片功能待实现
            SwiftMessages.showInfoMessage("实况照片功能待开发")
        case .ratio:
            if let ratioState = item.state as? SCRatioState {
                // 设置预览比例
                UIView.animate(withDuration: 0.3) {
                    self.previewView.snp.updateConstraints { make in
                        make.height.equalTo(self.previewView.snp.width).multipliedBy(ratioState.aspectRatio).priority(.high)
                    }
                    self.view.layoutIfNeeded()
                }
                SwiftMessages.showInfoMessage("预览比例：\(option)")
            }
        case .whiteBalance:
            if let whiteBalanceState = item.state as? SCWhiteBalanceState {
                // 设置白平衡
                guard let device = photoSession.videoInput?.device else { return }
                do {
                    try device.lockForConfiguration()
                    if device.isWhiteBalanceModeSupported(.locked) {
                        let whiteBalanceGains = try device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: whiteBalanceState.temperature, tint: 0))
                        device.setWhiteBalanceModeLocked(with: whiteBalanceGains)
                    }
                    device.unlockForConfiguration()
                    SwiftMessages.showInfoMessage("白平衡：\(option)")
                } catch {
                    print("设置白平衡失败: \(error)")
                }
            }
        case .exposure:
            if let exposureState = item.state as? SCExposureState {
                // 设置曝光补偿
                guard let device = photoSession.videoInput?.device else { return }
                do {
                    try device.lockForConfiguration()
                    device.setExposureTargetBias(exposureState.value)
                    device.unlockForConfiguration()
                    SwiftMessages.showInfoMessage("曝光补偿：\(option)")
                } catch {
                    print("设置曝光补偿失败: \(error)")
                }
            }
        case .iso:
            if let isoState = item.state as? SCISOState {
                // 设置 ISO
                guard let device = photoSession.videoInput?.device else { return }
                do {
                    try device.lockForConfiguration()
                    if isoState.value == 0 {
                        device.exposureMode = .continuousAutoExposure
                    } else {
                        let minISO = device.activeFormat.minISO
                        let maxISO = device.activeFormat.maxISO
                        let clampedISO = max(minISO, min(maxISO, isoState.value))
                        device.setExposureModeCustom(duration: device.exposureDuration, iso: clampedISO)
                    }
                    device.unlockForConfiguration()
                    SwiftMessages.showInfoMessage("ISO：\(option)")
                } catch {
                    print("设置 ISO 失败: \(error)")
                }
            }
        case .timer:
            if let timerState = item.state as? SCTimerState {
                SwiftMessages.showInfoMessage("定时器：\(option)")
            }
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didToggleState item: SCToolItem) {
        // 处理状态切换
        switch item.type {
        case .flash:
            if let flashState = item.state as? SCFlashState {
                photoSession.setFlashMode(flashState.avFlashMode)
                SwiftMessages.showInfoMessage("闪光灯模式：\(flashState.title)")
            }
        case .livePhoto:
            // 实况照片功能待实现
            SwiftMessages.showInfoMessage("实况照片功能待开发")
        default:
            break
        }
    }
} 

