import 'package:flutter/material.dart';

class NotificationItem {
  final String id;
  final String type;
  final IconData icon;
  final String title;
  final String body;
  final String? time;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.icon,
    required this.title,
    required this.body,
    this.time,
  });
}

class NotificationsState {
  final List<NotificationItem> notifications;
  final bool isLoading;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = true,
  });

  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
  }) => NotificationsState(
    notifications: notifications ?? this.notifications,
    isLoading: isLoading ?? this.isLoading,
  );
}
