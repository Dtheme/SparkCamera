class SCPhotoPreviewVC: UIViewController {
    // MARK: - Properties
    private var isEditingMode: Bool = false
    
    // MARK: - UI Methods
    private func updateUIForEditingMode(_ isEditing: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.infoView.alpha = isEditing ? 0 : 1
        }
    }
    
    private func showExitEditingConfirmation(completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "退出编辑",
            message: "确定要退出编辑模式吗？未保存的修改将会丢失。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            completion(false)
        })
        
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in
            completion(true)
        })
        
        present(alert, animated: true)
    }
    
    private func enterEditingMode() {
        isEditingMode = true
        updateUIForEditingMode(true)
    }
    
    private func exitEditingMode() {
        showExitEditingConfirmation { [weak self] shouldExit in
            guard let self = self, shouldExit else { return }
            
            self.isEditingMode = false
            self.updateUIForEditingMode(false)
        }
    }
    
    @objc private func edit() {
        if isEditingMode {
            exitEditingMode()
        } else {
            enterEditingMode()
            // 显示编辑功能提示
            let view = MessageView.viewFromNib(layout: .statusLine)
            view.configureTheme(.info)
            view.configureContent(title: "提示", body: "后续会开发滤镜等图片编辑操作")
            SwiftMessages.show(view: view)
        }
    }
}

// MARK: - SCPhotoPreviewToolbarDelegate
extension SCPhotoPreviewVC: SCPhotoPreviewToolbarDelegate {
    func toolbarDidTapCancel(_ toolbar: SCPhotoPreviewToolbar) {
        if isEditingMode {
            exitEditingMode()
        } else {
            animateDismissal {
                self.dismiss(animated: false)
            }
        }
    }
    
    func toolbarDidTapEdit(_ toolbar: SCPhotoPreviewToolbar) {
        if isEditingMode {
            exitEditingMode()
        } else {
            enterEditingMode()
        }
    }
    
    func toolbarDidTapConfirm(_ toolbar: SCPhotoPreviewToolbar) {
        if isEditingMode {
            // TODO: 保存编辑效果
            isEditingMode = false
            updateUIForEditingMode(false)
        } else {
            // 显示进度条
            showProgressView()
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
                    
                    // 保存照片到相册
                    UIImageWriteToSavedPhotosAlbum(self.image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                    
                    // 隐藏进度条
                    self.hideProgressView()
                }
            }
        }
    }
} 