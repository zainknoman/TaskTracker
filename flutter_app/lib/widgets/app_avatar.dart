import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../core/ui_helpers.dart';
import '../models/workspace_member.dart';

/// Same presets as `AVATAR_PRESETS` in js/utils.js.
const avatarPresetEmoji = [
  '👤', '👩', '👨', '👩‍💼', '👨‍💼', '👩‍💻', //
  '👨‍💻', '👩‍🔬', '👨‍🔬', '🧑‍🎨', '🧑‍🏫', '🧑‍💻',
];

/// Web `.team-avatar`: solid circle in the member color with white bold text.
class AppAvatar extends StatelessWidget {
  final Color color;
  final String text;
  final double size;
  final double? fontSize;
  const AppAvatar({
    super.key,
    required this.color,
    required this.text,
    this.size = 44,
    this.fontSize,
  });

  /// Avatar for a workspace member. `emoji` matches the team-card avatar
  /// (preset icon); otherwise initials, like the dashboard workload rows.
  factory AppAvatar.member(
    WorkspaceMember m, {
    double size = 44,
    bool emoji = false,
  }) {
    final color = parseHex(m.color);
    if (emoji) {
      final preset = m.avatarPreset;
      final icon =
          (preset != null && preset >= 0 && preset < avatarPresetEmoji.length)
          ? avatarPresetEmoji[preset]
          : '👤';
      return AppAvatar(
        color: color,
        text: icon,
        size: size,
        fontSize: size * .36,
      );
    }
    return AppAvatar(
      color: color,
      text: initials(m.displayName),
      size: size,
      fontSize: size * .21 + 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize ?? rem(1),
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
