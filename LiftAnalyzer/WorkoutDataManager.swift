//
//  WorkoutData.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/18/23.
//

import HealthKit
import Combine
import SwiftUI

struct WorkoutData {
    var split : String?
    var workout : HKWorkout
}

class WorkoutDataManager: ObservableObject {
    private var healthStore: HKHealthStore?
    private var splitManager: SplitManager?
    @Published var workouts: [WorkoutData] = []
    @Published var currentWorkout: WorkoutData?
    private var cancellables = Set<AnyCancellable>()
    
    init(splitManager: SplitManager) {
        self.splitManager = splitManager
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            // Request authorization and fetch initial data
            requestAuthorization()
        }
        setupAppLifecycleObserver()
    }
    
    private func setupAppLifecycleObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.fetchWorkouts()
                self?.startObservingLiveWorkouts()
            }
            .store(in: &cancellables)
    }

    private func requestAuthorization() {
        // Define the health data types for read access
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            // Handle the error if the heart rate type is not available
            return
        }

        let typesToRead: Set<HKObjectType> = [HKObjectType.workoutType(), heartRateType, HKObjectType.quantityType(forIdentifier: .restingHeartRate)!, HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!]

        healthStore?.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                self.fetchWorkouts()
            } else {
                // Handle errors
                print("Authorization failed with error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }


    private func fetchWorkouts() {
        // Replace 'functionalStrengthTraining' with the appropriate type if available
        let workoutPredicate = HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining)

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let fetchedWorkouts = samples as? [HKWorkout] {
                    self.workouts = fetchedWorkouts.map { WorkoutData(split: nil, workout: $0) }
                    if let splitManager = self.splitManager {
                        self.updateWorkoutSplits(from: splitManager)
                    }
                }
            }
        }

        healthStore?.execute(query)
    }

    func fetchAverageHeartRate(for workout: HKWorkout, completion: @escaping (Double) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(0)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, _ in
            DispatchQueue.main.async {
                let averageHeartRate = statistics?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
                completion(averageHeartRate)
            }
        }

        healthStore?.execute(query)
    }

    //function to fetch resting heart rate from HealthKit
    func fetchRestingHeartRate(completion: @escaping (Double) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(0)
            return
        }

        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: nil, options: .discreteAverage) { _, statistics, _ in
            DispatchQueue.main.async {
                let restingHeartRate = statistics?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 72
                completion(restingHeartRate)
            }
        }

        healthStore?.execute(query)
    }

    //function to access date of birth, then calculate age, then calculate max heart rate using age
    func fetchMaxHR(completion: @escaping (Double) -> Void) {
    if let healthStore = healthStore {
        let dateOfBirthComponents = try! healthStore.dateOfBirthComponents()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let age = currentYear - dateOfBirthComponents.year!
        let maxHeartRate = 220 - Double(age)
        completion(maxHeartRate)
    }
}

    //function to fetch heart rate time series from HealthKit
    func fetchHeartRateTimeSeries(for workout: HKWorkout, completion: @escaping ([Double]) -> Void) {
    guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
        completion([])
        return
    }

    let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
    let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, samples, error) in
        DispatchQueue.main.async {
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                completion([])
                return
            }

            let heartRates = samples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
            completion(heartRates)
        }
    }

    healthStore?.execute(query)
}

    
    func updateWorkoutSplits(from splitManager: SplitManager) {
        for (splitName, storedWorkouts) in splitManager.splits {
            for storedWorkout in storedWorkouts {
                if let index = workouts.firstIndex(where: { $0.workout.startDate == storedWorkout.startDate }) {
                    workouts[index].split = splitName
                }
            }
        }
    }
    
    func startObservingLiveWorkouts() {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(type: workoutType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) {
            [weak self] (query, addedSamples, deletedSamples, newAnchor, error) in

            guard let self = self, error == nil else {
                print("Failed to fetch workouts: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let workouts = addedSamples as? [HKWorkout], !workouts.isEmpty {
                DispatchQueue.main.async {
                    self.currentWorkout = workouts.map { WorkoutData(split: nil, workout: $0) }.first
                }
            }
        }

        query.updateHandler = { [weak self] (query, addedSamples, deletedSamples, newAnchor, error) in
            guard let self = self, error == nil else {
                print("Failed to update workouts: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let workouts = addedSamples as? [HKWorkout], !workouts.isEmpty {
                DispatchQueue.main.async {
                    self.currentWorkout = workouts.map { WorkoutData(split: nil, workout: $0) }.first
                }
            }
        }

        healthStore?.execute(query)
    }


    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
