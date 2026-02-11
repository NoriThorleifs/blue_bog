import 'package:flutter/material.dart';

class NodeData {
  const NodeData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.offset,
    required this.url,
  });

  final String id;
  final String title;
  final String subtitle;
  final Offset offset;
  final String url;
}

class LineData {
  const LineData(this.fromNodeId, this.toNodeId, this.color);

  final String fromNodeId;
  final String toNodeId;
  final Color color;
}

const allNodes = [
  NodeData(
    id: '1',
    title: 'Node 1',
    subtitle: 'The first node',
    offset: Offset(400, 400),
    url: '/node/1',
  ),
  NodeData(
    id: '2',
    title: 'Node 2',
    subtitle: 'The second node',
    offset: Offset(800, 600),
    url: '/node/2',
  ),
  NodeData(
    id: '3',
    title: 'Node 3',
    subtitle: 'The third node',
    offset: Offset(200, 600),
    url: '/node/3',
  ),
  NodeData(
    id: '4',
    title: 'Node 4',
    subtitle: 'The fourth node',
    offset: Offset(1000, 400),
    url: '/node/4',
  ),
  NodeData(
    id: '5',
    title: 'Node 5',
    subtitle: 'The fifth node',
    offset: Offset(1200, 600),
    url: '/node/5',
  ),
  NodeData(
    id: '6',
    title: 'Node 6',
    subtitle: 'The sixth node',
    offset: Offset(1400, 400),
    url: '/node/6',
  ),
];

const allLines = [
  LineData('1', '2', Colors.blue),
  LineData('1', '3', Colors.blue),
  LineData('2', '4', Colors.red),
  LineData('4', '5', Colors.grey),
];
