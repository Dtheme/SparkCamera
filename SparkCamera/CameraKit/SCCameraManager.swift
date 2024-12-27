//
//  SCCameraManager.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/25.
//

import AVFoundation

class SCCameraManager {
    
    public var currentCameraPosition: AVCaptureDevice.Position = .back
    private var availableDevices: [AVCaptureDevice] = []
    private var session: SCSession
    private var lastSelectedLens: SCLensModel? // 保存前一次选中的镜头
    private var photoSession: SCPhotoSession
    
    init(session: SCSession, photoSession: SCPhotoSession) {
        self.session = session
        self.photoSession = photoSession
        
        // 使用默认相机初始化
        if let defaultDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            setupCamera(with: defaultDevice)
        }
        
        // 异步获取可用设备
        DispatchQueue.global(qos: .background).async {
            self.availableDevices = self.getAvailableDevices()
        }
    }
    
    private func setupCamera(with device: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.session.beginConfiguration()
            
            // 移除现有输入
            for input in session.session.inputs {
                session.session.removeInput(input)
            }
            
            // 添加新输入
            if session.session.canAddInput(input) {
                session.session.addInput(input)
                session.videoInput = input
                currentCameraPosition = device.position
            }
            
            session.session.commitConfiguration()
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    private func getAvailableDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }
    
    func getAvailableLensOptions(completion: @escaping ([SCLensModel]) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let devices = self.getAvailableDevices()
            let lensOptions = devices.filter { $0.position == .back }.map { device in
                switch device.deviceType {
                case .builtInUltraWideCamera:
                    return SCLensModel(name: "0.5x", type: .builtInUltraWideCamera)
                case .builtInWideAngleCamera:
                    return SCLensModel(name: "1x", type: .builtInWideAngleCamera)
                case .builtInTelephotoCamera:
                    return SCLensModel(name: "3x", type: .builtInTelephotoCamera)
                default:
                    return nil
                }
            }.compactMap { $0 }
            
            DispatchQueue.main.async {
                completion(lensOptions)
            }
        }
    }
    
    func switchCamera(to lens: SCLensModel, completion: @escaping (String) -> Void) {
        guard let device = availableDevices.first(where: { $0.deviceType == lens.type && $0.position == (lens.name == "Front" ? .front : .back) }) else {
            completion("Lens not available")
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            session.session.beginConfiguration()
            
            // Remove existing inputs
            for input in session.session.inputs {
                session.session.removeInput(input)
            }
            
            // Add new input
            if session.session.canAddInput(newInput) {
                session.session.addInput(newInput)
                session.videoInput = newInput
                currentCameraPosition = device.position
                
                // 更新 currentLens
                session.currentLens = lens
                print("Switched to lens: \(lens.name)")
                
                if let previewLayer = session.previewLayer,
                   let superlayer = previewLayer.superlayer,
                   let previewView = superlayer.delegate as? SCPreviewView {
                    switch lens.name {
                    case "0.5x":
                        previewView.maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 2.0)
                    case "1x":
                        previewView.maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 2.96)
                    case "3x":
                        previewView.maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 15.0)
                    default:
                        previewView.maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 15.0)
                    }
                    previewView.currentZoomFactor = 1.0
                    print("Current zoom factor set to \(previewView.currentZoomFactor)")
                    
                    do {
                        try device.lockForConfiguration()
                        device.videoZoomFactor = previewView.currentZoomFactor
                        device.unlockForConfiguration()
                        print("Applied zoom factor: \(device.videoZoomFactor)")
                    } catch {
                        print("Error setting zoom: \(error.localizedDescription)")
                    }
                }
                
                if device.position == .back {
                    lastSelectedLens = lens
                }
                
                let lensInfo = """
                Switched to \(lens.name) camera
                Device: \(device.localizedName)
                Position: \(device.position == .front ? "Front" : "Back")
                Focal Length: \(device.activeFormat.videoFieldOfView)mm
                Aperture: f/\(device.lensAperture)
                Zoom Range: \(device.minAvailableVideoZoomFactor)x to \(device.maxAvailableVideoZoomFactor)x
                """
                print(lensInfo)
                
                let lensName = device.position == .front ? "Front" : lens.name
                completion("镜头已切换至 \(lensName)")
            } else {
                completion("Failed to switch lens")
            }
            
            session.session.commitConfiguration()
        } catch {
            completion("Error switching lens: \(error.localizedDescription)")
        }
    }
    
    func getLastSelectedLens() -> SCLensModel? {
        return lastSelectedLens
    }
} 
