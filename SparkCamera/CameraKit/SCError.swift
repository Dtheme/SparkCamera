//
//  SCError.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import Foundation

public enum SCError: LocalizedError {
    case captureDeviceNotFound
    case captureError(String)
    case permissionDenied
    case setupError(String)
    
    public var errorDescription: String? {
        switch self {
        case .captureDeviceNotFound:
            return "未找到可用的相机设备"
        case .captureError(let message):
            return message
        case .permissionDenied:
            return "相机权限被拒绝"
        case .setupError(let message):
            return message
        }
    }
}
