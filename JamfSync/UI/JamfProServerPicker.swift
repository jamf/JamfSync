//
//  Copyright 2025, Jamf
//

import SwiftUI

struct JamfProServerPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataPersistence: DataPersistence
    @ObservedObject var savableItems: SavableItems
    @State var items: [JamfProServerSelectionItem] = []
    @Binding var changesMade: Bool

    var body: some View {
        VStack {
            Text("Active Jamf Pro Servers")
                .font(.title)

            List($items) { $item in
                Toggle("\(item.selectionName)", isOn: $item.isActive)
                    .toggleStyle(.checkbox)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .padding([.top, .trailing])

                Button("OK") {
                    saveChanges()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding(.top)

                Spacer()
            }
        }
        .padding()
        .frame(width: 725, height: 400)
        .onAppear() {
            var jamfProInstances: [JamfProInstance] = []
            for saveableItem in savableItems.items {
                if let jamfProInstance = saveableItem as? JamfProInstance {
                    jamfProInstances.append(jamfProInstance)
                }
            }
            createSelectionItemsFromSavableItems(jamfProInstances: jamfProInstances)
        }
    }

    func createSelectionItemsFromSavableItems(jamfProInstances: [JamfProInstance]) {
        for jamfProInstance in jamfProInstances {
            items.append(JamfProServerSelectionItem(jamfProInstance: jamfProInstance))
        }
    }

    func saveChanges() {
        for item in items {
            if item.jamfProInstance.isActive != item.isActive {
                item.jamfProInstance.isActive = item.isActive
                dataPersistence.updateInCoreData(instance: item.jamfProInstance)
                changesMade = true
            }
        }
    }
}

struct JamfProServerPicker_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var dataPersistence = DataPersistence(dataManager: DataManager())
        let savableItems = DataModel().savableItems
        @State var changesMade: Bool = false

        SetupView(dataPersistence: dataPersistence, savableItems: savableItems, changesMade: $changesMade)
    }
}
