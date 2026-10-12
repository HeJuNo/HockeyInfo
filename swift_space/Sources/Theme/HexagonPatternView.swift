import SwiftUI

struct HexagonPatternView: View {
    var body: some View {
        Canvas { context, size in
            let hexSize: CGFloat = 30
            let w = hexSize * 2
            let h = hexSize * sqrt(3)
            let cols = Int(size.width / (w * 0.75)) + 2
            let rows = Int(size.height / h) + 2
            for row in 0..<rows {
                for col in 0..<cols {
                    let offsetX = CGFloat(col) * w * 0.75
                    let offsetY = CGFloat(row) * h + (col % 2 == 1 ? h / 2 : 0)
                    let center = CGPoint(x: offsetX, y: offsetY)
                    var path = Path()
                    for i in 0..<6 {
                        let angle = CGFloat(i) * .pi / 3
                        let point = CGPoint(
                            x: center.x + hexSize * cos(angle),
                            y: center.y + hexSize * sin(angle)
                        )
                        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
