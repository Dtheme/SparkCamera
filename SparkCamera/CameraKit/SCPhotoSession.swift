//
//  SCPhotoSession.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import AVFoundation

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
    
    @objc public init(position: CameraPosition = .back, detection: CameraDetection = .none) {
        super.init()
        
        defer {
            self.cameraPosition = position
            self.cameraDetection = detection
        }
        
        self.session.sessionPreset = .high
        self.session.addOutput(self.photoOutput)
        configureInputs()
    }
    
    @objc deinit {
        self.faceDetectionBoxes.forEach({ $0.removeFromSuperview() })
    }
    
    var captureCallback: (UIImage, AVCaptureResolvedPhotoSettings) -> Void = { (_, _) in }
    var errorCallback: (Error) -> Void = { (_) in }
    
    @objc public func capture(_ callback: @escaping (UIImage, AVCaptureResolvedPhotoSettings) -> Void, _ error: @escaping (Error) -> Void) {
        self.captureCallback = callback
        self.errorCallback = error

        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode.captureFlashMode
        
        // 确保使用当前的曝光设置
        if let device = videoInput?.device {
            settings.isAutoStillImageStabilizationEnabled = false  // 禁用自动图像稳定
            if device.exposureMode == .custom {
                print("📸 [Capture] 使用自定义曝光设置")
                print("📸 [Capture] 当前快门速度：\(CMTimeGetSeconds(device.exposureDuration))秒")
                print("📸 [Capture] 当前 ISO：\(device.iso)")
                settings.isAutoStillImageStabilizationEnabled = false
            } else {
                print("📸 [Capture] 使用自动曝光设置")
            }
        }

        if let connection = self.photoOutput.connection(with: .video) {
            if self.resolution.width > 0, self.resolution.height > 0 {
                connection.videoOrientation = .portrait
            } else {
                connection.videoOrientation = UIDevice.current.orientation.videoOrientation
            }
        }
        
        self.photoOutput.capturePhoto(with: settings, delegate: self)
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
    
    @objc public var resolution = CGSize.zero {
        didSet {
            guard let deviceInput = self.captureDeviceInput else {
                return
            }
            
            do {
                try deviceInput.device.lockForConfiguration()
                
                if
                    self.resolution.width > 0, self.resolution.height > 0,
                    let format = SCSession.deviceInputFormat(input: deviceInput, width: Int(self.resolution.width), height: Int(self.resolution.height))
                {
                    deviceInput.device.activeFormat = format
                } else {
                    self.session.sessionPreset = .high
                }
                
                deviceInput.device.unlockForConfiguration()
            } catch {
                //
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
        defer {
            self.captureCallback = { (_, _) in }
            self.errorCallback = { (_) in }
        }

        if let error = error {
            self.errorCallback(error)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            self.errorCallback(SCError.error("Cannot get photo file data representation"))
            return
        }

        self.processPhotoData(data: data, resolvedSettings: photo.resolvedSettings)
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

        self.processPhotoData(data: data, resolvedSettings: resolvedSettings)
    }
    
    private func processPhotoData(data: Data, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        guard let image = UIImage(data: data) else {
            self.errorCallback(SCError.error("Cannot get photo"))
            return
        }

        if
            self.resolution.width > 0, self.resolution.height > 0,
            let transformedImage = SCUtils.cropAndScale(image, width: Int(self.resolution.width), height: Int(self.resolution.height), orientation: UIDevice.current.orientation, mirrored: self.cameraPosition == .front)
        {
            self.captureCallback(transformedImage, resolvedSettings)
            return
        }

        self.captureCallback(image, resolvedSettings)
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
    
    // MARK: - Camera Setup
    private func setupCamera() {
        setupSession()
        loadFocusSettings()
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
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }
    
    func stopSession() {
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
                print("📸 [Shutter Speed] 设备不支持自定义曝光模式")
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
}
