import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/profile_store.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final bytes = context.watch<ProfileStore?>()?.avatar;
    final colors = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Icons.person_outline,
      size: diameter > 36 ? 30 : 24,
    );
    if (bytes == null && diameter <= 36) return placeholder;
    return SizedBox.square(
      dimension: diameter,
      child: ClipOval(
        child: ColoredBox(
          color: colors.secondaryContainer,
          child: bytes == null
              ? Center(
                  child: IconTheme(
                    data: IconThemeData(color: colors.onSecondaryContainer),
                    child: placeholder,
                  ),
                )
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(child: placeholder),
                ),
        ),
      ),
    );
  }
}
