import 'package:flutter/material.dart';

class BroadcastThumbnail extends StatelessWidget {
  final String url;

  const BroadcastThumbnail({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.primaryContainer,
      child: Center(
          child: Icon(Icons.ondemand_video, color: colors.onPrimaryContainer)),
    );

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: url.startsWith('https://')
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  frameBuilder: (context, child, frame, synchronous) =>
                      synchronous || frame != null ? child : placeholder,
                  errorBuilder: (context, error, stack) => placeholder,
                )
              : placeholder,
        ),
      ),
    );
  }
}
