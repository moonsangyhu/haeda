import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_data.freezed.dart';
part 'notification_data.g.dart';

@freezed
class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    required String id,
    required String type,
    required String title,
    required String body,
    @JsonKey(name: 'data_json') Map<String, dynamic>? dataJson,
    @JsonKey(name: 'is_read') required bool isRead,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}

@freezed
class NotificationListData with _$NotificationListData {
  const factory NotificationListData({
    required List<NotificationItem> notifications,
    @JsonKey(name: 'unread_count') required int unreadCount,
  }) = _NotificationListData;

  factory NotificationListData.fromJson(Map<String, dynamic> json) =>
      _$NotificationListDataFromJson(json);
}
