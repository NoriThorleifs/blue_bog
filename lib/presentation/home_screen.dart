import 'package:blue_bog/data/map_data.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InteractiveViewer(
        transformationController: _transformationController,
        maxScale: 5.0,
        minScale: 0.1,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Stack(
          children: [
            Image.asset(
              'assets/galactic-map.jpg',
              fit: BoxFit.cover,
              width: 1920,
              height: 1920,
            ),
            CustomPaint(
              painter: LinePainter(
                nodes: allNodes,
                lines: allLines,
              ),
              child: Container(),
            ),
            ...allNodes.map((node) => Node(
                  offset: node.offset,
                  title: node.title,
                  subtitle: node.subtitle,
                  url: node.url,
                  transformationController: _transformationController,
                )),
          ],
        ),
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  const LinePainter({required this.nodes, required this.lines});

  final List<NodeData> nodes;
  final List<LineData> lines;

  @override
  void paint(Canvas canvas, Size size) {
    const nodeCenter = Offset(10, 10);
    for (final lineData in lines) {
      final fromNode = nodes.firstWhere((node) => node.id == lineData.fromNodeId);
      final toNode = nodes.firstWhere((node) => node.id == lineData.toNodeId);

      final paint = Paint()
        ..color = lineData.color
        ..strokeWidth = 2;
      final glowPaint = Paint()
        ..color = lineData.color.withOpacity(0.5)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawLine(
          fromNode.offset + nodeCenter, toNode.offset + nodeCenter, glowPaint);
      canvas.drawLine(
          fromNode.offset + nodeCenter, toNode.offset + nodeCenter, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class Node extends StatefulWidget {
  const Node({
    super.key,
    required this.offset,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.transformationController,
  });

  final Offset offset;
  final String title;
  final String subtitle;
  final String url;
  final TransformationController transformationController;

  @override
  State<Node> createState() => _NodeState();
}

class _NodeState extends State<Node> {
  OverlayEntry? _overlayEntry;
  bool _isTooltipVisible = false;

  @override
  void initState() {
    super.initState();
    widget.transformationController.addListener(_updateTooltip);
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_updateTooltip);
    _hideTooltip();
    super.dispose();
  }

  void _updateTooltip() {
    if (_isTooltipVisible) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _showTooltip() {
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final matrix = widget.transformationController.value;
        final newOffset = MatrixUtils.transformPoint(matrix, widget.offset);

        return Positioned(
          left: newOffset.dx + 25,
          top: newOffset.dy,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    onPressed: () {
                      _hideTooltip();
                      GoRouter.of(context).go(widget.url);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shadowColor: Colors.blue.withOpacity(0.5),
                      elevation: 8,
                    ),
                    child: const Text('Go'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isTooltipVisible = true;
    });
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isTooltipVisible = false;
    });
  }

  void _toggleTooltip() {
    if (_isTooltipVisible) {
      _hideTooltip();
    } else {
      _showTooltip();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.offset.dx,
      top: widget.offset.dy,
      child: GestureDetector(
        onTap: _toggleTooltip,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
