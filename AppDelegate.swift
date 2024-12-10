//
//  AppDelegate.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/10.
//

import UIKit
import RxSwift
import RxCocoa

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let disposeBag = DisposeBag()
    
    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAppearance()
        setupWindow()
        return true
    }
    
    private func setupAppearance() {
        // 设置全局UI样式
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .black
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    private func setupWindow() {
        if #available(iOS 13.0, *) {
            // 使用 SceneDelegate 管理
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.backgroundColor = .white
            let mainVC = SCMainVC()
            window?.rootViewController = SCNavigationController(rootViewController: mainVC)
            window?.makeKeyAndVisible()
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

