import SwiftMessages

extension SwiftMessages {
    static func showSuccessMessage(_ message: String, title: String = "提示") {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.success)
        view.backgroundColor = SCConstants.successColor
        view.configureContent(title: title, body: message)
        SwiftMessages.show(view: view)
    }
    
    static func showWarningMessage(_ message: String, title: String = "警告") {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.warning)
        view.backgroundColor = SCConstants.warningColor
        view.configureContent(title: title, body: message)
        SwiftMessages.show(view: view)
    }
    
    static func showErrorMessage(_ message: String, title: String = "错误") {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.error)
        view.backgroundColor = SCConstants.warningColor
        view.configureContent(title: title, body: message)
        SwiftMessages.show(view: view)
    }
    
    static func showInfoMessage(_ message: String, title: String = "提示") {
        let view = MessageView.viewFromNib(layout: .statusLine)
        view.configureTheme(.info)
        view.backgroundColor = SCConstants.themeColor
        view.configureContent(title: title, body: message)
        SwiftMessages.show(view: view)
    }
} 