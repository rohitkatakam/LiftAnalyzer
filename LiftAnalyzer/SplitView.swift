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
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(splitName)")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding([.leading])

            List(workouts, id: \.startDate) { workout in
                Text("Workout on \(workout.startDate, formatter: itemFormatter)")
                // Display additional workout information as needed
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

