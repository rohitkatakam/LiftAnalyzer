//
//  SettingsView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 8/13/24.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    let timeframes = ["Last Week", "Last Month", "Last Year", "All Time"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Default Timeframe for SplitView")) {
                    Picker("Default Timeframe", selection: $settingsManager.defaultTimeframe) {
                        ForEach(timeframes, id: \.self) { timeframe in
                            Text(timeframe)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
        }
    }
}
