import UIKit

protocol SCCameraToolBarDelegate: AnyObject {
    // 工具项被选中
    func toolBar(_ toolBar: SCCameraToolBar, didSelect item: SCToolItem, optionType: SCCameraToolOptionsViewType)
    
    // 工具项展开显示子选项
    func toolBar(_ toolBar: SCCameraToolBar, didExpand item: SCToolItem, optionType: SCCameraToolOptionsViewType)
    
    // 工具项收起子选项
    func toolBar(_ toolBar: SCCameraToolBar, didCollapse item: SCToolItem, optionType: SCCameraToolOptionsViewType)
    
    // 动画相关
    func toolBar(_ toolBar: SCCameraToolBar, willAnimate item: SCToolItem, optionType: SCCameraToolOptionsViewType)
    func toolBar(_ toolBar: SCCameraToolBar, didFinishAnimate item: SCToolItem, optionType: SCCameraToolOptionsViewType)
    
    // 选项选择
    func toolBar(_ toolBar: SCCameraToolBar, didSelect option: String, for item: SCToolItem, optionType: SCCameraToolOptionsViewType)
    
    // 状态切换
    func toolBar(_ toolBar: SCCameraToolBar, didToggleState item: SCToolItem, optionType: SCCameraToolOptionsViewType)
    
    // 滑动条值改变
    func toolBar(_ toolBar: SCCameraToolBar, didChangeSlider value: Float, for item: SCToolItem, optionType: SCCameraToolOptionsViewType)
}
