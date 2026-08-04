import SwiftUI
import Charts
import UIKit

enum ChartSelection: Equatable {
    case point(PricePoint)
    case range(PricePoint, PricePoint)
}

/// Interactive price chart, Apple Stocks style:
/// - one finger scrubs a single point (price + date lollipop)
/// - two fingers select a range and the header shows the delta between them
struct PriceChartView: View {
    let points: [PricePoint]
    @Binding var selection: ChartSelection?

    private var isUp: Bool {
        guard let first = points.first, let last = points.last else { return true }
        return last.price >= first.price
    }

    private var lineColor: Color { isUp ? .green : .red }

    private var yDomain: ClosedRange<Double> {
        let prices = points.map(\.price)
        guard let lo = prices.min(), let hi = prices.max(), hi > lo else { return 0...1 }
        let pad = (hi - lo) * 0.08
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("Price", p.price))
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                AreaMark(x: .value("Date", p.date), y: .value("Price", p.price))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.25), lineColor.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
            }

            if case .point(let sel) = selection {
                RuleMark(x: .value("Selected", sel.date))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Selected", sel.date), y: .value("Price", sel.price))
                    .foregroundStyle(lineColor)
                    .symbolSize(80)
            }

            if case .range(let a, let b) = selection {
                RectangleMark(
                    xStart: .value("Start", a.date),
                    xEnd: .value("End", b.date)
                )
                .foregroundStyle((b.price >= a.price ? Color.green : Color.red).opacity(0.12))
                RuleMark(x: .value("Start", a.date))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                RuleMark(x: .value("End", b.date))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Start", a.date), y: .value("Price", a.price))
                    .foregroundStyle(.secondary)
                    .symbolSize(60)
                PointMark(x: .value("End", b.date), y: .value("Price", b.price))
                    .foregroundStyle(lineColor)
                    .symbolSize(80)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                TouchCatcher(
                    onChange: { locations in handleTouches(locations, proxy: proxy, geo: geo) },
                    onEnd: { selection = nil }
                )
            }
        }
    }

    private func handleTouches(_ locations: [CGPoint], proxy: ChartProxy, geo: GeometryProxy) {
        guard !points.isEmpty, let plotAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotAnchor]
        let picked = locations.compactMap { loc -> PricePoint? in
            let x = loc.x - plotFrame.origin.x
            guard let date: Date = proxy.value(atX: x) else { return nil }
            return nearest(to: date)
        }
        let old = selection
        if picked.count >= 2 {
            let sorted = [picked[0], picked[1]].sorted { $0.date < $1.date }
            selection = .range(sorted[0], sorted[1])
        } else if let single = picked.first {
            selection = .point(single)
        }
        if old != selection {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func nearest(to date: Date) -> PricePoint? {
        points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
}

// MARK: - Multi-touch capture (SwiftUI gestures can't track two independent fingers)

private struct TouchCatcher: UIViewRepresentable {
    var onChange: ([CGPoint]) -> Void
    var onEnd: () -> Void

    func makeUIView(context: Context) -> TouchCatcherView {
        let view = TouchCatcherView()
        view.onChange = onChange
        view.onEnd = onEnd
        return view
    }

    func updateUIView(_ view: TouchCatcherView, context: Context) {
        view.onChange = onChange
        view.onEnd = onEnd
    }
}

final class TouchCatcherView: UIView {
    var onChange: (([CGPoint]) -> Void)?
    var onEnd: (() -> Void)?
    private var active = Set<UITouch>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        active.formUnion(touches)
        report()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        report()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        active.subtract(touches)
        finishIfIdle()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        active.subtract(touches)
        finishIfIdle()
    }

    private func finishIfIdle() {
        if active.isEmpty {
            onEnd?()
        } else {
            report()
        }
    }

    private func report() {
        let locations = active.map { $0.location(in: self) }.sorted { $0.x < $1.x }
        onChange?(Array(locations.prefix(2)))
    }
}
