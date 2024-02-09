//
//  PopupManager.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 2/8/24.
//

import SwiftUI
import HealthKit

class PopupManager: ObservableObject {
    @Published var showPopup: Bool = false
    
    func animatePopup() {
        showPopup = true
    }
    
    func dismissPopup() {
        showPopup = false
    }
}
