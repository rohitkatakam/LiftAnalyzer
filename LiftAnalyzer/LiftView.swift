//
//  LiftView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/18/23.
//

import SwiftUI
import HealthKit

struct LiftView: View {
    @EnvironmentObject var splitManager: SplitManager
    @Binding var workoutData: WorkoutData
    @State private var showDropDown = false

    var body: some View {
        VStack {
            HStack {
                Text(workoutData.split ?? "NO SPLIT")
                Button(action: { showDropDown.toggle() }) {
                    Image(systemName: "arrowtriangle.down.circle")
                }
                .popover(isPresented: $showDropDown, arrowEdge: .top) {
                    SplitDropDownMenu(workoutData: $workoutData, showDropDown: $showDropDown)
                }
            }
            Text("Workout on \(workoutData.workout.startDate, formatter: itemFormatter)")
        }
    }
}


private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .medium
    return formatter
}()

struct LiftView_Previews: PreviewProvider {
    @State static var mockWorkoutData = WorkoutData(split: "Example Split", workout: HKWorkout(activityType: .running, start: Date(), end: Date()))

    static var previews: some View {
        LiftView(workoutData: $mockWorkoutData)
    }
}

