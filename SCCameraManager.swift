func switchCamera(to lens: SCLensModel, completion: @escaping (String) -> Void) {
    // 根据选择的镜头倍数切换相机
    // 这里需要实现具体的切换逻辑
    completion("Switched to \(lens.name)")
}