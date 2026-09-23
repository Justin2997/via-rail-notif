import SwiftUI

struct HomeView: View {
    @Bindable var model: JourneyModel

    var body: some View {
        DashboardView(model: model)
            .sheet(isPresented: $model.showAlarmEditor) {
                AlarmEditor(model: model)
            }
    }
}

#Preview { HomeView(model: JourneyModel()) }
