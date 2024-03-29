//
//  SplitDropDownMenu.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/19/23.
//

import SwiftUI
import HealthKit

struct SplitDropDownMenu: View {
    @EnvironmentObject var splitManager: SplitManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @Binding var workoutData: WorkoutData
    @Binding var showDropDown: Bool

    var body: some View {
        VStack {
            ForEach(splitManager.splits.keys.sorted(), id: \.self) { split in
                Button(split) {
                    updateSplit(split)
                }
            }
            Button("Clear Split") {
                updateSplit(nil)
            }
        }
    }

    private func updateSplit(_ newSplit: String?) {
        let workout = workoutData.workout
        splitManager.updateWorkoutSplit(workout: workout, newSplit: newSplit, pInZone: 0.5, workoutDataManager: workoutDataManager)
        showDropDown = false
    }
}
