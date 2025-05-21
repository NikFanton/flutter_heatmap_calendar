import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/src/extentions/first_or_null_extension.dart';
import 'package:flutter_heatmap_calendar/src/widget/heatmap_container.dart';

import '../data/heatmap_color_mode.dart';
import '../util/datasets_util.dart';
import '../util/date_util.dart';
import './heatmap_column.dart';
import './heatmap_month_text.dart';

class HeatMapPage extends StatelessWidget {
  /// List value of every sunday's month information.
  ///
  /// From 1: January to 12: December.
  final List<int> _firstDayInfos = [];

  /// The number of days between [startDate] and [endDate].
  final int _dateDifferent;

  /// The Date value of start day of heatmap.
  ///
  /// HeatMap shows the start day of [startDate]'s week.
  ///
  /// Default value is 1 year before the [endDate].
  /// And if [endDate] is null, then set 1 year before the [DateTime.now]
  final DateTime startDate;

  /// The Date value of end day of heatmap.
  ///
  /// Default value is [DateTime.now]
  final DateTime endDate;

  /// The double value of every block's width and height.
  final double? size;

  /// The double value of every block's fontSize.
  final double? fontSize;
  final FontWeight? fontWeight;

  /// The datasets which fill blocks based on its value.
  final Map<DateTime, int>? datasets;

  /// The margin value for every block.
  final EdgeInsets? margin;

  /// The default background color value of every blocks.
  final Color? defaultColor;

  /// The text color value of every blocks.
  final Color? textColor;

  /// ColorMode changes the color mode of blocks.
  ///
  /// [ColorMode.opacity] requires just one colorsets value and changes color
  /// dynamically based on hightest value of [datasets].
  /// [ColorMode.color] changes colors based on [colorsets] thresholds key value.
  final ColorMode colorMode;

  /// The colorsets which give the color value for its thresholds key value.
  ///
  /// Be aware that first Color is the maximum value if [ColorMode] is [ColorMode.opacity].
  final Map<int, Color>? colorsets;

  /// The double value of every block's borderRadius.
  final double? borderRadius;

  /// The integer value of the maximum value for the [datasets].
  ///
  /// Get highest key value of filtered datasets using [DatasetsUtil.getMaxValue].
  final int? maxValue;

  /// Function that will be called when a block is clicked.
  ///
  /// Paratmeter gives clicked [DateTime] value.
  final Function(DateTime)? onClick;

  final bool? showText;
  final bool showMonthGap;

  HeatMapPage({
    Key? key,
    required this.colorMode,
    required this.startDate,
    required this.endDate,
    this.size,
    this.fontSize,
    this.fontWeight,
    this.datasets,
    this.defaultColor,
    this.textColor,
    this.colorsets,
    this.borderRadius,
    this.onClick,
    this.margin,
    this.showText,
    this.showMonthGap = true,
  })  : _dateDifferent = endDate.difference(startDate).inDays,
        maxValue = DatasetsUtil.getMaxValue(datasets),
        super(key: key);

