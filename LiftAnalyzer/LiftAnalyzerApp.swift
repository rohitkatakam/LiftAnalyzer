//
//  LiftAnalyzerApp.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/14/23.
//

import SwiftUI

@main
struct LiftAnalyzerApp: App {
    var splitManager = SplitManager()
    var workoutDataManager: WorkoutDataManager

    init() {
        workoutDataManager = WorkoutDataManager(splitManager: splitManager)
    }

    var body: some Scene {
        WindowGroup {
            HomepageView()
                .environmentObject(splitManager)
                .environmentObject(workoutDataManager)
        }
    }
}

