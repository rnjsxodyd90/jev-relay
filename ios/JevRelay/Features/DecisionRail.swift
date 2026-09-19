import SwiftUI

struct DecisionRail: View {
    let result: InterpretResponse?
    private let steps = [("action", "Can this turn proceed?"), ("memory", "Does a complete phrase match?"), ("register", "Which form of address?"), ("sense", "Is the intended meaning resolved?")]

    var body: some View {
        PaperSurface {
            VStack(alignment: .leading, spacing: 0) {
                Text("Four decisions").font(.relay(.headline, weight: .semibold)).foregroundStyle(RelayStyle.slate).padding(.bottom, 4)
                Text("One connected inspection rail").font(.relay(.caption)).foregroundStyle(RelayStyle.muted).padding(.bottom, 14)
                ForEach(Array(steps.enumerated()), id: \.element.0) { index, step in
                    decisionRow(id: step.0, prompt: step.1, index: index)
                    if index < steps.count - 1 { Rectangle().fill(RelayStyle.rule).frame(width: 2, height: 16).padding(.leading, 13) }
                }
            }
        }
    }

    @ViewBuilder private func decisionRow(id: String, prompt: String, index: Int) -> some View {
        let decision = decision(for: id)
        DisclosureGroup {
            if let decision {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Distribution score \(decision.confidence, format: .number.precision(.fractionLength(2)))").font(.relay(.caption, weight: .semibold))
                    Text("This score describes the answer distribution. It is not calibrated accuracy or a chance of correctness.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted)
                    ForEach(decision.probabilities.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                        HStack { Text(key).lineLimit(1); Spacer(); Text(value, format: .percent.precision(.fractionLength(0))) }.font(.relay(.caption)).foregroundStyle(RelayStyle.muted)
                    }
                }.padding(.top, 9)
            } else { Text("Interpret a turn to inspect the typed decision detail.").font(.relay(.caption)).foregroundStyle(RelayStyle.muted).padding(.top, 8) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack { Circle().fill(decision == nil ? RelayStyle.rule : RelayStyle.indigo).frame(width: 28, height: 28); Text("\(index + 1)").font(.relay(.caption, weight: .bold)).foregroundStyle(decision == nil ? RelayStyle.slate : .white) }
                VStack(alignment: .leading, spacing: 2) { Text(prompt).font(.relay(.subheadline, weight: .semibold)).foregroundStyle(RelayStyle.slate); Text(decision?.choice ?? id.capitalized).font(.relay(.caption)).foregroundStyle(decision == nil ? RelayStyle.muted : RelayStyle.indigo) }
            }.frame(minHeight: 44)
        }.accessibilityIdentifier("decision_\(id)")
    }
    private func decision(for id: String) -> Decision? {
        guard let d = result?.decisions else { return nil }
        switch id { case "action": return d.action; case "memory": return d.memory; case "register": return d.register; default: return d.sense }
    }
}
