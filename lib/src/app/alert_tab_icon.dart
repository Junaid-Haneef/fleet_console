part of '../app.dart';

class _AlertTabIcon extends StatelessWidget {
  const _AlertTabIcon({required this.count, this.active = false});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final icon = active ? Icons.warning_amber : Icons.warning_amber_outlined;
    if (count <= 0) {
      return Icon(icon);
    }

    final badgeText = count > 99 ? '99+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -10,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 18),
            child: Text(
              badgeText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
