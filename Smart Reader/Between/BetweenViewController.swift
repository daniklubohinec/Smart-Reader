//
//  BetweenViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 8.11.24.
//

import UIKit
import RxSwift
import Combine

class BetweenViewController: UIViewController {
    
    @IBOutlet weak var betweenActivityView: UIActivityIndicatorView!
    private var cancelable = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PurchaseService.shared.$inAppPaywall
            .sink { [weak self] paywall in
                guard paywall != nil, let self else {
                    return
                }
                onMain {
                    if !InfoTree.shared.introPresented, !PurchaseService.shared.hasPremium {
                        self.showUserGuide()
                    } else {
                        self.goToScanViewController()
                        self.unhideMain()
                    }
                }
            }
            .store(in: &cancelable)
    }
    
    private func goToScanViewController() {
        let readerStorybaord = UIStoryboard(name: "Reader", bundle: nil)
        if let readerViewController = readerStorybaord.instantiateInitialViewController() {
            readerViewController.modalTransitionStyle = .crossDissolve
            readerViewController.modalPresentationStyle = .fullScreen
            
            self.addChild(readerViewController)
            self.view.addSubview(readerViewController.view)
            readerViewController.view.frame = self.view.bounds
            readerViewController.didMove(toParent: self)
            
            readerViewController.view.isHidden = true
        }
    }
    
    private func unhideMain() {
        if let mainViewController = children.first {
            mainViewController.view.isHidden = false
        }
    }
    
    private func showUserGuide() {
        let vc = UIStoryboard(name: "Intro", bundle: .main).instantiateViewController(identifier: "IntroViewController") as IntroViewController
        vc.completion = { [weak self] in
            self?.goToScanViewController()
            self?.unhideMain()
        }
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true)
    }
}