  /// Get [HeatMapColumn] from [startDate] to [endDate].
  List<Widget> _heatmapColumnList() {
    // List of vertical columns (each column = 7 blocks).
    List<Widget> columns = [];

    // Temporary list to collect one column's worth of day/placeholder widgets.
    List<Widget> currentColumnDays = [];

    const int daysPerColumn = 7;

    // Tracks the currently processed month.
    int? currentMonth;

    // If a month transition happens mid-column, we store how many empty boxes
    // need to be added at the top of the *next* column to complete the visual gap.
    int carryoverTopPadding = 0;

    // If the previous column ended exactly at the end of the month (full 7 days),
    // we still need to insert a new empty column as a separator.
    bool forceEmptyColumnOnNext = false;

    // Align the cursor to the Sunday before or of startDate.
    DateTime cursor = DateUtil.changeDay(startDate, -(startDate.weekday % 7));
    DateTime limit = endDate;

    while (cursor.isBefore(limit) || cursor.isAtSameMomentAs(limit)) {
      DateTime nextDay = cursor.add(const Duration(days: 1));
      bool isMonthChangeNext = nextDay.month != cursor.month;

      // Start new column with carryover padding or forced empty gap
      if (showMonthGap && currentColumnDays.isEmpty) {
        if (carryoverTopPadding > 0) {
          currentColumnDays.addAll(List.generate(
            carryoverTopPadding,
            (_) => _emptyDayBox(),
          ));
          carryoverTopPadding = 0;
        } else if (forceEmptyColumnOnNext) {
          currentColumnDays.addAll(List.generate(
            daysPerColumn,
            (_) => _emptyDayBox(),
          ));
          forceEmptyColumnOnNext = false;

          // Add the column of empty boxes
          columns.add(Column(children: currentColumnDays));
          _firstDayInfos.add(currentMonth!);
          currentColumnDays = [];
        }
      }

      // Add the actual day container for this date.
      currentColumnDays.add(HeatMapContainer(
        date: cursor,
        backgroundColor: defaultColor,
        size: size,
        fontSize: fontSize,
        textColor: textColor,
        borderRadius: borderRadius,
        margin: margin,
        showText: showText,
        onClick: onClick,
        selectedColor: _resolveSelectedColor(cursor),
      ));

      // If it's time to close the column
      if ((showMonthGap && isMonthChangeNext) ||
          currentColumnDays.length == daysPerColumn) {
        if (showMonthGap && isMonthChangeNext) {
          if (currentColumnDays.length < daysPerColumn) {
            int bottomPadding = daysPerColumn - currentColumnDays.length;
            currentColumnDays
                .addAll(List.generate(bottomPadding, (_) => _emptyDayBox()));
            carryoverTopPadding = 7 - bottomPadding;
          } else {
            forceEmptyColumnOnNext = true;
          }
        }

        columns.add(Column(children: currentColumnDays));

        final firstRealDate = currentColumnDays
            .whereType<HeatMapContainer>()
            .map((c) => c.date)
            .firstOrNull;
        _firstDayInfos
            .add(firstRealDate?.month ?? currentMonth ?? cursor.month);

        currentColumnDays = [];
      }

      currentMonth = cursor.month;
      cursor = nextDay;
    }

    // Final column (if unfinished)
    if (currentColumnDays.isNotEmpty) {
      while (currentColumnDays.length < daysPerColumn) {
        currentColumnDays.add(_emptyDayBox());
      }
      columns.add(Column(children: currentColumnDays));

      final firstRealDate = currentColumnDays
          .whereType<HeatMapContainer>()
          .map((c) => c.date)
          .firstOrNull;
      _firstDayInfos.add(firstRealDate?.month ?? currentMonth!);
    }

    return columns;
  }

  Widget _emptyDayBox() {
    return Container(
      margin: margin ?? const EdgeInsets.all(2),
      width: size ?? 20,
      height: size ?? 20,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius ?? 5),
      ),
    );
  }

  Color? _resolveSelectedColor(DateTime date) {
    final value = datasets?[date];
    if (value == null) return null;

    if (colorMode == ColorMode.opacity) {
      return _getOpacityColor(value);
    } else {
      return DatasetsUtil.getColor(colorsets, value);
    }
  }

  Color _getOpacityColor(int value) {
    final base = colorsets?.values.first ?? Colors.transparent;
    final ratio = value / (maxValue ?? 1);
    final alpha = (ratio * 255).round().clamp(0, 255);
    return base.withAlpha(alpha);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show week labels to left side of heatmap.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show month labels to top of heatmap.
                HeatMapMonthText(
                  firstDayInfos: _firstDayInfos,
                  margin: margin,
                  fontSize: fontSize,
                  fontColor: textColor,
                  fontWeight: fontWeight,
                  size: size,
                ),

                // Heatmap itself.
                Row(
                  children: <Widget>[..._heatmapColumnList()],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
