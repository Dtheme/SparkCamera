//
//  SCPhotoSession.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import AVFoundation
import CoreMotion

// MARK: - Focus Enums
public enum SCFocusMode: Int {
    case auto = 0          // 单次自动对焦
    case continuous = 1    // 连续自动对焦
    case locked = 2        // 锁定对焦
    case manual = 3        // 手动对焦
}

public enum SCFocusState {
    case focusing       // 正在对焦
    case focused        // 对焦成功
    case failed        // 对焦失败
    case locked        // 对焦已锁定
}

extension SCSession.FlashMode {
    
    var captureFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }
}

@objc public class SCPhotoSession: SCSession, AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate {
    
    @objc public enum CameraDetection: UInt {
        case none, faces
    }
    
    @objc public var cameraPosition: CameraPosition = .back {
        didSet {
            if cameraPosition == oldValue {
                return
            }
            
            configureInputs()
        }
    }
    
    @objc public var cameraDetection = CameraDetection.none {
        didSet {
            if oldValue == self.cameraDetection { return }
            
            for output in self.session.outputs {
                if output is AVCaptureMetadataOutput {
                    self.session.removeOutput(output)
                }
            }
            
            self.faceDetectionBoxes.forEach({ $0.removeFromSuperview() })
            self.faceDetectionBoxes = []
            
            if self.cameraDetection == .faces {
                let metadataOutput = AVCaptureMetadataOutput()
                self.session.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                if metadataOutput.availableMetadataObjectTypes.contains(.face) {
                    metadataOutput.metadataObjectTypes = [.face]
                }
            }
        }
    }
    
    @objc public var flashMode = SCSession.FlashMode.off
    
    var captureDeviceInput: AVCaptureDeviceInput? {
        didSet {
            if let device = captureDeviceInput?.device {
                try? device.lockForConfiguration()
                device.videoZoomFactor = CGFloat(zoom)
                device.unlockForConfiguration()
            }
        }
    }
    
    var photoOutput = AVCapturePhotoOutput()
    
    var faceDetectionBoxes: [UIView] = []
    
    private var isPreviewLayerSetup = false
    private var isSessionRunning = false
    
    @objc public var resolution: CGSize = .zero {
        didSet {
            print("📸 [Photo Session] 设置分辨率: \(resolution.width) x \(resolution.height)")
            
            // 如果分辨率为零，使用设备支持的最大分辨率
            if resolution.width == 0 || resolution.height == 0 {
                if let device = videoInput?.device {
                    let maxResolution = device.activeFormat.highResolutionStillImageDimensions
                    resolution = CGSize(width: CGFloat(maxResolution.width), height: CGFloat(maxResolution.height))
                    print("📸 [Photo Session] 使用设备最大分辨率: \(resolution.width) x \(resolution.height)")
                }
                return
            }
            
            // 开始配置会话
            session.beginConfiguration()
            
            // 计算目标比例
            let targetAspectRatio = resolution.width / resolution.height
            print("📸 [Photo Session] 目标比例: \(targetAspectRatio)")
            
            // 根据目标比例选择合适的预设
            if abs(targetAspectRatio - 3.0/4.0) < 0.01 {
                // 3:4 比例
                session.sessionPreset = .photo
                print("📸 [Photo Session] 设置会话预设为: photo (3:4)")
            } else if abs(targetAspectRatio - 9.0/16.0) < 0.01 {
                // 9:16 比例
                session.sessionPreset = .hd1920x1080
                print("📸 [Photo Session] 设置会话预设为: 1920x1080 (16:9)")
            } else if abs(targetAspectRatio - 1.0) < 0.01 {
                // 1:1 比例
                session.sessionPreset = .high
                print("📸 [Photo Session] 设置会话预设为: high (1:1)")
            }
            
            // 确保不超过设备支持的最大分辨率
            if let device = videoInput?.device {
                let maxResolution = device.activeFormat.highResolutionStillImageDimensions
                let finalWidth = min(resolution.width, CGFloat(maxResolution.width))
                let finalHeight = min(resolution.height, CGFloat(maxResolution.height))
                resolution = CGSize(width: finalWidth, height: finalHeight)
                print("📸 [Photo Session] 最终分辨率: \(resolution.width) x \(resolution.height)")
            }
            
            // 配置照片输出
            if let connection = photoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            // 更新高分辨率设置
            photoOutput.isHighResolutionCaptureEnabled = true
            
            session.commitConfiguration()
            
            print("📸 [Photo Session] 会话配置完成")
            print("📸 [Photo Session] - 会话预设: \(session.sessionPreset.rawValue)")
            print("📸 [Photo Session] - 高分辨率拍摄: \(photoOutput.isHighResolutionCaptureEnabled)")
        }
    }
    
