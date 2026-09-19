import SwiftUI

enum RelayStyle {
    static let workspace = Color(red: 244/255, green: 247/255, blue: 251/255)
    static let paper = Color.white
    static let slate = Color(red: 23/255, green: 35/255, blue: 59/255)
    static let muted = Color(red: 98/255, green: 112/255, blue: 138/255)
    static let indigo = Color(red: 79/255, green: 95/255, blue: 215/255)
    static let rule = Color(red: 215/255, green: 222/255, blue: 234/255)
    static let success = Color(red: 35/255, green: 122/255, blue: 87/255)
    static let error = Color(red: 181/255, green: 68/255, blue: 68/255)
}

extension Font {
    static func relay(_ style: TextStyle, weight: Weight = .regular) -> Font { .custom("Avenir Next", size: baseSize(style), relativeTo: style).weight(weight) }
    private static func baseSize(_ style: TextStyle) -> CGFloat {
        switch style { case .largeTitle: return 34; case .title: return 28; case .title2: return 22; case .title3: return 20; case .headline: return 17; case .subheadline: return 15; case .caption: return 12; default: return 16 }
    }
}

struct PaperSurface<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { content.padding(20).background(RelayStyle.paper).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(RelayStyle.rule)) }
}

struct RelayButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.relay(.headline, weight: .semibold)).frame(minHeight: 44).padding(.horizontal, 16)
            .foregroundStyle(isEnabled ? (prominent ? Color.white : RelayStyle.slate) : RelayStyle.muted)
            .background(isEnabled && prominent ? RelayStyle.indigo.opacity(configuration.isPressed ? 0.8 : 1) : RelayStyle.paper)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isEnabled && prominent ? RelayStyle.indigo : RelayStyle.rule))
            .clipShape(RoundedRectangle(cornerRadius: 10)).opacity(isEnabled && configuration.isPressed ? 0.85 : 1)
    }
}
