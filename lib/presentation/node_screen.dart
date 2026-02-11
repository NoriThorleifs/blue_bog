import 'package:flutter/material.dart';

class NodeScreen extends StatelessWidget {
  const NodeScreen({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Node $nodeId'),
      ),
      body: Center(
        child: Text('Content for Node $nodeId'),
      ),
    );
  }
}
