//
//  ScannedCodesExtension.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 28.11.24.
//

import UIKit
import Differentiator

extension ItemsSctionOriginal: SectionModelType {
    typealias Item = QRDataItem
    
    init(original: ItemsSctionOriginal, items: [QRDataItem]) {
        self = original
        self.items = items
    }
}

extension ReaderViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionDate = dataSource[section].date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy"
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 40))
        let headerLabel = UILabel(frame: CGRect(x: 16, y: 0, width: tableView.bounds.width, height: 40))
        headerLabel.font = UIFont(name: "Inter-Regular", size: 12)
        headerLabel.textColor = UIColor(named: "8E8E94")
        
        headerLabel.text = dateFormatter.string(from: sectionDate)
        headerLabel.sizeToFit()
        headerView.addSubview(headerLabel)
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
}
