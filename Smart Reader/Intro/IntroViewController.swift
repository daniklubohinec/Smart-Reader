//
//  IntroViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 12.11.24.
//

import UIKit
import RxSwift
import RxCocoa

class IntroViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    @IBOutlet weak var dismissButton: UIButton!
    
    @IBOutlet weak var contentCollectionView: UICollectionView!
    
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    @IBOutlet weak var pageController: UIPageControl!
    @IBAction func pageControllerAction(_ sender: Any) {
        let pc = sender as! UIPageControl
        contentCollectionView.scrollToItem(at: IndexPath(item: pc.currentPage, section: 0),
                                           at: .centeredHorizontally, animated: true)
        changeConfiguration()
    }
    
    @IBOutlet weak var reviewSubscriptionButton: UIButton!
    
    @IBOutlet weak var politicsButtonStackView: UIStackView!
    @IBOutlet weak var termsOfUseButton: UIButton!
    @IBOutlet weak var restoreButton: UIButton!
    @IBOutlet weak var privacyPolicyButton: UIButton!
    
    private let review = PurchaseService.shared.review
    
    let disposeBag = DisposeBag()
    var completion: (() -> Void)?
    
    var pages: [Page] = [
        Page(imageName: "IntroFirstScreenImage", title: "Universal QR and Barcode Scanner", subtitle: "Compatible with over 10 barcode types, including QR codes, Data Matrix, and more."),
        
        Page(imageName: "IntroSecondScreenImage", title: "Build and Customize Your QR Codes", subtitle: "Effortlessly create and modify personalized QR codes in no time."),
        
        Page(imageName: "IntroThirdScreenImage", title: "Gather All Your Codes in One Place", subtitle: "Organize and store all your scanned and generated codes in a single location."),
        
        Page(imageName: "IntroFourthScreenImage", title: "Unlimited QR Code Scanning & Creation", subtitle: "Unlimited QR code scanning and generating with a 3-day free trial, then $6.99 per week.")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        isPurchasesPresented = true
        
        pageController.numberOfPages = review ? self.pages.count : self.pages.count + 1
        
        buttonConfiguration()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bounceAnimation()
    }
    
    func buttonConfiguration() {
        nextButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                let visibleItems: NSArray = this.contentCollectionView.indexPathsForVisibleItems as NSArray
                let currentItem: IndexPath = visibleItems.object(at: 0) as! IndexPath
                let nextItem: IndexPath = IndexPath(item: currentItem.item + 1, section: 0)
                if this.pageController.currentPage == 1 && this.review == false {
                    AppRetingRequest().requestImmediately()
                }
                
                if this.pageController.currentPage == 3 {
                    InfoTree.shared.introPresented = true
                    if let product = PurchaseService.shared.inAppPaywall?.products.first {
                        Task { [weak self] in
                            await PurchaseService.shared.makePurchase(product: product)
                            DispatchQueue.main.async { [weak self] in
                                self?.completion?()
                                self?.dismiss(animated: true)
                            }
                        }
                    }
                } else {
                    if nextItem.row < this.pages.count {
                        this.contentCollectionView.scrollToItem(at: nextItem, at: .left, animated: true)
                        this.pageController.currentPage = nextItem.row
                    }
                }
                this.changeConfiguration()
            })
            .disposed(by: disposeBag)
        
        backButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                let visibleItems: NSArray = this.contentCollectionView.indexPathsForVisibleItems as NSArray
                let currentItem: IndexPath = visibleItems.object(at: 0) as! IndexPath
                let nextItem: IndexPath = IndexPath(item: currentItem.item - 1, section: 0)
                if nextItem.row < this.pages.count {
                    this.contentCollectionView.scrollToItem(at: nextItem, at: .right, animated: true)
                    this.pageController.currentPage = nextItem.row
                }
                this.changeConfiguration()
            })
            .disposed(by: disposeBag)
        
        termsOfUseButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.requestUrl("https://docs.google.com/document/d/12Vo18RoC7JhslNA4WfuwGxUE7fMFrL1g1EmEzO9KW3g/edit?usp=sharing")
            })
            .disposed(by: disposeBag)
        
        restoreButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                Task {
                    await PurchaseService.shared.restorePurchases()
                }
            })
            .disposed(by: disposeBag)
        
        privacyPolicyButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.requestUrl("https://docs.google.com/document/d/1ABLEDZf52tn2SibnFWijgiPqIkuGvq5WMNqCwIWEcoc/edit?usp=sharing")
            })
            .disposed(by: disposeBag)
        
        reviewSubscriptionButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                InfoTree.shared.introPresented = true
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
        
        dismissButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.completion?()
                InfoTree.shared.introPresented = true
                this.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
    
    func changeConfiguration() {
        if pageController.currentPage == pageController.numberOfPages - 1 && review == true {
            InfoTree.shared.introPresented = true
            reviewSubscriptionButton.isHidden = false
            dismissButton.setImage(UIImage(named: "kckbjxkbj"), for: .normal)
            nextButton.isHidden = true
            backButton.isHidden = true
            pageController.isHidden = true
            dismissButton.isHidden = false
            politicsButtonStackView.isHidden = false
        } else if pageController.currentPage == pageController.numberOfPages - 2 && review == false {
            politicsButtonStackView.isHidden = false
            dismissButton.setImage(UIImage(named: "asdasdkvkcv"), for: .normal)
            politicsButtonStackView.isHidden = false
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(4)) {
                self.dismissButton.isHidden = false
            }
        } else {
            reviewSubscriptionButton.isHidden = true
            nextButton.isHidden = false
            backButton.isHidden = false
            pageController.isHidden = false
            dismissButton.isHidden = true
            politicsButtonStackView.isHidden = true
            politicsButtonStackView.isHidden = true
        }
    }
    
    func bounceAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1
        pulseAnimation.toValue = 1.05
        pulseAnimation.duration = 1
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        reviewSubscriptionButton.layer.add(pulseAnimation, forKey: "animateOpacity")
        nextButton.layer.add(pulseAnimation, forKey: "animateOpacity")
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = contentCollectionView.dequeueReusableCell(withReuseIdentifier: "introCellID", for: indexPath) as! IntroCollectionViewCell
        cell.configureCell(page: pages[indexPath.item])
        cell.subTextLabel.textColor = review ? .black : UIColor(named: "8E8E94")
        
        if pageController.currentPage == pageController.numberOfPages - 1 && review == true {
            cell.reviewSubscriptionView.isHidden = false
            cell.subTextLabel.isHidden = true
            cell.reviewViewHeightConstraint.constant = 32
            cell.reviewViewtopConstraint.constant = 34
        } else if pageController.currentPage == pageController.numberOfPages - 2 && review == false {
            cell.reviewSubscriptionView.isHidden = true
            cell.subTextLabel.isHidden = false
            cell.reviewViewHeightConstraint.constant = 12
            cell.reviewViewtopConstraint.constant = 54
        } else {
            cell.reviewSubscriptionView.isHidden = true
            cell.subTextLabel.isHidden = false
            cell.reviewViewHeightConstraint.constant = 12
            cell.reviewViewtopConstraint.constant = 54
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.contentCollectionView.frame.width, height: self.contentCollectionView.frame.height)
    }
    
    deinit {
        isPurchasesPresented = false
    }
}

extension UICollectionView {
    func scrollToNextItem() {
        let contentOffset = CGFloat(floor(self.contentOffset.x + self.bounds.size.width))
        self.moveToFrame(contentOffset: contentOffset)
    }
    func moveToFrame(contentOffset : CGFloat) {
        self.setContentOffset(CGPoint(x: contentOffset, y: self.contentOffset.y), animated: true)
    }
}
