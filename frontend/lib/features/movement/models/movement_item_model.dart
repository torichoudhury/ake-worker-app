// lib/features/movement/models/movement_item_model.dart
import '../../sales/models/dropdown_options_model.dart';

class MovementItem {
  final LookupOption item;
  final LookupOption thread;
  final LookupOption length;
  final LookupOption head;
  final LookupOption colour; // Before Colour
  final double? quantity; // Before Quantity
  final String? uom; // Before UoM
  final double? packet;
  final int? perPacket;
  final String? packetUom;

  // After Plating Fields
  final LookupOption? afterColour;
  final double? afterQuantity;
  final String? afterUom;
  final double? afterPacket;
  final int? afterPerPacket;
  final String? afterPacketUom;

  const MovementItem({
    required this.item,
    required this.thread,
    required this.length,
    required this.head,
    required this.colour,
    this.quantity,
    this.uom,
    this.packet,
    this.perPacket,
    this.packetUom,
    this.afterColour,
    this.afterQuantity,
    this.afterUom,
    this.afterPacket,
    this.afterPerPacket,
    this.afterPacketUom,
  });
}
