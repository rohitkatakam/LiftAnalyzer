//
//  LiftView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/18/23.
//

import SwiftUI
import HealthKit
import UIKit
import Combine

let hasSeenLiftTutorialKey = "hasSeenLiftTutorial"

struct LiftView: View {
    @EnvironmentObject var splitManager: SplitManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var popupManager: PopupManager
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
                        HStack {
                            Text("\(headingFormatter.string(from: workoutData.workout.startDate))")
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                            Button(action: {
                                showLiftTutorialPopup()
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.gray)
                            }
                        }
                        
                        SplitInfoSquare(workoutData: $workoutData, showDropDown: $showDropDown, percentInZone: percentInZone ?? 0, averageHeartRate: averageHeartRate ?? 0)
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
                                        Text("A recommended sweet-spot of intensity for lifting weights: high enough that you exerting yourself, but low enough that your body will not burn excess nutrients that could be used to build muscle. Calculated using the Karvonen formula.")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color.primary)
                                        Spacer()
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
                            }
                        }
                        .padding([.top, .bottom], 3)
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
            .onAppear {
                checkAndShowLiftTutorialPopup()
            }
        }
    }
    
    private func checkAndShowLiftTutorialPopup() {
            if !UserDefaults.standard.bool(forKey: hasSeenLiftTutorialKey) {
                showLiftTutorialPopup()
                UserDefaults.standard.set(true, forKey: hasSeenLiftTutorialKey)
            }
    }
    
    private func showLiftTutorialPopup() {
            DispatchQueue.main.async {
                let popupView = PopupView {
                    VStack {
                        Text("Workout Page")
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundColor(Color.primary)
                        Text("Classify this workout into one of your splits by tapping the pencil button. If a prediction can be made from your past workout data, that prediction will be displayed with a green checkmark next to it: press that checkmark if the model correctly predicted your workout split.")
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
    var popupManager: PopupManager?
    private var cancellables: Set<AnyCancellable> = []

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
        gestureView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        gestureView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(animateOut)))
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(animateOut))
        swipeDown.direction = .down
        gestureView.addGestureRecognizer(swipeDown)

        view.addSubview(containerView)
        containerView.layer.cornerRadius = 20
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        containerView.backgroundColor = .gray
        contentView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.transform = CGAffineTransform(translationX: 0, y: containerView.bounds.height)

        containerView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10)
        ])

        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            containerView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            containerView.heightAnchor.constraint(lessThanOrEqualToConstant: 400) // Max height if needed
        ])


        animateIn()
        observePopupManager()
    }
    
    private func observePopupManager() {
        popupManager?.$showPopup
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] showPopup in
                if !showPopup {
                    self?.animateOut()
                }
            })
            .store(in: &cancellables)
    }

    func buttonPressed() {
        animateOut()
    }

    func configUI() {
        // Configure your UI elements here
        containerView.layer.cornerRadius = 20 
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        containerView.backgroundColor = .gray
        //this wone works for sure , but for fixed height
        //containerView.frame = CGRect(x: 0, y: view.bounds.height, width: view.bounds.width, height: 300)
    }

    @objc func animateIn() {
        self.view.layoutIfNeeded()  // Layout adjustments before animation

        // Start with containerView positioned just off the bottom of the screen
        containerView.transform = CGAffineTransform(translationX: 0, y: containerView.bounds.height)

        // Animate containerView to move up so its bottom edge is at the bottom of the screen
        UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 1, options: [.curveEaseInOut]) {
            self.containerView.transform = .identity  // Reset to original position, which aligns with screen bottom
            self.gestureView.alpha = 0.7
        }
    }


    
    @objc func animateOut() {
        UIView.animate(withDuration: 0.3, animations: {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.containerView.bounds.height)  // Move back below the screen
            self.gestureView.alpha = 0
        }) { _ in
            self.dismiss(animated: false, completion: nil)
        }
    }
}

struct PopupView<Content: View>: UIViewControllerRepresentable {
    let content: Content
    @EnvironmentObject var popupManager: PopupManager

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> PopupViewController {
        let contentView = UIHostingController(rootView: content).view!
        let viewController = PopupViewController(contentView: contentView)
        viewController.popupManager = popupManager
        return viewController
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
        .padding()
        .background(Color.gray.opacity(0.2).allowsHitTesting(false))
        .cornerRadius(10) 
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
    @EnvironmentObject var popupManager: PopupManager
    @Binding var workoutData: WorkoutData
    @Binding var showDropDown: Bool
    var percentInZone: Double
    var averageHeartRate: Double
    @State private var predicted = false
    @State private var guessSplit: String? = nil

    var body: some View {
        HStack {
            HStack {
                Text("Split")
                    .font(.body)
                    .fontWeight(.heavy)
                    .foregroundColor(.gray)
                Button(action: {
                    let popupView = PopupView {
                        HStack {
                            Text("Change split")
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundColor(Color.primary)
                            Button(action: {
                                updateSplit(nil, pInZone: percentInZone)
                                popupManager.dismissPopup()
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .imageScale(.large)
                                    .foregroundStyle(Color.red.opacity(0.8))
                                    .padding(.trailing)
                            }
                        }
                        ScrollView {
                            VStack {
                                ForEach(splitManager.sortedSplitsByLastModifiedDate(), id: \.self) { split in
                                    Button(action: {
                                        updateSplit(split, pInZone: percentInZone)
                                        popupManager.dismissPopup()
                                    }) {
                                        Text(split)
                                            .bold()
                                            .foregroundColor(Color.primary)
                                            .padding()
                                            .frame(maxWidth: .infinity)  // Apply maxWidth here within the button's content
                                            .background(Color.gray)      // Background applies to the Text and padding
                                    }
                                    .cornerRadius(15)  // Apply cornerRadius to the Button itself
                                    .frame(maxWidth: .infinity)  // Ensure Button frame fills the space
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .cornerRadius(15)
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
                }) 
                {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
            Spacer()
            if let split = workoutData.split, !split.isEmpty && split != "NO SPLIT" {
                HStack {
                    Text(split)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color.primary)  // Use predicted flag to determine text color
                    if predicted {
                        Button(action: {
                            updateSplit(guessSplit, pInZone: percentInZone)
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .imageScale(.large)
                        }
                    }
                }
            } else {
                Text("Predicting...")
                    .font(.body)
                    .fontWeight(.medium)
                    .onAppear {
                        splitManager.predictSplit(for: workoutData.toStoredWorkout(avgHeartRate: averageHeartRate, pInZone: percentInZone)) { predictedSplit in
                            DispatchQueue.main.async {
                                predicted = predictedSplit != nil  // Update predicted flag based on the prediction result
                                guessSplit = predictedSplit
                                workoutData.split = predictedSplit != nil ? "Prediction: \(predictedSplit ?? "")?" : "NO SPLIT"
                            }
                        }
                    }
                    .foregroundColor(predicted ? Color.red : Color.gray)  // Use predicted flag to determine text color
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    private func updateSplit(_ newSplit: String?, pInZone: Double) {
        let workout = workoutData.workout
        splitManager.updateWorkoutSplit(workout: workout, newSplit: newSplit, pInZone: percentInZone, workoutDataManager: workoutDataManager)
        showDropDown = false
        predicted = false
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
