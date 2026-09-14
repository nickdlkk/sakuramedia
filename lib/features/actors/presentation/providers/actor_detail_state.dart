import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';

@immutable
class ActorDetailState {
  const ActorDetailState({this.actor, this.errorMessage});

  final ActorDetailDto? actor;
  final String? errorMessage;

  ActorDetailState copyWith({
    Object? actor = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return ActorDetailState(
      actor:
          identical(actor, _sentinel) ? this.actor : actor as ActorDetailDto?,
      errorMessage:
          identical(errorMessage, _sentinel)
              ? this.errorMessage
              : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();
