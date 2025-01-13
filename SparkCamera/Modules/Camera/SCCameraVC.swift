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
    private var photoSession: SCPhotoSession!
    private var previewView: SCPreviewView!
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
        button.layer.borderColor = SCConstants.themeColor.cgColor
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
        view.layer.borderColor = SCConstants.themeColor.cgColor
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
        label.backgroundColor = .clear
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
    
    // MARK: - Focus UI
    private lazy var focusModeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.focus"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(focusModeButtonTapped), for: .touchUpInside)
        return button
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
            self.previewView.addGestureRecognizer(doubleTapGesture)
            
            let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleSingleTap))
            singleTapGesture.require(toFail: doubleTapGesture)
            self.previewView.addGestureRecognizer(singleTapGesture)
            
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch))
            self.previewView.addGestureRecognizer(pinchGesture)
        }
    }

    @objc private func handleSingleTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: previewView)
        
        // 确保点击位置在预览视图范围内
        guard location.x >= 0 && location.x <= previewView.bounds.width &&
              location.y >= 0 && location.y <= previewView.bounds.height else {
            return
        }
        
        // 将点击位置转换为预览层的坐标
        guard let previewLayer = previewView.previewLayer else { return }
        
        // 将点击位置转换为 AVCaptureDevice 可用的坐标（范围在 0-1 之间）
        let normalizedPoint = CGPoint(
            x: location.x / previewView.bounds.width,
            y: location.y / previewView.bounds.height
        )
        
        // 在点击位置显示对焦动画
        showFocusAnimation(at: location)
        
        // 设置对焦点
        photoSession.focus(at: normalizedPoint)
        
        print("📸 [Focus] 点击位置: \(location), 归一化坐标: \(normalizedPoint)")
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
        
        // 1. 初始化相机会话
        photoSession = SCPhotoSession()
        photoSession.delegate = self
        
        // 2. 初始化相机管理器
        cameraManager = SCCameraManager(session: photoSession, photoSession: photoSession)
        
        // 3. 配置预览视图
        previewView.session = photoSession
        previewView.autorotate = true
        
        // 4. 设置当前设备到 SCCameraSettingsManager
        if let device = AVCaptureDevice.default(for: .video) {
            SCCameraSettingsManager.shared.setCurrentDevice(device)
        }
        
        // 5. 设置镜头选择器
        setupLensSelector()
        
        // 6. 检查并设置闪光灯初始状态
        setupFlashState()
        
        // 7. 启动相机会话
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.photoSession.startSession()
            
            // 确保在主线程更新 UI
            DispatchQueue.main.async {
                self.hideLoading()
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
        toolBar.delegate = self
        print("📸 [ToolBar] 设置代理: \(String(describing: toolBar.delegate))")

        // 从数据库中查询设置
        // 获取保存的闪光灯状态，如果没有保存过，默认为自动模式
        let savedFlashMode = SCCameraSettingsManager.shared.flashMode
        let flashState = SCFlashState(rawValue: savedFlashMode) ?? .auto
        
        // 如果是第一次使用（没有保存过状态），保存默认的自动模式
        if SCCameraSettingsManager.shared.flashMode == 0 {
            SCCameraSettingsManager.shared.flashMode = SCFlashState.auto.rawValue
        }
        
        // 获取保存的比例设置，如果没有保存过，默认为 4:3
        let savedRatioMode = SCCameraSettingsManager.shared.ratioMode
        let ratioState = SCRatioState(rawValue: savedRatioMode) ?? .ratio4_3
        
        // 如果是第一次使用，保存默认的 4:3 比例
        if SCCameraSettingsManager.shared.ratioMode == 0 {
            SCCameraSettingsManager.shared.ratioMode = SCRatioState.ratio4_3.rawValue
            print("📸 [Ratio] 首次使用，设置默认比例为 4:3")
        }

        // 获取保存的定时器设置，如果没有保存过，默认为关闭状态
        let savedTimerMode = SCCameraSettingsManager.shared.timerMode
        let timerState = SCTimerState(rawValue: savedTimerMode) ?? .off
        
        // 如果是第一次使用，保存默认的关闭状态
        if SCCameraSettingsManager.shared.timerMode == 0 {
            SCCameraSettingsManager.shared.timerMode = SCTimerState.off.rawValue
            print("📸 [Timer] 首次使用，设置默认定时器状态为关闭")
        }

        // 获取保存的白平衡设置，如果没有保存过，默认为自动
        let savedWhiteBalanceMode = SCCameraSettingsManager.shared.whiteBalanceMode
        let whiteBalanceState = SCWhiteBalanceState(rawValue: savedWhiteBalanceMode) ?? .auto
        
        // 如果是第一次使用，保存默认的自动白平衡
        if SCCameraSettingsManager.shared.whiteBalanceMode == 0 {
            SCCameraSettingsManager.shared.whiteBalanceMode = SCWhiteBalanceState.auto.rawValue
            print("📸 [WhiteBalance] 首次使用，设置默认白平衡为自动")
        }

        // 获取保存的曝光设置，如果没有保存过，默认为0
        let savedExposureValue = SCCameraSettingsManager.shared.exposureValue
        let exposureStates: [SCExposureState] = [.negative2, .negative1, .zero, .positive1, .positive2]
        let exposureState = exposureStates.first { $0.value == savedExposureValue } ?? .zero
        
        // 如果是第一次使用，保存默认的曝光值
        if SCCameraSettingsManager.shared.exposureValue == 0 {
            SCCameraSettingsManager.shared.exposureValue = SCExposureState.zero.value
            print("📸 [Exposure] 首次使用，设置默认曝光值为0")
        }

        // 获取保存的ISO设置，如果没有保存过，默认为自动
        let savedISOValue = SCCameraSettingsManager.shared.isoValue
        let isoStates: [SCISOState] = [.auto, .iso100, .iso200, .iso400, .iso800]
        let isoState = isoStates.first { $0.value == savedISOValue } ?? .auto
        
        // 如果是第一次使用，保存默认的ISO值
        if SCCameraSettingsManager.shared.isoValue == 0 {
            SCCameraSettingsManager.shared.isoValue = SCISOState.auto.value
            print("📸 [ISO] 首次使用，设置默认ISO为自动")
        }

        // 初始化闪光灯工具项
        let flashItem = SCToolItem(type: .flash)
        flashItem.setState(flashState)  // 设置状态，这会自动更新图标
        flashItem.isSelected = false    // 确保初始状态未选中
        
        // 初始化比例工具项
        let ratioItem = SCToolItem(type: .ratio)
        ratioItem.setState(ratioState)  // 设置状态，这会自动更新图标
        ratioItem.isSelected = false    // 确保初始状态未选中
        print("📸 [Ratio] 初始化比例状态: \(ratioState.title)")
        
        // 初始化白平衡工具项
        let whiteBalanceItem = SCToolItem(type: .whiteBalance)
        whiteBalanceItem.setState(whiteBalanceState)
        whiteBalanceItem.isSelected = false
        print("📸 [WhiteBalance] 初始化白平衡状态: \(whiteBalanceState.title)")
        
        // 初始化曝光工具项
        let exposureItem = SCToolItem(type: .exposure)
        exposureItem.setState(exposureState)
        exposureItem.isSelected = false
        print("📸 [Exposure] 初始化曝光状态: \(exposureState.title)")
        
        // 初始化ISO工具项
        let isoItem = SCToolItem(type: .iso)
        isoItem.setState(isoState)
        isoItem.isSelected = false
        print("📸 [ISO] 初始化ISO状态: \(isoState.title)")
        
        // 初始化定时器工具项
        let timerItem = SCToolItem(type: .timer)
        timerItem.setState(timerState)  // 设置状态
        timerItem.isSelected = false    // 确保初始状态未选中
        print("📸 [Timer] 初始化定时器状态: \(timerState.title)")

        // 获取保存的快门速度设置
        let savedShutterSpeedValue = SCCameraSettingsManager.shared.shutterSpeedValue
        print("📸 [ShutterSpeed] 数据库中保存的快门速度值: \(savedShutterSpeedValue)")
        let shutterSpeedStates: [SCShutterSpeedState] = [.auto, .speed1_1000, .speed1_500, .speed1_250, .speed1_125, .speed1_60, .speed1_30]
        let shutterSpeedState = shutterSpeedStates.first(where: { $0.value == savedShutterSpeedValue }) ?? .auto
        
        // 如果是第一次使用，保存默认的快门速度值
        if SCCameraSettingsManager.shared.shutterSpeedValue == 0 {
            SCCameraSettingsManager.shared.shutterSpeedValue = SCShutterSpeedState.auto.value
            print("📸 [ShutterSpeed] 首次使用，设置默认快门速度为自动")
        }

        // 初始化快门速度工具项
        let shutterSpeedItem = SCToolItem(type: .shutterSpeed)
        shutterSpeedItem.setState(shutterSpeedState)
        shutterSpeedItem.isSelected = false
        print("📸 [ShutterSpeed] 初始化快门速度状态: \(shutterSpeedState.title)")
        print("📸 [ShutterSpeed] 快门速度值: \(shutterSpeedState.value)")
        print("📸 [ShutterSpeed] 当前实际快门速度状态: \(shutterSpeedState)")

        // 初始化工具栏项目
        let toolItems: [SCToolItem] = [
            flashItem,          // 闪光灯
            ratioItem,          // 比例
            whiteBalanceItem,   // 白平衡
            exposureItem,       // 曝光
            isoItem,            // ISO
            shutterSpeedItem,   // 快门速度
            timerItem           // 上次选的延时摄影
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
        
        // 8. 添加对焦框 - 确保添加到预览视图上
        previewView.addSubview(focusView)
        
        // 9. 添加镜头选择器
        view.addSubview(lensSelectorView)
        
        // 10. 添加水平指示器 - 确保添加到预览视图上
        previewView.addSubview(horizontalIndicator)
        
        // 设置初始状态
        zoomIndicatorView.isHidden = true
        focusView.isHidden = true
        horizontalIndicator.isHidden = !isHorizontalIndicatorVisible
        
        // 设置初始预览比例
        switch ratioState {
        case .ratio4_3:
            updatePreviewRatio(4.0 / 3.0)
        case .ratio1_1:
            updatePreviewRatio(1.0)
        case .ratio16_9:
            updatePreviewRatio(16.0 / 9.0)
        }
        
        setupFocusUI()
    }
    
    private func updatePreviewRatio(_ ratio: CGFloat) {
        // 先移除预览视图的所有约束
        previewView.snp.removeConstraints()
        
        // 重新设置预览视图约束
        previewView.snp.remakeConstraints() { make in
            make.width.equalTo(UIScreen.main.bounds.width)
            make.centerX.equalToSuperview()
            make.height.equalTo(previewView.snp.width).multipliedBy(ratio)
            
            // 根据比例调整位置
            if ratio == 16.0 / 9.0 {
                // 16:9 模式下垂直居中
                make.centerY.equalToSuperview()
            } else {
                // 其他模式保持原来的布局
                let screenHeight = UIScreen.main.bounds.height
                let safeAreaTop = CGFloat(0.0)
                let toolBarHeight: CGFloat = 80
                let bottomSpace: CGFloat = 100
                let availableHeight = screenHeight - safeAreaTop - toolBarHeight - bottomSpace
                let previewHeight = UIScreen.main.bounds.width * ratio
                let verticalOffset = (availableHeight - previewHeight) / 2 + safeAreaTop
                make.top.equalToSuperview().offset(verticalOffset)
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
        
        // 更新镜头选择器位置
        updateLensSelectorPosition(for: ratioState)
        
        // 使用动画更新布局
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateLensSelectorPosition(for ratioState: SCRatioState) {
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
                make.bottom.equalTo(toolBar.snp.top).offset(-20)
            default:
                // 1:1和4:3模式下，距离预览视图底部-20pt
                make.bottom.equalTo(previewView.snp.bottom).offset(-20)
            }
        }
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
            print("📸 [Timer] 检测到定时器状态：\(timerState.seconds)秒")
            // 开始倒计时拍照
            startCountdown(seconds: timerState.seconds)
        } else {
            // 不是定时拍照模式，直接拍照
            print("📸 [Camera] 直接拍照模式")
            capturePhotoWithFlash(flashState.avFlashMode)
        }
    }
    
    private func capturePhotoWithFlash(_ flashMode: AVCaptureDevice.FlashMode) {
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
        
        photoSession.flashMode = sessionFlashMode
        photoSession.capture({ [weak self] image, _ in
            guard let self = self else { return }
            
            // 如果是定时拍照，直接保存原图到相册
            if self.countdownTimer != nil {
                print("📸 [Timer Photo] 定时拍照完成，准备保存原图")
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
            print("⚠️ [Photo Save] 保存照片失败: \(error.localizedDescription)")
            // 显示错误提示
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.error)
            view.configureContent(title: "保存失败", body: error.localizedDescription)
            SwiftMessages.show(view: view)
        } else {
            print("✅ [Photo Save] 照片保存成功")
            // 显示成功提示
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.success)
            view.configureContent(title: "保存成功", body: "照片已保存到相册")
            SwiftMessages.show(view: view)
            
            // 添加触觉反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
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
        // 确保对焦框在预览视图内
        let focusViewSize = focusView.bounds.size
        let minX = focusViewSize.width / 2
        let maxX = previewView.bounds.width - focusViewSize.width / 2
        let minY = focusViewSize.height / 2
        let maxY = previewView.bounds.height - focusViewSize.height / 2
        
        let clampedPoint = CGPoint(
            x: min(maxX, max(minX, point.x)),
            y: min(maxY, max(minY, point.y))
        )
        
        // 确保对焦框在最上层
        previewView.bringSubviewToFront(focusView)
        
        // 更新对焦框的位置
        focusView.center = clampedPoint
        focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusView.alpha = 1.0
        focusView.isHidden = false
        
        // 执行动画
        UIView.animate(withDuration: 0.3, animations: {
            self.focusView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0.5) {
                self.focusView.alpha = 0
            } completion: { _ in
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
            print("📸 [Flash] 首次使用，设置默认闪光灯状态为自动")
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
            print("📸 [Flash] 初始化闪光灯状态: \(flashState.title)")
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
    private func showFlashModeChanged(_ state: SCFlashState) {
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
    private func showRatioModeChanged(_ state: SCRatioState) {
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
        print("📸 [Photo Save] 准备保存照片到相册")
        
        // 检查相册访问权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    print("📸 [Photo Save] 相册访问权限已获取，开始保存")
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
    private func setupFocusUI() {
        view.addSubview(focusModeButton)
        
        focusModeButton.snp.makeConstraints { make in
            make.right.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.centerY.equalTo(captureButton)
        }
        
        updateFocusModeButton()
    }
    
    private func updateFocusModeButton() {
        guard let session = photoSession else { return }
        
        let imageName: String
        switch session.focusMode {
        case .auto:
            imageName = "camera.focus"
        case .continuous:
            imageName = "camera.focus.auto"
        case .locked:
            imageName = "camera.focus.locked"
        case .manual:
            imageName = "camera.focus.manual"
        }
        
        focusModeButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    @objc private func focusModeButtonTapped() {
        guard let session = photoSession else { return }
        
        // 循环切换对焦模式
        let nextMode: SCFocusMode
        switch session.focusMode {
        case .auto:
            nextMode = .continuous
        case .continuous:
            nextMode = .locked
        case .locked:
            nextMode = .auto
        case .manual:
            nextMode = .auto
        }
        
        session.setFocusMode(nextMode)
        updateFocusModeButton()
        
        // 显示提示
        let message: String
        switch nextMode {
        case .auto:
            message = "单次自动对焦"
        case .continuous:
            message = "连续自动对焦"
        case .locked:
            message = "对焦已锁定"
        case .manual:
            message = "手动对焦"
        }
        
        showSuccess(message)
    }
    
    private func handleFocusStateChange(_ state: SCFocusState) {
        let focusBoxView = SCFocusBoxView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusBoxView.animate(for: state)
        
        switch state {
        case .focusing:
            print("📸 [Focus] 正在对焦...")
        case .focused:
            print("📸 [Focus] 对焦成功")
        case .failed:
            print("📸 [Focus] 对焦失败")
            let error = NSError(domain: "com.sparkcamera.focus", code: -1, userInfo: [NSLocalizedDescriptionKey: "对焦失败"])
            showError(error)
        case .locked:
            print("📸 [Focus] 对焦已锁定")
        }
    }
}

// MARK: - SCSessionDelegate
extension SCCameraVC: SCSessionDelegate {
    func didChangeValue(session: SCSession, value: Any, key: String) {
        switch key {
        case "zoom":
            if let zoomValue = value as? Double {
                // 更新变焦指示器
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 更新文字
                    self.zoomLabel.text = String(format: "%.1fx", zoomValue)
                    
                    // 确保 zoomLabel 在 zoomIndicatorView 内部
                    self.zoomLabel.frame = self.zoomIndicatorView.bounds
                    
                    // 显示变焦指示器
                    if self.zoomIndicatorView.isHidden {
                        self.zoomIndicatorView.alpha = 0
                        self.zoomIndicatorView.isHidden = false
                        
                        UIView.animate(withDuration: 0.2) {
                            self.zoomIndicatorView.alpha = 1
                            self.zoomLabel.alpha = 1
                        }
                    }
                    
                    // 延迟隐藏变焦指示器
                    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.hideZoomIndicator), object: nil)
                    self.perform(#selector(self.hideZoomIndicator), with: nil, afterDelay: 1.5)
                }
            }
            
        case "focusState":
            if let focusState = value as? SCFocusState {
                DispatchQueue.main.async { [weak self] in
                    self?.handleFocusStateChange(focusState)
                }
            }
            
        default:
            break
        }
    }
    
    @objc private func hideZoomIndicator() {
        UIView.animate(withDuration: 0.2) { [weak self] in
            guard let self = self else { return }
            self.zoomIndicatorView.alpha = 0
            self.zoomLabel.alpha = 0
        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.zoomIndicatorView.isHidden = true
        }
    }
}

// MARK: - SCCameraToolBarDelegate
extension SCCameraVC: SCCameraToolBarDelegate {
    func toolBar(_ toolBar: SCCameraToolBar, didSelect item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 空实现，所有选择逻辑都在 didSelect:for: 方法中处理
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didExpand item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 打印展开的工具项信息
        print("📸📸 [ToolBar] 展开工具项: \(item.type)")
        print("📸 [ToolBar] 当前状态: \(String(describing: item.state))")
        print("📸 [ToolBar] 是否选中: \(item.isSelected)")
        
        // 根据工具项类型处理特定逻辑
        switch item.type {
        case .ratio:
            // 获取保存的比例设置
            let savedRatioMode = SCCameraSettingsManager.shared.ratioMode
            print("📸 [Ratio] 数据库中保存的比例模式: \(savedRatioMode)")
            if let ratioState = SCRatioState(rawValue: savedRatioMode) {
                item.setState(ratioState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [Ratio] 选中保存的状态: \(ratioState.title)")
                print("📸 [Ratio] 比例值: \(ratioState.aspectRatio)")
                print("📸 [Ratio] 当前实际比例状态: \(ratioState)")
            }

        case .flash:
            // 获取保存的闪光灯设置
            let savedFlashMode = SCCameraSettingsManager.shared.flashMode
            print("📸 [Flash] 数据库中保存的闪光灯模式: \(savedFlashMode)")
            if let flashState = SCFlashState(rawValue: savedFlashMode) {
                item.setState(flashState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [Flash] 选中保存的状态: \(flashState.title)")
                print("📸 [Flash] 闪光灯模式: \(flashState.avFlashMode.rawValue)")
                print("📸 [Flash] 当前实际闪光灯状态: \(flashState)")
            }

        case .whiteBalance:
            // 获取保存的白平衡设置
            let savedWhiteBalanceMode = SCCameraSettingsManager.shared.whiteBalanceMode
            print("📸 [WhiteBalance] 数据库中保存的白平衡模式: \(savedWhiteBalanceMode)")
            if let whiteBalanceState = SCWhiteBalanceState(rawValue: savedWhiteBalanceMode) {
                item.setState(whiteBalanceState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [WhiteBalance] 选中保存的状态: \(whiteBalanceState.title)")
                print("📸 [WhiteBalance] 色温值: \(whiteBalanceState.temperature)")
                print("📸 [WhiteBalance] 当前实际白平衡状态: \(whiteBalanceState)")
            }

        case .exposure:
            // 获取保存的曝光值
            let savedExposureValue = SCCameraSettingsManager.shared.exposureValue
            print("📸 [Exposure] 数据库中保存的曝光值: \(savedExposureValue)")
            let exposureStates: [SCExposureState] = [.negative2, .negative1, .zero, .positive1, .positive2]
            if let exposureState = exposureStates.first(where: { $0.value == savedExposureValue }) {
                item.setState(exposureState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [Exposure] 选中保存的状态: \(exposureState.title)")
                print("📸 [Exposure] 曝光值: \(exposureState.value)")
                print("📸 [Exposure] 当前实际曝光状态: \(exposureState)")
            }

        case .iso:
            // 获取保存的 ISO 值
            let savedISOValue = SCCameraSettingsManager.shared.isoValue
            print("📸 [ISO] 数据库中保存的 ISO 值: \(savedISOValue)")
            let isoStates: [SCISOState] = [.auto, .iso100, .iso200, .iso400, .iso800]
            if let isoState = isoStates.first(where: { $0.value == savedISOValue }) {
                item.setState(isoState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [ISO] 选中保存的状态: \(isoState.title)")
                print("📸 [ISO] ISO 值: \(isoState.value)")
                print("📸 [ISO] 当前实际ISO状态: \(isoState)")
            }

        case .timer:
            // 获取保存的定时器设置
            let savedTimerMode = SCCameraSettingsManager.shared.timerMode
            print("📸 [Timer] 数据库中保存的定时器模式: \(savedTimerMode)")
            if let timerState = SCTimerState(rawValue: savedTimerMode) {
                item.setState(timerState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [Timer] 选中保存的状态: \(timerState.title)")
                print("📸 [Timer] 定时秒数: \(timerState.seconds)")
                print("📸 [Timer] 当前实际定时器状态: \(timerState)")
            }

        case .livePhoto:
            print("📸 [LivePhoto] 功能未实现，使用默认关闭状态")
            let defaultState = SCLivePhotoState.off
            item.setState(defaultState)
            item.isSelected = true
            toolBar.updateItem(item)
            print("📸 [LivePhoto] 使用默认状态: \(defaultState.title)")
            print("📸 [LivePhoto] 当前实际实况照片状态: \(defaultState)")
        case .shutterSpeed:
            // 获取保存的快门速度设置
            let savedShutterSpeedValue = SCCameraSettingsManager.shared.shutterSpeedValue
            print("📸 [ShutterSpeed] 数据库中保存的快门速度值: \(savedShutterSpeedValue)")
            let shutterSpeedStates: [SCShutterSpeedState] = [.auto, .speed1_1000, .speed1_500, .speed1_250, .speed1_125, .speed1_60, .speed1_30]
            if let shutterSpeedState = shutterSpeedStates.first(where: { $0.value == savedShutterSpeedValue }) {
                item.setState(shutterSpeedState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [ShutterSpeed] 选中保存的状态: \(shutterSpeedState.title)")
                print("📸 [ShutterSpeed] 快门速度值: \(shutterSpeedState.value)")
                print("📸 [ShutterSpeed] 当前实际快门速度状态: \(shutterSpeedState)")
            }

        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didCollapse item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 处理工具项收起
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: {
            // 显示拍照按钮和其他控制按钮
            self.captureButton.transform = .identity
            self.switchCameraButton.transform = .identity
            self.livePhotoButton.transform = .identity
            
            self.captureButton.alpha = 1
            self.switchCameraButton.alpha = 1
            self.livePhotoButton.alpha = 1
        })
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, willAnimate item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 处理工具项动画开始
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didFinishAnimate item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        print("工具栏动画完成：\(item.type)")
        
        // 根据工具类型和选项类型处理不同的逻辑
        switch (item.type, optionType) {
        case (.exposure, .scale):
            // 从 scale 选项类型获取曝光值
            if let value = item.getValue(for: SCCameraToolOptionsViewType.scale) as? Float {
                print("📸 [Exposure] 工具栏收起，应用曝光值：\(value)")
                // 更新相机曝光
                if photoSession.setExposure(value) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.exposureValue = value
                    // 显示状态更新提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "曝光：\(value)")
                    SwiftMessages.show(view: view)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        case (.timer, .normal):
            // 从 normal 选项类型获取定时器状态
            if let timerState = item.getValue(for: SCCameraToolOptionsViewType.normal) as? SCTimerState {
                print("📸 [Timer] 工具栏收起，定时器状态：\(timerState.seconds)秒")
            }
        default:
            break
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didSelect option: String, for item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        if item.type == .flash {
            if let flashState = item.state as? SCFlashState {
                print("📸 [Flash] 选择闪光灯状态：\(flashState.title)")
                // 更新闪光灯状态
                if photoSession.setFlashMode(flashState.avFlashMode) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.flashMode = flashState.rawValue
                    // 显示状态更新提示
                    showFlashModeChanged(flashState)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else if item.type == .ratio {
            if let ratioState = item.state as? SCRatioState {
                print("📸 [Ratio] 选择比例状态：\(ratioState.title)")
                // 更新预览比例
                switch ratioState {
                case .ratio4_3:
                    updatePreviewRatio(4.0 / 3.0)
                case .ratio1_1:
                    updatePreviewRatio(1.0)
                case .ratio16_9:
                    updatePreviewRatio(16.0 / 9.0)
                }
                // 保存到数据库
                SCCameraSettingsManager.shared.ratioMode = ratioState.rawValue
                // 显示状态更新提示
                showRatioModeChanged(ratioState)
                // 添加触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } else if item.type == .timer {
            if let timerState = item.state as? SCTimerState {
                print("📸 [Timer] 选择定时器状态：\(timerState.seconds)秒")
                // 保存到数据库
                SCCameraSettingsManager.shared.timerMode = timerState.rawValue
                // 显示状态更新提示
                let view = MessageView.viewFromNib(layout: .statusLine)
                view.configureTheme(.success)
                view.configureContent(title: "", body: timerState == .off ? "定时器已关闭" : "定时器：\(timerState.seconds)秒")
                SwiftMessages.show(view: view)
                // 添加触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } else if item.type == .whiteBalance {
            if let whiteBalanceState = item.state as? SCWhiteBalanceState {
                print("📸 [WhiteBalance] 选择白平衡状态：\(whiteBalanceState.title)")
                // 更新相机白平衡
                if photoSession.setWhiteBalanceMode(whiteBalanceState) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.whiteBalanceMode = whiteBalanceState.rawValue
                    // 显示状态更新提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "白平衡：\(whiteBalanceState.title)")
                    SwiftMessages.show(view: view)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else if item.type == .exposure {
            if let exposureState = item.state as? SCExposureState {
                print("📸 [Exposure] 选择曝光状态：\(exposureState.title)")
                // 更新相机曝光
                if photoSession.setExposure(exposureState.value) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.exposureValue = exposureState.value
                    // 显示状态更新提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "曝光：\(exposureState.title)")
                    SwiftMessages.show(view: view)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else if item.type == .iso {
            if let isoState = item.state as? SCISOState {
                print("📸 [ISO] 选择ISO状态：\(isoState.title)")
                // 更新相机ISO
                if photoSession.setISO(isoState.value) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.isoValue = isoState.value
                    // 显示状态更新提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "ISO：\(isoState.title)")
                    SwiftMessages.show(view: view)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else if item.type == .shutterSpeed {
            if let shutterSpeedState = item.state as? SCShutterSpeedState {
                print("📸 [ShutterSpeed] 选择快门速度状态：\(shutterSpeedState.title)")
                // 更新相机快门速度
                photoSession.setShutterSpeed(shutterSpeedState.value) { success in
                    if success {
                        // 保存到数据库
                        SCCameraSettingsManager.shared.shutterSpeedValue = shutterSpeedState.value
                        
                        // 显示状态更新提示
                        DispatchQueue.main.async {
                            let view = MessageView.viewFromNib(layout: .statusLine)
                            view.configureTheme(.success)
                            view.configureContent(title: "", body: shutterSpeedState == .auto ? "自动快门速度" : "快门速度：1/\(Int(1/shutterSpeedState.value))秒")
                            SwiftMessages.show(view: view)
                            
                            // 添加触觉反馈
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    } else {
                        // 设置失败时显示错误提示
                        DispatchQueue.main.async {
                            SwiftMessages.showErrorMessage("设置快门速度失败")
                        }
                    }
                }
            }
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didToggleState item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 处理状态切换
        switch item.type {
        case .flash:
            if let flashState = item.state as? SCFlashState {
                if photoSession.setFlashMode(flashState.avFlashMode) {
                    // 保存闪光灯状态
                    SCCameraSettingsManager.shared.flashMode = flashState.rawValue
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    // 显示状态更新提示
                    showFlashModeChanged(flashState)
                }
            }
        case .livePhoto:
            // 实况照片功能待实现
            SwiftMessages.showInfoMessage("实况照片功能待开发")
        case .ratio, .whiteBalance, .exposure, .iso, .timer:
            break
        case .shutterSpeed:
            if let shutterSpeedState = item.state as? SCShutterSpeedState {
                let nextState = shutterSpeedState.nextState()
                // 更新工具项状态
                item.setState(nextState)
                toolBar.updateItem(item)
                
                // 设置快门速度
                photoSession.setShutterSpeed(nextState.value) { success in
                    if success {
                        // 保存快门速度状态
                        SCCameraSettingsManager.shared.shutterSpeedValue = nextState.value
                        
                        // 添加触觉反馈
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // 显示状态更新提示
                        let message = nextState.value == 0 ? "自动快门速度" : "快门速度: 1/\(Int(1/nextState.value))秒"
                        DispatchQueue.main.async {
                            SwiftMessages.showSuccessMessage(message)
                        }
                    } else {
                        // 设置失败时显示错误提示
                        DispatchQueue.main.async {
                            SwiftMessages.showErrorMessage("设置快门速度失败")
                        }
                    }
                }
            }
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didChangeSlider value: Float, for item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 目前只处理曝光值的调整
        if item.type == .exposure {
            // 获取设备支持的曝光值范围
            let range = SCCameraSettingsManager.shared.exposureRange
            // 确保值在设备支持的范围内
            let clampedValue = min(range.max, max(range.min, value))
            
            print("📸 [Exposure] 准备更新曝光值：\(value)")
            print("📸 [Exposure] 设备支持范围：[\(range.min), \(range.max)]")
            print("📸 [Exposure] 调整后的值：\(clampedValue)")
            
            if photoSession.setExposure(clampedValue) {
                print("📸 [Exposure] 成功更新曝光值：\(clampedValue)")
                // 保存到数据库
                SCCameraSettingsManager.shared.exposureValue = clampedValue
            }
        }
    }
}

// MARK: - SCCameraToolOptionsViewDelegate
extension SCCameraVC: SCCameraToolOptionsViewDelegate {
    func optionsView(_ optionsView: SCCameraToolOptionsView, didChangeSliderValue value: Float, for type: SCToolType) {
        // 处理选项选择
        if let item = toolBar.getItem(for: type) {
            item.setValue(value, for: .scale)
//            toolBar.updateItem(item)
//            toolBar.delegate?.toolBar(toolBar, didSelect: option.title, for: item, optionType: .normal)
        }
    }
    
    func optionsView(_ optionsView: SCCameraToolOptionsView, didSelect option: SCToolOption, for type: SCToolType) {
        // 处理选项选择
        if let item = toolBar.getItem(for: type) {
            item.setState(option.state)
            toolBar.updateItem(item)
            toolBar.delegate?.toolBar(toolBar, didSelect: option.title, for: item, optionType: .normal)
        }
    }
}

