//
//  SplitManager.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/19/23.
//

import SwiftUI
import HealthKit
import CoreML

struct StoredWorkout: Codable {
    let startDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double
    let totalDistance: Double
    let averageHeartRate: Double
    let percentInZone: Double
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
    private var healthStore: HKHealthStore?
    private var classifierModel: SplitClassifier?
    
    init() {
        loadSplits()
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            // Request authorization and fetch initial data
        }
        self.classifierModel = try? SplitClassifier(configuration: .init())
//      printSplits()
//        predictSplit(for: splits["Sarms"]![0]) { predictedSplit in
//            print("Predicted Split: \(predictedSplit ?? "No prediction")")
//        }
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
    
    func updateWorkoutSplit(workout: HKWorkout, newSplit: String?, pInZone: Double, workoutDataManager: WorkoutDataManager) {
        // Asynchronously fetch the average heart rate
        workoutDataManager.fetchAverageHeartRate(for: workout) { [weak self] averageHeartRate in
            guard let self = self else { return }

            // Create the StoredWorkout with the fetched heart rate
            let storedWorkout = StoredWorkout(
                startDate: workout.startDate,
                duration: workout.duration,
                totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                totalDistance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                averageHeartRate: averageHeartRate,
                percentInZone: pInZone
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
    
    func sortedSplitsByLastModifiedDate() -> [String] {
        return splits.keys.sorted {
            guard let lastWorkoutDate1 = splits[$0]?.max(by: { $0.startDate < $1.startDate })?.startDate,
                  let lastWorkoutDate2 = splits[$1]?.max(by: { $0.startDate < $1.startDate })?.startDate else {
                return false
            }
            return lastWorkoutDate1 > lastWorkoutDate2
        }
    }
    
    func fetchHeartRateTimeSeries(for workout: StoredWorkout, completion: @escaping ([Double]) -> Void) {
            guard let healthStore = healthStore,
                  let startDate = Calendar.current.date(byAdding: .second, value: -Int(workout.duration), to: workout.startDate),
                  let endDate = Calendar.current.date(byAdding: .second, value: Int(workout.duration), to: workout.startDate),
                  let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                completion([])
                return
            }

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                DispatchQueue.main.async {
                    guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                        completion([])
                        return
                    }

                    let heartRates = samples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
                    completion(heartRates)
                }
            }

            healthStore.execute(query)
        }
//    
//    func printSplits() {
//            var csvString = "split,startDate,duration,totalEnergyBurned,totalDistance,averageHeartRate,percentInZone,minHR,maxHR,stdHR\n"
//            let group = DispatchGroup()
//
//            for split in splits {
//                for workout in split.value {
//                    group.enter()
//                    fetchHeartRateTimeSeries(for: workout) { heartRateTimeSeries in
//                        let dateString = ISO8601DateFormatter().string(from: workout.startDate)
//                        let minHR = heartRateTimeSeries.min() ?? 0
//                        let maxHR = heartRateTimeSeries.max() ?? 0
//                        let stdHR = heartRateTimeSeries.isEmpty ? 0 : sqrt(heartRateTimeSeries.reduce(0) { $0 + pow($1 - workout.averageHeartRate, 2) } / Double(heartRateTimeSeries.count))
//                        csvString += "\(split.key),\(dateString),\(workout.duration),\(workout.totalEnergyBurned),\(workout.totalDistance),\(workout.averageHeartRate),\(workout.percentInZone),\(minHR),\(maxHR),\(stdHR)\n"
//                        group.leave()
//                    }
//                }
//            }
//
//            group.notify(queue: .main) {
//                print(csvString)
//            }
//        }
    
    func predictSplit(for workout: StoredWorkout, completion: @escaping (String?) -> Void) {
        guard let classifierModel = classifierModel else {
            completion(nil)
            return
        }
        
        fetchHeartRateTimeSeries(for: workout) { heartRateTimeSeries in
            let minHR = heartRateTimeSeries.min() ?? 0
            let maxHR = heartRateTimeSeries.max() ?? 0
            let stdHR = heartRateTimeSeries.isEmpty ? 0 : sqrt(heartRateTimeSeries.reduce(0) { $0 + pow($1 - workout.averageHeartRate, 2) } / Double(heartRateTimeSeries.count))
            
            let input = SplitClassifierInput(
                duration: workout.duration,
                totalEnergyBurned: workout.totalEnergyBurned,
                averageHeartRate: workout.averageHeartRate,
                percentInZone: workout.percentInZone,
                minHR: minHR,
                maxHR: maxHR,
                stdHR: stdHR
            )
            
            if let prediction = try? classifierModel.prediction(input: input) {
                completion(prediction.split)
            } else {
                completion(nil)
            }
        }
    }
}
