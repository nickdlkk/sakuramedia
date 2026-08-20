import 'package:sakuramedia/features/shared/data/sort_direction.dart';

// SortDirection 已抬到 lib/features/shared/data/sort_direction.dart，
// 这里 re-export 保持 movies 域现有 import 路径不变。
export 'package:sakuramedia/features/shared/data/sort_direction.dart'
    show SortDirection, SortDirectionX;

enum MovieStatusFilter { all, subscribed, unsubscribed, playable }

extension MovieStatusFilterX on MovieStatusFilter {
  String get apiValue => switch (this) {
    MovieStatusFilter.all => 'all',
    MovieStatusFilter.subscribed => 'subscribed',
    MovieStatusFilter.unsubscribed => 'unsubscribed',
    MovieStatusFilter.playable => 'playable',
  };

  String get label => switch (this) {
    MovieStatusFilter.all => '全部',
    MovieStatusFilter.subscribed => '已订阅',
    MovieStatusFilter.unsubscribed => '未订阅',
    MovieStatusFilter.playable => '可播放',
  };
}

enum MovieNumberSourceFilter { all, regular, fc2 }

extension MovieNumberSourceFilterX on MovieNumberSourceFilter {
  String get apiValue => switch (this) {
    MovieNumberSourceFilter.all => 'all',
    MovieNumberSourceFilter.regular => 'regular',
    MovieNumberSourceFilter.fc2 => 'fc2',
  };

  String get label => switch (this) {
    MovieNumberSourceFilter.all => '全部',
    MovieNumberSourceFilter.regular => '常规',
    MovieNumberSourceFilter.fc2 => 'FC2',
  };
}

enum MovieCollectionTypeFilter { all, single }

extension MovieCollectionTypeFilterX on MovieCollectionTypeFilter {
  String get apiValue => switch (this) {
    MovieCollectionTypeFilter.all => 'all',
    MovieCollectionTypeFilter.single => 'single',
  };

  String get label => switch (this) {
    MovieCollectionTypeFilter.all => '全部',
    MovieCollectionTypeFilter.single => '单体',
  };
}

enum TagMatchMode { or, and }

extension TagMatchModeX on TagMatchMode {
  String get apiValue => switch (this) {
    TagMatchMode.or => 'or',
    TagMatchMode.and => 'and',
  };

  String get label => switch (this) {
    TagMatchMode.or => '任一',
    TagMatchMode.and => '全部',
  };
}

enum MovieSortField {
  releaseDate,
  addedAt,
  subscribedAt,
  commentCount,
  scoreNumber,
  wantWatchCount,
  heat,
}

extension MovieSortFieldX on MovieSortField {
  String get apiValue => switch (this) {
    MovieSortField.releaseDate => 'release_date',
    MovieSortField.addedAt => 'added_at',
    MovieSortField.subscribedAt => 'subscribed_at',
    MovieSortField.commentCount => 'comment_count',
    MovieSortField.scoreNumber => 'score_number',
    MovieSortField.wantWatchCount => 'want_watch_count',
    MovieSortField.heat => 'heat',
  };

  String get label => switch (this) {
    MovieSortField.releaseDate => '发行时间',
    MovieSortField.addedAt => '最近入库',
    MovieSortField.subscribedAt => '订阅时间',
    MovieSortField.commentCount => '评论人数',
    MovieSortField.scoreNumber => '评分人数',
    MovieSortField.wantWatchCount => '想看人数',
    MovieSortField.heat => '热度',
  };
}

const Object _movieFilterUnset = Object();

/// 普通影片库的年份筛选不依赖后端聚合：范围固定为 2008 年至当前年。
///
/// 女优详情会显式传入服务端返回的年份和数量，因此仍可保持「年份(影片数)」
/// 的精确展示。
const int movieFilterEarliestYear = 2008;

/// 热度范围筛选的滑块上限：滑到顶即「无上界」（2w 及以上都包含）。
///
/// 与后端语义对齐：`heat_min` 传 0 等价于不传（全部包含），`heat_max`
/// 传 20000 等价于不传（无上界），因此参数层用 `null` 表达「不限」。
const int movieFilterHeatSliderMax = 20000;

/// 滑块下限值 → 接口参数：0 即不限（不传 `heat_min`）。
int? movieHeatMinFromSlider(int value) => value <= 0 ? null : value;

/// 滑块上限值 → 接口参数：滑到顶即无上界（不传 `heat_max`）。
int? movieHeatMaxFromSlider(int value) =>
    value >= movieFilterHeatSliderMax ? null : value;

