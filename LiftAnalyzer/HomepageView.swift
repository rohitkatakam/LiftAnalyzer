//
//  HomepageView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/14/23.
//

import SwiftUI
import HealthKit
import UIKit
import Combine

struct HomepageView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var splitManager: SplitManager
    @EnvironmentObject var popupManager: PopupManager
    @State private var showingAddSplitView = false
    @State private var newSplitName = ""
    
    private var itemHeight: CGFloat = 70 // Adjust this based on your button size
    
    var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading) {
                        HStack(spacing: 2) {
                            sectionHeader("Recent Lifts")
                            Button(action: {
                                let popupView = PopupView {
                                    VStack {
                                        Text("Getting Started")
                                            .font(.title)
                                            .fontWeight(.heavy)
                                            .foregroundColor(Color.primary)
                                        ScrollView{
                                            Text("Tap the plus button to add a split, tap on one of your recent workouts to edit the split for the workout and view stats for that lift. Tap on one of your created splits to view averages for that split. If no lifts are showing up, make sure you allow this app to access your health data in settings; also make sure you are recording \"Traditional Strength Training\" workouts on your Apple Watch.")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color.primary)
                                        }
                                        .cornerRadius(8)
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
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.gray)
                                    .padding(.top,8)
                            }
                        }

                        // Scrollable section for workouts
                        ScrollViewWrapper(itemCount: workoutDataManager.workouts.count) {
                            ForEach(workoutDataManager.workouts, id: \.workout.uuid) { workoutData in
                                NavigationLink(destination: LiftView(workoutData: Binding(
                                    get: { workoutData },
                                    set: { workoutDataManager.workouts[workoutDataManager.workouts.firstIndex(where: { $0.workout == workoutData.workout })!] = $0 }
                                ))) {
                                    WorkoutView(workoutData: workoutData)
                                }
                            }
                        }

                        HStack(spacing: 2) {
                            sectionHeader("Splits")
                            Button(action: {
                                let popupView = PopupView {
                                    VStack {
                                        Text("Add Split")
                                            .font(.title)
                                            .fontWeight(.heavy)
                                            .foregroundColor(Color.primary)
                                        TextField("Split Name", text: $newSplitName)
                                            .padding()
                                            .background(Color.gray)
                                            .foregroundStyle(Color.primary)
                                            .cornerRadius(8)
                                        Button("Add Split") {
                                            addSplit()
                                            popupManager.dismissPopup()
                                        }
                                        .bold()
                                        .foregroundColor(Color.primary)
                                        .padding()
                                        .background(Color.gray)
                                        .cornerRadius(8)
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
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.gray)
                                    .padding(.top,8)
                            }
                        }

                        // Scrollable section for splits
                        ScrollViewWrapper(itemCount: splitManager.splits.count) {
                            ForEach(splitManager.sortedSplitsByLastModifiedDate(), id: \.self) { splitName in
                                NavigationLink(destination: SplitView(splitName: splitName, workouts: splitManager.splits[splitName] ?? [])) {
                                    SplitHomeView(workoutData: splitName)
                                }
                            }
                        }
                    }
                    .padding([.horizontal, .vertical])
                }
            }
            .sheet(isPresented: $showingAddSplitView) {
                AddSplitView(splitManager: splitManager)
            }
        }

    private func addSplit() {
        if !newSplitName.isEmpty {
            splitManager.addSplit(named: newSplitName)
        }
        self.newSplitName = ""
    }
    
        private func calculateScrollViewHeight(_ itemCount: Int) -> CGFloat {
            let totalHeight = CGFloat(itemCount) * itemHeight
            return min(totalHeight, itemHeight * 3)
        }

        private var plusButton: some View {
            Button(action: {
                showingAddSplitView = true
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.blue)
            }
        }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.largeTitle)
            .fontWeight(.semibold)
            .multilineTextAlignment(.leading)
    }

}

struct ScrollViewWrapper<Content: View>: View {
    let content: Content
    let itemHeight: CGFloat = 70
    let itemCount: Int

    init(itemCount: Int, @ViewBuilder content: () -> Content) {
        self.itemCount = itemCount
        self.content = content()
    }

    var body: some View {
        VStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack { content }
            }
            .frame(height: calculateScrollViewHeight(itemCount))
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
    }

    private func calculateScrollViewHeight(_ itemCount: Int) -> CGFloat {
        let totalHeight = CGFloat(itemCount) * itemHeight
        return min(totalHeight, itemHeight * 3)
    }
}

// Define the WorkoutView and SplitView as separate Views
struct WorkoutView: View {
    let workoutData: WorkoutData

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .cornerRadius(10)

            HStack(spacing: 2) {
                Text("\(itemFormatter.string(from: workoutData.workout.startDate))-")
                    .bold()
                Text(workoutData.split ?? "NO SPLIT")
                    .bold()
                    .foregroundColor(workoutData.split == nil ? Color.red : Color.primary)
            }
            .padding(.vertical, 10)
            .foregroundColor(Color.primary) // Adapts to dark/light mode
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}

struct SplitHomeView: View {
    let workoutData: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .cornerRadius(10)

            Text(workoutData).bold()
            .foregroundColor(Color.primary)
            .padding(.vertical, 10)// Adapts to dark/light mode
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomepageView()
    }
}

