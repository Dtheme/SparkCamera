//
//  SCCameraManager.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/25.
//

import AVFoundation

class SCCameraManager {
    
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var availableDevices: [AVCaptureDevice] = []
    
    init() {
        self.availableDevices = self.getAvailableDevices()
    }
    
    private func getAvailableDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }
    
    func getAvailableLensOptions() -> [SCLensModel] {
        return [
            SCLensModel(name: "0.5x", type: .builtInUltraWideCamera),
            SCLensModel(name: "1x", type: .builtInWideAngleCamera),
            SCLensModel(name: "3x", type: .builtInTelephotoCamera)
        ]
    }
    
    func switchCamera(to lens: SCLensModel, completion: @escaping (String) -> Void) {
        // 根据选择的镜头倍数切换相机
        // 这里需要实现具体的切换逻辑
        completion("Switched to \(lens.name)")
    }
} 