//
//  SceneDelegate.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 创建窗口
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // 设置根视图控制器
        let homeVC = HomeVC()
        window.rootViewController = homeVC
        
        // 显示窗口
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // 场景断开连接时调用
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // 场景变为活跃状态时调用
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // 场景即将进入非活跃状态时调用
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // 场景即将进入前台时调用
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // 场景进入后台时调用
    }
}

