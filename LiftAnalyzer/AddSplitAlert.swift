//
//  File.swift
//  LiftAnalyzer
//
//  Created by Rohit Katakam on 1/14/24.
//

import SwiftUI

struct AddSplitView: View {
    @ObservedObject var splitManager: SplitManager
    @State private var newSplitName = ""

    var body: some View {
        Form {
            TextField("Split Name", text: $newSplitName)
            Button("Add Split") {
                addSplit()
            }
        }
        .backgroundStyle(.gray)
    }
    
    private func addSplit() {
        if !newSplitName.isEmpty {
            splitManager.addSplit(named: newSplitName)
        }
    }
}
