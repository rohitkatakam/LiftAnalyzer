//
//  LiftView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/18/23.
//

import SwiftUI
import HealthKit
import UIKit

struct LiftView: View {
    @EnvironmentObject var splitManager: SplitManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @Binding var workoutData: WorkoutData
    @State private var showDropDown = false
    @State private var averageHeartRate: Double?
    @State private var heartRateTimeSeries: [Double] = []
    @State private var restingHeartRate: Double?
    @State private var maxHeartRate: Double?
    @State private var zoneUpperLimit: Double?
    @State private var zoneLowerLimit: Double?
    @State private var percentInZone: Double?
    @State private var isLoading = true
    @State private var loadingCounter = 4
    @State private var selectedDataPoint: (x: Double, y: Double)?
    @State private var isDragging = false
    @State private var showingPopover = false
    @State private var isPopupShown = false

    var body: some View {
        if isLoading {
            ProgressView("Fetching data...")
            .onAppear {
                fetchHeartRate()
                fetchRestingHeartRate()
                fetchMaxHeartRate()
                fetchHeartRateTimeSeries()
            }
        } else {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("\(headingFormatter.string(from: workoutData.workout.startDate))")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        
                        SplitInfoSquare(workoutData: $workoutData, showDropDown: $showDropDown, percentInZone: percentInZone ?? 0)
                        InfoSquare(title: "Duration", value: formatDuration(Int(workoutData.workout.duration.rounded())), color: .red)
                        InfoSquare(title: "Avg. Heart Rate", value: averageHeartRate != nil ? "\(Int(averageHeartRate!.rounded())) bpm" : "Fetching...", color: .orange)
                        InfoSquare(title: "Energy Burned", value: "\(Int(workoutData.workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()).rounded() ?? 0)) kcal", color: .indigo)
                        HStack {
                            InfoSquare(title: "Percent in Zone", value: percentInZone != nil ? "\(Int(percentInZone! * 100))%" : "Fetching...", color: .teal)
                            Button(action: {
                                let popupView = PopupView {
                                    VStack {
                                        Text("Heart Rate Zone")
                                            .font(.title)
                                            .fontWeight(.heavy)
                                            .foregroundColor(Color.primary)
                                        Text("A recommended sweet-spot of intensity for lifting weights: high enough that you exerting yourself, but low enough that your body will not burn excess nutrients that could be used to build muscle.")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
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
                            }
                        }
                        .padding(.top, 3)
                        //heart rate time series graph
                        if !heartRateTimeSeries.isEmpty {
                            HeartRateGraph(heartRateTimeSeries: heartRateTimeSeries, startDate: workoutData.workout.startDate, workoutDurationInSeconds: workoutData.workout.duration, upperZoneLimit: zoneUpperLimit ?? 0, lowerZoneLimit: zoneLowerLimit ?? 0)
                                .frame(height: 200)
                                .padding([.top, .bottom])
                        } else {
                            Text("Fetching heart rate data...")
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                    }
                    .padding([.leading, .trailing, .bottom])
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        
    }
    

    //function to fetch resting heart rate from HealthKit
    func fetchRestingHeartRate() {
        workoutDataManager.fetchRestingHeartRate { restingHeartRate in
            self.restingHeartRate = restingHeartRate
            self.calculateZoneLimits()
            self.calculatePercentInZone()
            loadingCounter -= 1
        if loadingCounter == 0 {
            isLoading = false
        }
        }
    }

    func fetchHeartRate() {
        workoutDataManager.fetchAverageHeartRate(for: workoutData.workout) { heartRate in
            self.averageHeartRate = heartRate
            loadingCounter -= 1
        if loadingCounter == 0 {
            isLoading = false
        }
        }
    }

    //function to fetch max heart rate from HealthKit
    func fetchMaxHeartRate() {
        workoutDataManager.fetchMaxHR { maxHeartRate in
            self.maxHeartRate = maxHeartRate
            self.calculateZoneLimits()
            self.calculatePercentInZone()
            loadingCounter -= 1
        if loadingCounter == 0 {
            isLoading = false
        }
        }
    }

    //function to fetch heart rate time series from HealthKit
    func fetchHeartRateTimeSeries() {
        workoutDataManager.fetchHeartRateTimeSeries(for: workoutData.workout) { heartRateTimeSeries in
            self.heartRateTimeSeries = heartRateTimeSeries
            self.calculateZoneLimits()
            loadingCounter -= 1
        if loadingCounter == 0 {
            isLoading = false
        }
        }
    }

    //function to calculate zone limits
    //zone is (maxhr - restinghr) * intensity + restinghr between intensity 0.5 and 0.7
    func calculateZoneLimits() {
        if let restingHeartRate = restingHeartRate, let maxHeartRate = maxHeartRate {
            let zoneUpperLimit = (maxHeartRate - restingHeartRate) * 0.7 + restingHeartRate
            let zoneLowerLimit = (maxHeartRate - restingHeartRate) * 0.5 + restingHeartRate
            self.zoneUpperLimit = zoneUpperLimit
            self.zoneLowerLimit = zoneLowerLimit
            self.calculatePercentInZone()
        }
    }

    func calculatePercentInZone() {
    if let zoneUpperLimit = zoneUpperLimit, let zoneLowerLimit = zoneLowerLimit {
        let totalSamples = heartRateTimeSeries.count
        let samplesInZone = heartRateTimeSeries.filter { $0 >= zoneLowerLimit && $0 <= zoneUpperLimit }.count
        let percentInZone = Double(samplesInZone) / Double(totalSamples)
        self.percentInZone = percentInZone
    }
}
}

class PopupViewController: UIViewController {
    let gestureView = UIView()
    let containerView = UIView()
    let contentView: UIView

    init(contentView: UIView) {
        self.contentView = contentView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(gestureView)
        gestureView.frame = view.bounds
        gestureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gestureView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(animateOut)))

        view.addSubview(containerView)
        containerView.frame = CGRect(x: 0, y: view.bounds.height, width: view.bounds.width, height: 200)

        containerView.addSubview(contentView)
        contentView.frame = containerView.bounds.inset(by: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.backgroundColor = .clear // Set the background color of contentView to be transparent

        configUI()
        animateIn()
    }

    func configUI() {
        // Configure your UI elements here
        containerView.layer.cornerRadius = 20 
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        containerView.backgroundColor = .gray
    }

    @objc func animateIn() {
        UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1, options: [.curveEaseInOut]) {
            self.containerView.center = self.view.center
        }
    }

    @objc func animateOut() {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.frame.origin.y = self.view.bounds.height
        }) { _ in
            self.dismiss(animated: false, completion: nil)
        }
    }
}

