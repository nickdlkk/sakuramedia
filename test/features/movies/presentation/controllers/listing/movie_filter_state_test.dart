import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';

void main() {
  group('MovieStatusFilter', () {
    test('unsubscribed 映射后端 status 枚举值', () {
      expect(MovieStatusFilter.unsubscribed.apiValue, 'unsubscribed');
      expect(MovieStatusFilter.unsubscribed.label, '未订阅');
    });
  });

  group('滑块值 → 接口参数映射', () {
    test('下限 0 映射为不限，正值原样透传', () {
      expect(movieHeatMinFromSlider(0), isNull);
      expect(movieHeatMinFromSlider(1000), 1000);
      // 左 thumb 也能拖到顶：2w 及以上（无上界）。
      expect(movieHeatMinFromSlider(movieFilterHeatSliderMax), 20000);
    });

    test('上限滑到顶映射为不限，未到顶原样透传', () {
      expect(movieHeatMaxFromSlider(movieFilterHeatSliderMax), isNull);
      expect(movieHeatMaxFromSlider(movieFilterHeatSliderMax - 1), 19999);
      expect(movieHeatMaxFromSlider(5000), 5000);
    });
  });

  group('movieHeatRangeLabel', () {
    test('双边 / 单边 / 不限的文案', () {
      expect(movieHeatRangeLabel(1000, 5000), '1000 ~ 5000');
      expect(movieHeatRangeLabel(1000, null), '≥ 1000');
      expect(movieHeatRangeLabel(null, 5000), '≤ 5000');
      expect(movieHeatRangeLabel(null, null), '不限');
    });
  });

  group('MovieFilterState', () {
    test('初始状态不含热度条件', () {
      const state = MovieFilterState.initial;
      expect(state.heatMin, isNull);
      expect(state.heatMax, isNull);
      expect(state.hasHeatRange, isFalse);
      expect(state.isDefault, isTrue);
      expect(state.triggerLabel, '全部');
    });

    test('热度条件影响 isDefault / hasHeatRange / triggerLabel', () {
      final state = const MovieFilterState().copyWith(heatMin: 1000);
      expect(state.hasHeatRange, isTrue);
      expect(state.isDefault, isFalse);
      expect(state.triggerLabel, '≥ 1000');

      final both = const MovieFilterState().copyWith(
        heatMin: 1000,
        heatMax: 5000,
      );
      expect(both.triggerLabel, '1000 ~ 5000');
    });

    test('triggerLabel 优先级：年份 > 热度 > 状态', () {
      final withYear = const MovieFilterState().copyWith(year: 2024);
      expect(withYear.triggerLabel, '2024');

      final withYearAndHeat = withYear.copyWith(heatMin: 1000);
      expect(withYearAndHeat.triggerLabel, '2024');

      final withHeatOnly = const MovieFilterState().copyWith(heatMax: 2000);
      expect(withHeatOnly.triggerLabel, '≤ 2000');
    });

    test('copyWith 可显式清空热度条件', () {
      const withHeat = MovieFilterState(heatMin: 1000, heatMax: 5000);
      final cleared = withHeat.copyWith(
        heatMin: null,
        heatMax: null,
      );
      expect(cleared.heatMin, isNull);
      expect(cleared.heatMax, isNull);
      expect(cleared.isDefault, isTrue);
    });

    test('matches 比较热度条件', () {
      const base = MovieFilterState();
      expect(base.matches(const MovieFilterState()), isTrue);
      expect(
        base.matches(const MovieFilterState(heatMin: 1000)),
        isFalse,
      );
    });
  });
}
