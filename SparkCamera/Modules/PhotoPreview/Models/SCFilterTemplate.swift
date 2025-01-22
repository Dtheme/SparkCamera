import UIKit
import GPUImage

/// 滤镜模板
struct SCFilterTemplate {
    /// 滤镜名称
    let name: String
    /// 预览图
    let thumbnail: UIImage?
    /// 滤镜类型
    let type: FilterType
    /// 滤镜参数
    let parameters: FilterParameters
    
    /// 滤镜类型
    enum FilterType {
        case original           // 原图
        case fujiFilm          // 富士胶片
        case polaroid          // 拍立得
        case blackAndWhite     // 黑白
        case vintage           // 复古
        case dreamy            // 梦幻
        case cinematic         // 电影胶片
        case retroBlue         // 复古蓝调
        case softFocus         // 软焦
        case japaneseStyle     // 日系清新
        case comic             // 版画效果
    }
    
    /// 滤镜参数
    struct FilterParameters {
        // 基础参数
        var brightness: CGFloat = 0.0     // 亮度 (-1.0 to 1.0)
        var contrast: CGFloat = 1.0       // 对比度 (0.0 to 4.0)
        var saturation: CGFloat = 1.0     // 饱和度 (0.0 to 2.0)
        var exposure: CGFloat = 0.0       // 曝光 (-4.0 to 4.0)
        var highlights: CGFloat = 1.0     // 高光 (0.0 to 1.0)
        var shadows: CGFloat = 0.0        // 阴影 (0.0 to 1.0)
        var grain: CGFloat = 0.0          // 颗粒感 (0.0 to 1.0)
        var sharpness: CGFloat = 0.0      // 锐度 (0.0 to 4.0)
        var blur: CGFloat = 0.0           // 模糊 (0.0 to 2.0)
        var glow: CGFloat = 0.0           // 光晕 (0.0 to 1.0)
        var edgeStrength: CGFloat = 0.0   // 边缘强度 (0.0 to 1.0)
        
        // RGB 参数
        var red: CGFloat = 1.0            // 红色通道
        var green: CGFloat = 1.0          // 绿色通道
        var blue: CGFloat = 1.0           // 蓝色通道
        
        // 预设模板
        static let fujiFilm = FilterParameters(
            brightness: -0.05,     // 轻微降低亮度，增加胶片感
            contrast: 1.35,        // 增加对比度，突出色彩层次
            saturation: 1.25,      // 降低饱和度，避免过度鲜艳
            exposure: -0.15,       // 降低曝光，增加富士特有的暗调
            highlights: 0.25,      // 降低高光，避免过曝
            shadows: 0.7,          // 提升阴影，增加细节
            grain: 0.25,          // 增加颗粒感，模拟胶片质感
            sharpness: 0.9,       // 降低锐化，更柔和
            glow: 0.15,           // 添加轻微光晕，增加胶片感
            red: 1.15,            // 增强红色，富士特征
            green: 0.95,          // 降低绿色，避免过度艳丽
            blue: 0.9             // 降低蓝色，温暖色调
        )
        
        static let polaroid = FilterParameters(
            brightness: 0.1,
            contrast: 1.2,
            saturation: 0.9,
            exposure: -0.2,
            highlights: 0.4,
            shadows: 0.3,
            grain: 0.15,
            blur: 0.5,
            red: 1.15,
            green: 1.1,
            blue: 0.9
        )
        
        static let blackAndWhite = FilterParameters(
            brightness: -0.1,
            contrast: 2.0,
            saturation: 0.0,
            exposure: -0.1,
            highlights: 0.5,
            shadows: 0.4,
            grain: 0.15,
            sharpness: 1.3,
            red: 1.0,
            green: 1.0,
            blue: 1.0
        )
        
        static let vintage = FilterParameters(
            brightness: -0.1,
            contrast: 1.3,
            saturation: 0.8,
            exposure: -0.25,
            highlights: 0.3,
            shadows: 0.6,
            grain: 0.35,
            red: 1.2,
            green: 0.95,
            blue: 0.85
        )
        
