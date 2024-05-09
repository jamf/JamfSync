//
//  Copyright 2024, Jamf
//

import SwiftUI

struct SourceDestinationView: View {
    @StateObject var dataModel = DataModel.shared

    var body: some View {
        VStack {
            HStack { // Source and destination fields
                Picker("Source:", selection: $dataModel.selectedSrcDpId) {
                    ForEach($dataModel.dpsForSource) {
                        Text("\($0.wrappedValue.selectionName())").tag($0.id.wrappedValue)
                    }
                }
                .onChange(of: dataModel.selectedSrcDpId) {
                    dataModel.updateListViewModels()
                }
                .padding([.top])

                Button {
                    swap(&dataModel.selectedSrcDpId, &dataModel.selectedDstDpId)
                    dataModel.verifySelectedItemsStillExist()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .padding([.top, .leading, .trailing])

                Picker("Destination:", selection: $dataModel.selectedDstDpId) {
                    ForEach($dataModel.dpsForDestination) {
                        Text("\($0.wrappedValue.selectionName())").tag($0.id.wrappedValue)
                    }
                }
                .onChange(of: dataModel.selectedDstDpId) {
                    dataModel.updateListViewModels()
                }
                .padding([.top])
            }

            ZStack {
                HStack {
                    PackageListView(isSrc: true, dataModel: dataModel, packageListViewModel: dataModel.srcPackageListViewModel)
                        .padding(.trailing, 3)

                    PackageListView(isSrc: false, dataModel: dataModel, packageListViewModel: dataModel.dstPackageListViewModel)
                        .padding(.leading, 3)
                }
                if dataModel.showSpinner {
                    ProgressView()
                        .frame(width: 100, height: 100)
                }
            }
            .padding([.top])
        }
    }
}

struct SourceDestinationView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var dataModel = DataModel()
        SourceDestinationView(dataModel: dataModel)
    }
}
