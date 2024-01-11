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
        ScrollView {
            VStack(alignment: .leading) {
                Text("\(headingFormatter.string(from: workoutData.workout.startDate))")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                SplitInfoSquare(workoutData: $workoutData, showDropDown: $showDropDown)
                InfoSquare(title: "Energy Burned", value: "\(Int(workoutData.workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()).rounded() ?? 0)) kcal")
                InfoSquare(title: "Duration", value: formatDuration(Int(workoutData.workout.duration.rounded())))
                InfoSquare(title: "Heart Rate", value: averageHeartRate != nil ? "\(Int(averageHeartRate!.rounded())) bpm" : "Fetching...")
            }
            .padding([.leading, .trailing])
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                fetchHeartRate()
            }
        }
        }

    private func fetchHeartRate() {
        workoutDataManager.fetchAverageHeartRate(for: workoutData.workout) { heartRate in
            self.averageHeartRate = heartRate
        }
    }
}

private struct SplitInfoSquare: View {
    @Binding var workoutData: WorkoutData
    @Binding var showDropDown: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Split")
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundColor(.gray)
                Button(action: { showDropDown.toggle() }) {
                    Image(systemName: "pencil")
                }
                .popover(isPresented: $showDropDown, arrowEdge: .top) {
                    SplitDropDownMenu(workoutData: $workoutData, showDropDown: $showDropDown)
                }
            }
            Text(workoutData.split ?? "NO SPLIT")
                .font(.title2)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

private struct InfoSquare: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title)
                .fontWeight(.heavy)
                .foregroundColor(.gray)
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
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

func formatDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60

    var formattedString = ""
    if hours > 0 {
        formattedString += "\(hours) hour" + (hours > 1 ? "s" : "")
    }
    if minutes > 0 {
        if !formattedString.isEmpty {
            formattedString += " "
        }
        formattedString += "\(minutes) minute" + (minutes > 1 ? "s" : "")
    }
    return formattedString.isEmpty ? "0 minutes" : formattedString
}


// LiftView_Previews remains the same


struct LiftView_Previews: PreviewProvider {
    @State static var mockWorkoutData = WorkoutData(split: "Example Split", workout: HKWorkout(activityType: .running, start: Date(), end: Date()))

    static var previews: some View {
        LiftView(workoutData: $mockWorkoutData)
    }
}
