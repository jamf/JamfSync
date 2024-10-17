//
//  Copyright 2024, Jamf
//

import SwiftUI

struct SynchronizeProgressView: View {
    @Environment(\.dismiss) var dismiss
    var srcDp: DistributionPoint?
    var dstDp: DistributionPoint
    var deleteFiles: Bool
    var deletePackages: Bool
    @StateObject var progress = SynchronizationProgress()
    @State var shouldPresentConfirmationSheet = false
    let synchronizeTask = SynchronizeTask()
    var processToExecute: (SynchronizeTask, Bool, Bool, SynchronizationProgress, SynchronizeProgressView)->Void = {_,_,_,_,_ in }

    // For CrappyButReliableAnimation
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State var leftOffset: CGFloat = -100
    @State var rightOffset: CGFloat = 100

    var body: some View {
        VStack {
            HStack {
                Text("\(srcDp?.selectionName() ?? "Local Files")")
                    .padding()

                BackAndForthAnimation(leftOffset: $leftOffset, rightOffset: $rightOffset)

                Text("\(dstDp.selectionName())")
                    .padding()
            }
            .onReceive(timer) { (_) in
                swap(&self.leftOffset,
                     &self.rightOffset)
            }

            if let currentFile = progress.currentFile, let fileProgress = progress.fileProgress()  {
                HStack {
                    if let operation = progress.operation {
                        Text("\(operation)")
                    }
                    Text("\(currentFile.name)")
                    ProgressView(value: fileProgress)
                }
                .padding([.leading, .trailing])
            }

            if let totalProgress = progress.totalProgress() {
                HStack {
                    Text("Overall Progress: ")
                    ProgressView(value: totalProgress)
                }
                .padding()
            }

            Button("Cancel") {
                shouldPresentConfirmationSheet = true
            }
            .padding(.bottom)
            .alert("Are you sure you want to cancel the syncrhonization?", isPresented: $shouldPresentConfirmationSheet) {
                HStack {
                    Button("Yes", role: .destructive) {
                        synchronizeTask.cancel()
                        shouldPresentConfirmationSheet = false
                    }
                    Button("No", role: .cancel) {
                        shouldPresentConfirmationSheet = false
                    }
                }
            }
        }
        .frame(minWidth: 600)
        .onAppear {
            processToExecute(synchronizeTask, deleteFiles, deletePackages, progress, self)
        }
    }
}

struct SynchronizeProgressView_Previews: PreviewProvider {
    static var previews: some View {
        let srcDp = DistributionPoint(name: "CasperShare")
        let dstDp = DistributionPoint(name: "MyTest")
        @StateObject var progress = SynchronizationProgress()

        SynchronizeProgressView(srcDp: srcDp, dstDp: dstDp, deleteFiles: false, deletePackages: false, progress: progress)
    }
}