struct PopupView<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> PopupViewController {
        let contentView = UIHostingController(rootView: content).view!
        return PopupViewController(contentView: contentView)
    }

    func updateUIViewController(_ uiViewController: PopupViewController, context: Context) {
    }
}

class PopupHostingController<Content: View>: UIHostingController<Content>, UIAdaptivePresentationControllerDelegate {
    var onDismiss: (() -> Void)?

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        presentationController?.delegate = self
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss?()
    }
}

struct HeartRateGraph: View {
    var heartRateTimeSeries: [Double]
    @State private var selectedDataPoint: (x: Double, y: Double)?
    @State private var isDragging = false
    var startDate : Date
    var workoutDurationInSeconds: Double
    var upperZoneLimit: Double
    var lowerZoneLimit: Double

    var body: some View {
        GeometryReader { geometry in
            // Draw horizontal lines at the zone limits
            Rectangle()
                .strokeBorder(Color.gray, lineWidth: 1)
                .frame(height: 1)
                .offset(y: geometry.size.height * (1 - CGFloat(lowerZoneLimit / 200)))
            Rectangle()
                .strokeBorder(Color.gray, lineWidth: 1)
                .frame(height: 1)
                .offset(y: geometry.size.height * (1 - CGFloat(upperZoneLimit / 200)))

            ForEach(heartRateTimeSeries.indices, id: \.self) { index in
                let xPosition = geometry.size.width * CGFloat(index) / CGFloat(heartRateTimeSeries.count - 1)
                let yPosition = geometry.size.height * (1 - CGFloat(heartRateTimeSeries[index]) / 200)
                let pointColor = heartRateTimeSeries[index] >= lowerZoneLimit && heartRateTimeSeries[index] <= upperZoneLimit ? Color.green : Color.red
                let selectedPointColor = Color.yellow
                let isPointSelected = isDragging && selectedDataPoint != nil && Int(selectedDataPoint!.x / Double(geometry.size.width) * Double(heartRateTimeSeries.count)) == index

                Circle()
                    .fill(isPointSelected ? selectedPointColor : pointColor)
                    .frame(width: isPointSelected ? 8 : 2, height: isPointSelected ? 8 : 2)
                    .position(x: xPosition, y: yPosition)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let x = value.location.x
                    let index = Int(x / geometry.size.width * CGFloat(heartRateTimeSeries.count))
                    if index >= 0 && index < heartRateTimeSeries.count {
                        selectedDataPoint = (x: Double(x), y: round(heartRateTimeSeries[index]))
                        isDragging = true
                    }
                }
                .onEnded { _ in
                    isDragging = false
                }
                        )
            Text("Heartrate over Time")
            .position(x: geometry.size.width / 2, y: geometry.size.height)
            .foregroundStyle(.gray)
            .font(.title2)
            .fontWeight(.medium)
            if isDragging, let dataPoint = selectedDataPoint {
                Text("\(formatTime(x: dataPoint.x, totalWidth: geometry.size.width)): \(Int(dataPoint.y)) bpm")
                    .alignmentGuide(.leading) { d in d[.leading] }
                    .alignmentGuide(.bottom) { d in d[.bottom] }
                    .offset(x: 0, y: 0)
                    .font(.title2)
                    .fontWeight(.medium)
            }
        }
        .frame(height: 200)
    }
    func formatTime(x: Double, totalWidth: CGFloat) -> String {
    let totalSeconds = x / Double(totalWidth) * workoutDurationInSeconds
    let date = startDate.addingTimeInterval(totalSeconds)
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}
}

