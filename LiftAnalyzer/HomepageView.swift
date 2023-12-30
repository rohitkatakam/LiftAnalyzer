//
//  HomepageView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/14/23.
//

import SwiftUI

struct HomepageView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var splitManager: SplitManager
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    Text("Recent Lifts")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .padding([.top, .leading])
                    
                    // NavigationLink to navigate to LiftView
                    ForEach(workoutDataManager.workouts.prefix(3), id: \.workout.uuid) { workoutData in
                        NavigationLink(destination: LiftView(workoutData: Binding(
                            get: { workoutData },
                            set: { workoutDataManager.workouts[workoutDataManager.workouts.firstIndex(where: { $0.workout == workoutData.workout })!] = $0 }
                        ))) {
                            HStack {
                                Text(workoutData.split ?? "NO SPLIT")
                                Text("Workout on \(workoutData.workout.startDate, formatter: itemFormatter)")
                            }
                        }
                        .padding()
                    }
                    
                    NavigationLink(destination: WorkoutListView()) {
                        Text("View all workouts")
                            .foregroundColor(.blue)
                            .padding()
                    }

                    Text("Splits")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .padding([.top, .leading])
                    ForEach(Array(splitManager.splits.keys.prefix(3)), id: \.self) { splitName in
                        NavigationLink(destination: SplitView(splitName: splitName, workouts: splitManager.splits[splitName] ?? [])) {
                            Text(splitName)
                                .foregroundColor(.blue)
                                .padding()
                        }
                    }
                    NavigationLink(destination: SplitListView()) {
                        Text("View all splits")
                            .foregroundColor(.blue)
                            .padding()
                    }
                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomepageView()
    }
}
