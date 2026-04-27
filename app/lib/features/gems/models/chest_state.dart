import 'package:json_annotation/json_annotation.dart';

enum ChestState {
  @JsonValue('no_chest')
  noChest,
  @JsonValue('locked')
  locked,
  @JsonValue('openable')
  openable,
  @JsonValue('opened')
  opened,
}
