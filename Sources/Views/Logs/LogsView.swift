import SwiftUI

public struct LogsView: View {
    @ObservedObject var store = StoreKitService.shared
    @Environment(\.presentationMode) var presentationMode

    public var body: some View {
        NavigationView {
            ZStack {
                Color.iappayBackground.edgesIgnoringSafeArea(.all)

                if store.logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "terminal")
                            .font(.system(size: 40))
                            .foregroundColor(.iappayTextMuted)
                        Text("Chưa có logs giao dịch")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.iappayTextSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(store.logs) { log in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("[\(log.formattedTime)]")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.iappayTextMuted)

                                        Text(log.tag)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(.iappayPurple)

                                        Spacer()

                                        Text(log.level)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.iappayGreen)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.iappayGreen.opacity(0.15))
                                            .cornerRadius(4)
                                    }

                                    Text(log.message)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.iappayTextPrimary)
                                }
                                .padding(10)
                                .background(Color.iappayCard)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.iappayBorder, lineWidth: 0.5))
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("StoreKit Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.accentBlue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let text = store.logs.map { "[\($0.formattedTime)] [\($0.tag)] \($0.message)" }.joined(separator: "\n")
                        UIPasteboard.general.string = text
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.iappayPurple)
                    }
                }
            }
        }
    }
}
