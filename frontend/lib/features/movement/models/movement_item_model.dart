// lib/features/movement/models/movement_item_model.dart
import '../../sales/models/dropdown_options_model.dart';

class MovementItem {
  final LookupOption item;
  final LookupOption thread;
  final LookupOption length;
  final LookupOption head;
  final LookupOption colour;
  final double quantity;
  final String uom;
  final double? packet;
  final int? perPacket;
  final String? packetUom;

  const MovementItem({
    required this.item,
    required this.thread,
    required this.length,
    required this.head,
    required this.colour,
    required this.quantity,
    required this.uom,
    this.packet,
    this.perPacket,
    this.packetUom,
  });
}
