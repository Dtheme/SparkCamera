import UIKit
import SwiftSVG

public class SCSVGImageLoader {
    
    /// 缓存已加载的 SVG 图片
    private static var imageCache = NSCache<NSString, UIImage>()
    
    /// 从文件加载 SVG 图片
    /// - Parameters:
    ///   - named: SVG 文件名（不包含扩展名）
    ///   - bundle: 资源包，默认为 main bundle
    ///   - size: 期望的图片大小，默认为 nil（使用 SVG 原始大小）
    ///   - tintColor: 图片着色颜色，默认为 nil（使用原始颜色）
    /// - Returns: 加载的 UIImage，如果加载失败则返回 nil
    public static func loadSVG(named: String,
                             bundle: Bundle = .main,
                             size: CGSize? = nil,
                             tintColor: UIColor? = nil) -> UIImage? {
        // 生成缓存 key
        let cacheKey = "\(named)_\(size?.width ?? 0)_\(size?.height ?? 0)_\(tintColor?.description ?? "")" as NSString
        
        // 检查缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // 获取 SVG 文件路径
        guard let svgURL = bundle.url(forResource: named, withExtension: "svg") else {
            print("⚠️ [SVG] 未找到文件: \(named).svg")
            return nil
        }
        
        do {
            // 创建 SVG 容器视图
            let svgView = UIView()
            if let size = size {
                svgView.frame = CGRect(origin: .zero, size: size)
            }
            
            // 加载 SVG
            let svgLayer = CALayer()
            try svgLayer.loadSVG(from: svgURL)
            
            // 如果指定了大小，调整 SVG 大小
            if let size = size {
                let scale = min(size.width / svgLayer.bounds.width,
                              size.height / svgLayer.bounds.height)
                svgLayer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            }
            
            svgView.layer.addSublayer(svgLayer)
            
            // 渲染图片
            let renderer = UIGraphicsImageRenderer(bounds: svgView.bounds)
            let image = renderer.image { context in
                svgView.layer.render(in: context.cgContext)
            }
            
            // 如果需要着色
            let finalImage: UIImage
            if let tintColor = tintColor {
                finalImage = image.withTintColor(tintColor, renderingMode: .alwaysTemplate)
            } else {
                finalImage = image
            }
            
            // 缓存图片
            imageCache.setObject(finalImage, forKey: cacheKey)
            
            return finalImage
        } catch {
            print("⚠️ [SVG] 加载失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 清除图片缓存
    public static func clearCache() {
        imageCache.removeAllObjects()
    }
    
    /// 从缓存中移除指定图片
    /// - Parameter named: SVG 文件名
    public static func removeFromCache(named: String) {
        let keys = imageCache.allKeys().filter { $0.hasPrefix(named) }
        keys.forEach { imageCache.removeObject(forKey: $0) }
    }
} 