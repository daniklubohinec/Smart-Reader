//
//  IntroCollectionViewCell.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 13.11.24.
//

import UIKit
import RxSwift

class IntroCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var mainImageView: UIImageView!
    
    @IBOutlet weak var mainTextLabel: UILabel!
    @IBOutlet weak var subTextLabel: UILabel!
    
    @IBOutlet weak var reviewViewtopConstraint: NSLayoutConstraint!
    @IBOutlet weak var reviewViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var reviewSubscriptionView: UIView!
    @IBOutlet weak var reviewPriceTextLabel: UILabel!
    @IBOutlet weak var reviewTrialTextLabel: UILabel!
    
    func configureCell(page: Page) {
        self.mainImageView.image = UIImage(named: page.imageName)
        self.mainTextLabel.text = page.title
        self.subTextLabel.text = page.subtitle
    }
}
