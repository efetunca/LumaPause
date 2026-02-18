import SwiftUI

struct WarningPopoverView: View {
    @ObservedObject var manager: TimerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dim başlıyor")
                .font(.headline)

            Text("\(manager.countdown) sn sonra")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            HStack(spacing: 8) {
                Button("Döngüyü atla") { manager.skipCycle() }
                Button("1 dk uzat") { manager.extendOneMinute() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
