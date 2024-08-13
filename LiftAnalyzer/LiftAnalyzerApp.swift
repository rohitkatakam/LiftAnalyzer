//
//  LiftAnalyzerApp.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/14/23.
//

import SwiftUI

@main
struct LiftAnalyzerApp: App {
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    
    var splitManager = SplitManager()
    var workoutDataManager: WorkoutDataManager
    var popupManager = PopupManager()
    var settingsManager = SettingsManager()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        workoutDataManager = WorkoutDataManager(splitManager: splitManager)
        appDelegate.workoutDataManager = workoutDataManager
    }

    var body: some Scene {
        WindowGroup {
            HomepageView()
                .environmentObject(splitManager)
                .environmentObject(workoutDataManager)
                .environmentObject(popupManager)
                .environmentObject(settingsManager)
                .onAppear {
                    if !hasSeenTutorial {
                        showTutorialPopup()
                        hasSeenTutorial = true
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
        }
    }
    
    private func handleDeepLink(url: URL) {
        guard let workoutID = url.host else { return }
                if let workoutData = workoutDataManager.workouts.first(where: { $0.workout.uuid.uuidString == workoutID }) {
                    workoutDataManager.selectedWorkout = workoutData
                }
        }
    
    private func showTutorialPopup() {
        DispatchQueue.main.async {
            let popupView = PopupView {
                VStack {
                    Text("Getting Started")
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundColor(Color.primary)
                    Text(buildAttributedString())
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
        }
    }

    private func buildAttributedString() -> AttributedString {
        var attributedString = AttributedString("Start by pressing ")
        attributedString.font = .body
        
        var plus = AttributedString("+")
        plus.font = .body.bold()
        attributedString.append(plus)
        
        var nextTo = AttributedString(" next to ")
        nextTo.font = .body
        attributedString.append(nextTo)
        
        var splits = AttributedString("Splits ")
        splits.font = .body.bold()
        attributedString.append(splits)
        
        var instructions = AttributedString("to create a new workout split. When you record workouts on your Apple Watch, those workouts will show up below Recent Workouts and you can categorize those workouts based into the splits that you created. If you record workouts on your Watch and they don't show up here, go to ")
        instructions.font = .body
        attributedString.append(instructions)
        
        var settings = AttributedString("Settings -> Health -> Data Access & Devices -> LiftAnalyzer ")
        settings.font = .body.bold()
        attributedString.append(settings)
        
        var enableAll = AttributedString("and enable all.")
        enableAll.font = .body
        attributedString.append(enableAll)
        
        return attributedString
    }
}

