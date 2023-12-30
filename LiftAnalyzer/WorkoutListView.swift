//
//  WorkoutListView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/18/23.
//

import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager

    var body: some View {
        List {
            ForEach(workoutDataManager.workouts, id: \.workout.uuid) { workoutData in
                NavigationLink(destination: LiftView(workoutData: Binding(
                    get: { workoutData },
                    set: { workoutDataManager.workouts[workoutDataManager.workouts.firstIndex(where: { $0.workout == workoutData.workout })!] = $0 }
                ))) {
                    HStack {
                        Text(workoutData.split ?? "NO SPLIT")
                        Text("Workout on \(workoutData.workout.startDate, formatter: itemFormatter)")
                    }
                }
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .medium
    return formatter
}()

struct WorkoutListView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutListView().environmentObject(WorkoutDataManager())
    }
}


