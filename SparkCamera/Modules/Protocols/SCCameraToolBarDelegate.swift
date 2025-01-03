import UIKit

protocol SCCameraToolBarDelegate: AnyObject {
    // 工具项被选中
    func toolBar(_ toolBar: SCCameraToolBar, didSelect item: SCToolItem)
    
    // 工具项展开显示子选项
    func toolBar(_ toolBar: SCCameraToolBar, didExpand item: SCToolItem)
    
    // 工具项收起子选项
    func toolBar(_ toolBar: SCCameraToolBar, didCollapse item: SCToolItem)
    
    // 动画相关
    func toolBar(_ toolBar: SCCameraToolBar, willAnimate item: SCToolItem)
    func toolBar(_ toolBar: SCCameraToolBar, didFinishAnimate item: SCToolItem)
    
    // 选项选择
    func toolBar(_ toolBar: SCCameraToolBar, didSelect option: String, for item: SCToolItem)
    
    // 状态切换
    func toolBar(_ toolBar: SCCameraToolBar, didToggleState item: SCToolItem)
} 
