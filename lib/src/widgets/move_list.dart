import 'package:flutter/material.dart';

/// A scrollable, numbered SAN move list (1. e4 e5  2. Nf3 ...).
class MoveList extends StatelessWidget {
  final List<String> sanMoves;

  const MoveList({super.key, required this.sanMoves});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < sanMoves.length; i += 2) {
      final no = (i ~/ 2) + 1;
      final white = sanMoves[i];
      final black = (i + 1 < sanMoves.length) ? sanMoves[i + 1] : '';
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                  width: 32,
                  child: Text('$no.',
                      style: const TextStyle(color: Colors.grey))),
              Expanded(child: Text(white)),
              Expanded(child: Text(black)),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: rows.isEmpty
          ? const Center(child: Text('No moves yet'))
          : ListView(reverse: false, children: rows),
    );
  }
}
