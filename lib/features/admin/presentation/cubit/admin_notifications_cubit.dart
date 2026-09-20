import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../data/models/admin_notification_model.dart';
import '../../data/repos/admin_notifications_repo.dart';

class AdminNotificationsState {
  final List<AdminNotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const AdminNotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = true,
    this.error,
  });

  AdminNotificationsState copyWith({
    List<AdminNotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => AdminNotificationsState(
    notifications: notifications ?? this.notifications,
    unreadCount: unreadCount ?? this.unreadCount,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class AdminNotificationsCubit extends Cubit<AdminNotificationsState> {
  final AdminNotificationsRepo _repo;

  AdminNotificationsCubit(this._repo) : super(const AdminNotificationsState());

  Future<void> load() async {
    try {
      emit(state.copyWith(isLoading: true));
      final results = await Future.wait([
        _repo.getNotifications(),
        _repo.getUnreadCount(),
      ]);
      emit(
        state.copyWith(
          notifications: results[0] as List<AdminNotificationModel>,
          unreadCount: results[1] as int,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorLoadFailed));
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      final count = await _repo.getUnreadCount();
      emit(state.copyWith(unreadCount: count));
    } catch (e) {
      emit(state.copyWith(error: LangKeys.errorLoadFailed));
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _repo.markAsRead(id);
      await load();
    } catch (e) {
      emit(state.copyWith(error: LangKeys.errorSaveFailed));
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      await load();
    } catch (e) {
      emit(state.copyWith(error: LangKeys.errorSaveFailed));
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
