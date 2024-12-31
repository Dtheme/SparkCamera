import UIKit

protocol SCCameraToolBarDelegate: AnyObject {
    // 工具项被选中
    func toolBar(_ toolBar: SCCameraToolBar, didSelect item: SCCameraToolItem)
    
    // 工具项展开显示子选项
    func toolBar(_ toolBar: SCCameraToolBar, didExpand item: SCCameraToolItem)
    
    // 工具项收起子选项
    func toolBar(_ toolBar: SCCameraToolBar, didCollapse item: SCCameraToolItem)
    
    // 可选方法
    func toolBar(_ toolBar: SCCameraToolBar, willAnimate item: SCCameraToolItem)
    func toolBar(_ toolBar: SCCameraToolBar, didFinishAnimate item: SCCameraToolItem)
} 