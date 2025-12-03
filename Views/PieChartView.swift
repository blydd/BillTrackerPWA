import SwiftUI

/// 饼图视图
struct PieChartView: View {
    let data: [(String, Decimal, Color)]
    let total: Decimal
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2 * 0.8
            
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    PieSliceView(
                        startAngle: slice.startAngle,
                        endAngle: slice.endAngle,
                        color: slice.color
                    )
                    .frame(width: size, height: size)
                    .position(center)
                    
                    // 显示金额标签
                    if slice.percentage > 0.05 { // 只显示占比大于5%的标签
                        Text(formatAmount(slice.value))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .position(labelPosition(for: slice, center: center, radius: radius * 0.7))
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var slices: [(name: String, value: Decimal, color: Color, startAngle: Angle, endAngle: Angle, percentage: Double)] {
        var currentAngle: Double = -90 // 从顶部开始
        var result: [(String, Decimal, Color, Angle, Angle, Double)] = []
        
        for item in data {
            let percentage = Double(truncating: item.1 as NSDecimalNumber) / Double(truncating: total as NSDecimalNumber)
            let angle = percentage * 360
            let startAngle = Angle(degrees: currentAngle)
            let endAngle = Angle(degrees: currentAngle + angle)
            
            result.append((item.0, item.1, item.2, startAngle, endAngle, percentage))
            currentAngle += angle
        }
        
        return result
    }
    
    private func labelPosition(for slice: (name: String, value: Decimal, color: Color, startAngle: Angle, endAngle: Angle, percentage: Double), center: CGPoint, radius: CGFloat) -> CGPoint {
        let midAngle = (slice.startAngle.degrees + slice.endAngle.degrees) / 2
        let radians = midAngle * .pi / 180
        
        return CGPoint(
            x: center.x + radius * CGFloat(cos(radians)),
            y: center.y + radius * CGFloat(sin(radians))
        )
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "¥\(formatter.string(from: amount as NSDecimalNumber) ?? "0")"
    }
}

/// 饼图切片视图
struct PieSliceView: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}
