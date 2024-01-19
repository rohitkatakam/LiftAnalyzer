//
//  File.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 1/14/24.
//

import SwiftUI

struct AddSplitView: View {
    @Binding var isPresented: Bool
    @ObservedObject var splitManager: SplitManager
    @State private var newSplitName = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Split Name", text: $newSplitName)
                Button("Add Split") {
                    addSplit()
                }
            }
            .navigationBarItems(leading: Button("Cancel") {
                self.isPresented = false
            })
        }
    }

    private func addSplit() {
        if !newSplitName.isEmpty {
            splitManager.addSplit(named: newSplitName)
            isPresented = false
        }
    }
}
