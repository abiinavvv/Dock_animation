import 'package:flutter/material.dart';

/// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// [Widget] building the [MaterialApp].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (e) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[e.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(e, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dock of the reorderable [items].
class Dock<T> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  /// Initial [T] items to put in this [Dock].
  final List<T> items;

  /// Builder building the provided [T] item.
  final Widget Function(T) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T> extends State<Dock<T>> with TickerProviderStateMixin {
  /// [T] items being manipulated.
  late final List<T> _items = widget.items.toList();
  
  /// Current hover position
  double? _hoverX;
  
  /// Dragging item index
  int? _draggingIndex;
  
  /// Current drag position relative to dock
  Offset? _dragPosition;
  
  /// Global drag position for absolute positioning
  Offset? _globalDragPosition;
  
  /// Reference to dock position
  final GlobalKey _dockKey = GlobalKey();
  
  /// Item width including margins
  final double itemWidth = 64.0;

  /// Gets the relative position in the dock from a global position
  double? _getRelativeX(Offset? global) {
    if (global == null) return null;
    final RenderBox? renderBox = _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final local = renderBox.globalToLocal(global);
    return local.dx;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (_draggingIndex == null) {
          setState(() {
            _hoverX = event.localPosition.dx;
          });
        }
      },
      onExit: (event) {
        if (_draggingIndex == null) {
          setState(() {
            _hoverX = null;
          });
        }
      },
      child: Container(
        key: _dockKey,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black12,
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            
            return Draggable<int>(
              data: index,
              feedback: Material(
                color: Colors.transparent,
                child: widget.builder(item),
              ),
              childWhenDragging: SizedBox(
                width: itemWidth,
                child: Opacity(
                  opacity: 0.3,
                  child: widget.builder(item),
                ),
              ),
              onDragStarted: () {
                setState(() {
                  _draggingIndex = index;
                });
              },
              onDragUpdate: (details) {
                setState(() {
                  _globalDragPosition = details.globalPosition;
                  _dragPosition = Offset(
                    _getRelativeX(details.globalPosition) ?? 0,
                    details.localPosition.dy,
                  );
                });
              },
              onDragEnd: (details) {
                final targetIndex = _calculateTargetIndex();
                setState(() {
                  if (_draggingIndex != null && targetIndex != null && targetIndex != _draggingIndex) {
                    final item = _items.removeAt(_draggingIndex!);
                    _items.insert(targetIndex, item);
                  }
                  _draggingIndex = null;
                  _dragPosition = null;
                  _globalDragPosition = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..translate(_calculateOffset(index))
                  ..scale(_calculateScale(index)),
                child: widget.builder(item),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Calculate the target index based on current drag position
  int? _calculateTargetIndex() {
    if (_dragPosition == null) return null;
    
    // Get the relative x position in the dock
    final dx = _dragPosition!.dx;
    
    // Calculate the index based on position
    final rawIndex = (dx / itemWidth).round();
    
    // Clamp to valid range
    return rawIndex.clamp(0, _items.length - 1);
  }

  /// Calculate horizontal offset for each item during drag
  double _calculateOffset(int index) {
    if (_draggingIndex == null || _dragPosition == null) return 0;
    
    final targetIndex = _calculateTargetIndex();
    if (targetIndex == null) return 0;
    
    // Don't move the item being dragged
    if (index == _draggingIndex) return 0;
    
    // Calculate direction of movement
    final moveRight = targetIndex > _draggingIndex!;
    
    // Determine if this item needs to move
    if (moveRight) {
      if (index > _draggingIndex! && index <= targetIndex) {
        return -itemWidth;
      }
    } else {
      if (index < _draggingIndex! && index >= targetIndex) {
        return itemWidth;
      }
    }
    
    return 0;
  }

  /// Calculate scale based on hover position
  double _calculateScale(int index) {
    if (_hoverX == null || _draggingIndex != null) return 1.0;
    
    final itemCenter = index * itemWidth + itemWidth / 2;
    final distance = (_hoverX! - itemCenter).abs();
    
    const maxScale = 1.2;
    const scalingDistance = 100.0;
    
    if (distance >= scalingDistance) return 1.0;
    
    return 1.0 + (maxScale - 1.0) * 
      (1 - (distance / scalingDistance)) * 
      (1 - (distance / scalingDistance));
  }
}