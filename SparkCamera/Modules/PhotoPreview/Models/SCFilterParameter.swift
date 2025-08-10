//
//  SCFilterParameter.swift
//  SparkCamera
//
//  预览页编辑模式的参数模型与规范
//

import Foundation

/// 支持的滤镜参数（单一职责：定义参数元数据）
enum SCFilterParameter: CaseIterable {
    case presetTemplates
    case brightness
    case contrast
    case saturation
    case exposure
    case highlights
    case shadows
    case grain
    case sharpness
    case blur
    case glow
    case edgeStrength
    case red
    case green
    case blue
}

extension SCFilterParameter {
    var displayName: String {
        switch self {
        case .presetTemplates: return "预置"
        case .brightness: return "亮度"
        case .contrast: return "对比度"
        case .saturation: return "饱和度"
        case .exposure: return "曝光"
        case .highlights: return "高光"
        case .shadows: return "阴影"
        case .grain: return "颗粒感"
        case .sharpness: return "锐度"
        case .blur: return "模糊"
        case .glow: return "光晕"
        case .edgeStrength: return "边缘强度"
        case .red: return "红色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        }
    }
    
    /// 与 SCFilterView.updateParameter 的键名保持一致
    var key: String? {
        switch self {
        case .presetTemplates: return nil
        case .brightness: return "亮度"
        case .contrast: return "对比度"
        case .saturation: return "饱和度"
        case .exposure: return "曝光"
        case .highlights: return "高光"
        case .shadows: return "阴影"
        case .grain: return "颗粒感"
        case .sharpness: return "锐度"
        case .blur: return "模糊"
        case .glow: return "光晕"
        case .edgeStrength: return "边缘强度"
        case .red: return "红色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        }
    }
    
    var minValue: Float {
        switch self {
        case .presetTemplates: return 0
        case .brightness: return -1.0
        case .contrast: return 0.5
        case .saturation: return 0.0
        case .exposure: return -3.0
        case .highlights: return 0.0
        case .shadows: return 0.0
        case .grain: return 0.0
        case .sharpness: return -4.0
        case .blur: return 0.0
        case .glow: return 0.0
        case .edgeStrength: return 0.0
        case .red, .green, .blue: return 0.0
        }
    }
    
    var maxValue: Float {
        switch self {
        case .presetTemplates: return 0
        case .brightness: return 1.0
        case .contrast: return 4.0
        case .saturation: return 2.0
        case .exposure: return 3.0
        case .highlights: return 1.0
        case .shadows: return 1.0
        case .grain: return 1.0
        case .sharpness: return 4.0
        case .blur: return 2.0
        case .glow: return 1.0
        case .edgeStrength: return 4.0
        case .red, .green, .blue: return 2.0
        }
    }
    
    var step: Float {
        switch self {
        case .presetTemplates: return 0
        case .brightness: return 0.05
        case .contrast: return 0.1
        case .saturation: return 0.05
        case .exposure: return 0.1
        case .highlights: return 0.05
        case .shadows: return 0.05
        case .grain: return 0.05
        case .sharpness: return 0.1
        case .blur: return 0.05
        case .glow: return 0.05
        case .edgeStrength: return 0.1
        case .red, .green, .blue: return 0.05
        }
    }
    
    var defaultValue: Float {
        switch self {
        case .presetTemplates: return 0
        case .brightness: return 0.0
        case .contrast: return 1.0
        case .saturation: return 1.0
        case .exposure: return 0.0
        case .highlights: return 1.0
        case .shadows: return 1.0
        case .grain: return 0.0
        case .sharpness: return 0.0
        case .blur: return 0.0
        case .glow: return 0.0
        case .edgeStrength: return 0.0
        case .red, .green, .blue: return 1.0
        }
    }
}