/// 热度范围的展示文案，桌面浮层与移动抽屉、筛选入口共用一份。
String movieHeatRangeLabel(int? heatMin, int? heatMax) {
  if (heatMin != null && heatMax != null) {
    return '$heatMin ~ $heatMax';
  }
  if (heatMin != null) {
    return '≥ $heatMin';
  }
  if (heatMax != null) {
    return '≤ $heatMax';
  }
  return '不限';
}

List<MovieFilterYearOption> buildDefaultMovieFilterYearOptions({
  int? currentYear,
}) {
  final latestYear = currentYear ?? DateTime.now().year;
  if (latestYear < movieFilterEarliestYear) {
    return const <MovieFilterYearOption>[];
  }
  return <MovieFilterYearOption>[
    for (var year = latestYear; year >= movieFilterEarliestYear; year--)
      MovieFilterYearOption(year: year),
  ];
}

class MovieFilterYearOption {
  const MovieFilterYearOption({required this.year, this.movieCount});

  final int year;
  final int? movieCount;

  String get label => movieCount == null ? '$year' : '$year($movieCount)';
}

class MovieFilterState {
  const MovieFilterState({
    this.status = MovieStatusFilter.all,
    this.collectionType = MovieCollectionTypeFilter.single,
    this.numberSource = MovieNumberSourceFilter.all,
    this.sortField = MovieSortField.releaseDate,
    this.sortDirection = SortDirection.desc,
    this.year,
    this.heatMin,
    this.heatMax,
  });

  final MovieStatusFilter status;
  final MovieCollectionTypeFilter collectionType;
  final MovieNumberSourceFilter numberSource;
  final MovieSortField sortField;
  final SortDirection sortDirection;
  final int? year;

  /// 热度下限（接口 `heat_min` 语义）：null 表示不限。
  final int? heatMin;

  /// 热度上限（接口 `heat_max` 语义）：null 表示不限。
  final int? heatMax;

  static const MovieFilterState initial = MovieFilterState();

  bool get isDefault =>
      status == MovieStatusFilter.all &&
      collectionType == MovieCollectionTypeFilter.single &&
      numberSource == MovieNumberSourceFilter.all &&
      sortField == MovieSortField.releaseDate &&
      sortDirection == SortDirection.desc &&
      year == null &&
      heatMin == null &&
      heatMax == null;

  bool get hasHeatRange => heatMin != null || heatMax != null;

  String get sortExpression =>
      '${sortField.apiValue}:${sortDirection.apiValue}';

  /// 筛选入口上显示的当前筛选摘要。**只反映一个主维度**——筛了年份就报年份，
  /// 否则报热度范围，再否则报状态；番号来源、排序等有独立分节，不堆在入口上
  /// 避免文字变长。语义对齐 `MediaBrowseFilterState.triggerLabel`，桌面移动共用。
  String get triggerLabel => switch ((year, hasHeatRange)) {
    (final int y, _) => '$y',
    (_, true) => movieHeatRangeLabel(heatMin, heatMax),
    _ => status.label,
  };

  bool matches(MovieFilterState other) =>
      status == other.status &&
      collectionType == other.collectionType &&
      numberSource == other.numberSource &&
      sortField == other.sortField &&
      sortDirection == other.sortDirection &&
      year == other.year &&
      heatMin == other.heatMin &&
      heatMax == other.heatMax;

  MovieFilterState copyWith({
    MovieStatusFilter? status,
    MovieCollectionTypeFilter? collectionType,
    MovieNumberSourceFilter? numberSource,
    MovieSortField? sortField,
    SortDirection? sortDirection,
    Object? year = _movieFilterUnset,
    Object? heatMin = _movieFilterUnset,
    Object? heatMax = _movieFilterUnset,
  }) {
    return MovieFilterState(
      status: status ?? this.status,
      collectionType: collectionType ?? this.collectionType,
      numberSource: numberSource ?? this.numberSource,
      sortField: sortField ?? this.sortField,
      sortDirection: sortDirection ?? this.sortDirection,
      year: identical(year, _movieFilterUnset) ? this.year : year as int?,
      heatMin: identical(heatMin, _movieFilterUnset)
          ? this.heatMin
          : heatMin as int?,
      heatMax: identical(heatMax, _movieFilterUnset)
          ? this.heatMax
          : heatMax as int?,
    );
  }
}
