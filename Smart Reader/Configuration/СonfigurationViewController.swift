//
//  СonfigurationViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 20.11.24.
//

import UIKit
import RxSwift
import RxCocoa
import MessageUI

class ConfigurationViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    @IBOutlet weak var restoreConfigButton: UIButton!
    @IBOutlet weak var restoreConfigButtonView: UIView!
    
    @IBOutlet weak var rateConfigButton: UIButton!
    @IBOutlet weak var rateConfigButtonView: UIView!
    
    @IBOutlet weak var shareConfigButton: UIButton!
    @IBOutlet weak var shareConfigButtonView: UIView!
    
    @IBOutlet weak var privacyConfigButton: UIButton!
    @IBOutlet weak var privacyConfigButtonView: UIView!
    
    @IBOutlet weak var termsConfigButton: UIButton!
    @IBOutlet weak var termsConfigButtonView: UIView!
    
    @IBOutlet weak var contactConfigButton: UIButton!
    @IBOutlet weak var contactConfigButtonView: UIView!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configurateButtons()
    }
    
    func configurateButtons() {
        rxButtonTapAnimate(restoreConfigButton, restoreConfigButtonView, disposeBag)
        rxButtonTapAnimate(rateConfigButton, rateConfigButtonView, disposeBag)
        rxButtonTapAnimate(shareConfigButton, shareConfigButtonView, disposeBag)
        
        rxButtonTapAnimate(privacyConfigButton, privacyConfigButtonView, disposeBag)
        rxButtonTapAnimate(termsConfigButton, termsConfigButtonView, disposeBag)
        rxButtonTapAnimate(contactConfigButton, contactConfigButtonView, disposeBag)
        
        contactConfigButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                if MFMailComposeViewController.canSendMail() {
                    let mail = MFMailComposeViewController()
                    mail.mailComposeDelegate = self
                    mail.setToRecipients(["lirakkchhe@outlook.com"])
                    this.present(mail, animated: true)
                } else {
                    let alert = UIAlertController(title: "Error", message: "Device is not able to send an email", preferredStyle: .alert)
                    let cancel = UIAlertAction(title: "Close", style: .cancel)
                    alert.addAction(cancel)
                    this.present(alert, animated: true)
                }
            })
            .disposed(by: disposeBag)
        
        rateConfigButton.rx.tap
            .asDriver()
            .drive(onNext: { _ in
                EfficiencyGenerator.shared.kickback()
                AppRetingRequest().requestImmediately()
            })
            .disposed(by: disposeBag)
        
        shareConfigButton.rx.tap
            .asDriver()
            .drive(onNext: { _ in
                EfficiencyGenerator.shared.kickback()
                let linkToShare = ["https://itunes.apple.com/app/6737909166"]
                let activityController = UIActivityViewController(activityItems: linkToShare, applicationActivities: nil)
                self.present(activityController, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
        
        restoreConfigButton.rx.tap
            .asDriver()
            .drive(onNext: { _ in
                EfficiencyGenerator.shared.kickback()
                Task {
                    await PurchaseService.shared.restorePurchases()
                }
            })
            .disposed(by: disposeBag)
        
        termsConfigButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.requestUrl("https://docs.google.com/document/d/12Vo18RoC7JhslNA4WfuwGxUE7fMFrL1g1EmEzO9KW3g/edit?usp=sharing")
            })
            .disposed(by: disposeBag)
        
        privacyConfigButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.requestUrl("https://docs.google.com/document/d/1ABLEDZf52tn2SibnFWijgiPqIkuGvq5WMNqCwIWEcoc/edit?usp=sharing")
            })
            .disposed(by: disposeBag)
    }
}