    @objc public init(position: CameraPosition = .back, detection: CameraDetection = .none) {
        super.init()
        
        defer {
            self.cameraPosition = position
            self.cameraDetection = detection
        }
        
        self.session.sessionPreset = .high
        
        // 配置照片输出
        photoOutput.isHighResolutionCaptureEnabled = true
        print("📸 [Photo Session] 初始化照片输出:")
        print("📸 [Photo Session] - 高分辨率拍摄: \(photoOutput.isHighResolutionCaptureEnabled)")
        print("📸 [Photo Session] - 图像稳定: \(photoOutput.isStillImageStabilizationSupported)")
        
        self.session.addOutput(self.photoOutput)
        configureInputs()
        
        // 开始监听设备方向变化
        startDeviceOrientationNotifier()
    }
    
    // 添加设备方向监听
    private var deviceOrientationNotifier: Any?
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait
    private let motionManager = CMMotionManager()
    
    private func startDeviceOrientationNotifier() {
        // 确保设备支持陀螺仪
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ [Orientation] 设备不支持运动检测")
            return
        }
        
        // 设置更新频率
        motionManager.deviceMotionUpdateInterval = 0.5
        
        // 开始监听设备运动
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self,
                  let motion = motion else {
                if let error = error {
                    print("⚠️ [Orientation] 运动更新错误: \(error.localizedDescription)")
                }
                return
            }
            
            // 获取重力向量
            let gravity = motion.gravity
            
            // 根据重力方向判断设备方向
            let orientation: UIDeviceOrientation
            if gravity.z < -0.75 {
                orientation = .faceUp
            } else if gravity.z > 0.75 {
                orientation = .faceDown
            } else {
                let x = gravity.x
                let y = gravity.y
                
                if abs(y) < 0.45 {
                    orientation = x < 0 ? .landscapeRight : .landscapeLeft
                } else {
                    orientation = y < 0 ? .portrait : .portraitUpsideDown
                }
            }
            
