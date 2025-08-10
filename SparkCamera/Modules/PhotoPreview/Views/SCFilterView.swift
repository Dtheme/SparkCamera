//
//  SCFilterView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/21.
//

import UIKit
import GPUImage

protocol SCFilterViewDelegate: AnyObject {
    func filterViewDidTap(_ filterView: SCFilterView)
    func filterViewDidDoubleTap(_ filterView: SCFilterView)
    func filterViewDidLongPress(_ filterView: SCFilterView)
    func filterView(_ filterView: SCFilterView, didChangeFilter template: SCFilterTemplate?)
}

class SCFilterView: UIView {
    
    // MARK: - Properties
    weak var delegate: SCFilterViewDelegate?
    private var gpuImageView: GPUImageView!
    private var currentPicture: GPUImagePicture?
    private var originalImage: UIImage?
    
    // 防抖机制
    private var updateTimer: Timer?
    
    // 添加滤镜参数属性
    private var brightness: CGFloat = 0.0
    private var contrast: CGFloat = 1.0
    private var saturation: CGFloat = 1.0
    private var exposure: CGFloat = 0.0
    private var highlights: CGFloat = 0.0
    private var shadows: CGFloat = 0.0
    private var grain: CGFloat = 0.0
    private var sharpness: CGFloat = 0.0
    private var blur: CGFloat = 0.0
    private var glow: CGFloat = 0.0
    private var edgeStrength: CGFloat = 0.0
    private var redChannel: CGFloat = 1.0
    private var greenChannel: CGFloat = 1.0
    private var blueChannel: CGFloat = 1.0
    
    // 添加滤镜对象
    private var brightnessFilter: GPUImageBrightnessFilter?
    private var contrastFilter: GPUImageContrastFilter?
    private var saturationFilter: GPUImageSaturationFilter?
    private var exposureFilter: GPUImageExposureFilter?
    private var highlightsFilter: GPUImageHighlightShadowFilter?
    private var grainFilter: GPUImageJFAVoronoiFilter?  // 使用 Voronoi 滤镜模拟颗粒感
    private var sharpenFilter: GPUImageSharpenFilter?
    private var gaussianBlurFilter: GPUImageGaussianBlurFilter?
    private var sobelEdgeFilter: GPUImageSobelEdgeDetectionFilter?
    private var rgbFilter: GPUImageRGBFilter?
    
    var filterTemplate: SCFilterTemplate? {
        didSet {
            if let template = filterTemplate {
                print("[FilterView] 设置滤镜模板: \(template.name)")
                // 清理现有的渲染内容
                currentPicture?.removeAllTargets()
                // 应用新的滤镜模板
                if let picture = currentPicture {
                    template.applyFilter(to: picture, output: gpuImageView)
                    picture.processImage()
                }
                // 通知代理
                delegate?.filterView(self, didChangeFilter: template)
            } else {
                print("[FilterView] 清除滤镜模板")
                resetFilters()
            }
        }
    }
    
