// lib/features/sales/models/cart_item_model.dart
import 'dropdown_options_model.dart';

class CartItem {
  final LookupOption item;
  final LookupOption thread;
  final LookupOption length;
  final LookupOption head;
  final LookupOption colour;
  final double quantity;
  final String uom;
  final double rate;

  const CartItem({
    required this.item,
    required this.thread,
    required this.length,
    required this.head,
    required this.colour,
    required this.quantity,
    required this.uom,
    required this.rate,
  });

  double get amount => quantity * rate;
}
