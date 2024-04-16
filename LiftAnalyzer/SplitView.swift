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
    var splitName: String
    var workouts: [StoredWorkout]
    @State private var selectedStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    //@State private var selectedTimeframe = "one month"
    //private let timeframes = ["one week", "one month", "three months", "six months", "one year", "all time"]
    @State private var showingDeleteAlert = false
    
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
                    HStack(spacing: 2) {
                        Text("Showing averages since")
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
                    
                    if !workouts.isEmpty {
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
                    }
                    
                    Text("All Lifts")
                        .font(.title3)
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
                .padding([.leading, .trailing, .bottom])
                Spacer()
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

struct SplitView_Previews : PreviewProvider {
    static let mockStoredWorkout = StoredWorkout(
        startDate: Date(),
        duration: 3600, // For example, 1 hour
        totalEnergyBurned: 500, // Example value
        totalDistance: 1000, // Example value in meters
        averageHeartRate: 120, // Example average heart rate
        percentInZone: 0.5
    )
    
    static var previews: some View {
        SplitView(splitName: "Example", workouts: [mockStoredWorkout])
    }
}

