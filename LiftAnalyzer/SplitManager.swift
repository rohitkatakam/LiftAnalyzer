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
    let duration: TimeInterval
    let totalEnergyBurned: Double
    let totalDistance: Double
    let averageHeartRate: Double
}



struct StoredSplit: Codable {
    var name: String
    var workouts: [StoredWorkout]
}

class SplitManager: ObservableObject {
    @Published var splits: [String: [StoredWorkout]] = [:] {
        didSet {
            saveSplits()
        }
    }
    
    init() {
        loadSplits()
    }

    private func saveSplits() {
        if let encoded = try? JSONEncoder().encode(splits) {
            UserDefaults.standard.set(encoded, forKey: "storedSplits")
        }
    }
    
    
    private func loadSplits() {
        if let storedSplitsData = UserDefaults.standard.data(forKey: "storedSplits"),
           let decodedSplits = try? JSONDecoder().decode([String: [StoredWorkout]].self, from: storedSplitsData) {
            self.splits = decodedSplits
        }
    }

    
    private func queryHealthKitForWorkout(healthStore: HKHealthStore, startDate: Date, uuidString: String, completion: @escaping (HKWorkout?) -> Void) {
        guard let uuid = UUID(uuidString: uuidString) else {
                completion(nil)
                return
            }

            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForSamples(withStart: startDate, end: startDate, options: .strictStartDate),
                HKQuery.predicateForObject(with: uuid)
            ])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            DispatchQueue.main.async {
                if let workouts = samples as? [HKWorkout], !workouts.isEmpty {
                    completion(workouts.first)
                } else {
                    completion(nil)
                }
            }
        }

        healthStore.execute(query)
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
        // Asynchronously fetch the average heart rate
        workoutDataManager.fetchAverageHeartRate(for: workout) { [weak self] averageHeartRate in
            guard let self = self else { return }

            // Create the StoredWorkout with the fetched heart rate
            let storedWorkout = StoredWorkout(
                startDate: workout.startDate,
                duration: workout.duration,
                totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                totalDistance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                averageHeartRate: averageHeartRate
            )

            // Update splits dictionary in a thread-safe way
            DispatchQueue.main.async {
                self.updateSplitsDictionary(storedWorkout: storedWorkout, newSplit: newSplit, workoutDataManager: workoutDataManager)
            }
        }
    }

    private func updateSplitsDictionary(storedWorkout: StoredWorkout, newSplit: String?, workoutDataManager: WorkoutDataManager) {
        // Remove the workout from its current split
        for (split, workoutArray) in splits {
            if let idx = workoutArray.firstIndex(where: { $0.startDate == storedWorkout.startDate }) {
                splits[split]?.remove(at: idx)
                break
            }
        }

        // Add the workout to the new split, if provided
        if let newSplit = newSplit {
            splits[newSplit, default: []].append(storedWorkout)
        }
        workoutDataManager.updateWorkoutSplits(from: self)
    }


}
