import '../../features/family/presentation/widgets/family_qr_scanner_modal.dart'
    show parseInviteQrPayload;

/// Navigation rules (audit F26):
/// * signed-out users can only reach the splash / login screens;
/// * invite deep links (`ournest://invite/CODE`, `…/join?code=CODE`) open the
///   Join screen, even if the user has to sign in first;
/// * the email sign-in callback doesn't land on an unknown page.
class RouteGuard {
  RouteGuard._();

  static const publicPaths = {'/', '/phone-login', '/otp-verify'};

  /// A join link opened while signed out, resumed after sign-in.
  static String? pendingJoinLocation;

  /// Maps an incoming deep link to an app route, or null if it isn't one.
  static String? deepLinkTarget(Uri uri, {required bool loggedIn}) {
    final path = uri.path;
    final isLoginCallback = uri.host == 'login-callback' ||
        path == '/login-callback' ||
        path.startsWith('/login-callback/');
    if (isLoginCallback) {
      // Supabase finishes the sign-in itself; the OTP screen moves on as soon
      // as the session arrives.
      return loggedIn ? '/' : '/otp-verify';
    }

    // Some Flutter versions pass only the path of `ournest://invite/CODE`
    // (i.e. "/CODE"), so a bare code path is an invite too. Codes only use
    // the generate_invite_code() alphabet (uppercase, no 0/O/1/I), so normal
    // routes such as "/family" or "/notify" can never match.
    final bareCode = RegExp(r'^/[2-9A-HJ-NP-Z]{6}$').hasMatch(path);
    final isInvite = uri.host == 'invite' ||
        bareCode ||
        path.startsWith('/invite/') ||
        (path == '/join' && uri.queryParameters.containsKey('code'));
    if (!isInvite) return null;

    // Reuse the QR parser so every invite format behaves the same way.
    final invite = parseInviteQrPayload(
        bareCode && uri.host != 'invite' ? 'ournest://invite${uri.toString()}' : uri.toString());
    if (invite == null) return '/family-entry';
    return Uri(path: '/join-family', queryParameters: {
      'code': invite.code,
      if (invite.familyName != null) 'name': invite.familyName!,
    }).toString();
  }

  /// GoRouter redirect. Returns null to stay, or the location to go to.
  static String? redirect(Uri uri, {required bool loggedIn}) {
    final deepLink = deepLinkTarget(uri, loggedIn: loggedIn);
    final target = deepLink != null ? Uri.parse(deepLink) : uri;
    final path = target.path.isEmpty ? '/' : target.path;

    if (!loggedIn) {
      if (publicPaths.contains(path)) return deepLink;
      if (path == '/join-family') pendingJoinLocation = target.toString();
      return '/phone-login';
    }

    // Signed in: resume a join link that was opened before signing in.
    final pending = pendingJoinLocation;
    if (pending != null && (path == '/family-entry' || path == '/join-family')) {
      pendingJoinLocation = null;
      if (path == '/family-entry') return pending;
    }
    return deepLink;
  }
}