        static let dreamy = FilterParameters(
            brightness: 0.1,
            contrast: 1.15,
            saturation: 1.0,
            exposure: 0.0,
            highlights: 0.2,
            shadows: 0.4,
            blur: 0.6,
            glow: 0.7,
            red: 1.05,
            green: 1.0,
            blue: 1.05
        )
        
        static let cinematic = FilterParameters(
            brightness: 0.0,
            contrast: 1.75,
            saturation: 1.1,
            exposure: -0.15,
            highlights: 0.4,
            shadows: 0.3,
            grain: 0.25,
            sharpness: 1.3,
            red: 0.9,
            green: 1.0,
            blue: 1.15
        )
        
        static let retroBlue = FilterParameters(
            brightness: -0.1,
            contrast: 1.6,
            saturation: 0.85,
            exposure: 0.0,
            highlights: 0.3,
            shadows: 0.5,
            grain: 0.2,
            red: 0.85,
            green: 0.95,
            blue: 1.2
        )
        
        static let softFocus = FilterParameters(
            brightness: 0.1,
            contrast: 1.2,
            saturation: 0.95,
            exposure: -0.25,
            highlights: 0.4,
            shadows: 0.6,
            blur: 0.75,
            glow: 0.8,
            red: 1.05,
            green: 1.0,
            blue: 1.0
        )
        
        static let japaneseStyle = FilterParameters(
            brightness: 0.05,      // 降低亮度，避免过曝
            contrast: 1.05,        // 降低对比度，使画面更柔和
            saturation: 0.85,      // 降低饱和度，增加日系感
            exposure: -0.1,        // 降低曝光，避免过亮
            highlights: 0.2,       // 降低高光，避免过曝
            shadows: 0.5,          // 提升阴影，增加细节
            grain: 0.15,          // 增加一点颗粒感
            sharpness: 0.6,       // 降低锐化，更柔和
            blur: 0.3,            // 增加模糊，更梦幻
            glow: 0.2,            // 降低光晕，更自然
            red: 0.92,            // 降低红色，避免偏黄
            green: 1.02,          // 轻微提升绿色
            blue: 1.05            // 增加蓝色，冷色调
        )
        
        static let comic = FilterParameters(
            brightness: 0.1,
            contrast: 2.0,
            saturation: 0.5,
            exposure: -0.1,
            highlights: 0.6,
            shadows: 0.4,
            grain: 0.2,
            sharpness: 1.5,
            edgeStrength: 1.0,
            red: 1.0,
            green: 1.0,
            blue: 1.0
        )
    }
    
    // MARK: - 预设滤镜模板
    static let templates: [SCFilterTemplate] = [
        SCFilterTemplate(
            name: "原图",
            thumbnail: nil,
            type: .original,
            parameters: FilterParameters()
        ),
        SCFilterTemplate(
            name: "富士胶片",
            thumbnail: nil,
            type: .fujiFilm,
            parameters: FilterParameters.fujiFilm
        ),
        SCFilterTemplate(
            name: "拍立得",
            thumbnail: nil,
            type: .polaroid,
            parameters: FilterParameters.polaroid
        ),
        SCFilterTemplate(
            name: "黑白",
            thumbnail: nil,
            type: .blackAndWhite,
            parameters: FilterParameters.blackAndWhite
        ),
        SCFilterTemplate(
            name: "复古",
            thumbnail: nil,
            type: .vintage,
            parameters: FilterParameters.vintage
        ),
        SCFilterTemplate(
            name: "梦幻",
            thumbnail: nil,
            type: .dreamy,
            parameters: FilterParameters.dreamy
        ),
        SCFilterTemplate(
            name: "电影",
            thumbnail: nil,
            type: .cinematic,
            parameters: FilterParameters.cinematic
        ),
        SCFilterTemplate(
            name: "蓝调",
            thumbnail: nil,
            type: .retroBlue,
            parameters: FilterParameters.retroBlue
        ),
        SCFilterTemplate(
            name: "柔焦",
            thumbnail: nil,
            type: .softFocus,
            parameters: FilterParameters.softFocus
        ),
        SCFilterTemplate(
            name: "日系清新",
            thumbnail: nil,
            type: .japaneseStyle,
            parameters: FilterParameters.japaneseStyle
        ),
        SCFilterTemplate(
            name: "版画效果",
            thumbnail: nil,
            type: .comic,
            parameters: FilterParameters.comic
        )
    ]
    
