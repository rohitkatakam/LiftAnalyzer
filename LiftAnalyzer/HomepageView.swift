//
//  HomepageView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/14/23.
//

import SwiftUI

struct HomepageView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var splitManager: SplitManager
    @State private var showingAddSplitView = false
    
    private var itemHeight: CGFloat = 70 // Adjust this based on your button size
    
    var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading) {
                        sectionHeader("Recent Lifts")

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

                        HStack {
                            sectionHeader("Splits")
                            plusButton
                        }

                        // Scrollable section for splits
                        ScrollViewWrapper(itemCount: splitManager.splits.count) {
                            ForEach(Array(splitManager.splits.keys), id: \.self) { splitName in
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
                AddSplitView(isPresented: $showingAddSplitView, splitManager: splitManager)
            }
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

            HStack {
                Text("\(itemFormatter.string(from: workoutData.workout.startDate))")
                    .bold()
                Text(workoutData.split ?? "NO SPLIT")
                    .bold()
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
    formatter.dateFormat = "MMM d"
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomepageView()
    }
}

