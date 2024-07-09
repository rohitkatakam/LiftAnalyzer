//
//  SplitManager.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/19/23.
//

import SwiftUI
import HealthKit
import CoreML
import Foundation
import TabularData
import CreateML

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
        self.classifierModel = loadTrainedClassifier()
//      printSplits()
//        predictSplit(for: splits["Sarms"]![0]) { predictedSplit in
//            print("Predicted Split: \(predictedSplit ?? "No prediction")")
//        }
//        trainClassifier()
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
            updateTrainingData(with: storedWorkout, for: newSplit)
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
//    func printSplits(completion: @escaping (String) -> Void) {
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
    
    private func updateTrainingData(with workout: StoredWorkout, for split: String) {
        fetchHeartRateTimeSeries(for: workout) { heartRateTimeSeries in
            // Calculate heart rate metrics
            let minHR = heartRateTimeSeries.min() ?? 0
            let maxHR = heartRateTimeSeries.max() ?? 0
            let stdHR = heartRateTimeSeries.isEmpty ? 0 : sqrt(heartRateTimeSeries.reduce(0) { $0 + pow($1 - workout.averageHeartRate, 2) } / Double(heartRateTimeSeries.count))
            
            // Convert to CSV format
            let dateString = ISO8601DateFormatter().string(from: workout.startDate)
            let csvLine = "\(split),\(dateString),\(workout.duration),\(workout.totalEnergyBurned),\(workout.totalDistance),\(workout.averageHeartRate),\(workout.percentInZone),\(minHR),\(maxHR),\(stdHR)\n"
            
            // Append to CSV file
            self.appendToCSVFile(csvLine)
        }
    }
    
    private func appendToCSVFile(_ csvLine: String) {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing the document directory.")
            return
        }
        let trainingDataURL = documentDirectory.appendingPathComponent("Training.csv")

        // Check if the file exists
        if !fileManager.fileExists(atPath: trainingDataURL.path) {
            // Create the file with headers if it doesn't exist
            do {
                let headers = "split,startDate,duration,totalEnergyBurned,totalDistance,averageHeartRate,percentInZone,minHR,maxHR,stdHR\n"
                try headers.write(to: trainingDataURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error creating Training.csv file: \(error)")
                return
            }
        }

        // Read the existing CSV content
        var csvContent = ""
        do {
            csvContent = try String(contentsOf: trainingDataURL, encoding: .utf8)
        } catch {
            print("Error reading Training.csv file: \(error)")
            return
        }
        // Remove the existing line for the workout, if present
        var updatedContent = csvContent.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.contains(csvLine.components(separatedBy: ",")[1]) }
            .joined(separator: "\n")

        // Append the new line to the file
        updatedContent.append("\n\(csvLine)")
        // Write the updated CSV content back to the file
        do {
            try updatedContent.write(to: trainingDataURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing to Training.csv file: \(error)")
            return
        }
        trainClassifier(trainingDataURL: trainingDataURL)
        trainAndSaveRegressors(trainingDataURL: trainingDataURL)
    }
    
    private func trainClassifier(trainingDataURL: URL) {
        do {
            let dataTable = try MLDataTable(contentsOf: trainingDataURL)
            let columns = ["split", "duration", "totalEnergyBurned", "averageHeartRate", "percentInZone", "minHR", "maxHR", "stdHR"]
            let filteredTable = dataTable[columns]
            let randomForest = try MLRandomForestClassifier(trainingData: filteredTable, targetColumn: "split")
            
            saveTrainedClassifier(randomForest)
        } catch {
            print("Error training classifier")
        }
    }
    
    private func saveTrainedClassifier(_ classifier: MLRandomForestClassifier) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing the documents directory.")
            return
        }

        let modelURL = documentsDirectory.appendingPathComponent("SplitClassifier.mlmodel")

        do {
            try classifier.write(to: modelURL)
            print("Classifier saved successfully at: \(modelURL)")

            // Perform compilation asynchronously
            DispatchQueue.global().async {
                do {
                    let compiledURL = try MLModel.compileModel(at: modelURL)
                    print("Model compiled successfully at URL: \(compiledURL)")

                    // Destination URL for compiled model
                    let compiledDestinationURL = documentsDirectory.appendingPathComponent("SplitClassifier.mlmodelc")

                    // Check if file already exists
                    if FileManager.default.fileExists(atPath: compiledDestinationURL.path) {
                        // If file exists, remove it before copying
                        try FileManager.default.removeItem(at: compiledDestinationURL)
                    }

                    // Copy compiled model to destination
                    try FileManager.default.copyItem(at: compiledURL, to: compiledDestinationURL)
                    print("Compiled model copied to: \(compiledDestinationURL)")

                    // Initialize classifier with the compiled model URL on the main thread
                    DispatchQueue.main.async {
                        self.classifierModel = try? SplitClassifier(contentsOf: compiledDestinationURL)
                    }
                } catch {
                    print("Error saving or compiling classifier: \(error)")
                }
            }
        } catch {
            print("Error saving classifier: \(error)")
        }
    }
    
    private func loadTrainedClassifier() -> SplitClassifier? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing the documents directory.")
            return nil
        }

        let modelURL = documentsDirectory.appendingPathComponent("SplitClassifier.mlmodelc")

        do {
            let classifier = try SplitClassifier(contentsOf: modelURL)
            print("Classifier loaded successfully from: \(modelURL)")
            return classifier
        } catch {
            print("Error loading classifier: \(error)")
            return nil
        }
    }
    
    private func trainAndSaveRegressors(trainingDataURL: URL) {
        do {
            let dataTable = try MLDataTable(contentsOf: trainingDataURL)
            let inputColumns = ["split"]
            let targetColumns = ["duration", "totalEnergyBurned", "averageHeartRate", "percentInZone", "minHR", "maxHR", "stdHR"]

            for targetColumn in targetColumns {
                let filteredTable = dataTable[inputColumns + [targetColumn]]
                let randomForest = try MLRandomForestRegressor(trainingData: filteredTable, targetColumn: targetColumn)

                saveTrainedRegressor(randomForest, for: targetColumn)
            }
        } catch {
            print("Error training regressors: \(error)")
        }
    }

    private func saveTrainedRegressor(_ regressor: MLRandomForestRegressor, for targetColumn: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing the documents directory.")
            return
        }

        let modelURL = documentsDirectory.appendingPathComponent("\(targetColumn)Regressor.mlmodel")

        do {
            try regressor.write(to: modelURL)
            print("Regressor saved successfully at: \(modelURL)")

            // Perform compilation asynchronously
            DispatchQueue.global().async {
                do {
                    let compiledURL = try MLModel.compileModel(at: modelURL)
                    print("Model compiled successfully at URL: \(compiledURL)")

                    // Destination URL for compiled model
                    let compiledDestinationURL = documentsDirectory.appendingPathComponent("\(targetColumn)Regressor.mlmodelc")

                    // Check if file already exists
                    if FileManager.default.fileExists(atPath: compiledDestinationURL.path) {
                        // If file exists, remove it before copying
                        try FileManager.default.removeItem(at: compiledDestinationURL)
                    }

                    // Copy compiled model to destination
                    try FileManager.default.copyItem(at: compiledURL, to: compiledDestinationURL)
                    print("Compiled model copied to: \(compiledDestinationURL)")
                } catch {
                    print("Error saving or compiling regressor: \(error)")
                }
            }
        } catch {
            print("Error saving regressor: \(error)")
        }
    }
    
    private func loadTrainedRegressor(for targetColumn: String) -> MLModel? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing the documents directory.")
            return nil
        }

        let modelURL = documentsDirectory.appendingPathComponent("\(targetColumn)Regressor.mlmodelc")

        do {
            let regressor = try MLModel(contentsOf: modelURL)
            print("Regressor loaded successfully from: \(modelURL)")
            return regressor
        } catch {
            print("Error loading regressor: \(error)")
            return nil
        }
    }
    
    func predictStats(for split: String, completion: @escaping ([String: Double]) -> Void) {
        let targetColumns = ["duration", "totalEnergyBurned", "averageHeartRate", "percentInZone", "minHR", "maxHR", "stdHR"]
        var predictions: [String: Double] = [:]

        let group = DispatchGroup()

        for targetColumn in targetColumns {
            group.enter()

            DispatchQueue.global().async {
                if let regressor = self.loadTrainedRegressor(for: targetColumn) {
                    do {
                        let input = try MLDictionaryFeatureProvider(dictionary: ["split": split])
                        let prediction = try regressor.prediction(from: input)
                        if let predictedValue = prediction.featureValue(for: targetColumn)?.doubleValue {
                            predictions[targetColumn] = predictedValue
                        }
                    } catch {
                        print("Error predicting \(targetColumn): \(error)")
                    }
                }

                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(predictions)
        }
    }
}
