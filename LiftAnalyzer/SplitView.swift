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
    @EnvironmentObject var popupManager: PopupManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @StateObject private var settingsManager = SettingsManager()
    var splitName: String
    var workouts: [StoredWorkout]
    @State private var selectedStartDate: Date = Date()
    @State private var showingDeleteAlert = false
    @State private var predictedStats: [String: Double] = [:]
    
    //filter workouts by timeframe
    private var filteredWorkouts: [StoredWorkout] {
        workouts.filter { $0.startDate >= selectedStartDate && $0.startDate <= Date() }
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

    // Calculate average percent in zone
    private func averagePercentInZone() -> Double {
        let totalPercentInZone = filteredWorkouts.reduce(0) { $0 + $1.percentInZone }
        return filteredWorkouts.isEmpty ? 0 : totalPercentInZone / Double(filteredWorkouts.count)
    }

    var body: some View {
        ScrollView {
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Text("\(splitName)")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(Color.red.opacity(0.8))
                                .padding(.top,8)
                        }
                        .alert(isPresented: $showingDeleteAlert) {
                            Alert(
                                title: Text("Delete Split"),
                                message: Text("Are you sure you want to delete this split? This action cannot be undone."),
                                primaryButton: .destructive(Text("Delete")) {
                                    splitManager.deleteSplit(named: splitName)
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    
                    if !workouts.isEmpty {
                        HStack(spacing: 2) {
                            Text("Averages since")
                                .font(.body)
                                .fontWeight(.semibold)
                            Button(action: {
                                let popupView = PopupView {
                                    VStack {
                                        Text("Timeframe")
                                            .font(.title)
                                            .fontWeight(.heavy)
                                            .foregroundColor(Color.primary)
                                        DatePicker(
                                            "Filter workouts from:",
                                            selection: $selectedStartDate,
                                            in: ...Date(),
                                            displayedComponents: .date
                                        )
                                        .datePickerStyle(.graphical)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                    .environmentObject(popupManager)
                                popupManager.animatePopup()
                                let popupViewController = PopupHostingController(rootView: popupView)
                                popupViewController.view.backgroundColor = .clear
                                popupViewController.modalPresentationStyle = .overCurrentContext
                                popupViewController.modalTransitionStyle = .crossDissolve
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootViewController = windowScene.windows.first?.rootViewController {
                                    rootViewController.present(popupViewController, animated: true, completion: nil)
                                }
                            }) {
                                HStack(spacing: 2) {
                                    Text("\(selectedStartDate, formatter: itemFormatter)")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.down.circle.fill")
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        VStack {
                            //First row of InfoSquares (Count, Duration, Heart Rate)
                            InfoSquare(title: "Count", value: "\(workoutsInTimeFrame())", color: .primary)
                            InfoSquare(title: "Duration", value: formatDuration(Int(averageDuration().rounded())), color: .red)
                            InfoSquare(title: "Heart Rate", value: "\(Int(averageHeartRate().rounded())) bpm", color: .orange)
                            InfoSquare(title: "Energy Burned", value: "\(Int(averageEnergyBurned().rounded())) kcal", color: .indigo)
                            HStack {
                                InfoSquare(title: "Percent in Zone", value: "\(Int(averagePercentInZone() * 100))%", color: .teal)
                                Button(action: {
                                    let popupView = PopupView {
                                        VStack {
                                            Text("Heart Rate Zone")
                                                .font(.title)
                                                .fontWeight(.heavy)
                                                .foregroundColor(Color.primary)
                                            Text("A recommended sweet-spot of intensity for lifting weights: high enough that you exerting yourself, but low enough that your body will not burn excess nutrients that could be used to build muscle. Calculated using the Karvonen formula.")
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(Color.primary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                        .environmentObject(popupManager)
                                    popupManager.animatePopup()
                                    let popupViewController = PopupHostingController(rootView: popupView)
                                    popupViewController.view.backgroundColor = .clear
                                    popupViewController.modalPresentationStyle = .overCurrentContext
                                    popupViewController.modalTransitionStyle = .crossDissolve
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootViewController = windowScene.windows.first?.rootViewController {
                                        rootViewController.present(popupViewController, animated: true, completion: nil)
                                    }
                                }) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(.gray)
                                }
                            }
                            .padding(.top, 2)
                        }
                        .onAppear {
                            selectedStartDate = settingsManager.getDefaultStartDate()
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("AI Benchmarks for Next Workout")
                                .font(.body)
                                .fontWeight(.semibold)

                            if let duration = predictedStats["duration"] {
                                InfoSquare(title: "Duration", value: formatDuration(Int(duration.rounded())), color: .red)
                            }
                            
                            if let heartRate = predictedStats["averageHeartRate"] {
                                InfoSquare(title: "Heart Rate", value: "\(Int(heartRate)) bpm", color: .orange)
                            }
                            
                            if let energyBurned = predictedStats["totalEnergyBurned"] {
                                InfoSquare(title: "Energy Burned", value: "\(Int(energyBurned)) kcal", color: .indigo)
                            }
                            
                            if let percentInZone = predictedStats["percentInZone"] {
                                InfoSquare(title: "Percent in Zone", value: "\(Int(percentInZone * 100))%", color: .teal)
                            }
                        }
                        .padding(.top, 10)
                        
                        WorkoutProgressGraph(filteredWorkouts: filteredWorkouts)

                        Text("All Workouts")
                            .font(.body)
                            .fontWeight(.semibold)
                            .padding([.top])
                        
                        ForEach(workoutDataManager.workouts.indices, id: \.self) { index in
                            let workoutData = workoutDataManager.workouts[index]
                            // Check if this workoutData is within the filteredWorkouts range
                            if filteredWorkouts.contains(where: { $0.startDate == workoutData.workout.startDate }) {
                                NavigationLink(destination: LiftView(workoutData: Binding(
                                    get: { workoutDataManager.workouts[index] },
                                    set: { workoutDataManager.workouts[index] = $0 }
                                ))) {
                                    Text("\(workoutData.workout.startDate, formatter: itemFormatter)")
                                }
                            }
                        }
                    }
                    else {
                        Text("You have no workouts associated with this split yet!")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
                .padding([.leading, .trailing, .bottom])
                Spacer()
            }
        }
        .onAppear {
            splitManager.predictStats(for: splitName) { stats in
                self.predictedStats = stats
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM d"
    return formatter
}()

private struct InfoSquare: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .fontWeight(.heavy)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

enum WorkoutMetric: String, CaseIterable {
    case duration = "Duration"
    case averageHeartRate = "Heart Rate"
    case totalEnergyBurned = "Calories"
    case percentInZone = "% in Zone"
}

struct WorkoutProgressGraph: View {
    var filteredWorkouts: [StoredWorkout]
    @State private var selectedMetric: WorkoutMetric = .duration
    
    var body: some View {
        VStack {
            // Toggle between different metrics
            HStack {
                Text("Workout Progress")
                    .font(.body)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Picker("Select Metric", selection: $selectedMetric) {
                ForEach(WorkoutMetric.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Display the graph based on the selected metric
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Draw the Y-axis with tick marks and labels
                    ZStack {
                        ForEach(0..<6) { i in
                            let yPosition = geometry.size.height * CGFloat(Double(i) / 5)
                            HStack {
                                Text("\(formatYAxisValue(i: i, metric: selectedMetric))")
                                    .font(.caption)
                                    .frame(width: 40, alignment: .trailing)
                                    .foregroundStyle(.gray)
                                Rectangle().fill(Color.gray).frame(width: 10, height: 2)
                            }
                            .position(x: 5, y: yPosition) // Adjust x to align with axis
                        }
                    }
                    .frame(width: 40)
                    // Add padding to avoid overlap
                    
                    // Draw the graph
                    ZStack {
                        // Draw the line connecting the data points
                        Path { path in
                            for index in filteredWorkouts.indices {
                                let xPosition = (geometry.size.width - 80) * CGFloat(index) / CGFloat(filteredWorkouts.count - 1) - 30
                                let yValue = valueForMetric(filteredWorkouts[index], metric: selectedMetric)
                                let yPosition = geometry.size.height * CGFloat(1 - yValue / maxYValue(for: selectedMetric))
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: xPosition, y: yPosition))
                                } else {
                                    path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                                }
                            }
                        }
                        .stroke(lineColor(for: selectedMetric), lineWidth: 1)
                        
                        // Draw the points on the graph
                        ForEach(filteredWorkouts.indices, id: \.self) { index in
                            let xPosition = (geometry.size.width - 80) * CGFloat(index) / CGFloat(filteredWorkouts.count - 1) - 30
                            let yValue = valueForMetric(filteredWorkouts[index], metric: selectedMetric)
                            let yPosition = geometry.size.height * CGFloat(1 - yValue / maxYValue(for: selectedMetric))
                            
                            Circle()
                                .fill(lineColor(for: selectedMetric))
                                .frame(width: 4, height: 4)
                                .position(x: xPosition, y: yPosition)
                        }
                    }
                    .padding(.leading, 40) // Ensure the graph has space for the Y-axis
                    .padding(.trailing, 20) // Add extra padding on the right to avoid cutoff
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        .padding(.top)
    }
    
    // Function to get the value for the selected metric
    private func valueForMetric(_ workout: StoredWorkout, metric: WorkoutMetric) -> Double {
        switch metric {
        case .duration:
            return round(workout.duration / 60) // Convert to minutes and round
        case .averageHeartRate:
            return workout.averageHeartRate
        case .totalEnergyBurned:
            return workout.totalEnergyBurned
        case .percentInZone:
            return workout.percentInZone * 100
        }
    }
    
    // Function to get the maximum value for the selected metric (for scaling)
    private func maxYValue(for metric: WorkoutMetric) -> Double {
        switch metric {
        case .duration:
            return round(filteredWorkouts.map { $0.duration / 60 }.max() ?? 1) // Max value in minutes
        case .averageHeartRate:
            return filteredWorkouts.map { $0.averageHeartRate }.max() ?? 1 // Assuming heart rate max is 200 bpm
        case .totalEnergyBurned:
            return filteredWorkouts.map { $0.totalEnergyBurned }.max() ?? 1
        case .percentInZone:
            return 100
        }
    }
    
    // Function to format the Y-axis value based on the metric
    private func formatYAxisValue(i: Int, metric: WorkoutMetric) -> String {
        let max = maxYValue(for: metric)
        let step = max / 5
        let value = step * Double(5 - i)
        return "\(Int(value))"
    }
    
    // Function to get the line and dot color for the selected metric
    private func lineColor(for metric: WorkoutMetric) -> Color {
        switch metric {
        case .duration:
            return .red
        case .averageHeartRate:
            return .orange
        case .totalEnergyBurned:
            return .indigo
        case .percentInZone:
            return .teal
        }
    }
}
