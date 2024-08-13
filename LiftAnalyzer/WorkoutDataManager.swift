//
//  WorkoutData.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/18/23.
//

import HealthKit
import Combine
import SwiftUI
import UserNotifications
import UIKit
import BackgroundTasks 

struct WorkoutData {
    var split : String?
    var workout : HKWorkout
}

extension WorkoutData {
    func toStoredWorkout(avgHeartRate: Double, pInZone: Double) -> StoredWorkout {
        return StoredWorkout(
            startDate: workout.startDate,
            duration: workout.duration,
            totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
            totalDistance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            averageHeartRate: avgHeartRate,
            percentInZone: pInZone
        )
    }
}

class WorkoutDataManager: ObservableObject {
    private var healthStore: HKHealthStore?
    private var splitManager: SplitManager?
    @Published var workouts: [WorkoutData] = []
    @Published var selectedWorkout: WorkoutData?

    private var lastFetchDate: Date?
    private var lastNotificationWorkoutID: UUID?
    private var cancellables = Set<AnyCancellable>()
    
    init(splitManager: SplitManager) {
        self.splitManager = splitManager
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            // Request authorization and fetch initial data
            requestAuthorization()
        }
        setupAppLifecycleObserver()
        requestNotificationAuthorization()
    }
    
    private func setupAppLifecycleObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.fetchWorkouts {
                    print("fetched workouts successfully")
                }
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
                self.fetchWorkouts {
                    print("requested success")
                }
            } else {
                // Handle errors
                print("Authorization failed with error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
        }
    }
        
    func sendNewWorkoutNotification(with workoutID: UUID) {
        guard lastNotificationWorkoutID != workoutID else {
                // Prevent sending a notification if it's for the same workout as the last one.
                return
            }
            
        lastNotificationWorkoutID = workoutID
        let content = UNMutableNotificationContent()
        content.title = "New Workout Recorded"
        content.body = "A new workout has been recorded. Check it out in the app!"
        content.sound = .default
        content.userInfo = ["workoutID": workoutID.uuidString]

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error {
                print("Error adding notification request: \(error)")
            }
        }
    }

    func handleNewWorkout() {
        // Fetch the most recent workout or handle the new workout detection
        if let mostRecentWorkout = workouts.first {
            sendNewWorkoutNotification(with: mostRecentWorkout.workout.uuid)
        }
    }


    func fetchWorkouts(completion: @escaping () -> Void) {
        let workoutPredicate: NSPredicate
            if let lastFetchDate = lastFetchDate {
                workoutPredicate = HKQuery.predicateForWorkouts(with: .greaterThanOrEqualTo, duration: 0)
            } else {
                workoutPredicate = HKQuery.predicateForWorkouts(with: .greaterThanOrEqualTo, duration: 0)
            }

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let fetchedWorkouts = samples as? [HKWorkout] {
                        self.workouts = fetchedWorkouts.map { WorkoutData(split: nil, workout: $0) }
                        if let splitManager = self.splitManager {
                            self.updateWorkoutSplits(from: splitManager)
                        }
                        self.handleNewWorkout()
                        self.lastFetchDate = Date()
                    }
                    completion()
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
    
    func startWorkoutObserver() {
        let workoutType = HKObjectType.workoutType()

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] (query, completionHandler, error) in
            if let error = error {
                print("Error in observer query: \(error.localizedDescription)")
                return
            }

            // Fetch the latest workouts
            self?.fetchWorkouts {
                // Handle new workout
                self?.handleNewWorkout()
            }

            // Call the completion handler
            completionHandler()
        }

        healthStore?.execute(query)

        // Enable background delivery for the workout type
        healthStore?.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { (success, error) in
            if success {
                print("Enabled background delivery for workouts")
            } else if let error = error {
                print("Failed to enable background delivery: \(error.localizedDescription)")
            }
        }
    }


    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
