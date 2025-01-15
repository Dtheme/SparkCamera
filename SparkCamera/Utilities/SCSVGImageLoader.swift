import UIKit

public class SCSVGImageLoader {
    
    /// 缓存已加载的 SVG 图片
    private static var imageCache = NSCache<NSString, UIImage>()
    
    /// 用于跟踪缓存的键
    private static var cacheKeys = Set<String>()
    
    /// 从 Assets.xcassets 加载 SVG 图片
    /// - Parameters:
    ///   - named: SVG 图片名称
    ///   - size: 期望的图片大小，默认为 nil（使用原始大小）
    ///   - tintColor: 图片着色颜色，默认为 nil（使用原始颜色）
    /// - Returns: 加载的 UIImage，如果加载失败则返回 nil
    public static func loadSVG(named: String,
                             size: CGSize? = nil,
                             tintColor: UIColor? = nil) -> UIImage? {
        // 生成缓存 key
        let cacheKey = "\(named)_\(size?.width ?? 0)_\(size?.height ?? 0)_\(tintColor?.description ?? "")" as NSString
        
        // 检查缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // 从 Assets.xcassets 加载图片
        guard var image = UIImage(named: named) else {
            print("⚠️ [SVG] 加载失败: \(named)")
            return nil
        }
        
        // 调整大小（如果需要）
        if let size = size, size.width > 0, size.height > 0 {
            let renderer = UIGraphicsImageRenderer(size: size)
            image = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        
        // 着色（如果需要）
        if let tintColor = tintColor {
            image = image.withTintColor(tintColor, renderingMode: .alwaysTemplate)
        }
        
        // 缓存图片
        imageCache.setObject(image, forKey: cacheKey)
        cacheKeys.insert(cacheKey as String)
        
        return image
    }
    
    /// 清除图片缓存
    public static func clearCache() {
        imageCache.removeAllObjects()
        cacheKeys.removeAll()
    }
    
    /// 从缓存中移除指定图片
    /// - Parameter named: SVG 文件名
    public static func removeFromCache(named: String) {
        let keysToRemove = cacheKeys.filter { $0.hasPrefix(named) }
        keysToRemove.forEach { key in
            imageCache.removeObject(forKey: key as NSString)
            cacheKeys.remove(key)
        }
    }
} 
