import SwiftUI

/// A compact row that shows the current note (or a placeholder) and opens a
/// popover with a full-sized TextEditor when tapped.
struct NoteButton: View {
    @Binding var note: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: note.isEmpty ? "note.text.badge.plus" : "note.text")
                    .font(.system(size: 11))
                    .foregroundStyle(note.isEmpty ? .tertiary : .secondary)
                Text(note.isEmpty ? "Add note…" : note)
                    .font(.system(size: 11))
                    .foregroundStyle(note.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if !note.isEmpty {
                    Button {
                        note = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            NoteEditorPopover(note: $note, isPresented: $isPresented)
        }
    }
}

private struct NoteEditorPopover: View {
    @Binding var note: String
    @Binding var isPresented: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Session note", systemImage: "note.text")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: $note)
                .font(.system(size: 13))
                .frame(minHeight: 90, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .focused($isFocused)
                .overlay(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("Describe what you worked on…")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 12)
                            .padding(.leading, 10)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                if !note.isEmpty {
                    Text("\(note.count) chars")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 280)
        .onAppear { isFocused = true }
    }
}
