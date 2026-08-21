import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/utils/image_provider_utils.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// A model representing a user in the avatar stack
class AvatarUser {
  /// The user's ID
  final String id;

  /// The user's name
  final String name;

  /// The user's avatar URL
  final String? avatarUrl;

  /// Whether the user is online
  final bool isOnline;

  /// The user's status message
  final String? status;

  /// The timestamp when the user was last active
  final DateTime? lastActive;

  AvatarUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
    this.status,
    this.lastActive,
  });
}


/// The avatar itself — a real WELL, not bare initials on the page.
///
/// It was `CircleAvatar(backgroundColor: Colors.transparent)` with the
/// initials in `MlTokens.slate800`, and both halves of that are wrong at once:
/// there is no circle behind an avatar with no photo, and slate-800 on the
/// dark theme's card measures barely above the background it is painted on. In
/// this product almost nobody has uploaded a photo, so almost every avatar in
/// the chat header rendered as a grey smudge. Photographed 2026-08-21 on the
/// chat thread, where "FO TM SR" was three illegible marks above two green
/// dots that were the only visible part of the control.
///
/// Same treatment as `_Avatar` in the Messages screen: an accent tint at 14%
/// with accent-coloured initials, so it reads in both themes.
Widget _initialsAvatar(BuildContext context, AvatarUser user, double size) {
  final hasPhoto = (user.avatarUrl ?? '').isNotEmpty;
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: hasPhoto ? null : MlTokens.accent.withValues(alpha: 0.14),
      image: hasPhoto
          ? DecorationImage(
              image: imageProviderFromString(user.avatarUrl)!,
              fit: BoxFit.cover,
            )
          : null,
    ),
    child: hasPhoto
        ? null
        : Text(
            _initialsOf(user.name),
            style: TextStyle(
              color: MlTokens.accent,
              fontWeight: FontWeight.w800,
              fontSize: size / 3,
            ),
          ),
  );
}

/// Initials, without indexing into an empty string.
///
/// `name.split(' ')` on `"Thandi "` yields `['Thandi', '']`, and the old
/// version then read `parts[1][0]` — a RangeError on a trailing space in a
/// display name, which is a thing a person types.
String _initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// A widget that displays a stack of avatars with presence indicators
class AvatarStack extends StatelessWidget {
  /// The list of users to display
  final List<AvatarUser> users;

  /// The maximum number of avatars to display
  final int maxDisplayed;

  /// The size of each avatar
  final double avatarSize;

  /// The overlap between avatars
  final double overlap;

  /// Whether to show the online indicator
  final bool showOnlineIndicator;

  /// Callback when an avatar is tapped
  final Function(AvatarUser user)? onAvatarTap;

  /// Whether to show the total count of users
  final bool showTotalCount;

  /// The background color of the count circle
  final Color? countBackgroundColor;

  /// The text color of the count
  final Color? countTextColor;

  const AvatarStack({
    super.key,
    required this.users,
    this.maxDisplayed = 4,
    this.avatarSize = 40,
    this.overlap = 0.3,
    this.showOnlineIndicator = true,
    this.onAvatarTap,
    this.showTotalCount = true,
    this.countBackgroundColor,
    this.countTextColor,
  });

  @override
  Widget build(BuildContext context) {
    // Sort users by online status
    final sortedUsers = List<AvatarUser>.from(users)
      ..sort((a, b) => a.isOnline == b.isOnline ? 0 : (a.isOnline ? -1 : 1));

    // Determine how many avatars to display
    final displayCount = sortedUsers.length > maxDisplayed
        ? maxDisplayed
        : sortedUsers.length;
    final remainingCount = sortedUsers.length - displayCount;
    final totalVisibleItems =
        displayCount + (remainingCount > 0 && showTotalCount ? 1 : 0);
    final horizontalOffset = avatarSize * (1 - overlap);
    final stackWidth = totalVisibleItems == 0
        ? 0.0
        : avatarSize +
              (totalVisibleItems > 1
                  ? (totalVisibleItems - 1) * horizontalOffset
                  : 0);

    if (totalVisibleItems == 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: stackWidth,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Display avatars
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * horizontalOffset,
              child: _buildAvatar(context, sortedUsers[i]),
            ),

          // Display count if needed
          if (remainingCount > 0 && showTotalCount)
            Positioned(
              left: displayCount * horizontalOffset,
              child: _buildCountCircle(context, remainingCount),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, AvatarUser user) {
    return GestureDetector(
      onTap: onAvatarTap != null ? () => onAvatarTap!(user) : null,
      child: Stack(
        children: [
          _initialsAvatar(context, user, avatarSize),
          if (showOnlineIndicator && user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: avatarSize / 4,
                height: avatarSize / 4,
                decoration: BoxDecoration(
                  color: MlTokens.green600,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountCircle(BuildContext context, int count) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: countBackgroundColor ?? Theme.of(context).primaryColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '+$count',
          style: TextStyle(
            color: countTextColor ?? MlTokens.inkOnFill,
            fontWeight: FontWeight.bold,
            fontSize: avatarSize / 3,
          ),
        ),
      ),
    );
  }

}

/// A widget that displays a horizontal list of avatars with presence indicators
class AvatarList extends StatelessWidget {
  /// The list of users to display
  final List<AvatarUser> users;

  /// The size of each avatar
  final double avatarSize;

  /// Whether to show the online indicator
  final bool showOnlineIndicator;

  /// Callback when an avatar is tapped
  final Function(AvatarUser user)? onAvatarTap;

  /// The spacing between avatars
  final double spacing;

  /// Whether to show the user's name
  final bool showName;

  /// The text style for the user's name
  final TextStyle? nameStyle;

  const AvatarList({
    super.key,
    required this.users,
    this.avatarSize = 40,
    this.showOnlineIndicator = true,
    this.onAvatarTap,
    this.spacing = 16.0,
    this.showName = true,
    this.nameStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Sort users by online status
    final sortedUsers = List<AvatarUser>.from(users)
      ..sort((a, b) => a.isOnline == b.isOnline ? 0 : (a.isOnline ? -1 : 1));

    return SizedBox(
      height: showName ? avatarSize + 24 : avatarSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sortedUsers.length,
        separatorBuilder: (context, index) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          final user = sortedUsers[index];
          return GestureDetector(
            onTap: onAvatarTap != null ? () => onAvatarTap!(user) : null,
            child: Column(
              children: [
                Stack(
                  children: [
                    _initialsAvatar(context, user, avatarSize),
                    if (showOnlineIndicator && user.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: avatarSize / 4,
                          height: avatarSize / 4,
                          decoration: BoxDecoration(
                            color: MlTokens.green600,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      user.name,
                      style: nameStyle ?? const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

}
