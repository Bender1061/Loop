//
//  Chart.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation

import CarbKit
import GlucoseKit
import HealthKit
import InsulinKit
import LoopKit
import SwiftCharts


final class StatusChartsManager {

    // MARK: - Configuration

    private lazy var chartSettings: ChartSettings = {
        let chartSettings = ChartSettings()
        chartSettings.top = 12
        chartSettings.bottom = 0
        chartSettings.trailing = 8
        chartSettings.axisTitleLabelsToLabelsSpacing = 0
        chartSettings.labelsToAxisSpacingX = 6
        chartSettings.labelsWidthY = 30

        return chartSettings
    }()

    private lazy var dateFormatter: DateFormatter = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        return timeFormatter
    }()

    private lazy var decimalFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2

        return numberFormatter
    }()

    private lazy var integerFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.maximumFractionDigits = 0

        return numberFormatter
    }()

    private lazy var axisLineColor = UIColor.clear

    private lazy var axisLabelSettings: ChartLabelSettings = ChartLabelSettings(font: UIFont.preferredFont(forTextStyle: UIFontTextStyle.caption1), fontColor: UIColor.secondaryLabelColor)

    private lazy var guideLinesLayerSettings: ChartGuideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: UIColor.gridColor)

    var panGestureRecognizer: UIPanGestureRecognizer?

    // MARK: - Data

    var startDate = Date()

    var glucoseUnit: HKUnit = HKUnit.milligramsPerDeciliterUnit()

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    var glucoseValues: [GlucoseValue] = [] {
        didSet {
            let unitString = glucoseUnit.glucoseUnitDisplayString

            glucosePoints = glucoseValues.map {
                return ChartPoint(
                    x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                    y: ChartAxisValueDoubleUnit($0.quantity.doubleValue(for: glucoseUnit), unitString: unitString)
                )
            }
        }
    }

    var glucoseDisplayRange: (min: HKQuantity, max: HKQuantity)? {
        didSet {
            if let range = glucoseDisplayRange {
                glucoseDisplayRangePoints = [
                    ChartPoint(x: ChartAxisValue(scalar: 0), y: ChartAxisValueDouble(range.min.doubleValue(for: glucoseUnit))),
                    ChartPoint(x: ChartAxisValue(scalar: 0), y: ChartAxisValueDouble(range.max.doubleValue(for: glucoseUnit)))
                ]
            } else {
                glucoseDisplayRangePoints = []
            }
        }
    }

    var predictedGlucoseValues: [GlucoseValue] = [] {
        didSet {
            let unitString = glucoseUnit.glucoseUnitDisplayString

            predictedGlucosePoints = predictedGlucoseValues.map {
                return ChartPoint(
                    x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                    y: ChartAxisValueDoubleUnit($0.quantity.doubleValue(for: glucoseUnit), unitString: unitString, formatter: integerFormatter)
                )
            }
        }
    }

    var alternatePredictedGlucoseValues: [GlucoseValue] = [] {
        didSet {
            let unitString = glucoseUnit.glucoseUnitDisplayString

            alternatePredictedGlucosePoints = alternatePredictedGlucoseValues.map {
                return ChartPoint(
                    x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                    y: ChartAxisValueDoubleUnit($0.quantity.doubleValue(for: glucoseUnit), unitString: unitString, formatter: integerFormatter)
                )
            }
        }
    }

    var IOBValues: [InsulinValue] = [] {
        didSet {
            IOBPoints = IOBValues.map {
                return ChartPoint(
                    x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                    y: ChartAxisValueDoubleUnit($0.value, unitString: "U", formatter: decimalFormatter)
                )
            }
        }
    }

    var COBValues: [CarbValue] = [] {
        didSet {
            let unit = HKUnit.gram()
            let unitString = unit.unitString

            COBPoints = COBValues.map {
                ChartPoint(
                    x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                    y: ChartAxisValueDoubleUnit($0.quantity.doubleValue(for: unit), unitString: unitString, formatter: integerFormatter)
                )
            }
        }
    }

    var doseEntries: [DoseEntry] = [] {
        didSet {
            dosePoints = doseEntries.reduce([], { (points, entry) -> [ChartPoint] in
                if entry.unit == .unitsPerHour {
                    let startX = ChartAxisValueDate(date: entry.startDate, formatter: dateFormatter)
                    let endX = ChartAxisValueDate(date: entry.endDate, formatter: dateFormatter)
                    let zero = ChartAxisValueInt(0)
                    let value = ChartAxisValueDoubleLog(actualDouble: entry.value, unitString: "U/hour", formatter: decimalFormatter)

                    let newPoints = [
                        ChartPoint(x: startX, y: zero),
                        ChartPoint(x: startX, y: value),
                        ChartPoint(x: endX, y: value),
                        ChartPoint(x: endX, y: zero)
                    ]

                    return points + newPoints
                } else {
                    return points
                }
            })
        }
    }

    // MARK: - State

    private var glucosePoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
            xAxisValues = nil
        }
    }

    private var glucoseDisplayRangePoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
        }
    }

    private var predictedGlucosePoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
            xAxisValues = nil
        }
    }

    private var alternatePredictedGlucosePoints: [ChartPoint]?

    private var targetGlucosePoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
        }
    }

    private var targetOverridePoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
        }
    }

    private var targetOverrideDurationPoints: [ChartPoint] = [] {
        didSet {
            glucoseChart = nil
        }
    }

    private var IOBPoints: [ChartPoint] = [] {
        didSet {
            IOBChart = nil
            xAxisValues = nil
        }
    }

    private var COBPoints: [ChartPoint] = [] {
        didSet {
            COBChart = nil
            xAxisValues = nil
        }
    }

    private var dosePoints: [ChartPoint] = [] {
        didSet {
            doseChart = nil
            xAxisValues = nil
        }
    }

    private var xAxisValues: [ChartAxisValue]? {
        didSet {
            if let xAxisValues = xAxisValues {
                xAxisModel = ChartAxisModel(axisValues: xAxisValues, lineColor: axisLineColor)
            } else {
                xAxisModel = nil
            }
        }
    }

    private var xAxisModel: ChartAxisModel?

    private var glucoseChart: Chart?

    private var IOBChart: Chart?

    private var COBChart: Chart?

    private var doseChart: Chart?

    private var glucoseChartCache: ChartPointsTouchHighlightLayerViewCache?

    private var IOBChartCache: ChartPointsTouchHighlightLayerViewCache?

    private var COBChartCache: ChartPointsTouchHighlightLayerViewCache?

    private var doseChartCache: ChartPointsTouchHighlightLayerViewCache?

    // MARK: - Generators

    func glucoseChartWithFrame(_ frame: CGRect) -> Chart? {
        if let chart = glucoseChart, chart.frame != frame {
            self.glucoseChart = nil
        }

        if glucoseChart == nil {
            glucoseChart = generateGlucoseChartWithFrame(frame)
        }

        return glucoseChart
    }

    private func generateGlucoseChartWithFrame(_ frame: CGRect) -> Chart? {
        guard glucosePoints.count > 1, let xAxisModel = xAxisModel else {
            return nil
        }

        let points = glucosePoints + predictedGlucosePoints + targetGlucosePoints + targetOverridePoints + glucoseDisplayRangePoints

        let yAxisValues = ChartAxisValuesGenerator.generateYAxisValuesWithChartPoints(points,
            minSegmentCount: 2,
            maxSegmentCount: 4,
            multiple: glucoseUnit.glucoseUnitYAxisSegmentSize,
            axisValueGenerator: {
                ChartAxisValueDouble($0, labelSettings: self.axisLabelSettings)
            },
            addPaddingSegmentIfEdge: true
        )

        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: axisLineColor)

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxis, yAxis, innerFrame) = (coordsSpace.xAxis, coordsSpace.yAxis, coordsSpace.chartInnerFrame)

        // The glucose targets
        var targetLayer: ChartPointsAreaLayer? = nil

        if targetGlucosePoints.count > 1 {
            let alpha: CGFloat = targetOverridePoints.count > 1 ? 0.15 : 0.3

            targetLayer = ChartPointsAreaLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: targetGlucosePoints, areaColor: UIColor.glucoseTintColor.withAlphaComponent(alpha), animDuration: 0, animDelay: 0, addContainerPoints: false)
        }

        var targetOverrideLayer: ChartPointsAreaLayer? = nil

        if targetOverridePoints.count > 1 {
            targetOverrideLayer = ChartPointsAreaLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: targetOverridePoints, areaColor: UIColor.glucoseTintColor.withAlphaComponent(0.3), animDuration: 0, animDelay: 0, addContainerPoints: false)
        }

        var targetOverrideDurationLayer: ChartPointsAreaLayer? = nil

        if targetOverrideDurationPoints.count > 1 {
            targetOverrideDurationLayer = ChartPointsAreaLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: targetOverrideDurationPoints, areaColor: UIColor.glucoseTintColor.withAlphaComponent(0.3), animDuration: 0, animDelay: 0, addContainerPoints: false)
        }

        let gridLayer = ChartGuideLinesLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, axis: .xAndY, settings: guideLinesLayerSettings, onlyVisibleX: true, onlyVisibleY: false)

        let circles = ChartPointsScatterCirclesLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: glucosePoints, displayDelay: 0, itemSize: CGSize(width: 4, height: 4), itemFillColor: UIColor.glucoseTintColor)

        var alternatePrediction: ChartLayer?

        if let altPoints = alternatePredictedGlucosePoints, altPoints.count > 1 {
            // TODO: Bug in ChartPointsLineLayer requires a non-zero animation to draw the dash pattern
            let lineModel = ChartLineModel(chartPoints: altPoints, lineColor: UIColor.glucoseTintColor, lineWidth: 2, animDuration: 0.0001, animDelay: 0, dashPattern: [6, 5])

            alternatePrediction = ChartPointsLineLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, lineModels: [lineModel])
        }

        var prediction: ChartLayer?

        if predictedGlucosePoints.count > 1 {
            let lineColor = (alternatePrediction == nil) ? UIColor.glucoseTintColor : UIColor.secondaryLabelColor

            // TODO: Bug in ChartPointsLineLayer requires a non-zero animation to draw the dash pattern
            let lineModel = ChartLineModel(
                chartPoints: predictedGlucosePoints,
                lineColor: lineColor,
                lineWidth: 1,
                animDuration: 0.0001,
                animDelay: 0,
                dashPattern: [6, 5]
            )

            prediction = ChartPointsLineLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, lineModels: [lineModel])
        }

        glucoseChartCache = ChartPointsTouchHighlightLayerViewCache(
            xAxis: xAxis,
            yAxis: yAxis,
            innerFrame: innerFrame,
            chartPoints: glucosePoints + (alternatePredictedGlucosePoints ?? predictedGlucosePoints),
            tintColor: UIColor.glucoseTintColor,
            labelCenterY: chartSettings.top,
            gestureRecognizer: panGestureRecognizer
        )

        let layers: [ChartLayer?] = [
            gridLayer,
            targetLayer,
            targetOverrideLayer,
            targetOverrideDurationLayer,
            xAxis,
            yAxis,
            glucoseChartCache?.highlightLayer,
            prediction,
            alternatePrediction,
            circles
        ]

        return Chart(frame: frame, layers: layers.flatMap { $0 })
    }

    func IOBChartWithFrame(_ frame: CGRect) -> Chart? {
        if let chart = IOBChart, chart.frame != frame {
            self.IOBChart = nil
        }

        if IOBChart == nil {
            IOBChart = generateIOBChartWithFrame(frame)
        }

        return IOBChart
    }

    private func generateIOBChartWithFrame(_ frame: CGRect) -> Chart? {
        guard IOBPoints.count > 1, let xAxisModel = xAxisModel else {
            return nil
        }

        var containerPoints = IOBPoints

        // Create a container line at 0
        if let first = IOBPoints.first {
            containerPoints.insert(ChartPoint(x: first.x, y: ChartAxisValueInt(0)), at: 0)
        }

        if let last = IOBPoints.last {
            containerPoints.append(ChartPoint(x: last.x, y: ChartAxisValueInt(0)))
        }

        let yAxisValues = ChartAxisValuesGenerator.generateYAxisValuesWithChartPoints(IOBPoints, minSegmentCount: 2, maxSegmentCount: 3, multiple: 0.5, axisValueGenerator: { ChartAxisValueDouble($0, labelSettings: self.axisLabelSettings) }, addPaddingSegmentIfEdge: false)

        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: axisLineColor)

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxis, yAxis, innerFrame) = (coordsSpace.xAxis, coordsSpace.yAxis, coordsSpace.chartInnerFrame)

        // The IOB area
        let lineModel = ChartLineModel(chartPoints: IOBPoints, lineColor: UIColor.IOBTintColor, lineWidth: 2, animDuration: 0, animDelay: 0)
        let IOBLine = ChartPointsLineLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, lineModels: [lineModel])

        let IOBArea = ChartPointsAreaLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: containerPoints, areaColor: UIColor.IOBTintColor.withAlphaComponent(0.5), animDuration: 0, animDelay: 0, addContainerPoints: false)

        // Grid lines
        let gridLayer = ChartGuideLinesLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, axis: .xAndY, settings: guideLinesLayerSettings, onlyVisibleX: true, onlyVisibleY: false)

        // 0-line
        let dummyZeroChartPoint = ChartPoint(x: ChartAxisValueDouble(0), y: ChartAxisValueDouble(0))
        let zeroGuidelineLayer = ChartPointsViewsLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: [dummyZeroChartPoint], viewGenerator: {(chartPointModel, layer, chart) -> UIView? in
            let width: CGFloat = 0.5
            let viewFrame = CGRect(x: innerFrame.origin.x, y: chartPointModel.screenLoc.y - width / 2, width: innerFrame.size.width, height: width)

            let v = UIView(frame: viewFrame)
            v.backgroundColor = UIColor.IOBTintColor
            return v
        })

        IOBChartCache = ChartPointsTouchHighlightLayerViewCache(
            xAxis: xAxis,
            yAxis: yAxis,
            innerFrame: innerFrame,
            chartPoints: IOBPoints,
            tintColor: UIColor.IOBTintColor,
            labelCenterY: chartSettings.top,
            gestureRecognizer: panGestureRecognizer
        )

        let layers: [ChartLayer?] = [
            gridLayer,
            xAxis,
            yAxis,
            zeroGuidelineLayer,
            IOBChartCache?.highlightLayer,
            IOBArea,
            IOBLine,
        ]

        return Chart(frame: frame, layers: layers.flatMap { $0 })
    }

    func COBChartWithFrame(_ frame: CGRect) -> Chart? {
        if let chart = COBChart, chart.frame != frame {
            self.COBChart = nil
        }

        if COBChart == nil {
            COBChart = generateCOBChartWithFrame(frame)
        }

        return COBChart
    }

    private func generateCOBChartWithFrame(_ frame: CGRect) -> Chart? {
        guard COBPoints.count > 1, let xAxisModel = xAxisModel else {
            return nil
        }

        var containerPoints = COBPoints

        // Create a container line at 0
        if let first = COBPoints.first {
            containerPoints.insert(ChartPoint(x: first.x, y: ChartAxisValueInt(0)), at: 0)
        }

        if let last = COBPoints.last {
            containerPoints.append(ChartPoint(x: last.x, y: ChartAxisValueInt(0)))
        }

        let yAxisValues = ChartAxisValuesGenerator.generateYAxisValuesWithChartPoints(COBPoints, minSegmentCount: 2, maxSegmentCount: 3, multiple: 10, axisValueGenerator: { ChartAxisValueDouble($0, labelSettings: self.axisLabelSettings) }, addPaddingSegmentIfEdge: false)

        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: axisLineColor)

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxis, yAxis, innerFrame) = (coordsSpace.xAxis, coordsSpace.yAxis, coordsSpace.chartInnerFrame)

        // The COB area
        let lineModel = ChartLineModel(chartPoints: COBPoints, lineColor: UIColor.COBTintColor, lineWidth: 2, animDuration: 0, animDelay: 0)
        let COBLine = ChartPointsLineLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, lineModels: [lineModel])

        let COBArea = ChartPointsAreaLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: containerPoints, areaColor: UIColor.COBTintColor.withAlphaComponent(0.5), animDuration: 0, animDelay: 0, addContainerPoints: false)

        // Grid lines
        let gridLayer = ChartGuideLinesLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, axis: .xAndY, settings: guideLinesLayerSettings, onlyVisibleX: true, onlyVisibleY: false)


        COBChartCache = ChartPointsTouchHighlightLayerViewCache(
            xAxis: xAxis,
            yAxis: yAxis,
            innerFrame: innerFrame,
            chartPoints: COBPoints,
            tintColor: UIColor.COBTintColor,
            labelCenterY: chartSettings.top,
            gestureRecognizer: panGestureRecognizer
        )

        let layers: [ChartLayer?] = [
            gridLayer,
            xAxis,
            yAxis,
            COBChartCache?.highlightLayer,
            COBArea,
            COBLine
        ]

        return Chart(frame: frame, layers: layers.flatMap { $0 })
    }

    func doseChartWithFrame(_ frame: CGRect) -> Chart? {
        if let chart = doseChart, chart.frame != frame {
            self.doseChart = nil
        }

        if doseChart == nil {
            doseChart = generateDoseChartWithFrame(frame)
        }

        return doseChart
    }

    private func generateDoseChartWithFrame(_ frame: CGRect) -> Chart? {
        guard dosePoints.count > 1, let xAxisModel = xAxisModel else {
            return nil
        }

        let yAxisValues = ChartAxisValuesGenerator.generateYAxisValuesWithChartPoints(dosePoints, minSegmentCount: 2, maxSegmentCount: 3, multiple: log10(2) / 2, axisValueGenerator: { ChartAxisValueDoubleLog(screenLocDouble: $0, formatter: self.integerFormatter, labelSettings: self.axisLabelSettings) }, addPaddingSegmentIfEdge: true)

        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: axisLineColor)

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxis, yAxis, innerFrame) = (coordsSpace.xAxis, coordsSpace.yAxis, coordsSpace.chartInnerFrame)

        // The dose area
        let lineModel = ChartLineModel(chartPoints: dosePoints, lineColor: UIColor.doseTintColor, lineWidth: 2, animDuration: 0, animDelay: 0)
        let doseLine = ChartPointsLineLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, lineModels: [lineModel])

        let doseArea = ChartPointsAreaLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: dosePoints, areaColor: UIColor.doseTintColor.withAlphaComponent(0.5), animDuration: 0, animDelay: 0, addContainerPoints: false)

        // Grid lines
        let gridLayer = ChartGuideLinesLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, axis: .xAndY, settings: guideLinesLayerSettings, onlyVisibleX: true, onlyVisibleY: false)

        // 0-line
        let dummyZeroChartPoint = ChartPoint(x: ChartAxisValueDouble(0), y: ChartAxisValueDouble(0))
        let zeroGuidelineLayer = ChartPointsViewsLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: [dummyZeroChartPoint], viewGenerator: {(chartPointModel, layer, chart) -> UIView? in
            let width: CGFloat = 1
            let viewFrame = CGRect(x: innerFrame.origin.x, y: chartPointModel.screenLoc.y - width / 2, width: innerFrame.size.width, height: width)

            let v = UIView(frame: viewFrame)
            v.backgroundColor = UIColor.doseTintColor
            return v
        })

        doseChartCache = ChartPointsTouchHighlightLayerViewCache(
            xAxis: xAxis,
            yAxis: yAxis,
            innerFrame: innerFrame,
            chartPoints: dosePoints.filter { $0.y.scalar != 0 },
            tintColor: UIColor.doseTintColor,
            labelCenterY: chartSettings.top,
            gestureRecognizer: panGestureRecognizer
        )

        let layers: [ChartLayer?] = [
            gridLayer,
            xAxis,
            yAxis,
            zeroGuidelineLayer,
            doseChartCache?.highlightLayer,
            doseArea,
            doseLine
        ]
        
        return Chart(frame: frame, layers: layers.flatMap { $0 })
    }

    private func generateXAxisValues() {
        let points = glucosePoints + predictedGlucosePoints + IOBPoints + COBPoints + dosePoints

        guard points.count > 1 else {
            self.xAxisValues = []
            return
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h a"

        let minDate = startDate
        let xAxisValues = ChartAxisValuesGenerator.generateXAxisValuesWithChartPoints(points, minSegmentCount: 5, maxSegmentCount: 10, multiple: TimeInterval(hours: 1), axisValueGenerator: {
            ChartAxisValueDate(date: max(minDate, ChartAxisValueDate.dateFromScalar($0)), formatter: timeFormatter, labelSettings: self.axisLabelSettings)
        }, addPaddingSegmentIfEdge: false)
        xAxisValues.first?.hidden = true
        xAxisValues.last?.hidden = true

        self.xAxisValues = xAxisValues
    }

    func prerender() {
        glucoseChart = nil
        IOBChart = nil
        COBChart = nil

        generateXAxisValues()

        if let xAxisValues = xAxisValues, xAxisValues.count > 1,
            let targets = glucoseTargetRangeSchedule {
            targetGlucosePoints = ChartPoint.pointsForGlucoseRangeSchedule(targets, xAxisValues: xAxisValues)

            if let override = targets.temporaryOverride {
                targetOverridePoints = ChartPoint.pointsForGlucoseRangeScheduleOverride(override, xAxisValues: xAxisValues)

                targetOverrideDurationPoints = ChartPoint.pointsForGlucoseRangeScheduleOverrideDuration(override, xAxisValues: xAxisValues)
            } else {
                targetOverridePoints = []
                targetOverrideDurationPoints = []
            }
        }
    }
}


private extension HKUnit {
    var glucoseUnitYAxisSegmentSize: Double {
        if self == HKUnit.milligramsPerDeciliterUnit() {
            return 25
        } else {
            return 1
        }
    }
}
