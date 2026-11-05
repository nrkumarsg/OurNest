import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Something another app shared into OurNest (audit F44).
///
/// Android lists OurNest in the share menu (text, links and images). Before,
/// nothing received the shared item, so the app just opened. Now the family
/// chat opens with the text pre-filled, or asks to send the shared photos.
@immutable
class PendingShare {
  final String? text;
  final List<String> imagePaths;

  const PendingShare({this.text, this.imagePaths = const []});

  bool get isEmpty => (text == null || text!.trim().isEmpty) && imagePaths.isEmpty;

  /// Max photos accepted from one share, to avoid accidental mass uploads.
  static const maxImages = 10;

  /// Converts the plugin's items. Videos and other files aren't supported by
  /// the chat yet, so they're ignored (the user sees nothing pre-filled).
  static PendingShare fromMedia(List<SharedMediaFile> items) {
    final texts = <String>[];
    final images = <String>[];
    for (final item in items) {
      switch (item.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          if (item.path.trim().isNotEmpty) texts.add(item.path.trim());
        case SharedMediaType.image:
          if (images.length < maxImages) images.add(item.path);
          final caption = item.message?.trim();
          if (caption != null && caption.isNotEmpty) texts.add(caption);
        case SharedMediaType.video:
        case SharedMediaType.file:
          break;
      }
    }
    return PendingShare(
      text: texts.isEmpty ? null : texts.toSet().join('\n'),
      imagePaths: images,
    );
  }
}

/// The share waiting to be placed in the family chat (null when none).
final pendingShareProvider = StateProvider<PendingShare?>((ref) => null);

/// Listens for shares from other apps (Android only; iOS would need a Share
/// Extension target, which this project doesn't have yet).
class ShareIntake {
  ShareIntake._();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts listening. [onShare] is called for shares that arrive while the
  /// app is running; a share that cold-started the app is stored in
  /// [pendingShareProvider] and picked up after sign-in by the splash screen.
  static StreamSubscription<List<SharedMediaFile>>? start(
    WidgetRef ref, {
    required void Function(PendingShare share) onShare,
  }) {
    if (!isSupported) return null;
    try {
      ReceiveSharingIntent.instance.getInitialMedia().then((items) {
        final share = PendingShare.fromMedia(items);
        if (!share.isEmpty) ref.read(pendingShareProvider.notifier).state = share;
        ReceiveSharingIntent.instance.reset();
      }).catchError((Object e) {
        debugPrint('Share intake (initial) failed: $e');
      });

      return ReceiveSharingIntent.instance.getMediaStream().listen((items) {
        final share = PendingShare.fromMedia(items);
        if (share.isEmpty) return;
        ref.read(pendingShareProvider.notifier).state = share;
        onShare(share);
      }, onError: (Object e) => debugPrint('Share intake failed: $e'));
    } catch (e) {
      debugPrint('Share intake unavailable: $e');
      return null;
    }
  }
}