            // 如果方向发生变化，更新当前方向
            if orientation != self.currentDeviceOrientation {
                self.currentDeviceOrientation = orientation
                print("📸 [Orientation] 设备方向更新: \(orientation.rawValue)")
            }
        }
        
        print("📸 [Orientation] 开始监听设备方向")
    }
    
    deinit {
        // 停止运动更新
        motionManager.stopDeviceMotionUpdates()
        print("📸 [Orientation] 停止监听设备方向")
    }
    
    var captureCallback: (UIImage, AVCaptureResolvedPhotoSettings) -> Void = { (_, _) in }
    var errorCallback: (Error) -> Void = { (_) in }
    
    @objc public func capture(_ callback: @escaping (UIImage, AVCaptureResolvedPhotoSettings) -> Void, _ error: @escaping (Error) -> Void) {
        self.captureCallback = callback
        self.errorCallback = error

        // 创建照片设置
        let settings = AVCapturePhotoSettings()
        
        // 从SCCameraSettingsManager获取相机设置
        let cameraSettings = SCCameraSettingsManager.shared.getCameraSettings()
        
        // 设置闪光灯模式
        settings.flashMode = AVCaptureDevice.FlashMode(rawValue: cameraSettings.flashState.rawValue) ?? .auto
        
        // 设置图像稳定
        settings.isAutoStillImageStabilizationEnabled = photoOutput.isStillImageStabilizationSupported
        
        // 设置高分辨率拍摄
        settings.isHighResolutionPhotoEnabled = true
        
        // 获取目标分辨率
        let targetSize: CGSize
        if resolution.width > 0 && resolution.height > 0 {
            targetSize = resolution
            print("📸 [Capture] 使用设置的分辨率: \(targetSize.width) x \(targetSize.height)")
        } else if let device = videoInput?.device {
            // 使用设备支持的最大分辨率
            let maxResolution = device.activeFormat.highResolutionStillImageDimensions
            targetSize = CGSize(width: CGFloat(maxResolution.width), height: CGFloat(maxResolution.height))
            print("📸 [Capture] 使用设备最大分辨率: \(targetSize.width) x \(targetSize.height)")
        } else {
            // 使用默认分辨率
            targetSize = CGSize(width: 4032, height: 3024)
            print("📸 [Capture] 使用默认分辨率: \(targetSize.width) x \(targetSize.height)")
        }
        
        // 设置预览格式
        if let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first {
            let format: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                kCVPixelBufferWidthKey as String: Int(targetSize.width),
                kCVPixelBufferHeightKey as String: Int(targetSize.height)
            ]
            settings.previewPhotoFormat = format
            print("📸 [Capture] 设置照片格式: \(format)")
        }
        
        // 设置照片方向
        if let connection = photoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            print("📸 [Capture] 设置照片方向: portrait")
        }
        
        // 打印最终设置
        print("📸 [Capture] 最终照片设置:")
        print("📸 [Capture] - 目标尺寸: \(targetSize.width) x \(targetSize.height)")
        print("📸 [Capture] - 高分辨率: \(settings.isHighResolutionPhotoEnabled)")
        print("📸 [Capture] - 图像稳定: \(settings.isAutoStillImageStabilizationEnabled)")
        
        // 捕获照片
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc public func togglePosition() {
        self.cameraPosition = self.cameraPosition == .back ? .front : .back
    }
    
    @objc public override var zoom: Double {
        didSet {
            guard let device = self.captureDeviceInput?.device else {
                return
            }
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = CGFloat(self.zoom)
                device.unlockForConfiguration()
            } catch {
                //
            }
            
            if let delegate = self.delegate {
                delegate.didChangeValue(session: self, value: self.zoom, key: "zoom")
            }
        }
    }
    
    @objc public override func focus(at point: CGPoint) {
        guard let device = captureDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // 更新对焦状态
            focusState = .focusing
            
            // 设置对焦点
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                print("📸 [Focus] 设置对焦点：\(point)")
            }
            
            // 根据当前模式设置对焦
            switch focusMode {
            case .auto:
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            case .continuous:
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            case .locked:
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
            case .manual:
                // 手动对焦模式将在后续实现
                break
            }
            
            // 添加对焦观察者
            NotificationCenter.default.addObserver(self,
                                                 selector: #selector(subjectAreaDidChange),
                                                 name: .AVCaptureDeviceSubjectAreaDidChange,
                                                 object: device)
            
            device.unlockForConfiguration()
            
            // 延迟更新对焦状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.focusState = .focused
            }
            
            print("📸 [Focus] 对焦模式：\(focusMode)")
            
        } catch {
            print("⚠️ [Focus] 设置对焦失败: \(error.localizedDescription)")
            focusState = .failed
        }
    }
    
    @objc private func subjectAreaDidChange(notification: NSNotification) {
        // 主体区域发生变化时，如果是连续对焦模式，更新对焦状态
        if focusMode == .continuous {
            focusState = .focusing
            
            // 延迟更新状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.focusState = .focused
            }
        }
    }
    
    // 设置对焦模式
    public func setFocusMode(_ mode: SCFocusMode) {
        focusMode = mode
        print("📸 [Focus] 切换对焦模式：\(mode)")
    }
    
    // 锁定当前对焦
    public func lockFocus() {
        setFocusMode(.locked)
        focusState = .locked
        print("📸 [Focus] 锁定对焦")
    }
    
    // 解锁对焦
    public func unlockFocus() {
        setFocusMode(.continuous)
        print("📸 [Focus] 解锁对焦")
    }
    
    @available(iOS 11.0, *)
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📸 [Photo Session] ===== 照片处理完成 =====")
        
        if let error = error {
            print("❌ [Photo Session] 处理照片时出错: \(error.localizedDescription)")
            self.errorCallback(error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ [Photo Session] 无法获取图片数据")
            self.errorCallback(SCError.error("Cannot get photo file data representation"))
            return
        }
        
        print("📸 [Photo Session] 照片信息:")
        print("📸 [Photo Session] - 数据大小: \(Double(imageData.count) / 1024.0 / 1024.0) MB")
        
        // 获取照片分辨率
        if let cgImage = UIImage(data: imageData)?.cgImage {
            print("📸 [Photo Session] - 实际分辨率: \(cgImage.width) x \(cgImage.height)")
        }
        
        // 处理照片数据，传递原始的 resolvedSettings
        self.processPhotoData(imageData, photo.resolvedSettings)
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        defer {
            self.captureCallback = { (_, _) in }
            self.errorCallback = { (_) in }
        }

        if let error = error {
            self.errorCallback(error)
            return
        }

        guard
            let photoSampleBuffer = photoSampleBuffer, let previewPhotoSampleBuffer = previewPhotoSampleBuffer,
            let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer) else
        {
            self.errorCallback(SCError.error("Cannot get photo file data representation"))
            return
        }

        self.processPhotoData(data, resolvedSettings)
    }
    
    func processPhotoData(_ data: Data, _ resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("📸 [Photo Session] ===== 处理照片数据 =====")
        print("📸 [Photo Session] - 数据大小: \(Double(data.count) / 1024.0 / 1024.0) MB")
        
        guard let image = UIImage(data: data) else {
            print("❌ [Photo Session] 无法从数据创建图像")
            self.errorCallback(SCError.error("Cannot create image from data"))
            return
        }
        
        print("📸 [Photo Session] 原始图片信息:")
        print("📸 [Photo Session] - 尺寸: \(image.size.width) x \(image.size.height)")
        print("📸 [Photo Session] - 方向: \(image.imageOrientation.rawValue)")
        
        // 异步处理图像
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 获取当前设备方向
            let deviceOrientation = self.currentDeviceOrientation
            print("📸 [Photo Process] 设备方向: \(deviceOrientation.rawValue)")
            
            // 确定图片方向
            let imageOrientation: UIImage.Orientation = {
                switch deviceOrientation {
                case .portrait:
                    return self.cameraPosition == .front ? .rightMirrored : .right
                case .portraitUpsideDown:
                    return self.cameraPosition == .front ? .leftMirrored : .left
                case .landscapeLeft:
                    return self.cameraPosition == .front ? .upMirrored : .up
                case .landscapeRight:
                    return self.cameraPosition == .front ? .downMirrored : .down
                case .faceUp, .faceDown:
                    // 如果设备平放，使用预览层的方向
                    if let connection = self.previewLayer?.connection,
                       connection.isVideoOrientationSupported {
                        switch connection.videoOrientation {
                        case .portrait:
                            return self.cameraPosition == .front ? .rightMirrored : .right
                        case .portraitUpsideDown:
                            return self.cameraPosition == .front ? .leftMirrored : .left
                        case .landscapeLeft:
                            return self.cameraPosition == .front ? .upMirrored : .up
                        case .landscapeRight:
                            return self.cameraPosition == .front ? .downMirrored : .down
                        @unknown default:
                            return self.cameraPosition == .front ? .rightMirrored : .right
                        }
                    }
                    return self.cameraPosition == .front ? .rightMirrored : .right
                default:
                    return self.cameraPosition == .front ? .rightMirrored : .right
                }
            }()
            
            print("📸 [Photo Process] 目标图片方向: \(imageOrientation.rawValue)")
            
            // 创建正确方向的图片
            let finalImage: UIImage
            if let cgImage = image.cgImage {
                finalImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: imageOrientation)
                print("📸 [Photo Process] 已调整图片方向")
            } else {
                finalImage = image
                print("⚠️ [Photo Process] 无法获取 CGImage，使用原始图片")
            }
            
            print("📸 [Photo Process] 最终图片信息:")
            print("📸 [Photo Process] - 尺寸: \(finalImage.size.width) x \(finalImage.size.height)")
            print("📸 [Photo Process] - 方向: \(finalImage.imageOrientation.rawValue)")
            
            DispatchQueue.main.async {
                self.captureCallback(finalImage, resolvedSettings)
                print("📸 [Photo Session] ===== 照片处理完成 =====")
            }
        }
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let faceMetadataObjects = metadataObjects.filter({ $0.type == .face })
        
        if faceMetadataObjects.count > self.faceDetectionBoxes.count {
            for _ in 0..<faceMetadataObjects.count - self.faceDetectionBoxes.count {
                let view = UIView()
                view.layer.borderColor = UIColor.green.cgColor
                view.layer.borderWidth = 1
                self.overlayView?.addSubview(view)
                self.faceDetectionBoxes.append(view)
            }
        } else if faceMetadataObjects.count < self.faceDetectionBoxes.count {
            for _ in 0..<self.faceDetectionBoxes.count - faceMetadataObjects.count {
                self.faceDetectionBoxes.popLast()?.removeFromSuperview()
            }
        }
        
        for i in 0..<faceMetadataObjects.count {
            if let transformedMetadataObject = self.previewLayer?.transformedMetadataObject(for: faceMetadataObjects[i]) {
                self.faceDetectionBoxes[i].frame = transformedMetadataObject.bounds
            } else {
                self.faceDetectionBoxes[i].frame = CGRect.zero
            }
        }
    }
    
    private func configureInputs() {
        session.beginConfiguration()
        
        for input in session.inputs {
            session.removeInput(input)
        }
        
        do {
            let deviceInput = try SCSession.captureDeviceInput(type: cameraPosition.deviceType)
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
                self.captureDeviceInput = deviceInput
            }
        } catch {
            print("Error configuring camera input: \(error.localizedDescription)")
        }
        
        session.commitConfiguration()
    }

    override func setupPreviewLayer(in view: UIView, completion: (() -> Void)? = nil) {
        guard !isPreviewLayerSetup else { return }
        
        let startTime = Date()
        print("⏱️ [Preview Setup] Started at: \(startTime)")
        
        // 1. 创建预览层
        let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        print("⏱️ [Preview Setup] Preview layer created: +\(Date().timeIntervalSince(startTime))s")
        
        // 2. 在主线程设置UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer
            self.isPreviewLayerSetup = true
            print("⏱️ [Preview Setup] Preview layer configured: +\(Date().timeIntervalSince(startTime))s")
            
            // 3. 在后台线程启动会话
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                if !self.isSessionRunning {
                    print("⏱️ [Preview Setup] Starting session: +\(Date().timeIntervalSince(startTime))s")
                    self.session.startRunning()
                    self.isSessionRunning = true
                    print("⏱️ [Preview Setup] Session started: +\(Date().timeIntervalSince(startTime))s")
                    
                    DispatchQueue.main.async {
                        print("⏱️ [Preview Setup] Setup completed: +\(Date().timeIntervalSince(startTime))s")
                        completion?()
                    }
                }
            }
        }
    }

    // MARK: - Focus Methods
    private func loadFocusSettings() {
        let settings = SCCameraSettingsManager.shared
        focusMode = settings.focusMode
        
        if settings.isFocusLocked {
            lockFocus()
        }
    }

    // MARK: - Session Setup
    private func setupSession() {
        session.beginConfiguration()
        
        // 设置会话质量
        session.sessionPreset = .photo
        
        // 设置视频输入
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("无法获取相机设备")
            session.commitConfiguration()
            return
        }
        
        do {
            videoInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(videoInput!) {
                session.addInput(videoInput!)
            }
        } catch {
            print("设置视频输入失败: \(error)")
            session.commitConfiguration()
            return
        }
        
        // 设置照片输出
        photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
    }
    
    // MARK: - Session Control
    func startSession() {
        // 确保在后台线程调用
        if Thread.isMainThread {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.startSession()
            }
            return
        }
        
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    func stopSession() {
        // 确保在后台线程调用
        if Thread.isMainThread {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.stopSession()
            }
            return
        }
        
        if session.isRunning {
            session.stopRunning()
        }
    }

    // MARK: - Flash Control
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) -> Bool {
        guard let device = captureDeviceInput?.device else { return false }
        
        do {
            try device.lockForConfiguration()
            if device.hasFlash && device.isFlashAvailable {
                device.flashMode = mode
                device.unlockForConfiguration()
                return true
            } else {
                device.unlockForConfiguration()
                return false
            }
            print("设置闪光灯模式为：\(mode)")
        } catch {
            print("设置闪光灯失败: \(error)")
            return false
        }
    }
    
    var isFlashAvailable: Bool {
        guard let device = captureDeviceInput?.device else { return false }
        return device.hasFlash && device.isFlashAvailable
    }
    
    var currentFlashMode: AVCaptureDevice.FlashMode? {
        return captureDeviceInput?.device.flashMode
    }

    public func setWhiteBalanceMode(_ state: SCWhiteBalanceState) -> Bool {
        guard let device = captureDeviceInput?.device else { return false }
        
        do {
            try device.lockForConfiguration()
            
            switch state {
            case .auto:
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                    print("设置自动白平衡模式成功")
                } else {
                    print("设备不支持自动白平衡模式")
                    device.unlockForConfiguration()
                    return false
                }
                
            case .sunny, .cloudy, .fluorescent, .incandescent:
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                    let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                        temperature: state.temperature,
                        tint: state.tint
                    )
                    let gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
                    let normalizedGains = self.normalizeWhiteBalanceGains(gains, for: device)
                    device.setWhiteBalanceModeLocked(with: normalizedGains)
                    print("设置白平衡模式成功：\(state.title)")
                } else {
                    print("设备不支持锁定白平衡模式")
                    device.unlockForConfiguration()
                    return false
                }
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            print("设置白平衡模式失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 辅助方法：确保白平衡增益值在设备支持的范围内
    private func normalizeWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains, for device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        var normalizedGains = gains
        
        // 确保每个增益值都在设备支持的范围内
        let minGain: Float = 1.0  // 最小增益值通常为 1.0
        let maxGain: Float = device.maxWhiteBalanceGain
        
        normalizedGains.redGain = min(max(gains.redGain, minGain), maxGain)
        normalizedGains.greenGain = min(max(gains.greenGain, minGain), maxGain)
        normalizedGains.blueGain = min(max(gains.blueGain, minGain), maxGain)
        
        return normalizedGains
    }

    // MARK: - Camera Settings
    public func setExposure(_ value: Float) -> Bool {
        guard let device = captureDeviceInput?.device else { return false }

        do {
            try device.lockForConfiguration()
            
            // 首先切换到自动曝光模式
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                
                // 获取设备支持的曝光范围
                let minExposure = device.minExposureTargetBias
                let maxExposure = device.maxExposureTargetBias
                
                // 将输入值 (-2.0 到 +2.0) 映射到设备支持的范围
                let normalizedValue = (value + 2.0) / 4.0  // 将 -2.0~2.0 映射到 0~1
                let exposureValue = minExposure + (maxExposure - minExposure) * normalizedValue
                
                // 确保值在设备支持的范围内
                let clampedValue = min(max(exposureValue, minExposure), maxExposure)
                
                // 应用曝光值
                device.setExposureTargetBias(clampedValue)
                print("📸 [Exposure] 设置曝光值：\(clampedValue) (原始值：\(value))")
                print("📸 [Exposure] 设备支持范围：[\(minExposure), \(maxExposure)]")
                
                // 等待曝光调整生效
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            } else {
                print("⚠️ [Exposure] 设备不支持自动曝光模式")
                device.unlockForConfiguration()
                return false
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            print("⚠️ [Exposure] 设置曝光值失败: \(error.localizedDescription)")
            return false
        }
    }
    
    public func setISO(_ value: Float) -> Bool {
        guard let device = captureDeviceInput?.device else { return false }
        
        do {
            try device.lockForConfiguration()
            
            if value == 0 {
                // Auto ISO
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    print("设置 ISO 为自动模式")
                } else {
                    print("设备不支持自动 ISO 模式")
                    device.unlockForConfiguration()
                    return false
                }
            } else {
                // Manual ISO
                if device.isExposureModeSupported(.custom) {
                    device.exposureMode = .custom
                    let isoValue = min(max(value, device.activeFormat.minISO), device.activeFormat.maxISO)
                    device.setExposureModeCustom(duration: device.exposureDuration, iso: isoValue)
                    print("设置 ISO 值为：\(isoValue)")
                } else {
                    print("设备不支持自定义 ISO 模式")
                    device.unlockForConfiguration()
                    return false
                }
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            print("设置 ISO 失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Focus Mode
    public private(set) var focusMode: SCFocusMode = .continuous {
        didSet {
            updateFocusMode()
            // 保存设置
            SCCameraSettingsManager.shared.focusMode = focusMode
        }
    }
    
    public private(set) var focusState: SCFocusState = .focused {
        didSet {
            // 通知代理焦点状态变化
            if let delegate = self.delegate {
                delegate.didChangeValue(session: self, value: focusState, key: "focusState")
            }
            
            // 更新对焦锁定状态
            if focusState == .locked {
                SCCameraSettingsManager.shared.isFocusLocked = true
            } else if focusState == .focused && focusMode != .locked {
                SCCameraSettingsManager.shared.isFocusLocked = false
            }
        }
    }
    
    private func updateFocusMode() {
        guard let device = captureDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            switch focusMode {
            case .auto:
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            case .continuous:
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            case .locked:
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
            case .manual:
                // 手动对焦模式将在后续实现
                break
            }
            
            device.unlockForConfiguration()
        } catch {
            print("⚠️ [Focus] 更新对焦模式失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Shutter Speed Control
    public func setShutterSpeed(_ value: Float, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard let device = videoInput?.device else {
            print("📸 [Shutter Speed] 无法获取相机设备")
            completion?(false)
            return false
        }
        
        do {
            try device.lockForConfiguration()
            
            // 检查设备是否支持自定义曝光模式
            if device.isExposureModeSupported(.custom) {
                if value == 0 {
                    // 值为0时，切换到自动曝光模式
                    device.exposureMode = .continuousAutoExposure
                    print("📸 [Shutter Speed] 切换到自动曝光模式")
                    device.unlockForConfiguration()
                    completion?(true)
                    return true
                } else {
                    // 设置自定义曝光模式
                    device.exposureMode = .custom
                    
                    // 禁用自动曝光补偿
                    if device.isExposurePointOfInterestSupported {
                        device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                    }
                    
                    // 将快门速度值转换为 CMTime
                    // value 表示秒数，例如 value = 0.001 表示 1/1000 秒
                    let seconds = value
                    print("📸 [Shutter Speed] 设置快门速度：\(seconds)秒 (1/\(Int(1/seconds))秒)")
                    let shutterSpeed = CMTimeMakeWithSeconds(Float64(seconds), preferredTimescale: 1000000)
                    
                    // 获取设备支持的快门速度范围
                    let minDuration = device.activeFormat.minExposureDuration
                    let maxDuration = device.activeFormat.maxExposureDuration
                    print("📸 [Shutter Speed] 设备支持的快门速度范围：[\(CMTimeGetSeconds(minDuration))秒, \(CMTimeGetSeconds(maxDuration))秒]")
                    
                    // 确保快门速度在有效范围内
                    let clampedDuration = min(max(shutterSpeed, minDuration), maxDuration)
                    
                    // 使用固定的 ISO 值
                    let baseISO = device.activeFormat.minISO
                    print("📸 [Shutter Speed] 使用固定 ISO 值：\(baseISO)")
                    
                    // 设置曝光时间和 ISO
                    device.setExposureModeCustom(duration: clampedDuration, iso: baseISO) { _ in
                        print("📸 [Shutter Speed] 设置完成 - 快门速度: \(CMTimeGetSeconds(clampedDuration))秒, ISO: \(baseISO)")
                        completion?(true)
                    }
                }
                
                device.unlockForConfiguration()
                return true
            } else {
                print("⚠️ [Shutter Speed] 设备不支持自定义曝光模式")
                device.unlockForConfiguration()
                completion?(false)
                return false
            }
        } catch {
            print("📸 [Shutter Speed] 设置失败: \(error.localizedDescription)")
            completion?(false)
            return false
        }
    }

//    public func capturePhoto() {
//        print("📸 [Photo Session] ===== 开始拍照 =====")
//        
//        // 获取当前设备方向
//        let deviceOrientation = UIDevice.current.orientation
//        print("📸 [Photo Session] 拍摄信息:")
//        print("📸 [Photo Session] - 设备方向: \(deviceOrientation.rawValue)")
//        print("📸 [Photo Session] - 是否前置摄像头: \(self.cameraPosition == .front)")
//        
//        // 创建照片设置
//        let settings = AVCapturePhotoSettings()
//        
//        // 确保使用高质量照片输出
//        settings.isHighResolutionPhotoEnabled = photoOutput.isHighResolutionCaptureEnabled
//        
//        // 设置照片分辨率和格式
//        if let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first {
//            // 获取目标分辨率
//            let targetSize: CGSize
//            if resolution.width > 0 && resolution.height > 0 {
//                targetSize = resolution
//                print("📸 [Capture] 使用设置的分辨率: \(targetSize.width) x \(targetSize.height)")
//            } else if let device = videoInput?.device {
//                // 使用设备支持的最大分辨率
//                let maxResolution = device.activeFormat.highResolutionStillImageDimensions
//                targetSize = CGSize(width: CGFloat(maxResolution.width), height: CGFloat(maxResolution.height))
//                print("📸 [Capture] 使用设备最大分辨率: \(targetSize.width) x \(targetSize.height)")
//            } else {
//                // 使用默认 4:3 分辨率
//                targetSize = CGSize(width: 4032, height: 3024)
//                print("📸 [Capture] 使用默认分辨率: \(targetSize.width) x \(targetSize.height)")
//            }
//            
//            // 设置预览格式
//            let format: [String: Any] = [
//                kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
//                kCVPixelBufferWidthKey as String: Int(targetSize.width),
//                kCVPixelBufferHeightKey as String: Int(targetSize.height)
//            ]
//            settings.previewPhotoFormat = format
//            print("📸 [Capture] 设置照片格式: \(format)")
//        }
//        
//        // 根据设备能力设置图像稳定
//        settings.isAutoStillImageStabilizationEnabled = photoOutput.isStillImageStabilizationSupported
//        
//        // 设置闪光灯
//        settings.flashMode = self.flashMode.captureFlashMode
//        
//        // 设置照片方向
//        if let connection = self.photoOutput.connection(with: .video) {
//            connection.videoOrientation = deviceOrientation.videoOrientation
//            print("📸 [Capture] 设置照片方向: \(connection.videoOrientation.rawValue)")
//        }
//        
//        // 打印最终设置
//        print("📸 [Capture] 最终照片设置:")
//        print("📸 [Capture] - 预览格式: \(settings.previewPhotoFormat ?? [:])")
//        print("📸 [Capture] - 高分辨率: \(settings.isHighResolutionPhotoEnabled)")
//        print("📸 [Capture] - 图像稳定: \(settings.isAutoStillImageStabilizationEnabled)")
//        
//        // 开始拍照
//        self.photoOutput.capturePhoto(with: settings, delegate: self)
//    }

}
