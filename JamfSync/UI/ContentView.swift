//
//  Copyright 2024, Jamf
//

import SwiftUI
struct Position: Identifiable {
    let id: Int
    let name: String
}

struct ContentView: View {
    @ObservedObject var dataPersistence: DataPersistence
    @FetchRequest(sortDescriptors: []) private var savableItems: FetchedResults<SavableItemData>
    @State private var favoriteColor = 0
    @StateObject var dataModel = DataModel.shared
    @State var changesMade = false
    @State var canceled = false

    var body: some View {
        VStack {
            HeaderView(dataPersistence: dataPersistence, dataModel: dataModel)
                .padding([.leading, .trailing, .top])

            SourceDestinationView(dataModel: dataModel)
                .padding([.leading, .trailing])

            LogMessageView()
        }
        .toolbar {
            Button {
                dataModel.shouldPresentSetupSheet = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Setup")
            .sheet(isPresented: $dataModel.shouldPresentSetupSheet) {
                if changesMade {
                    dataModel.loadDps()
                }
            } content: {
                SetupView(dataPersistence: dataPersistence, savableItems: dataModel.savableItems, changesMade: $changesMade)
            }

            Button {
                dataModel.shouldPresentServerSelectionSheet = true
            } label: {
                Image(systemName: "server.rack")
            }
            .help("Choose active Jamf Pro instances")
            .sheet(isPresented: $dataModel.shouldPresentServerSelectionSheet) {
                if changesMade || dataModel.firstLoad {
                    dataModel.load(dataPersistence: dataPersistence)
                }
            } content: {
                JamfProServerPicker(dataPersistence: dataPersistence, savableItems: dataModel.savableItems, changesMade: $changesMade)
            }

            Button {
                dataModel.updateListViewModels(reload: .sourceAndDestination)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")

            Button("Show Log") {
                showLog()
            }
            .padding([.trailing])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear() {
            dataModel.load(dataPersistence: dataPersistence)
        }
        // Prompt for file share distribution point password
        .sheet(isPresented: $dataModel.shouldPromptForDpPassword) {
            if !canceled {
                dataModel.updateListViewModels()
            }
        } content: {
            FileSharePasswordView(fileShareDp: $dataModel.dpToPromptForPassword, canceled: $canceled)
        }
        // Prompt for Jamf Pro password
        .sheet(isPresented: $dataModel.shouldPromptForJamfProPassword) {
            if !canceled {
                Task {
                    dataModel.loadDps()
                }
            }
        } content: {
            JamfProPasswordView(jamfProInstances: $dataModel.jamfProServersToPromptForPassword, canceled: $canceled)
        }
    }

    func showLog() {
        LogView().openInNewWindow { window in
            window.title = "Activity and Error Log"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var dataPersistence = DataPersistence(dataManager: DataManager())

        ContentView(dataPersistence: dataPersistence)
    }
}
