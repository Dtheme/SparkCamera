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
import Photos

class SCCameraVC: UIViewController {
    
    // MARK: - Properties
    internal var photoSession: SCPhotoSession!
    internal var previewView: SCPreviewView!
    private var cameraManager: SCCameraManager!
    private lazy var lensSelectorView = SCLensSelectorView()
    private let motionManager = CMMotionManager()
    private var horizontalIndicator = SCHorizontalIndicatorView()
    private var isHorizontalIndicatorVisible = false
    private var lastScale: CGFloat = 1.0
    private var pendingTimerState: SCTimerState?
    
    // 新增属性来存储可用镜头选项
    private var availableLensOptions: [SCLensModel] = []
    
    private var loadingView: SCLoadingView?
    private var isConfiguring = false
    
    // 添加选项视图高度常量
    private let optionsViewHeight: CGFloat = 80
    
    private var countdownTimer: Timer?
    private var remainingSeconds: Int = 0
    
    private lazy var countdownLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 120, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.alpha = 1
        label.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        return label
    }()
    
    // 添加自动保存按钮
    private lazy var autoSaveButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "square.and.arrow.down", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(toggleAutoSave), for: .touchUpInside)
        return button
    }()
    
    // MARK: - UI Components
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        return button
    }()
    
    internal lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 3
        button.layer.borderColor = SCConstants.themeColor.cgColor
        return button
    }()
    
    internal lazy var switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        return button
    }()
    
    private lazy var focusBoxView: SCFocusBoxView = {
        let view = SCFocusBoxView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        view.isHidden = true
        return view
    }()
    
    internal lazy var zoomLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .center
        label.backgroundColor = .clear
        return label
    }()
    
    internal lazy var zoomIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.layer.cornerRadius = 15
        view.isHidden = true
        return view
    }()
    
    internal lazy var livePhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "livephoto"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(toggleLivePhoto), for: .touchUpInside)
        return button
    }()
    
    internal lazy var toolBar: SCCameraToolBar = {
        let toolBar = SCCameraToolBar()
        toolBar.delegate = self
        return toolBar
    }()
    
    // MARK: - Focus UI
