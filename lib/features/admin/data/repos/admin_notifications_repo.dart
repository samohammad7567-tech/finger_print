import '../data_source/admin_notifications_local_data_source.dart';
import '../models/admin_notification_model.dart';

class AdminNotificationsRepo {
  final AdminNotificationsLocalDataSource _dataSource;

  AdminNotificationsRepo(this._dataSource);

  Future<List<AdminNotificationModel>> getNotifications() =>
      _dataSource.getNotifications();

  Future<int> getUnreadCount() => _dataSource.getUnreadCount();

  Future<AdminNotificationModel> createNotification(
    AdminNotificationModel notification,
  ) => _dataSource.createNotification(notification);

  Future<void> markAsRead(String id) => _dataSource.markAsRead(id);

  Future<void> markAllAsRead() => _dataSource.markAllAsRead();

  Future<bool> hasNotificationForEmployeeMonth(
    String employeeId,
    String yearMonth,
  ) => _dataSource.hasNotificationForEmployeeMonth(employeeId, yearMonth);
}
