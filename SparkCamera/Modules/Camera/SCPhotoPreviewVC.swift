// MARK: - Gestures
private func setupGestures() {
    // 单击手势：显示/隐藏工具栏
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    view.addGestureRecognizer(tapGesture)
    
    // 双击手势：缩放
    let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
    doubleTapGesture.numberOfTapsRequired = 2
    view.addGestureRecognizer(doubleTapGesture)
    
    // 长按手势：显示操作菜单
    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    view.addGestureRecognizer(longPressGesture)
    
    // 确保单击手势不会干扰双击手势
    tapGesture.require(toFail: doubleTapGesture)
    
    // 下滑手势：关闭预览
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    view.addGestureRecognizer(panGesture)
}

@objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began else { return }
    
    print("🔍 [Preview] 长按手势触发")
    
    // 创建操作
    let saveAction = SCActionSheet.Action(
        title: "保存到相册",
        icon: UIImage(systemName: "square.and.arrow.down"),
        style: .default
    ) { [weak self] in
        print("✅ [Preview] 执行保存到相册操作")
        self?.saveImageToAlbum()
    }
    
    let shareAction = SCActionSheet.Action(
        title: "分享",
        icon: UIImage(systemName: "square.and.arrow.up"),
        style: .default
    ) { [weak self] in
        print("✅ [Preview] 执行分享操作")
        self?.shareImage()
    }
    
    let cancelAction = SCActionSheet.Action(
        title: "取消",
        icon: nil,
        style: .cancel,
        handler: nil
    )
    
    // 显示操作表
    SCActionSheet.show(actions: [saveAction, shareAction, cancelAction])
}

// MARK: - Actions
private func saveImageToAlbum() {
    // RAW 自动保存模式：会话已写入 RAW+JPEG，避免重复保存
    if SCCameraSettingsManager.shared.autoSaveMode == 2 {
        SwiftMessages.showSuccessMessage("RAW+JPEG 已保存到相册", title: "保存成功")
        self.dismiss(animated: true)
        return
    }
    // 显示进度条
    progressView.isHidden = false
    progressView.progress = 0
    
    // 添加触觉反馈
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    feedbackGenerator.prepare()
    
    // 模拟保存进度
    var progress: Float = 0
    Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
        guard let self = self else {
            timer.invalidate()
            return
        }
        
        progress += 0.1
        self.progressView.progress = min(progress, 1.0)
        
        if progress >= 1.0 {
            timer.invalidate()
            feedbackGenerator.impactOccurred()
            
            // 保存照片到相册（仅非 RAW 模式）
            UIImageWriteToSavedPhotosAlbum(self.image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
}

private func shareImage() {
    // 创建活动视图控制器
    let activityViewController = UIActivityViewController(
        activityItems: [image],
        applicationActivities: nil
    )
    
    // 在 iPad 上设置弹出位置
    if let popoverController = activityViewController.popoverPresentationController {
        popoverController.sourceView = view
        popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY,
                                            width: 0, height: 0)
        popoverController.permittedArrowDirections = []
    }
    
    // 显示分享界面
    present(activityViewController, animated: true)
} 