//    private lazy var focusModeButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setImage(UIImage(systemName: "camera.focus"), for: .normal)
//        button.tintColor = .white
//        button.addTarget(self, action: #selector(focusModeButtonTapped), for: .touchUpInside)
//        return button
//    }()
    
    internal lazy var gridButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "grid"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(toggleGrid), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        // 显示加载状态
        showLoading()
        
        // 初始化预览视图（不重复在 setupUI 内再次创建）
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
        // 在视图完全显示后，若已拥有会话但未运行，则启动；若还未创建会话，等待权限回调中的 setupCamera
        if let session = photoSession, session.session.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak session] in
                session?.startSession()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 停止倒计时
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        // 停止水平指示器
        motionManager.stopDeviceMotionUpdates()
        
        // 停止会话但不销毁对象，避免快速返回时重复重建；真正释放在 deinit
        if let session = photoSession {
            session.stopSession()
        }
    }
    // 禁止该视图控制器旋转
    override var shouldAutorotate: Bool {
        return false
    }

    // 限制该视图控制器支持的方向
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait // 仅支持竖屏
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
            self.previewView.addGestureRecognizer(doubleTapGesture)
            
            let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleSingleTap))
            singleTapGesture.require(toFail: doubleTapGesture)
            self.previewView.addGestureRecognizer(singleTapGesture)
            
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch))
            self.previewView.addGestureRecognizer(pinchGesture)
        }
    }

    @objc private func handleSingleTap(recognizer: UITapGestureRecognizer) {
        let locationInPreview = recognizer.location(in: previewView)
        guard let previewLayer = previewView.previewLayer else { return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: locationInPreview)
        photoSession.focus(at: devicePoint)
        print("  [Focus] 点击位置: \(locationInPreview), 设备坐标: \(devicePoint)")
    }

    @objc private func handlePinch(recognizer: UIPinchGestureRecognizer) {
        guard let device = photoSession.videoInput?.device else { return }
        
        switch recognizer.state {
        case .began:
            lastScale = previewView.currentZoomFactor
        case .changed:
            let scale = recognizer.scale
            let newZoomFactor = min(previewView.maxZoomFactor, max(1.0, lastScale * scale))

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoomFactor
                device.unlockForConfiguration()
                
                previewView.currentZoomFactor = newZoomFactor
                DispatchQueue.main.async {
                    self.zoomLabel.text = String(format: "%.1fx", self.previewView.currentZoomFactor)
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
        print("⏱️ [Camera Setup] Starting camera setup")
        
        // 确保在主线程进行初始化
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 1. 初始化或复用相机会话
            if self.photoSession == nil {
                self.photoSession = SCPhotoSession()
                self.photoSession.delegate = self
            } else {
                self.photoSession.delegate = self
            }
            
            // 2. 初始化相机管理器
            self.cameraManager = SCCameraManager(session: self.photoSession, photoSession: self.photoSession)
            
            // 3. 配置预览视图
            self.previewView.session = self.photoSession
            self.previewView.autorotate = true
            
            // 4. 设置当前设备到 SCCameraSettingsManager
            if let device = AVCaptureDevice.default(for: .video) {
                SCCameraSettingsManager.shared.setCurrentDevice(device)
            }
            
            // 5. 设置镜头选择器
            self.setupLensSelector()
            
            // 6. 检查并设置闪光灯初始状态
            self.setupFlashState()
            
            // 7. 在后台线程启动相机会话（若尚未运行）
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self, let session = self.photoSession else { return }
                if session.session.isRunning == false {
                    session.startSession()
                }
                // 8. 在主线程更新 UI
                DispatchQueue.main.async { self.hideLoading() }
            }
        }
    }
    
    private func setupUI() {
        // 1. 初始化基础组件（避免重复创建 photoSession 与 previewView）
        if photoSession == nil {
            photoSession = SCPhotoSession()
            photoSession?.delegate = self
        }
        if previewView.superview == nil {
            view.addSubview(previewView)
        }
        previewView.session = photoSession
        
        // 2. 设置预览比例和分辨率
        let ratioState = SCRatioState(rawValue: SCCameraSettingsManager.shared.ratioMode) ?? .ratio4_3
        updateAspectRatio(ratioState)
        
        // 3. 添加 UI 控件
        view.addSubview(closeButton)
        view.addSubview(toolBar)
        toolBar.delegate = self
        
        // 4. 初始化工具栏项目
        setupToolBarItems()
        
        // 5. 添加其他控件
        view.addSubview(switchCameraButton)
        view.addSubview(livePhotoButton)
        view.addSubview(captureButton)
        view.addSubview(gridButton)
        view.addSubview(zoomIndicatorView)
        zoomIndicatorView.addSubview(zoomLabel)
        previewView.addSubview(focusBoxView)
        view.addSubview(lensSelectorView)
        previewView.addSubview(horizontalIndicator)
        
        // 6. 设置初始状态
        zoomIndicatorView.isHidden = true
        focusBoxView.isHidden = true
        horizontalIndicator.isHidden = !isHorizontalIndicatorVisible
        
        view.addSubview(autoSaveButton)
        updateAutoSaveButtonState()
        
        // 8. 更新网格按钮状态
        gridButton.tintColor = previewView.showGrid ? SCConstants.themeColor : .white
    }
    
    // 将工具栏项目设置移到单独的方法
    private func setupToolBarItems() {
        // 获取保存的设置状态
        let flashState = SCFlashState(rawValue: SCCameraSettingsManager.shared.flashMode) ?? .auto
        let ratioState = SCRatioState(rawValue: SCCameraSettingsManager.shared.ratioMode) ?? .ratio4_3
        let whiteBalanceState = SCWhiteBalanceState(rawValue: SCCameraSettingsManager.shared.whiteBalanceMode) ?? .auto
        
        // 获取保存的曝光值
        let savedExposureValue = SCCameraSettingsManager.shared.exposureValue
        let exposureStates: [SCExposureState] = [.negative2, .negative1, .zero, .positive1, .positive2]
        let exposureState = exposureStates.first { $0.value == savedExposureValue } ?? .zero
        
        // 获取保存的 ISO 值
        let savedISOValue = SCCameraSettingsManager.shared.isoValue
        let isoStates: [SCISOState] = [.auto, .iso100, .iso200, .iso400, .iso800]
        let isoState = isoStates.first { $0.value == savedISOValue } ?? .auto
        
        let timerState = SCTimerState(rawValue: SCCameraSettingsManager.shared.timerMode) ?? .off
        let shutterSpeedState = SCShutterSpeedState(rawValue: SCCameraSettingsManager.shared.shutterSpeedValue) ?? .auto
        
        // 初始化工具项
        let toolItems = [
            createToolItem(type: SCToolType.flash, state: flashState),
            createToolItem(type: SCToolType.ratio, state: ratioState),
            createToolItem(type: SCToolType.whiteBalance, state: whiteBalanceState),
            createToolItem(type: SCToolType.exposure, state: exposureState),
            createToolItem(type: SCToolType.iso, state: isoState),
            createToolItem(type: SCToolType.shutterSpeed, state: shutterSpeedState),
            createToolItem(type: SCToolType.timer, state: timerState)
        ]
        
        toolBar.setItems(toolItems)
    }
    
    private func createToolItem<T: SCToolState>(type: SCToolType, state: T) -> SCToolItem {
        let item = SCToolItem(type: type)
        item.setState(state)
        item.isSelected = false
        return item
    }
    
    internal func updatePreviewRatio(_ ratio: CGFloat) {
        // 先移除预览视图的所有约束
        previewView.snp.removeConstraints()
        
        // 重新设置预览视图约束
        previewView.snp.remakeConstraints { make in
            make.width.equalTo(UIScreen.main.bounds.width)
            make.centerX.equalToSuperview()
            
            // 根据比例调整位置
            if ratio == 16.0 / 9.0 {
                // 16:9 模式下垂直居中
                make.centerY.equalToSuperview()
                make.height.equalTo(previewView.snp.width).multipliedBy(ratio).priority(.high)
            } else {
                // 其他模式保持原来的布局
                let screenHeight = UIScreen.main.bounds.height
                let safeAreaTop = view.safeAreaInsets.top
                let toolBarHeight: CGFloat = 80
                let bottomSpace: CGFloat = 100
                let availableHeight = screenHeight - safeAreaTop - toolBarHeight - bottomSpace
                let previewHeight = UIScreen.main.bounds.width * ratio
                let verticalOffset = (availableHeight - previewHeight) / 2 + safeAreaTop
                
                make.top.equalToSuperview().offset(verticalOffset)
                make.height.equalTo(previewHeight).priority(.high)
            }
        }
        
        // 获取当前比例状态
        let ratioState: SCRatioState = {
            if let ratioItem = toolBar.getItem(for: .ratio),
               let state = ratioItem.state as? SCRatioState {
                return state
            }
            return .ratio4_3
        }()
        
        // 更新相机会话的输出尺寸
        if let session = photoSession {
            let screenWidth = UIScreen.main.bounds.width * UIScreen.main.scale
            let screenHeight = screenWidth * ratio
            session.resolution = CGSize(width: screenWidth, height: screenHeight)
            print("  [Camera] 更新相机会话输出尺寸: \(screenWidth) x \(screenHeight)")
        }
        
        // 更新镜头选择器位置
        updateLensSelectorPosition(for: ratioState)
        
        // 更新网格视图
        if previewView.showGrid {
            previewView.showGrid = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.previewView.showGrid = true
            }
        }
        
        // 使用动画更新布局
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateLensSelectorPosition(for ratioState: SCRatioState) {
        // 确保 lensSelectorView 已经被添加到父视图
        if lensSelectorView.superview == nil {
            view.addSubview(lensSelectorView)
        }
        
        // 移除现有约束
        lensSelectorView.snp.removeConstraints()
        
        // 添加新约束
        lensSelectorView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(50)
            make.width.equalTo(200)
            
            // 根据不同的预览模式设置不同的布局
            switch ratioState {
            case .ratio16_9:
                // 16:9模式下，距离工具栏顶部-20pt
                make.bottom.equalTo(toolBar.snp.top).offset(-20).priority(.high)
            default:
                // 1:1和4:3模式下，距离预览视图底部-20pt
                make.bottom.equalTo(previewView.snp.bottom).offset(-20).priority(.high)
            }
        }
        
        // 立即更新布局
        view.layoutIfNeeded()
    }
    
    private func setupConstraints() {
        // 1. 关闭按钮
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.left.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.width.height.equalTo(44)
        }
        
        // 2. 拍照按钮
        captureButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-30)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(70)
        }
        
        // 3. 工具栏
        toolBar.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(captureButton.snp.top).offset(-20)
            make.width.equalTo(UIScreen.main.bounds.width)
            make.height.equalTo(80)
        }
        
        // 添加网格按钮约束
        gridButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.right.equalTo(livePhotoButton.snp.left).offset(-20)
            make.width.height.equalTo(44)
        }
        
        // 4. 预览视图
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let safeAreaTop = view.safeAreaInsets.top
        let toolBarHeight: CGFloat = 80
        let bottomSpace: CGFloat = 100  // 拍照按钮和底部安全区域的空间
        let availableHeight = screenHeight - safeAreaTop - toolBarHeight - bottomSpace
        
        // 获取当前比例状态
        let ratioState: SCRatioState = {
            if let ratioItem = toolBar.getItem(for: .ratio),
               let state = ratioItem.state as? SCRatioState {
                return state
            }
            return .ratio4_3  // 默认 4:3
        }()
        
        // 计算预览高度
        let previewHeight: CGFloat = {
            let heightByRatio = screenWidth * ratioState.aspectRatio
            return min(heightByRatio, availableHeight)
        }()

        // 根据不同的比例状态设置不同的布局
        switch ratioState {
        case .ratio16_9:
            // 16:9 模式下垂直居中
            let verticalCenter = (screenHeight - previewHeight) / 2
            previewView.snp.makeConstraints { make in
                make.width.equalTo(screenWidth)
                make.height.equalTo(previewHeight)
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview()
            }
        default:
            // 其他模式保持原来的布局
            let verticalOffset = (availableHeight - previewHeight) / 2 + safeAreaTop
            previewView.snp.makeConstraints { make in
                make.width.equalTo(screenWidth)
                make.height.equalTo(previewHeight)
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(verticalOffset)
            }
        }
        
        // 5. 切换相机按钮
        switchCameraButton.snp.makeConstraints { make in
            make.right.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.centerY.equalTo(captureButton)
            make.width.height.equalTo(44)
        }
        
        // 6. 实况照片按钮
        livePhotoButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.right.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.width.height.equalTo(44)
        }
        
        // 7. 变焦指示器
        zoomIndicatorView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.width.equalTo(70)
            make.height.equalTo(30)
        }
        
        zoomLabel.snp.makeConstraints { make in
            make.edges.equalTo(zoomIndicatorView)
        }
        
        // 8. 水平指示器
        horizontalIndicator.snp.makeConstraints { make in
            make.center.equalTo(previewView)
            make.width.equalTo(200)
            make.height.equalTo(4)
        }
        
        // 自动保存按钮约束
        autoSaveButton.snp.makeConstraints { make in
            make.centerY.equalTo(captureButton)
            make.left.equalTo(captureButton.snp.right).offset(20)
            make.width.height.equalTo(44)
        }
    }
    
    private func setupActions() {
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        livePhotoButton.addTarget(self, action: #selector(toggleLivePhoto), for: .touchUpInside)
    }
    
    private func setupLensSelector() {
        cameraManager.getAvailableLensOptions { [weak self] lensOptions in
            guard let self = self else { return }
            
            // 更新 availableLensOptions 属性
            self.availableLensOptions = lensOptions
            
            // 确保有可用的镜头选项
            guard !self.availableLensOptions.isEmpty else {
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
            
            // 设置默认选中的镜头为 1.0x
            let defaultLens = self.availableLensOptions.first(where: { $0.name == "1x" })
            
            // 更新 lensSelectorView 的显示内容并设置默认选中
            self.lensSelectorView.updateLensOptions(self.availableLensOptions, currentLens: defaultLens)
            
            // 更新布局
            self.view.addSubview(self.lensSelectorView)
            
            // 获取当前比例状态
            let ratioState: SCRatioState = {
                if let ratioItem = self.toolBar.getItem(for: .ratio),
                   let state = ratioItem.state as? SCRatioState {
                    return state
                }
                return .ratio4_3
            }()
            
            // 根据不同的预览模式设置不同的布局
            self.lensSelectorView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.height.equalTo(50)
                make.width.equalTo(200)
                
                switch ratioState {
                case .ratio16_9:
                    // 16:9模式下，距离工具栏顶部-20pt
                    make.bottom.equalTo(self.toolBar.snp.top).offset(-20)
                default:
                    // 1:1和4:3模式下，距离预览视图底部-20pt
                    make.bottom.equalTo(self.previewView.snp.bottom).offset(-20)
                }
            }
            
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
        // 获取当前闪光灯状态
        guard let flashItem = toolBar.getItem(for: .flash),
              let flashState = flashItem.state as? SCFlashState else {
            // 如果获取不到闪光灯状态，使用默认设置拍照
            capturePhotoWithFlash(.auto)
            return
        }
        
        // 获取当前定时器状态
        if let timerItem = toolBar.getItem(for: .timer),
           let timerState = timerItem.state as? SCTimerState,
           timerState != .off {
            print("  [Timer] 检测到定时器状态：\(timerState.seconds)秒")
            // 开始倒计时拍照
            startCountdown(seconds: timerState.seconds)
        } else {
            // 不是定时拍照模式，直接拍照
            print("  [Camera] 直接拍照模式")
            capturePhotoWithFlash(flashState.avFlashMode)
        }
    }
    
    private func capturePhotoWithFlash(_ flashMode: AVCaptureDevice.FlashMode) {
        // 检查相机会话状态
        guard let session = photoSession, session.session.isRunning else {
            print("⚠️ [Camera] 相机会话未运行")
            let error = NSError(domain: "com.sparkcamera", code: -1, userInfo: [NSLocalizedDescriptionKey: "相机未准备就绪"])
            showError(error)
            return
        }
        
        // 拍照并处理结果
        let sessionFlashMode: SCSession.FlashMode
        switch flashMode {
        case .auto:
            sessionFlashMode = .auto
        case .on:
            sessionFlashMode = .on
        case .off:
            sessionFlashMode = .off
        @unknown default:
            sessionFlashMode = .auto
        }
        
        session.flashMode = sessionFlashMode
        session.capture({ [weak self] image, resolvedSettings in
            guard let self = self else { return }
            
            // 如果是定时拍照，直接保存原图到相册
            if self.countdownTimer != nil {
                print("  [Timer Photo] 定时拍照完成，准备保存原图")
                self.savePhotoToAlbum(image)
            }
            
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
        // 打印原始图片信息
        print("  [Original Image] 尺寸: \(image.size.width) x \(image.size.height)")
        print("  [Original Image] 方向: \(image.imageOrientation.rawValue)")
        print("  [Original Image] 比例: \(image.scale)")
        
        // 如果开启了自动保存，先保存照片
        if SCCameraSettingsManager.shared.isAutoSaveEnabled {
            print("  [Auto Save] 自动保存已开启，准备保存原始图片")
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
        
        // 创建照片信息
        let photoInfo = SCPhotoInfo(image: image)
        print(photoInfo.description)
        
        let photoPreviewVC = SCPhotoPreviewVC(image: image, photoInfo: photoInfo)
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
            print("⚠️ [Photo Save] 保存照片失败: \(error.localizedDescription)")
            // 显示错误提示
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.error)
            view.configureContent(title: "保存失败", body: error.localizedDescription)
            SwiftMessages.show(view: view)
        } else {
            print("✅ [Photo Save] 照片保存成功")
            // 发送通知，通知预览界面更新状态
            NotificationCenter.default.post(name: NSNotification.Name("PhotoSavedToAlbum"), object: nil)
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
    
    internal func showFocusAnimation(at point: CGPoint, state: SCFocusState) {
        let boxSize = focusBoxView.bounds.size
        let clampedX = min(max(boxSize.width/2, point.x), previewView.bounds.width - boxSize.width/2)
        let clampedY = min(max(boxSize.height/2, point.y), previewView.bounds.height - boxSize.height/2)
        let clampedPoint = CGPoint(x: clampedX, y: clampedY)
        previewView.bringSubviewToFront(focusBoxView)
        focusBoxView.center = clampedPoint
        focusBoxView.isHidden = false
        focusBoxView.animate(for: state)
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
        UIView.animate(withDuration: 0.2, animations: {
            self.toolBar.transform = .identity
            self.toolBar.alpha = 1
        })
    }
    
    private func animateToolBarCollapse() {
        UIView.animate(withDuration: 0.2, animations: {
            self.toolBar.transform = CGAffineTransform(translationX: 0, y: 100)
            self.toolBar.alpha = 0
        })
    }
    
    private func animateControlsForToolBarExpand() {
        UIView.animate(withDuration: 0.2, animations: {
            self.captureButton.transform = .identity
            self.switchCameraButton.transform = .identity
            self.livePhotoButton.transform = .identity
            self.captureButton.alpha = 1
            self.switchCameraButton.alpha = 1
            self.livePhotoButton.alpha = 1
        })
    }
    
    private func animateControlsForToolBarCollapse() {
        UIView.animate(withDuration: 0.2, animations: {
            self.captureButton.transform = CGAffineTransform(translationX: 0, y: 100)
            self.switchCameraButton.transform = CGAffineTransform(translationX: 0, y: 100)
            self.livePhotoButton.transform = CGAffineTransform(translationX: 0, y: 100)
            self.captureButton.alpha = 0
            self.switchCameraButton.alpha = 0
            self.livePhotoButton.alpha = 0
        })
    }
    
    // 添加闪光灯状态设置方法
    private func setupFlashState() {
        // 检查闪光灯是否可用
        guard photoSession.isFlashAvailable else {
            // 如果闪光灯不可用，更新工具栏状态
            if let flashItem = toolBar.getItem(for: .flash) {
                flashItem.setState(SCFlashState.off)
                flashItem.isEnabled = false
                toolBar.updateItem(flashItem)
            }
            print("⚠️ [Flash] 闪光灯不可用")
            return
        }
        
        // 获取保存的闪光灯状态，如果没有保存过，默认为自动模式
        let savedFlashMode = SCCameraSettingsManager.shared.flashMode
        let flashState = SCFlashState(rawValue: savedFlashMode) ?? .auto
        
        // 如果是第一次使用（没有保存过状态），保存默认的自动模式
        if SCCameraSettingsManager.shared.flashMode == 0 {
            SCCameraSettingsManager.shared.flashMode = SCFlashState.auto.rawValue
            print(" [Flash] 首次使用，设置默认闪光灯状态为自动")
        }
        
        // 设置闪光灯状态
        if photoSession.setFlashMode(flashState.avFlashMode) {
            // 更新工具栏状态
            if let flashItem = toolBar.getItem(for: .flash) {
                flashItem.setState(flashState)
                flashItem.isEnabled = true
                flashItem.isSelected = false
                toolBar.updateItem(flashItem)
            }
            print("  [Flash] 初始化闪光灯状态: \(flashState.title)")
        } else {
            print("⚠️ [Flash] 设置闪光灯状态失败")
            // 如果设置失败，将状态设置为关闭
            if let flashItem = toolBar.getItem(for: .flash) {
                flashItem.setState(SCFlashState.off)
                flashItem.isEnabled = false
                toolBar.updateItem(flashItem)
            }
        }
    }
    
    // 添加闪光灯状态变化提示方法
    internal func showFlashModeChanged(_ state: SCFlashState) {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.success)
        
        let message: String
        switch state {
        case .auto:
            message = "闪光灯：自动"
        case .on:
            message = "闪光灯：开启"
        case .off:
            message = "闪光灯：关闭"
        }
        
        view.configureContent(title: "", body: message)
        SwiftMessages.show(view: view)
    }
    
    // 添加比例状态变化提示方法
    internal func showRatioModeChanged(_ state: SCRatioState) {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.success)
        view.configureContent(title: "", body: "预览比例：\(state.title)")
        SwiftMessages.show(view: view)
    }
    
    // MARK: - Timer Methods
    private func startCountdown(seconds: Int) {
        print("⏱️ [Countdown] 开始倒计时，总时长：\(seconds)秒")
        // 停止已存在的定时器
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        // 设置初始状态
        remainingSeconds = seconds
        
        // 添加倒计时标签到视图
        if countdownLabel.superview == nil {
            print("⏱️ [Countdown] 添加倒计时标签到视图")
            view.addSubview(countdownLabel)
            view.bringSubviewToFront(countdownLabel)
            countdownLabel.snp.remakeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(CGSize(width: 300, height: 200))
            }
            view.layoutIfNeeded()
        }
        
        // 重置标签状态
        print("⏱️ [Countdown] 重置标签初始状态")
        countdownLabel.alpha = 0
        countdownLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        
        // 直接显示第一个数字
        print("⏱️ [Countdown] 开始显示第一个数字：\(seconds)")
        showNumber(seconds)
        
        // 立即创建并启动定时器
        print("⏱️ [Countdown] 创建并启动定时器")
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }
    
    private func stopCountdown() {
        print("⏱️ [Countdown] 停止倒计时")
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        UIView.animate(withDuration: 0.3, animations: {
            self.countdownLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }) { _ in
            print("⏱️ [Countdown] 移除倒计时标签")
            self.countdownLabel.removeFromSuperview()
        }
    }
    
    private func updateCountdown() {
        remainingSeconds -= 1
        print("⏱️ [Countdown] 更新倒计时：当前数字 \(remainingSeconds)")
        
        if remainingSeconds > 0 {
            showNumber(remainingSeconds)
        } else if remainingSeconds == 0 {
            print("⏱️ [Countdown] 倒计时结束，准备拍照")
            countdownTimer?.invalidate()
            countdownTimer = nil
            
            // 立即拍照，不再等待
            print("⏱️ [Countdown] 执行拍照")
            self.stopCountdown()
            
            // 获取当前闪光灯状态
            if let flashItem = self.toolBar.getItem(for: .flash),
               let flashState = flashItem.state as? SCFlashState {
                self.capturePhotoWithFlash(flashState.avFlashMode)
            } else {
                // 如果获取不到闪光灯状态，使用默认设置拍照
                self.capturePhotoWithFlash(.auto)
            }
        }
    }
    
    private func showNumber(_ number: Int) {
        print("⏱️ [Countdown] 开始显示数字 \(number)")
        print("⏱️ [Label] 当前标签状态 - alpha: \(countdownLabel.alpha), transform: \(countdownLabel.transform)")
        
        // 确保标签在最上层
        view.bringSubviewToFront(countdownLabel)
        
        // 设置新数字
        self.countdownLabel.text = "\(number)"
        self.countdownLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        self.countdownLabel.alpha = 0
        
        print("⏱️ [Label] 设置初始状态 - alpha: \(countdownLabel.alpha), transform: \(countdownLabel.transform)")
        
        // 直接显示新数字，不需要先淡出
        print("⏱️ [Countdown] 开始显示新数字 \(number)")
        UIView.animate(withDuration: 0.2, 
                     delay: 0,
                     options: [.curveEaseOut],
                     animations: {
            self.countdownLabel.alpha = 1
            self.countdownLabel.transform = .identity
            print("⏱️ [Label] 动画中 - alpha: \(self.countdownLabel.alpha), transform: \(self.countdownLabel.transform)")
        }) { _ in
            print("⏱️ [Countdown] 数字 \(number) 显示完成")
            print("⏱️ [Label] 显示完成状态 - alpha: \(self.countdownLabel.alpha), transform: \(self.countdownLabel.transform)")
            
            // 在显示完成后延迟淡出
            if number > 0 { // 只有非零数字需要淡出
                print("⏱️ [Label] 准备延迟淡出数字 \(number)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    print("⏱️ [Label] 开始淡出数字 \(number)")
                    UIView.animate(withDuration: 0.2) {
                        self.countdownLabel.alpha = 0
                        self.countdownLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                        print("⏱️ [Label] 淡出动画中 - alpha: \(self.countdownLabel.alpha), transform: \(self.countdownLabel.transform)")
                    } completion: { _ in
                        print("⏱️ [Label] 淡出完成 - alpha: \(self.countdownLabel.alpha), transform: \(self.countdownLabel.transform)")
                    }
                }
            }
            
            // 添加触觉反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
    }
    
    private func savePhotoToAlbum(_ image: UIImage) {
        print("  [Photo Save] 准备保存照片到相册")
        
        // 检查相册访问权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    print("  [Photo Save] 相册访问权限已获取，开始保存")
                    UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                    
                case .denied, .restricted:
                    print("⚠️ [Photo Save] 相册访问被拒绝")
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.error)
                    view.configureContent(title: "无法保存", body: "请在设置中允许访问相册")
                    SwiftMessages.show(view: view)
                    
                case .notDetermined:
                    print("⚠️ [Photo Save] 相册权限未确定")
                    break
                    
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Focus UI
//    private func setupFocusUI() {
//        view.addSubview(focusModeButton)
//        
//        focusModeButton.snp.makeConstraints { make in
//            make.right.equalTo(view.safeAreaLayoutGuide).offset(-16)
//            make.centerY.equalTo(captureButton)
//        }
//        
//        updateFocusModeButton()
//    }
    
//    private func updateFocusModeButton() {
//        guard let session = photoSession else { return }
//        
//        let imageName: String
//        switch session.focusMode {
//        case .auto:
//            imageName = "camera.focus"
//        case .continuous:
//            imageName = "camera.focus.auto"
//        case .locked:
//            imageName = "camera.focus.locked"
//        case .manual:
//            imageName = "camera.focus.manual"
//        }
//        
//        focusModeButton.setImage(UIImage(systemName: imageName), for: .normal)
//    }
    
//    @objc private func focusModeButtonTapped() {
//        guard let session = photoSession else { return }
//        
//        // 循环切换对焦模式
//        let nextMode: SCFocusMode
//        switch session.focusMode {
//        case .auto:
//            nextMode = .continuous
//        case .continuous:
//            nextMode = .locked
//        case .locked:
//            nextMode = .auto
//        case .manual:
//            nextMode = .auto
//        }
//        
//        session.setFocusMode(nextMode)
//        updateFocusModeButton()
//        
//        // 显示提示
//        let message: String
//        switch nextMode {
//        case .auto:
//            message = "单次自动对焦"
//        case .continuous:
//            message = "连续自动对焦"
//        case .locked:
//            message = "对焦已锁定"
//        case .manual:
//            message = "手动对焦"
//        }
//        
//        showSuccess(message)
//    }
    
    internal func handleFocusStateChange(_ state: SCFocusState) {
        // 根据对焦状态更新现有对焦框的外观动画
        focusBoxView.animate(for: state)
        switch state {
        case .focusing:
            print("  [Focus] 正在对焦...")
        case .focused:
            print("  [Focus] 对焦成功")
        case .failed:
            print("  [Focus] 对焦失败")
            let error = NSError(domain: "com.sparkcamera.focus", code: -1, userInfo: [NSLocalizedDescriptionKey: "对焦失败"])
            showError(error)
        case .locked:
            print("  [Focus] 对焦已锁定")
        }
    }
    
    @objc private func toggleGrid() {
        previewView.showGrid.toggle()
        
        // 更新按钮颜色
        gridButton.tintColor = previewView.showGrid ? SCConstants.themeColor : .white
        
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // 显示提示
        SwiftMessages.showSuccessMessage(previewView.showGrid ? "网格已开启" : "网格已关闭")
    }
    
    @objc internal func hideZoomIndicator() {
        UIView.animate(withDuration: 0.3) {
            self.zoomIndicatorView.alpha = 0
        } completion: { _ in
            self.zoomIndicatorView.isHidden = true
            self.zoomIndicatorView.alpha = 1
        }
    }
    
    // 添加自动保存相关方法
    private func updateAutoSaveButtonState() {
        let isAutoSaveEnabled = SCCameraSettingsManager.shared.isAutoSaveEnabled
        let imageName = isAutoSaveEnabled ? "square.and.arrow.down.fill" : "square.and.arrow.down"
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        autoSaveButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
        autoSaveButton.tintColor = isAutoSaveEnabled ? SCConstants.themeColor : .white
    }
    
    @objc private func toggleAutoSave() {
        // 切换自动保存状态
        let newState = !SCCameraSettingsManager.shared.isAutoSaveEnabled
        SCCameraSettingsManager.shared.isAutoSaveEnabled = newState
        
        // 更新按钮状态
        updateAutoSaveButtonState()
        
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 显示提示
        let message = newState ? "已开启自动保存原图" : "已关闭自动保存原图"
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(newState ? .success : .info)
        view.configureContent(title: "", body: message)
        SwiftMessages.show(view: view)
    }
    
    func updateAspectRatio(_ state: SCRatioState) {
        // 更新UI约束
        updatePreviewRatio(state.aspectRatio)

        // 获取当前屏幕宽度和新的比例
        let screenWidth = UIScreen.main.bounds.width * UIScreen.main.scale
        let screenHeight = screenWidth * state.aspectRatio

        // 更新session的resolution
        if let session = photoSession {
            session.resolution = CGSize(width: screenWidth, height: screenHeight)
            print("  [Camera] 更新相机会话输出尺寸: \(screenWidth) x \(screenHeight)")
        }
    }
    
    // MARK: - Deinitialization
    deinit {
        print("  [Camera] SCCameraVC 正在释放...")
        
        // 停止倒计时
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        // 停止水平指示器
        motionManager.stopDeviceMotionUpdates()
        
        // 清理预览视图（先解除与 session 的关联，再置空，以防预览层仍持有 session）
        previewView?.session = nil
        previewView = nil
        
        // 清理相机会话
        photoSession?.stopSession()
        photoSession = nil
        cameraManager = nil
        
        print("  [Camera] SCCameraVC 已释放")
    }
}

