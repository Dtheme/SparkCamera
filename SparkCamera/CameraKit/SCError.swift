//
//  SCError.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import Foundation

public enum SCError: Error {
    case captureDeviceNotFound
    case error(String)
}
