//
//  LiftAnalyzerApp.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/14/23.
//

import SwiftUI

@main
struct LiftAnalyzerApp: App {
    @StateObject var workoutDataManager = WorkoutDataManager()
    @StateObject var splitManager = SplitManager()

    var body: some Scene {
        WindowGroup {
            HomepageView()
                .environmentObject(workoutDataManager)
                .environmentObject(splitManager)
        }
    }
}

