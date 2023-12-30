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
    @Published var workouts: [WorkoutData] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
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
                }
            }
        }

        healthStore?.execute(query)
    }


    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
