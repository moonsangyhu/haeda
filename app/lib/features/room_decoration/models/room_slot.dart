/// 미니룸 슬롯 enum — 8개 슬롯 정의.
enum MiniroomSlot {
  wall,
  ceiling,
  window,
  shelf,
  plant,
  desk,
  rug,
  floor;

  /// 화면에 표시할 한글 라벨.
  String get label {
    switch (this) {
      case MiniroomSlot.wall:
        return '벽지';
      case MiniroomSlot.ceiling:
        return '천장';
      case MiniroomSlot.window:
        return '창';
      case MiniroomSlot.shelf:
        return '선반';
      case MiniroomSlot.plant:
        return '화분';
      case MiniroomSlot.desk:
        return '책상';
      case MiniroomSlot.rug:
        return '러그';
      case MiniroomSlot.floor:
        return '바닥';
    }
  }

  /// API body / path param 키 (snake_case).
  String get apiKey {
    switch (this) {
      case MiniroomSlot.wall:
        return 'wall';
      case MiniroomSlot.ceiling:
        return 'ceiling';
      case MiniroomSlot.window:
        return 'window';
      case MiniroomSlot.shelf:
        return 'shelf';
      case MiniroomSlot.plant:
        return 'plant';
      case MiniroomSlot.desk:
        return 'desk';
      case MiniroomSlot.rug:
        return 'rug';
      case MiniroomSlot.floor:
        return 'floor';
    }
  }

  /// 해당 슬롯이 받을 수 있는 아이템 카테고리 (Item.category).
  String get category {
    switch (this) {
      case MiniroomSlot.wall:
        return 'MR_WALL';
      case MiniroomSlot.ceiling:
        return 'MR_CEILING';
      case MiniroomSlot.window:
        return 'MR_WINDOW';
      case MiniroomSlot.shelf:
        return 'MR_SHELF';
      case MiniroomSlot.plant:
        return 'MR_PLANT';
      case MiniroomSlot.desk:
        return 'MR_DESK';
      case MiniroomSlot.rug:
        return 'MR_RUG';
      case MiniroomSlot.floor:
        return 'MR_FLOOR';
    }
  }

  /// API body 에서 사용하는 item_id 키 (PUT /me/room/miniroom body).
  String get itemIdKey => '${apiKey}_item_id';
}
