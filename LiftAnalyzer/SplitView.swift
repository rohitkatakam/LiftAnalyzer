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
    var workouts : [HKWorkout]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(splitName)")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding([.leading])

            List(workouts, id: \.uuid) { workout in
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
    static let mockWorkout = HKWorkout(activityType: .traditionalStrengthTraining, start: Date(), end: Date())
    
    static var previews : some View {
        SplitView(splitName: "Example", workouts: [mockWorkout])
    }
}
