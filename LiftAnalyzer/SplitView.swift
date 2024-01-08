//
//  SplitView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/18/23.
//

import SwiftUI
import HealthKit

struct SplitView: View {
    @EnvironmentObject var splitManager: SplitManager
    var splitName: String
    var workouts: [StoredWorkout]

    // Calculate average duration
    private func averageDuration() -> TimeInterval {
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        return workouts.isEmpty ? 0 : totalDuration / Double(workouts.count)
    }

    // Calculate average energy burned
    private func averageEnergyBurned() -> Double {
        let totalEnergyBurned = workouts.reduce(0) { $0 + $1.totalEnergyBurned }
        return workouts.isEmpty ? 0 : totalEnergyBurned / Double(workouts.count)
    }

    // Calculate average heart rate
    private func averageHeartRate() -> Double {
        let totalHeartRate = workouts.reduce(0) { $0 + $1.averageHeartRate }
        return workouts.isEmpty ? 0 : totalHeartRate / Double(workouts.count)
    }
    
    // Calculate # of workouts in the past month
    private func workoutsInPastMonth() -> Int {
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return workouts.filter { $0.startDate >= oneMonthAgo }.count
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(splitName)")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding([.leading])

            // Display averages
            if !workouts.isEmpty {
                Text("Average Duration: \(averageDuration()) seconds")
                Text("Average Energy Burned: \(averageEnergyBurned()) kcal")
                Text("Average Heart Rate: \(averageHeartRate()) bpm")
                Text("Number of workouts in the past month: \(workoutsInPastMonth())")
            }

            List(workouts, id: \.startDate) { workout in
                Text("Workout on \(workout.startDate, formatter: itemFormatter)")
            }

            Button("Delete Split") {
                splitManager.deleteSplit(named: splitName)
            }
            .padding()
            .foregroundColor(.red)
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .medium
    return formatter
}()

struct SplitView_Previews : PreviewProvider {
    static let mockStoredWorkout = StoredWorkout(
        startDate: Date(),
        duration: 3600, // For example, 1 hour
        totalEnergyBurned: 500, // Example value
        totalDistance: 1000, // Example value in meters
        averageHeartRate: 120 // Example average heart rate
    )
    
    static var previews: some View {
        SplitView(splitName: "Example", workouts: [mockStoredWorkout])
    }
}

