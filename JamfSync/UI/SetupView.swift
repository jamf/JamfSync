//
//  Copyright 2024, Jamf
//

import SwiftUI

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataPersistence: DataPersistence
    @ObservedObject var savableItems: SavableItems
    @StateObject var setupViewModel = SetupViewModel()
    @Binding var changesMade: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("Setup")
                .font(.title)

            HStack {
                SavableItemListView(savableItems: savableItems, selectedSavableItemId: $setupViewModel.selectedSavableItemId)
                    .padding([.top, .bottom, .trailing])

                VStack {
                    Spacer()

                    Button("Add Jamf Pro Server") {
                        setupViewModel.shouldPresentJamfProServerSheet = true
                    }
                    .sheet(isPresented: $setupViewModel.shouldPresentJamfProServerSheet) {
                        if !setupViewModel.canceled {
                            savableItems.addJamfProInstance(jamfProInstance: setupViewModel.jamfProInstance)

                            dataPersistence.saveJamfProInCoreData(instance: setupViewModel.jamfProInstance)
                            changesMade = true
                        }
                    } content: {
                        addJamfProView()
                    }
                    .padding(.bottom)

                    Button("Add File Folder") {
                        setupViewModel.shouldPresentFileFolderSheet = true
                    }
                    .sheet(isPresented: $setupViewModel.shouldPresentFileFolderSheet) {
                        if !setupViewModel.canceled {
                            savableItems.addFolderInstance(folderInstance: setupViewModel.folderInstance)
                            dataPersistence.saveFolderInCoreData(instance: setupViewModel.folderInstance)
                            changesMade = true
                        }
                    } content: {
                        addFolderView()
                    }
                    .padding(.bottom)

                    Button("Edit") {
                        setupViewModel.shouldPresentEditSheet = true
                    }
                    .disabled(setupViewModel.selectedSavableItemId == nil)
                    .sheet(isPresented: $setupViewModel.shouldPresentEditSheet) {
                        if !setupViewModel.canceled {
                            if savableItems.findSavableItem(id: setupViewModel.selectedSavableItemId) as? JamfProInstance != nil {
                                savableItems.updateSavableItem(item: setupViewModel.jamfProInstance)
                                dataPersistence.updateInCoreData(instance: setupViewModel.jamfProInstance)
                            } else {
                                savableItems.updateSavableItem(item: setupViewModel.folderInstance)
                                dataPersistence.updateInCoreData(instance: setupViewModel.folderInstance)
                           }
                            changesMade = true
                        }
                    } content: {
                        editView()
                    }
                    .padding(.bottom)

                    Button("Delete") {
                        setupViewModel.shouldPresentConfirmationSheet = true
                    }
                    .disabled(setupViewModel.selectedSavableItemId == nil)
                    .sheet(isPresented: $setupViewModel.shouldPresentConfirmationSheet) {
                        if !setupViewModel.canceled, let selectedSavableItemId = setupViewModel.selectedSavableItemId {
                            savableItems.deleteSavableItem(id: selectedSavableItemId)
                            dataPersistence.deleteCoreDataItem(id: selectedSavableItemId)
                            changesMade = true
                            setupViewModel.selectedSavableItemId = nil
                        }
                    } content: {
                        deleteView()
                    }

                    Spacer()
                }
            }

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
            }
        }
        .padding()
        .frame(width: 725, height: 400 )
    }

    func addJamfProView() -> some View {
        setupViewModel.jamfProInstance.copy(source: JamfProInstance())
        return JamfProServerView(jamfProInstance: $setupViewModel.jamfProInstance, canceled: $setupViewModel.canceled)
    }

    func addFolderView() -> some View {
        setupViewModel.folderInstance.copy(source: FolderInstance())
        return FolderView(folderInstance: $setupViewModel.folderInstance, canceled: $setupViewModel.canceled)
    }

    func editView() -> some View {
        if let srcJamfProInstance = savableItems.findSavableItem(id: setupViewModel.selectedSavableItemId) as? JamfProInstance {
            setupViewModel.jamfProInstance.copy(source: srcJamfProInstance)
            return AnyView(JamfProServerView(jamfProInstance: $setupViewModel.jamfProInstance, canceled: $setupViewModel.canceled))
        } else if let srcFolderInstance = savableItems.findSavableItem(id: setupViewModel.selectedSavableItemId) as? FolderInstance {
            setupViewModel.folderInstance.copy(source: srcFolderInstance)
            return AnyView(FolderView(folderInstance: $setupViewModel.folderInstance, canceled: $setupViewModel.canceled))
        }
        return AnyView(ConfirmationView(promptMessage: "The item was of an unknown type", includeCancelButton: false, canceled: $setupViewModel.canceled))
    }

    func deleteView() -> some View {
        if let item = savableItems.findSavableItem(id: setupViewModel.selectedSavableItemId) {
            return ConfirmationView(promptMessage: "Are you sure you want to delete \(item.name)?", includeCancelButton: true, canceled: $setupViewModel.canceled)
        } else {
            return ConfirmationView(promptMessage: "Couldn't find the item", includeCancelButton: false, canceled: $setupViewModel.canceled)
        }
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var dataPersistence = DataPersistence(dataManager: DataManager())
        let savableItems = DataModel().savableItems
        @State var changesMade: Bool = false

        SetupView(dataPersistence: dataPersistence, savableItems: savableItems, changesMade: $changesMade)
    }
}
