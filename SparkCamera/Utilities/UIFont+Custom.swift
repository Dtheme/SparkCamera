import UIKit

extension UIFont {
    
    // 定义主要信息展示的字体
    static func mainFont(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        // 使用系统圆角字体作为主字体
        if let roundedFont = UIFont(name: "ProFontForPowerline-Bold", size: size) {
            return roundedFont
        } else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
    
    // 使用 ProFont for Powerline 字体显示数字和英文
    static func profont(ofSize size: CGFloat) -> UIFont {
        if let profont = UIFont(name: "ProFontForPowerline", size: size) {
            return profont
        } else {
            print("Failed to load ProFont for Powerline. Using system font instead.")
            return UIFont.systemFont(ofSize: size)
        }
    }
    
    // 可以根据需要添加更多自定义字体方法
    static func secondaryFont(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
} 