private struct SplitInfoSquare: View {
    @EnvironmentObject var splitManager: SplitManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @Binding var workoutData: WorkoutData
    @Binding var showDropDown: Bool
    var percentInZone: Double

    var body: some View {
        HStack {
            HStack {
                Text("Split")
                    .font(.body)
                    .fontWeight(.heavy)
                    .foregroundColor(.gray)
                Button(action: {
                    let popupView = PopupView {
                        Text("Change split")
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundColor(Color.primary)
                        ScrollView {
                            VStack {
                                ForEach(splitManager.splits.keys.sorted(), id: \.self) { split in
                                    Button(split) {
                                        updateSplit(split, pInZone: percentInZone)
                                    }
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.primary)
                                }
                                Button("Clear Split") {
                                    updateSplit(nil, pInZone: percentInZone)
                                }
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(Color.red)
                            }
                            .frame(maxWidth: .infinity) 
                        }
                        .frame(maxWidth: .infinity)
                    }
                    let popupViewController = PopupHostingController(rootView: popupView)
                    popupViewController.view.backgroundColor = .clear
                    popupViewController.modalPresentationStyle = .overCurrentContext
                    popupViewController.modalTransitionStyle = .crossDissolve
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                    let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(popupViewController, animated: true, completion: nil)
                    }
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
            Spacer()
            Text(workoutData.split ?? "NO SPLIT")
                .font(.body)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    private func updateSplit(_ newSplit: String?, pInZone: Double) {
        let workout = workoutData.workout
        splitManager.updateWorkoutSplit(workout: workout, newSplit: newSplit, pInZone: percentInZone, workoutDataManager: workoutDataManager)
        showDropDown = false
    }
}

private struct InfoSquare: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .fontWeight(.heavy)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .medium
    return formatter
}()

private let headingFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter
}()

func formatDuration(_ totalSeconds: Int) -> String {
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60

    var formattedString = ""
    if hours > 0 {
        formattedString += "\(hours) hour" + (hours > 1 ? "s" : "")
    }
    if minutes > 0 {
        if !formattedString.isEmpty {
            formattedString += " "
        }
        formattedString += "\(minutes) minute" + (minutes > 1 ? "s" : "")
    }
    return formattedString.isEmpty ? "0 minutes" : formattedString
}


// LiftView_Previews remains the same


struct LiftView_Previews: PreviewProvider {
    @State static var mockWorkoutData = WorkoutData(split: "Example Split", workout: HKWorkout(activityType: .running, start: Date(), end: Date()))

    static var previews: some View {
        LiftView(workoutData: $mockWorkoutData)
    }
}
