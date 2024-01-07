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
            }
            .store(in: &cancellables)
    }

    private func requestAuthorization() {
        // Define the health data types for read access
        let typesToRead: Set<HKObjectType> = [HKObjectType.workoutType()]

        healthStore?.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                self.fetchWorkouts()
            } else {
                // Handle errors
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
    
    func updateWorkoutSplits(from splitManager: SplitManager) {
        for (splitName, storedWorkouts) in splitManager.splits {
            for storedWorkout in storedWorkouts {
                if let index = workouts.firstIndex(where: { $0.workout.startDate == storedWorkout.startDate }) {
                    workouts[index].split = splitName
                }
            }
        }
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
