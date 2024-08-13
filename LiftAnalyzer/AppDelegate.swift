//
//  File.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 8/12/24.
//

import UIKit
import BackgroundTasks
import UserNotifications
import HealthKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var workoutDataManager: WorkoutDataManager?
    private var lastNotificationWorkoutID: UUID?
    private let healthStore = HKHealthStore()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "rohitkatakam.LiftAnalyzer.fetchWorkouts", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }

        // Request authorization and setup background fetch
        requestAuthorizationAndSetup()
        
        workoutDataManager?.startWorkoutObserver()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }

    private func requestAuthorizationAndSetup() {
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            if success {
                self?.scheduleAppRefresh()
            } else {
                print("Authorization failed with error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "rohitkatakam.LiftAnalyzer.fetchWorkouts")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // Fetch no earlier than 15 minutes from now

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule app refresh: \(error)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh() // Schedule the next background fetch

        // Fetch new workouts and send notifications
        workoutDataManager?.fetchWorkouts {
            task.setTaskCompleted(success: true)
        }

        // Expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let workoutID = response.notification.request.content.userInfo["workoutID"] as? String {
            openLiftView(with: workoutID)
        }
        completionHandler()
    }

    private func openLiftView(with workoutID: String) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let url = URL(string: "liftanalyzer://\(workoutID)")!
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification to verify that notifications are working."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error adding notification request: \(error)")
            } else {
                print("Test notification scheduled.")
            }
        }
    }
}