    // MARK: - 应用滤镜
    func applyFilter(to picture: GPUImagePicture, output: GPUImageView) {
        // 创建滤镜链
        let brightnessFilter = GPUImageBrightnessFilter()         // 亮度
        let contrastFilter = GPUImageContrastFilter()             // 对比度
        let saturationFilter = GPUImageSaturationFilter()         // 饱和度
        let exposureFilter = GPUImageExposureFilter()             // 曝光
        let highlightShadowFilter = GPUImageHighlightShadowFilter() // 高光和阴影
        let sharpenFilter = GPUImageSharpenFilter()               // 锐化
        let gaussianBlurFilter = GPUImageGaussianBlurFilter()     // 高斯模糊
        let colorFilter = GPUImageRGBFilter()                     // RGB颜色
        let grayscaleFilter = GPUImageGrayscaleFilter()           // 灰度滤镜
        let edgeDetectionFilter = GPUImageSobelEdgeDetectionFilter() // 边缘检测
        
        // 设置参数
        brightnessFilter.brightness = parameters.brightness
        contrastFilter.contrast = parameters.contrast
        saturationFilter.saturation = parameters.saturation
        exposureFilter.exposure = parameters.exposure
        highlightShadowFilter.highlights = parameters.highlights
        highlightShadowFilter.shadows = parameters.shadows
        sharpenFilter.sharpness = parameters.sharpness
        gaussianBlurFilter.blurRadiusInPixels = parameters.blur
        colorFilter.red = parameters.red
        colorFilter.green = parameters.green
        colorFilter.blue = parameters.blue
        edgeDetectionFilter.edgeStrength = parameters.edgeStrength
        
        // 如果是原图，直接输出
        if type == .original {
            picture.addTarget(output)
            picture.processImage()
            return
        }
        
        // 连接滤镜链
        if type == .blackAndWhite {
            // 黑白滤镜特殊处理
            picture.addTarget(grayscaleFilter)
            grayscaleFilter.addTarget(brightnessFilter)
            brightnessFilter.addTarget(exposureFilter)
            exposureFilter.addTarget(contrastFilter)
            contrastFilter.addTarget(highlightShadowFilter)
            highlightShadowFilter.addTarget(sharpenFilter)
            
            if parameters.blur > 0 {
                sharpenFilter.addTarget(gaussianBlurFilter)
                gaussianBlurFilter.addTarget(output)
            } else {
                sharpenFilter.addTarget(output)
            }
        } else if type == .comic {
            // 版画效果特殊处理
            picture.addTarget(edgeDetectionFilter)
            edgeDetectionFilter.addTarget(contrastFilter)
            contrastFilter.addTarget(saturationFilter)
            saturationFilter.addTarget(sharpenFilter)
            sharpenFilter.addTarget(highlightShadowFilter)
            
            if parameters.blur > 0 {
                highlightShadowFilter.addTarget(gaussianBlurFilter)
                gaussianBlurFilter.addTarget(output)
            } else {
                highlightShadowFilter.addTarget(output)
            }
        } else {
            // 其他滤镜正常处理
            picture.addTarget(brightnessFilter)
            brightnessFilter.addTarget(exposureFilter)
            exposureFilter.addTarget(contrastFilter)
            contrastFilter.addTarget(saturationFilter)
            saturationFilter.addTarget(highlightShadowFilter)
            highlightShadowFilter.addTarget(sharpenFilter)
            
            if parameters.blur > 0 {
                sharpenFilter.addTarget(gaussianBlurFilter)
                gaussianBlurFilter.addTarget(colorFilter)
            } else {
                sharpenFilter.addTarget(colorFilter)
            }
            
            colorFilter.addTarget(output)
        }
        
        // 处理图像
        picture.processImage()
    }
} 
