import UIKit
import AVFoundation
import RxSwift
import RxCocoa

@available(iOS 15.0, *)
class SCCameraManager: NSObject {
    
    // MARK: - Properties
    private let captureSession = AVCaptureSession()
    private var currentDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    private let disposeBag = DisposeBag()
    
    // RxSwift Subjects
    let capturePhotoSubject = PublishSubject<Data>()
    let errorSubject = PublishSubject<Error>()
    
    var configuration: SCCameraConfiguration {
        didSet {
            configureSession()
        }
    }
    
    // MARK: - Public Properties
    var session: AVCaptureSession {
        return captureSession
    }
    
    // MARK: - Initialization
    init(configuration: SCCameraConfiguration) {
        self.configuration = configuration
        super.init()
        setupSession()
    }
    
    // MARK: - Session Setup
    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = configuration.quality
        
        // 配置视频输入
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: configuration.position) else {
            errorSubject.onNext(CameraError.deviceNotAvailable)
            print("[Error] Camera device not available.")
            return
        }
        print("  选择的相机设备: \(device.localizedName)")
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                videoInput = input
                currentDevice = device
                print("  视频输入已添加到会话中。")
            }
        } catch {
            errorSubject.onNext(CameraError.systemError(error))
            print("[Error] Failed to create video input: \(error.localizedDescription)")
            return
        }
        
        // 配置照片输出
        let output = AVCapturePhotoOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            photoOutput = output
            output.maxPhotoQualityPrioritization = .quality
            print("  照片输出已添加到会话中。")
        }
        
        captureSession.commitConfiguration()
        print("  捕获会话已配置。")
        
        // 配置设备参数
        configureDevice()
    }
    
    // MARK: - Device Configuration
    private func configureDevice() {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // 配置对焦
            if device.isFocusModeSupported(configuration.focusMode) {
                device.focusMode = configuration.focusMode
                if let focusPoint = configuration.focusPoint {
                    device.focusPointOfInterest = focusPoint
                }
                print("  对焦模式设置为 \(device.focusMode.rawValue)。")
            }
            
            // 配置曝光
            if device.isExposureModeSupported(configuration.exposureMode) {
                device.exposureMode = configuration.exposureMode    
                try device.setExposureTargetBias(configuration.exposureBias)
                print("  曝光模式设置为 \(device.exposureMode.rawValue)。")
            }
            
            // 配置白平衡
            if device.isWhiteBalanceModeSupported(configuration.whiteBalanceMode) {
                device.whiteBalanceMode = configuration.whiteBalanceMode
                print("  白平衡模式设置为 \(device.whiteBalanceMode.rawValue)。")
            }
            
            // 配置变焦
            device.videoZoomFactor = configuration.videoZoomFactor
            print("  视频变焦因子设置为 \(device.videoZoomFactor)。")
            
            device.unlockForConfiguration()
        } catch {
            errorSubject.onNext(CameraError.systemError(error))
            print("[Error] Failed to configure device: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Session Configuration
    private func configureSession() {
        captureSession.beginConfiguration()
        
        // 更新会话质量
        captureSession.sessionPreset = configuration.quality
        
        // 如果位置发生变化，需要重新配置输入设备
        if let currentDevice = currentDevice, 
           currentDevice.position != configuration.position {
            // 移除当前输入
            if let videoInput = videoInput {
                captureSession.removeInput(videoInput)
            }
            
            // 配置新的视频输入
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                     for: .video,
                                                     position: configuration.position) else {
                errorSubject.onNext(CameraError.deviceNotAvailable)
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                    self.videoInput = input
                    self.currentDevice = device
                }
            } catch {
                errorSubject.onNext(CameraError.systemError(error))
                return
            }
        }
        
        captureSession.commitConfiguration()
        
        // 配置设备参数
        configureDevice()
    }
    
    // MARK: - Public Methods
    func updateConfiguration() {
        configureDevice()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                print("  捕获会话已启动。")
            } else {
                print("Capture session was already running.")
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            print("  捕获会话已停止。")
        } else {
            print("Capture session was not running.")
        }
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            errorSubject.onNext(CameraError.captureFailed)
            print("[Error] Photo output not available.")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = configuration.flashMode
        
        photoOutput.capturePhoto(with: settings, delegate: self)
        print("Photo capture initiated.")
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension SCCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            errorSubject.onNext(CameraError.systemError(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            errorSubject.onNext(CameraError.captureFailed)
            return
        }
        
        capturePhotoSubject.onNext(imageData)
    }
}

// MARK: - Custom Errors
enum CameraError: Error {
    case deviceNotAvailable
    case systemError(Error)
    case captureFailed
} 

