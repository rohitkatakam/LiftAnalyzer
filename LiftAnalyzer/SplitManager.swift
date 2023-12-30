//
//  SplitManager.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/19/23.
//

import SwiftUI
import HealthKit

struct StoredWorkout: Codable {
    let startDate: Date
}

struct StoredSplit: Codable {
    var name: String
    var workouts: [StoredWorkout]
}

class SplitManager: ObservableObject {
    @Published var splits: [String: [HKWorkout]] = [:] {
        didSet {
            saveSplits()
        }
    }
    @Published var workoutData: [WorkoutData] = []
    
    init() {
        loadSplits()
    }

    private func saveSplits() {
        let storedSplits = splits.map { (key, value) -> StoredSplit in
            let storedWorkouts = value.map { StoredWorkout(startDate: $0.startDate) }
            return StoredSplit(name: key, workouts: storedWorkouts)
        }

        if let encoded = try? JSONEncoder().encode(storedSplits) {
            UserDefaults.standard.set(encoded, forKey: "storedSplits")
        }
    }
    
    //THIS IS VERY INCORRECT!!!!
    
    private func loadSplits() {
        if let storedSplitsData = UserDefaults.standard.data(forKey: "storedSplits"),
           let storedSplits = try? JSONDecoder().decode([StoredSplit].self, from: storedSplitsData) {
            self.splits = Dictionary(uniqueKeysWithValues: storedSplits.map { ($0.name, $0.workouts.map { HKWorkout(activityType: .traditionalStrengthTraining, start: $0.startDate, end: $0.startDate) }) })
        }
    }
    
    // Function to add a new split with an empty workout array
    func addSplit(named name: String) {
        splits[name] = []
        //add WorkoutData env variable edits here!!!
    }
    func deleteSplit(named name : String) {
        //add WorkoutData env variable edits here!!!
        splits.removeValue(forKey: name)
    }
    
    func updateWorkoutSplit(workout: HKWorkout, newSplit: String?, workoutDataManager: WorkoutDataManager) {
        // Find and update the split in the workout data
        if let index = workoutDataManager.workouts.firstIndex(where: { $0.workout == workout }) {
            workoutDataManager.workouts[index].split = newSplit
        }

        // Update the splits dictionary
        updateSplitsDictionary(workout: workout, newSplit: newSplit)
    }
    
    private func updateSplitsDictionary(workout: HKWorkout, newSplit: String?) {
            // Remove workout from its current split
            for (split, _) in splits {
                if let idx = splits[split]?.firstIndex(of: workout) {
                    splits[split]?.remove(at: idx)
                    break
                }
            }

            // Add workout to the new split, if provided
            if let newSplit = newSplit {
                splits[newSplit, default: []].append(workout)
            }
        }
}
