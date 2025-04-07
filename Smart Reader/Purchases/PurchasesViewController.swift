//
//  PurchasesViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 12.11.24.
//

import UIKit
import RxSwift
import RxCocoa

var isPurchasesPresented = false

class PurchasesViewController: UIViewController {
    
    @IBOutlet weak var dismissControllerButton: UIButton!
    
    @IBOutlet weak var purchasesSubtitleTextLabel: UILabel!
    
    @IBOutlet weak var onReviewContentBackView: UIView!
    @IBOutlet weak var onReviewPriceTextLabel: UILabel!
    @IBOutlet weak var onReviewDurationLabel: UILabel!
    
    @IBOutlet weak var nextPageButtonAction: UIButton!
    
    @IBOutlet weak var termsOfUsePageButton: UIButton!
    @IBOutlet weak var restorePageButton: UIButton!
    @IBOutlet weak var privacyPolicyPageButton: UIButton!
    
    @IBOutlet weak var purchasesTitleBottomContraint: NSLayoutConstraint!
    
    let disposeBag = DisposeBag()
    let configReviewData = PurchaseService.shared.review
    
    var completion: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        isPurchasesPresented = true
        
        setupButtons()
        setiingInterfaceContentData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        scaleButtonAnimation()
    }
    
    func scaleButtonAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1
        pulseAnimation.toValue = 1.05
        pulseAnimation.duration = 1
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        nextPageButtonAction.layer.add(pulseAnimation, forKey: "animateOpacity")
    }
    
    func setiingInterfaceContentData() {
        guard let paywall = PurchaseService.shared.inAppPaywall else { return }
        purchasesSubtitleTextLabel.text = "\(paywall.config.descriptionSubtitle) \(paywall.products.first?.localizedPrice ?? "$6.99") per week"
        onReviewDurationLabel.text = paywall.config.trial
        onReviewPriceTextLabel.text = "Weekly \(paywall.products.first?.localizedPrice ?? "$6.99")"
        
        if configReviewData {
            dismissControllerButton.setImage(UIImage(named: "kckbjxkbj"), for: .normal)
            
            purchasesSubtitleTextLabel.isHidden = true
            onReviewContentBackView.isHidden = false
            
            purchasesTitleBottomContraint.constant = 12
            
            var configuration = nextPageButtonAction.configuration
            guard let paywall = PurchaseService.shared.inAppPaywall else { return }
            configuration?.title = "\(paywall.config.purchaseTitle) \(paywall.products.first?.localizedPrice ?? "$6.99")/week"
            configuration?.subtitle = paywall.config.priceSubtitle
            configuration?.titleAlignment = .center
            configuration?.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer({ container in
                var container = container
                container.font = UIFont(name: "Inter-Regular", size: 14)
                container.foregroundColor = UIColor.white.withAlphaComponent(0.4)
                return container
            })
            configuration?.titleTextAttributesTransformer = .init({ container in
                var container = container
                container.font = UIFont(name: "Inter-Medium", size: 16)
                return container
            })
            nextPageButtonAction.configuration = configuration
            nextPageButtonAction.updateConfiguration()
        } else {
            dismissControllerButton.setImage(UIImage(named: "asdasdkvkcv"), for: .normal)
            dismissControllerButton.isHidden = true
            
            purchasesSubtitleTextLabel.isHidden = false
            purchasesSubtitleTextLabel.textColor = UIColor(named: "8E8E94")
            onReviewContentBackView.isHidden = true
            
            purchasesTitleBottomContraint.constant = -8
            
            var configuration = UIButton.Configuration.filled()
            configuration.baseBackgroundColor = .clear
            configuration.baseForegroundColor = .white
            configuration.title = "Next"
            configuration.titleTextAttributesTransformer = .init({ container in
                var container = container
                container.font = UIFont(name: "Inter-Medium", size: 16)
                return container
            })
            nextPageButtonAction.configuration = configuration
            nextPageButtonAction.updateConfiguration()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) {
                self.dismissControllerButton.isHidden = false
            }
        }
    }
    
    func setupButtons() {
        dismissControllerButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.completion?()
                this.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
        
        nextPageButtonAction.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                if let product = PurchaseService.shared.inAppPaywall?.products.first {
                    Task {
                        await PurchaseService.shared.makePurchase(product: product)
                        DispatchQueue.main.async {
                            this.completion?()
                            this.dismiss(animated: true)
                        }
                    }
                }
            })
            .disposed(by: disposeBag)
        
        termsOfUsePageButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.requestUrl("https://docs.google.com/document/d/12Vo18RoC7JhslNA4WfuwGxUE7fMFrL1g1EmEzO9KW3g/edit?usp=sharing")
            })
            .disposed(by: disposeBag)
        
        restorePageButton.rx.tap
            .asDriver()
            .drive(onNext: {
                EfficiencyGenerator.shared.kickback()
                Task {
                    await PurchaseService.shared.restorePurchases()
                }
            })
            .disposed(by: disposeBag)
        
        privacyPolicyPageButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.requestUrl("https://docs.google.com/document/d/1ABLEDZf52tn2SibnFWijgiPqIkuGvq5WMNqCwIWEcoc/edit?usp=sharing")
            })
            .disposed(by: disposeBag)
    }
    
    deinit {
        isPurchasesPresented = false
    }
}
