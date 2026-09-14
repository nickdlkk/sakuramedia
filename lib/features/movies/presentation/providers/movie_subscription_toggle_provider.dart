import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_subscription_batch_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_toggle_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

part 'movie_subscription_toggle_provider.g.dart';

typedef MovieForceUnsubscribeProgress = ({double? value, String message});

/// 跨影片列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [movieSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构更新订阅态，避免把数据源耦合进展示组件。
@Riverpod(keepAlive: true)
class MovieSubscriptionToggle extends _$MovieSubscriptionToggle {
  @override
  Set<String> build() => const <String>{};

  /// 前端串行删除媒体，全部成功后仅发送一次批量取消订阅请求。
  Future<MovieSubscriptionBatchToggleResult> forceUnsubscribeBatch(
    Iterable<String> movieNumbers, {
    void Function(MovieForceUnsubscribeProgress progress)? onProgress,
  }) async {
    final numbers = movieNumbers.where((number) => number.isNotEmpty).toSet();
    if (numbers.isEmpty) {
      return const MovieSubscriptionBatchToggleResult(
        requestedCount: 0,
        updatedCount: 0,
        skippedMovieNotFoundNumbers: [],
        skippedHasMediaNumbers: [],
      );
    }
    if (numbers.any(state.contains)) {
      return MovieSubscriptionBatchToggleResult.failed(
        requestedCount: numbers.length,
        message: '选中影片正在处理，请稍后重试',
      );
    }
    state = Set.unmodifiable({...state, ...numbers});
    var deletedCount = 0;
    var step = '读取影片媒体失败';
    try {
      final api = ref.read(moviesApiProvider);
      final mediaApi = ref.read(mediaApiProvider);
      final movies = <MovieDetailDto>[];
      for (final number in numbers) {
        step = '读取 $number 的媒体失败';
        onProgress?.call((
          value: null,
          message: '正在读取媒体清单：${movies.length + 1}/${numbers.length} 部',
        ));
        movies.add(await api.getMovieDetail(movieNumber: number));
      }
      final total = movies.fold<int>(
        0,
        (count, movie) => count + movie.mediaItems.length,
      );
      for (final movie in movies) {
        final number = movie.movieNumber;
        try {
          for (final media in movie.mediaItems) {
            step = '删除 $number 的媒体 ${media.mediaId} 失败';
            onProgress?.call((
              value: deletedCount / total,
              message: '已删除 $deletedCount/$total 个媒体 · $number',
            ));
            await mediaApi.deleteMedia(mediaId: media.mediaId);
            deletedCount++;
            onProgress?.call((
              value: deletedCount / total,
              message: '已删除 $deletedCount/$total 个媒体 · $number',
            ));
          }
        } catch (_) {
          // 已删除的媒体不能回滚，尽力同步这一部影片的实际状态。
          try {
            await _reportMediaState(number);
          } catch (_) {}
          rethrow;
        }
        step = '刷新 $number 的媒体状态失败';
        await _reportMediaState(number);
      }
      step = '媒体已清理，但批量取消订阅失败';
      onProgress?.call((
        value: 1,
        message: '已删除 $deletedCount/$total 个媒体，正在批量取消订阅…',
      ));
      final response = await api.batchUnsubscribeMovies(
        movieNumbers: numbers.toList(),
      );
      final skipped = response.skipped.map((item) => item.movieNumber).toSet();
      ref.read(movieSubscriptionEventsProvider.notifier).reportBatch([
        for (final number in numbers)
          if (!skipped.contains(number))
            MovieSubscriptionChange(movieNumber: number, isSubscribed: false),
      ]);
      return MovieSubscriptionBatchToggleResult(
        requestedCount: response.requestedCount,
        updatedCount: response.updatedCount,
        skippedMovieNotFoundNumbers: response.movieNumbersSkippedBecause(
          MovieSubscriptionSkipReason.movieNotFound,
        ),
        skippedHasMediaNumbers: response.movieNumbersSkippedBecause(
          MovieSubscriptionSkipReason.hasMedia,
        ),
      );
    } catch (error) {
      final reason = apiErrorMessage(error, fallback: '请稍后重试');
      return MovieSubscriptionBatchToggleResult.failed(
        requestedCount: numbers.length,
        message: '$step：$reason。已停止操作，已删除 $deletedCount 个媒体，删除操作无法回滚。',
      );
    } finally {
      if (ref.mounted) {
        state = Set.unmodifiable(state.difference(numbers));
      }
    }
  }

  Future<void> _reportMediaState(String movieNumber) async {
    final movie = await ref
        .read(moviesApiProvider)
        .getMovieDetail(movieNumber: movieNumber);
    ref
        .read(movieMediaEventsProvider.notifier)
        .reportChange(
          MovieMediaChange(
            movieNumber: movieNumber,
            canPlay: movie.canPlay,
            isSubscribed: movie.isSubscribed,
          ),
        );
  }

  Future<MovieSubscriptionToggleResult> toggle({
    required String movieNumber,
    required bool isSubscribed,
  }) async {
    final normalizedMovieNumber = movieNumber.trim();
    if (normalizedMovieNumber.isEmpty ||
        state.contains(normalizedMovieNumber)) {
      return const MovieSubscriptionToggleResult.ignored();
    }
    state = Set<String>.unmodifiable(<String>{...state, normalizedMovieNumber});
    final subscribe = !isSubscribed;
    try {
      final api = ref.read(moviesApiProvider);
      if (subscribe) {
        await api.subscribeMovie(movieNumber: normalizedMovieNumber);
      } else {
        await api.unsubscribeMovie(
          movieNumber: normalizedMovieNumber,
          deleteMedia: false,
        );
      }
      ref
          .read(movieSubscriptionEventsProvider.notifier)
          .reportChange(
            movieNumber: normalizedMovieNumber,
            isSubscribed: subscribe,
          );
      return subscribe
          ? const MovieSubscriptionToggleResult.subscribed()
          : const MovieSubscriptionToggleResult.unsubscribed();
    } catch (error) {
      if (isMovieSubscriptionBlockedByMedia(error)) {
        return const MovieSubscriptionToggleResult.blockedByMedia();
      }
      return MovieSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: subscribe ? '订阅影片失败' : '取消订阅影片失败',
        ),
      );
    } finally {
      state = Set<String>.unmodifiable(
        state.where((number) => number != normalizedMovieNumber),
      );
    }
  }
}
