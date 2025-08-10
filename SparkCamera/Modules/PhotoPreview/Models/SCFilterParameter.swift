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
    
    /// UI 显示范围（s），非引擎值
    var minValue: Float {
        switch self {
        case .presetTemplates: return 0
        case .brightness: return -100
        case .contrast: return -100
        case .saturation: return -100
        case .exposure: return -200
        case .highlights: return -100
        case .shadows: return -100
        case .grain: return 0
        case .sharpness: return 0
        case .blur: return 0
        case .glow: return -100
        case .edgeStrength: return 0
        case .red, .green, .blue: return -100
        }
    }
    
    /// UI 显示范围（s），非引擎值
    var maxValue: Float {
        switch self {
        case .presetTemplates: return 0
        case .brightness: return 100
        case .contrast: return 100
        case .saturation: return 100
        case .exposure: return 200
        case .highlights: return 100
        case .shadows: return 100
        case .grain: return 100
        case .sharpness: return 150
        case .blur: return 100
        case .glow: return 100
        case .edgeStrength: return 100
        case .red, .green, .blue: return 100
        }
    }
    
    /// UI 步长（s）
    var step: Float {
        switch self {
        case .presetTemplates: return 0
        case .brightness: return 1
        case .contrast: return 1
        case .saturation: return 1
        case .exposure: return 5   // 0.1EV 对应 s=5
        case .highlights: return 1
        case .shadows: return 1
        case .grain: return 2
        case .sharpness: return 5
        case .blur: return 1
        case .glow: return 1
        case .edgeStrength: return 1
        case .red, .green, .blue: return 1
        }
    }
    
    /// UI 默认值（s），非引擎值
    var defaultValue: Float {
        switch self {
        case .presetTemplates: return 0
        case .brightness: return 0
        case .contrast: return 0
        case .saturation: return 0
        case .exposure: return 0
        case .highlights: return 0
        case .shadows: return 0
        case .grain: return 0
        case .sharpness: return 25
        case .blur: return 0
        case .glow: return 0
        case .edgeStrength: return 0
        case .red, .green, .blue: return 0
        }
    }
}

// MARK: - 映射：UI 值(s) ⇄ 引擎值(v)
extension SCFilterParameter {
    /// UI → 引擎
    func uiToEngine(_ s: Float) -> Float {
        switch self {
        case .presetTemplates:
            return 0
        case .brightness:
            return s / 100.0
        case .contrast:
            return powf(2.0, s / 50.0) // 0.25~4
        case .saturation:
            return max(0.0, min(2.0, 1.0 + 0.01 * s))
        case .exposure:
            return s / 50.0 // EV
        case .highlights:
            // GPUImage: 0..1, 默认1，减小变暗亮部；无法>1增亮
            return max(0.0, min(1.0, 1.0 + min(0.0, s) / 100.0))
        case .shadows:
            // GPUImage: 0..1，增大提亮阴影；无法<0变暗
            return max(0.0, min(1.0, max(0.0, s) / 100.0))
        case .grain:
            return max(0.0, min(1.0, s / 100.0))
        case .sharpness:
            // 推荐 s/25 → 0..6，GPU 支持 -4..4，这里夹到 0..4
            return max(0.0, min(4.0, s / 25.0))
        case .blur:
            // 半径像素：0..30，SCFilterView 内部用 blurRadiusInPixels
            return max(0.0, min(30.0, 0.3 * s))
        case .glow:
            return s / 100.0
        case .edgeStrength:
            return max(0.0, min(5.0, 0.05 * s))
        case .red, .green, .blue:
            return max(0.0, min(2.0, 1.0 + 0.01 * s))
        }
    }
    
    /// 引擎 → UI
    func engineToUi(_ v: Float) -> Float {
        switch self {
        case .presetTemplates:
            return 0
        case .brightness:
            return v * 100.0
        case .contrast:
            return 50.0 * (logf(v) / logf(2.0))
        case .saturation:
            return (v - 1.0) * 100.0
        case .exposure:
            return v * 50.0
        case .highlights:
            // v: 0..1, 1 为原图；无法>1增亮，UI>0 也按 0 显示
            return min(0.0, (v - 1.0) * 100.0)
        case .shadows:
            // v: 0..1, 0 为原图；仅正向提亮
            return max(0.0, v * 100.0)
        case .grain:
            return v * 100.0
        case .sharpness:
            return v * 25.0
        case .blur:
            return v / 0.3
        case .glow:
            return v * 100.0
        case .edgeStrength:
            return v / 0.05
        case .red, .green, .blue:
            return (v - 1.0) * 100.0
        }
    }
}


