//
//  PermissionAlertViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 24.11.24.
//

import UIKit
import RxSwift

class PermissionAlertViewController: UIViewController {
    
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var interfaceBackView: UIVisualEffectView!
    
    @IBOutlet weak var goToSettingsButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    public var goToSettingsAction: (action: () -> Void, title: String) = ({}, "")
    
    private let disposeBag = DisposeBag()
    private var goToSettingsPrivate: () -> Void = {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        background.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        
        // set actions
        goToSettingsPrivate = goToSettingsAction.action
        
        goToSettingsButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    this.dismiss(action: this.goToSettingsPrivate)
                }
            })
            .disposed(by: disposeBag)
        
        cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.dismiss(action: nil)
            })
            .disposed(by: disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.25) {
            self.background.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    static func presentAlert(
        firstAction: (action: () -> Void, title: String),
        onViewController: UIViewController? = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController) {
            
            let viewController = UIStoryboard(name: "PermissionAlert", bundle: .main).instantiateViewController(identifier: "PermissionAlertViewController") as PermissionAlertViewController
            
            viewController.modalPresentationStyle = .overFullScreen
            viewController.modalTransitionStyle = .crossDissolve
            viewController.goToSettingsAction = firstAction
            
            if let delegate = UIApplication.shared.delegate as? AppDelegate,
               let _ = delegate.window?.topViewController() as? PermissionAlertViewController { } else {
                   onViewController?.topViewController().present(viewController, animated: true)
               }
        }
    
    private func dismiss(_ success: Bool = false, action: (() -> Void)?) {
        modalTransitionStyle = .crossDissolve
        self.dismiss(animated: true, completion: {
            guard let action = action else { return }
            action()
        })
    }
    
    private func action(_ success: Bool = false, action: (() -> Void)?) {
        guard let action = action else { return }
        action()
    }
    
    @IBAction
    private func close(_ sender: Any) {
        EfficiencyGenerator.shared.kickback()
        self.dismiss(action: nil)
    }
}

extension UIViewController {
    func topViewController() -> UIViewController {
        var topController = self
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
}

extension UIWindow {
    func topViewController() -> UIViewController? {
        var top = self.rootViewController
        while true {
            if let presented = top?.presentedViewController {
                top = presented
            } else if let nav = top as? UINavigationController {
                top = nav.visibleViewController
            } else if let tab = top as? UITabBarController {
                top = tab.selectedViewController
            } else {
                break
            }
        }
        return top
    }
}
