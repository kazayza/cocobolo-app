import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isExpanded;
  final Widget? child;
  final Function(bool)? onToggle;

  const CollapsibleSection({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.isExpanded,
    this.child,
    this.onToggle,
  }) : super(key: key);

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
    
    _iconAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        GestureDetector(
          onTap: () {
            widget.onToggle?.call(!widget.isExpanded);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                RotationTransition(
                  turns: _iconAnimation,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Content
        SizeTransition(
          sizeFactor: _controller,
          axisAlignment: -1.0,
          child: widget.child ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}