    // 获取当前渲染后的图片
    var currentImage: UIImage? {
        // 创建当前尺寸的上下文
        let scale = UIScreen.main.scale
        let size = gpuImageView.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        // 将 GPUImageView 的内容渲染到上下文
        if let context = UIGraphicsGetCurrentContext() {
            gpuImageView.layer.render(in: context)
        }
        
        // 获取图片并关闭上下文
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    // MARK: - Public Methods
    
    /// 获取处理后的图片（异步）
    func getFilteredImage(completion: @escaping (UIImage?) -> Void) {
        guard let picture = currentPicture,
              let image = originalImage else {
            print("[FilterView] 获取图片失败: currentPicture 或 originalImage 为空")
            completion(nil)
            return
        }
        
        print("[FilterView] 开始处理图片:")
        print("- 原始图片尺寸: \(image.size)")
        print("- 是否有滤镜模板: \(filterTemplate != nil)")
        
        // 如果没有滤镜模板，直接返回原图
        if filterTemplate == nil {
            print("[FilterView] 无滤镜模板，返回原图")
            completion(image)
            return
        }
        
        // 创建新的图片对象和输出目标
        let pictureOutput = GPUImagePicture(image: image)!
        let outputFilter = GPUImageFilter()
        
        // 配置输出
        outputFilter.useNextFrameForImageCapture()
        
        // 应用滤镜模板
        if let template = filterTemplate {
            print("[FilterView] 应用滤镜模板: \(template.name)")
            template.applyFilter(to: pictureOutput, output: outputFilter)
        } else {
            print("[FilterView] 无滤镜模板，直接连接输出")
            pictureOutput.addTarget(outputFilter)
        }
        
        // 处理图像并在完成后获取结果
        pictureOutput.processImage { [weak self] in
            guard self != nil else { return }
            
            // 获取处理后的图像
            if let processedImage = outputFilter.imageFromCurrentFramebuffer() {
                print("[FilterView] 成功获取处理后的图片:")
                print("- 处理后图片尺寸: \(processedImage.size)")
                print("- 处理后图片scale: \(processedImage.scale)")
                print("- 处理后图片orientation: \(processedImage.imageOrientation.rawValue)")
                
                // 清理资源
                pictureOutput.removeAllTargets()
                outputFilter.removeAllTargets()
                
                DispatchQueue.main.async {
                    completion(processedImage)
                }
            } else {
                print("[FilterView] 获取处理后的图片失败")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Initialization
    init(frame: CGRect = .zero, template: SCFilterTemplate? = nil) {
        self.filterTemplate = template
        super.init(frame: frame)
        setupUI()
        setupGestures()
        setupFilters()
        
        // 如果有模板，立即应用参数
        if let template = template {
            let params = template.toParameters()
            brightness = CGFloat(params["亮度"] ?? 0.0)
            contrast = CGFloat(params["对比度"] ?? 1.0)
            saturation = CGFloat(params["饱和度"] ?? 1.0)
            exposure = CGFloat(params["曝光"] ?? 0.0)
            highlights = CGFloat(params["高光"] ?? 1.0)
            shadows = CGFloat(params["阴影"] ?? 1.0)
            grain = CGFloat(params["颗粒感"] ?? 0.0)
            sharpness = CGFloat(params["锐度"] ?? 1.0)
            blur = CGFloat(params["模糊"] ?? 0.0)
            glow = CGFloat(params["光晕"] ?? 0.0)
            edgeStrength = CGFloat(params["边缘强度"] ?? 0.0)
            redChannel = CGFloat(params["红色"] ?? 1.0)
            greenChannel = CGFloat(params["绿色"] ?? 1.0)
            blueChannel = CGFloat(params["蓝色"] ?? 1.0)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .black
        
        // 设置 GPUImageView
        gpuImageView = GPUImageView()
        gpuImageView.backgroundColor = .clear
        gpuImageView.fillMode = kGPUImageFillModePreserveAspectRatio
        addSubview(gpuImageView)
        
        gpuImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupGestures() {
        // 单击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        // 双击手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)
        
        // 设置手势优先级
        tapGesture.require(toFail: doubleTapGesture)
        
        // 长按手势
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Public Methods
    /// 刷新内部 GPUImageView 的布局，避免容器尺寸变化后出现拉伸/压缩
    public func refreshLayout() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentFillMode = self.gpuImageView.fillMode
            // 重新赋值以触发 GPUImageView 内部的几何计算
            self.gpuImageView.fillMode = currentFillMode
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
    func setImage(_ image: UIImage) {
        self.originalImage = image
        
        // 在主线程中设置 GPUImageView 的属性
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 清理现有的渲染内容
            self.currentPicture?.removeAllTargets()
            
            // 根据图片方向创建正确的图片
            let correctedImage: UIImage
            if image.imageOrientation != .up {
                UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
                image.draw(in: CGRect(origin: .zero, size: image.size))
                correctedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
            } else {
                correctedImage = image
            }
            
            // 创建新的 GPUImagePicture
            let picture = GPUImagePicture(image: correctedImage)
            self.currentPicture = picture
            
            // 如果没有滤镜，直接显示原图
            if self.filterTemplate == nil && self.allFiltersAtDefaultValues() {
                picture!.addTarget(self.gpuImageView)
                picture!.processImage()
            } else {
                // 应用滤镜
                self.applyFilter()
            }
        }
    }
    
    // 检查是否所有滤镜参数都是默认值
    private func allFiltersAtDefaultValues() -> Bool {
        return brightness == 0.0 &&
               contrast == 1.0 &&
               saturation == 1.0 &&
               exposure == 0.0 &&
               highlights == 0.0 &&
               shadows == 0.0 &&
               grain == 0.0 &&
               sharpness == 0.0 &&
               blur == 0.0 &&
               glow == 0.0 &&
               edgeStrength == 0.0 &&
               redChannel == 1.0 &&
               greenChannel == 1.0 &&
               blueChannel == 1.0
    }
    
    // MARK: - Filter Updates
    func updateBrightness(_ value: Float) {
        brightness = CGFloat(value)
        brightnessFilter?.brightness = brightness
        applyFilter()
    }
    
    func updateContrast(_ value: Float) {
        contrast = CGFloat(value)
        contrastFilter?.contrast = contrast
        applyFilter()
    }
    
    func updateSaturation(_ value: Float) {
        saturation = CGFloat(value)
        saturationFilter?.saturation = saturation
        applyFilter()
    }
    
    func updateExposure(_ value: Float) {
        exposure = CGFloat(value)
        exposureFilter?.exposure = exposure
        applyFilter()
    }
    
    func updateHighlights(_ value: Float) {
        highlights = CGFloat(value)
        highlightsFilter?.highlights = highlights
        applyFilter()
    }
    
    func updateShadows(_ value: Float) {
        shadows = CGFloat(value)
        highlightsFilter?.shadows = shadows
        applyFilter()
    }
    
    func updateGrain(_ value: Float) {
        grain = CGFloat(value)
        if let filter = grainFilter {
            let size = Int(value * 50)
            filter.sizeInPixels = CGSize(width: size, height: size)
        }
        applyFilter()
    }
    
    func updateSharpness(_ value: Float) {
        sharpness = CGFloat(value)
        sharpenFilter?.sharpness = sharpness
        applyFilter()
    }
    
    func updateBlur(_ value: Float) {
        blur = CGFloat(value)
        gaussianBlurFilter?.blurRadiusInPixels = CGFloat(value * 10)
        applyFilter()
    }
    
    func updateGlow(_ value: Float) {
        glow = CGFloat(value)
        // 移除 glowFilter，因为 GPUImage 中没有这个滤镜
        applyFilter()
    }
    
    func updateEdgeStrength(_ value: Float) {
        edgeStrength = CGFloat(value)
        sobelEdgeFilter?.edgeStrength = edgeStrength
        applyFilter()
    }
    
    func updateRedChannel(_ value: Float) {
        redChannel = CGFloat(value)
        rgbFilter?.red = redChannel
        applyFilter()
    }
    
    func updateGreenChannel(_ value: Float) {
        greenChannel = CGFloat(value)
        rgbFilter?.green = greenChannel
        applyFilter()
    }
    
    func updateBlueChannel(_ value: Float) {
        blueChannel = CGFloat(value)
        rgbFilter?.blue = blueChannel
        applyFilter()
    }
    
    private func setupFilters() {
        // 创建滤镜对象
        brightnessFilter = GPUImageBrightnessFilter()
        contrastFilter = GPUImageContrastFilter()
        saturationFilter = GPUImageSaturationFilter()
        exposureFilter = GPUImageExposureFilter()
        highlightsFilter = GPUImageHighlightShadowFilter()
        grainFilter = GPUImageJFAVoronoiFilter()
        sharpenFilter = GPUImageSharpenFilter()
        gaussianBlurFilter = GPUImageGaussianBlurFilter()
        sobelEdgeFilter = GPUImageSobelEdgeDetectionFilter()
        rgbFilter = GPUImageRGBFilter()
        
        // 设置初始值
        brightnessFilter?.brightness = brightness
        contrastFilter?.contrast = contrast
        saturationFilter?.saturation = saturation
        exposureFilter?.exposure = exposure
        highlightsFilter?.highlights = highlights
        highlightsFilter?.shadows = shadows
        let grainSize = grain * 100
        grainFilter?.sizeInPixels = CGSize(width: grainSize, height: grainSize)
        sharpenFilter?.sharpness = sharpness
        gaussianBlurFilter?.blurRadiusInPixels = blur * 10
        sobelEdgeFilter?.edgeStrength = edgeStrength
        rgbFilter?.red = redChannel
        rgbFilter?.green = greenChannel
        rgbFilter?.blue = blueChannel
    }
    
    private func applyFilter() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let picture = self.currentPicture else { return }
            
            // 清理现有的渲染内容
            picture.removeAllTargets()
            
            // 如果有滤镜模板，使用模板的滤镜链
            if let template = self.filterTemplate {
                template.applyFilter(to: picture, output: self.gpuImageView)
                picture.processImage()
                return
            }
            
            // 否则使用自定义滤镜链
            let filterChain = [
                brightnessFilter,
                contrastFilter,
                saturationFilter,
                exposureFilter,
                highlightsFilter,
                grainFilter,
                sharpenFilter,
                gaussianBlurFilter,
                sobelEdgeFilter,
                rgbFilter
            ].compactMap { $0 }
            
            if filterChain.isEmpty {
                // 如果没有滤镜，直接显示原图
                picture.addTarget(self.gpuImageView)
            } else {
                // 连接滤镜链
                var previousFilter: GPUImageOutput = picture
                for filter in filterChain {
                    previousFilter.addTarget(filter)
                    previousFilter = filter
                }
                
                // 连接到输出
                previousFilter.addTarget(self.gpuImageView)
            }
            
            // 处理图像
            picture.processImage()
        }
    }
    
    // MARK: - Filter Reset
    private func resetFilters() {
        // 重置所有滤镜参数为默认值
        let defaultParams = SCFilterTemplate.defaultParameters()
        
        updateBrightness(Float(defaultParams["亮度"] ?? 0.0))
        updateContrast(Float(defaultParams["对比度"] ?? 1.0))
        updateSaturation(Float(defaultParams["饱和度"] ?? 1.0))
        updateExposure(Float(defaultParams["曝光"] ?? 0.0))
        updateHighlights(Float(defaultParams["高光"] ?? 1.0))
        updateShadows(Float(defaultParams["阴影"] ?? 1.0))
        updateSharpness(Float(defaultParams["锐度"] ?? 1.0))
        updateBlur(Float(defaultParams["模糊"] ?? 0.0))
        updateGrain(Float(defaultParams["颗粒感"] ?? 0.0))
        updateGlow(Float(defaultParams["光晕"] ?? 0.0))
        updateEdgeStrength(Float(defaultParams["边缘强度"] ?? 0.0))
        updateRedChannel(Float(defaultParams["红色"] ?? 1.0))
        updateGreenChannel(Float(defaultParams["绿色"] ?? 1.0))
        updateBlueChannel(Float(defaultParams["蓝色"] ?? 1.0))
        
        // 应用重置后的滤镜链
        applyFilter()
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.filterViewDidTap(self)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.filterViewDidDoubleTap(self)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            delegate?.filterViewDidLongPress(self)
        }
    }
    
    // MARK: - Memory Management
    deinit {
        // 清理Timer
        updateTimer?.invalidate()
        
        // 清理资源
        currentPicture?.removeAllTargets()
        currentPicture = nil
        originalImage = nil
    }
    
    // MARK: - Public Methods
    func applyTemplate(_ template: SCFilterTemplate) {
        print("[FilterView] 应用滤镜模板: \(template.name)")
        
        guard let picture = currentPicture else {
            print("[FilterView] 错误：没有可用的图片")
            return
        }
        
        // 清理现有的渲染内容
        picture.removeAllTargets()
        
        // 应用滤镜模板
        template.applyFilter(to: picture, output: gpuImageView)
        
        // 处理图像
        picture.processImage()
        
        // 通知代理
        delegate?.filterView(self, didChangeFilter: template)
    }
    
    // MARK: - Parameter Updates
    public func updateParameter(_ parameter: String, value: Float) {
        switch parameter {
        case "亮度":
            brightness = CGFloat(value)
            brightnessFilter?.brightness = CGFloat(value)
        case "对比度":
            contrast = CGFloat(value)
            contrastFilter?.contrast = CGFloat(value)
        case "饱和度":
            saturation = CGFloat(value)
            saturationFilter?.saturation = CGFloat(value)
        case "曝光":
            exposure = CGFloat(value)
            exposureFilter?.exposure = CGFloat(value)
        case "高光":
            highlights = CGFloat(value)
            highlightsFilter?.highlights = CGFloat(value)
        case "阴影":
            shadows = CGFloat(value)
            highlightsFilter?.shadows = CGFloat(value)
        case "颗粒感":
            grain = CGFloat(value)
            if let filter = grainFilter {
                let size = Int(value * 50)
                filter.sizeInPixels = CGSize(width: size, height: size)
            }
        case "锐度":
            sharpness = CGFloat(value)
            sharpenFilter?.sharpness = CGFloat(value)
        case "模糊":
            blur = CGFloat(value)
            gaussianBlurFilter?.blurRadiusInPixels = CGFloat(value * 2.0)
        case "光晕":
            glow = CGFloat(value)
            // 光晕效果需要特殊处理，暂时跳过
        case "边缘强度":
            edgeStrength = CGFloat(value)
            sobelEdgeFilter?.edgeStrength = CGFloat(value)
        case "红色":
            redChannel = CGFloat(value)
            rgbFilter?.red = CGFloat(value)
        case "绿色":
            greenChannel = CGFloat(value)
            rgbFilter?.green = CGFloat(value)
        case "蓝色":
            blueChannel = CGFloat(value)
            rgbFilter?.blue = CGFloat(value)
        default:
            print("[FilterView] 未知的参数类型: \(parameter)")
        }
        
        // 使用防抖机制延迟应用滤镜，避免过于频繁的重新渲染
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.applyFilter()
        }
    }
    
    /// 获取当前的滤镜参数值
    public func getCurrentParameters() -> [String: Float] {
        return [
            "亮度": Float(brightness),
            "对比度": Float(contrast),
            "饱和度": Float(saturation),
            "曝光": Float(exposure),
            "高光": Float(highlights),
            "阴影": Float(shadows),
            "颗粒感": Float(grain),
            "锐度": Float(sharpness),
            "模糊": Float(blur),
            "光晕": Float(glow),
            "边缘强度": Float(edgeStrength),
            "红色": Float(redChannel),
            "绿色": Float(greenChannel),
            "蓝色": Float(blueChannel)
        ]
    }
    
    /// 验证滤镜功能是否正常工作
    public func validateFilterFunctionality() -> Bool {
        print("🔍 [FilterView] 开始验证滤镜功能...")
        
        // 检查滤镜对象是否正确初始化
        let filterChecks = [
            ("亮度滤镜", brightnessFilter != nil),
            ("对比度滤镜", contrastFilter != nil),
            ("饱和度滤镜", saturationFilter != nil),
            ("曝光滤镜", exposureFilter != nil),
            ("高光阴影滤镜", highlightsFilter != nil),
            ("锐度滤镜", sharpenFilter != nil),
            ("模糊滤镜", gaussianBlurFilter != nil),
            ("RGB滤镜", rgbFilter != nil)
        ]
        
        var allFiltersValid = true
        for (name, isValid) in filterChecks {
            let status = isValid ? "✅" : "❌"
            print("  \(status) \(name): \(isValid ? "已初始化" : "未初始化")")
            if !isValid { allFiltersValid = false }
        }
        
        // 检查当前图片是否加载
        let hasImage = currentPicture != nil
        print("  \(hasImage ? "✅" : "❌") 图片加载: \(hasImage ? "已加载" : "未加载")")
        if !hasImage { allFiltersValid = false }
        
        print("🔍 [FilterView] 滤镜功能验证\(allFiltersValid ? "通过" : "失败")")
        return allFiltersValid
    }
} 
