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
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @Binding var workoutData: WorkoutData
    @State private var showDropDown = false
    @State private var averageHeartRate: Double?

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(headingFormatter.string(from: workoutData.workout.startDate))")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
            HStack {
                Text(workoutData.split ?? "NO SPLIT").font(.headline).bold()
                Button(action: { showDropDown.toggle() }) {
                    Image(systemName: "pencil")
                }
                .popover(isPresented: $showDropDown, arrowEdge: .top) {
                    SplitDropDownMenu(workoutData: $workoutData, showDropDown: $showDropDown)
                }
            }
            Text("Start Date: \(workoutData.workout.startDate, formatter: itemFormatter)")
            Text("Duration: \(workoutData.workout.duration) seconds")
            Text("Energy Burned: \(workoutData.workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) kcal")
            if let heartRate = averageHeartRate {
                Text("Average Heart Rate: \(heartRate) bpm")
            } else {
                Text("Fetching heart rate...")
            }
            Spacer()
        }
        .onAppear {
            fetchHeartRate()
        }
    }

    private func fetchHeartRate() {
        workoutDataManager.fetchAverageHeartRate(for: workoutData.workout) { heartRate in
            self.averageHeartRate = heartRate
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .medium
    return formatter
}()

private let headingFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter
}()


// LiftView_Previews remains the same


struct LiftView_Previews: PreviewProvider {
    @State static var mockWorkoutData = WorkoutData(split: "Example Split", workout: HKWorkout(activityType: .running, start: Date(), end: Date()))

    static var previews: some View {
        LiftView(workoutData: $mockWorkoutData)
    }
}

