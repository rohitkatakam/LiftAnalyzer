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
    @State private var selectedTimeframe = "one month"
    private let timeframes = ["one week", "one month", "three months", "six months", "one year", "all time"]
    
    //filter workouts by timeframe
    private var filteredWorkouts: [StoredWorkout] {
        switch selectedTimeframe {
            case "one week":
                return workouts.filter { $0.startDate >= Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() }
            case "one month":
                return workouts.filter { $0.startDate >= Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date() }
            case "three months":
                return workouts.filter { $0.startDate >= Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date() }
            case "six months":
                return workouts.filter { $0.startDate >= Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date() }
            case "one year":
                return workouts.filter { $0.startDate >= Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date() }
            case "all time":
                return workouts
            default:
                return workouts
        }
    }

    // Calculate average duration
    private func averageDuration() -> TimeInterval {
        let totalDuration = filteredWorkouts.reduce(0) { $0 + $1.duration }
        return filteredWorkouts.isEmpty ? 0 : totalDuration / Double(filteredWorkouts.count)
    }

    // Calculate average energy burned
    private func averageEnergyBurned() -> Double {
        let totalEnergyBurned = filteredWorkouts.reduce(0) { $0 + $1.totalEnergyBurned }
        return filteredWorkouts.isEmpty ? 0 : totalEnergyBurned / Double(filteredWorkouts.count)
    }

    // Calculate average heart rate
    private func averageHeartRate() -> Double {
        let totalHeartRate = filteredWorkouts.reduce(0) { $0 + $1.averageHeartRate }
        return filteredWorkouts.isEmpty ? 0 : totalHeartRate / Double(filteredWorkouts.count)
    }
    
    // Calculate # of workouts in selected timeframe
    private func workoutsInTimeFrame() -> Int {
        return filteredWorkouts.count
    }

    var body: some View {
        ScrollView {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(splitName)")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 2) {
                        Text("Over")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Menu(selectedTimeframe) {
                                            ForEach(timeframes, id: \.self) { timeframe in
                                                Button(timeframe) {
                                                    selectedTimeframe = timeframe
                                                }
                                            }
                                        }
                                        .font(.title3)
                                        .fontWeight(.semibold)
                    }
                    
                    if !workouts.isEmpty {
                        InfoSquare(title: "Count", value: "\(workoutsInTimeFrame())")
                        InfoSquare(title: "Energy Burned", value: "\(Int(averageEnergyBurned().rounded())) kcal")
                        InfoSquare(title: "Duration", value: formatDuration(Int(averageDuration().rounded())))
                        InfoSquare(title: "Heart Rate", value: "\(Int(averageHeartRate().rounded())) bpm")
                    }
                    
                    Text("All Lifts")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding([.top])
                    ForEach(workouts, id: \.startDate) { workout in
                                        Text("\(workout.startDate, formatter: itemFormatter)")
                                    }
                    Button("Delete Split") {
                        splitManager.deleteSplit(named: splitName)
                    }
                    .padding(.top)
                    .foregroundColor(.red)
                }
                .padding([.leading, .trailing, .bottom])
                Spacer()
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
}()

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

