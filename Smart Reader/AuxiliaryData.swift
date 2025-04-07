//
//  AuxiliaryData.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 13.11.24.
//

import Foundation

func onMain(f: @escaping (() -> Void)) {
    DispatchQueue.main.async {
        f()
    }
}
