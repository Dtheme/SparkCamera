import Foundation
import RealmSwift
import UIKit

/// 自定义滤镜数据模型（持久化）
class SCCustomFilter: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var name: String = ""
    // 各参数（与 SCFilterTemplate.FilterParameters 对应）
    @Persisted var brightness: Float = 0.0
    @Persisted var contrast: Float = 1.0
    @Persisted var saturation: Float = 1.0
    @Persisted var exposure: Float = 0.0
    @Persisted var highlights: Float = 1.0
    @Persisted var shadows: Float = 0.0
    @Persisted var grain: Float = 0.0
    @Persisted var sharpness: Float = 0.0
    @Persisted var blur: Float = 0.0
    @Persisted var glow: Float = 0.0
    @Persisted var edgeStrength: Float = 0.0
    @Persisted var red: Float = 1.0
    @Persisted var green: Float = 1.0
    @Persisted var blue: Float = 1.0
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()

    // 从参数字典填充
    func apply(parameters: [String: Float]) {
        brightness = parameters["亮度"] ?? 0.0
        contrast = parameters["对比度"] ?? 1.0
        saturation = parameters["饱和度"] ?? 1.0
        exposure = parameters["曝光"] ?? 0.0
        highlights = parameters["高光"] ?? 1.0
        shadows = parameters["阴影"] ?? 0.0
        grain = parameters["颗粒感"] ?? 0.0
        sharpness = parameters["锐度"] ?? 0.0
        blur = parameters["模糊"] ?? 0.0
        glow = parameters["光晕"] ?? 0.0
        edgeStrength = parameters["边缘强度"] ?? 0.0
        red = parameters["红色"] ?? 1.0
        green = parameters["绿色"] ?? 1.0
        blue = parameters["蓝色"] ?? 1.0
        updatedAt = Date()
    }

    // 转为参数字典
    func toParameters() -> [String: Float] {
        return [
            "亮度": brightness,
            "对比度": contrast,
            "饱和度": saturation,
            "曝光": exposure,
            "高光": highlights,
            "阴影": shadows,
            "颗粒感": grain,
            "锐度": sharpness,
            "模糊": blur,
            "光晕": glow,
            "边缘强度": edgeStrength,
            "红色": red,
            "绿色": green,
            "蓝色": blue
        ]
    }

    // 转为可用于 UI 的模板
    func toTemplate() -> SCFilterTemplate {
        let params = toParameters()
        return SCFilterTemplate.customTemplate(name: name, parameters: params)
    }
}


