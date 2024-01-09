//
//  SplitListView.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 12/19/23.
//

import SwiftUI
import HealthKit

struct SplitListView: View {
    @EnvironmentObject var splitManager: SplitManager
    @State private var showingAddSplitSheet = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Splits")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding([.leading])
            List {
                ForEach(Array(splitManager.splits.keys), id: \.self) { split in
                    NavigationLink(destination: SplitView(splitName: split, workouts: splitManager.splits[split] ?? [])) {
                        Text(split)
                    }
                }
            }
            .navigationBarItems(trailing: Button(action: {
                self.showingAddSplitSheet = true
            }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showingAddSplitSheet) {
                AddSplitView(isPresented: self.$showingAddSplitSheet, splitManager: self.splitManager)
            }
        }
    }
}


struct SplitListView_Previews: PreviewProvider {
    static var previews: some View {
        SplitListView().environmentObject(SplitManager())
    }
}

