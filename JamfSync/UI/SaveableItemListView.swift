//
//  Copyright 2024, Jamf
//

import SwiftUI

struct SavableItemListView: View {
    @ObservedObject var savableItems: SavableItems
    @Binding var selectedSavableItemId: SavableItem.ID?
    @State private var sortOrder = [KeyPathComparator(\SavableItem.name), KeyPathComparator(\SavableItem.iconName), KeyPathComparator(\SavableItem.urlOrFolder)]
    let typeColumnSize = 35.0

    var body: some View {
        Table(savableItems.items, selection: $selectedSavableItemId, sortOrder: $sortOrder) {
            TableColumn("Type", value: \.iconName) { item in
                typeImage(savableItem: item)
                    .frame(width: typeColumnSize, alignment: .center)
            }
            .width(ideal: typeColumnSize)
            TableColumn("Name", value: \.name)
                .width(ideal: 150)
            TableColumn("URL or Folder", value: \.urlOrFolder) { item in
                Text(String(item.urlOrFolder))
            }
            .width(ideal: 300)
        }
        .onChange(of: sortOrder) {
            savableItems.items.sort(using: sortOrder)
        }
    }

    func typeImage(savableItem: SavableItem) -> Image {
        return Image(systemName: savableItem.iconName)
    }
}

struct SavableItemListView_Previews: PreviewProvider {
    static var previews: some View {
        @State var selectedItemId: SavableItem.ID?
        let savableItems = DataModel().savableItems
        SavableItemListView(savableItems: savableItems, selectedSavableItemId: $selectedItemId)
    }
}
