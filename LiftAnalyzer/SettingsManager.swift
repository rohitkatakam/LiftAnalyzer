//
//  SettingsManager.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 8/13/24.
//

import Foundation

class SettingsManager: ObservableObject {
    @Published var defaultTimeframe: String {
        didSet {
            UserDefaults.standard.set(defaultTimeframe, forKey: "defaultTimeframe")
        }
    }
    
    init() {
        self.defaultTimeframe = UserDefaults.standard.string(forKey: "defaultTimeframe") ?? "Last Year"
    }
    
    func getDefaultStartDate() -> Date {
        switch defaultTimeframe {
        case "Last Week":
            return Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        case "Last Month":
            return Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case "Last Year":
            return Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        case "All Time":
            return Date.distantPast
        default:
            return Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        }
    }
}
