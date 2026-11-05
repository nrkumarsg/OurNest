import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/widgets/nest_logo.dart';
import '../../family/presentation/family_controller.dart';
import '../data/chat_repository.dart';
import 'chat_controller.dart';
import 'widgets/native_sponsor_card.dart';

class HomeChatScreen extends ConsumerWidget {
  const HomeChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registers this device for push notifications once per app run (F04).
    ref.watch(pushRegistrationProvider);
    final familyAsync = ref.watch(currentFamilyProvider);
    final membershipAsync = ref.watch(currentMembershipProvider);
    final activeMembers = ref.watch(activeMembersProvider);
    final familyMessagesAsync = ref.watch(familyMessagesProvider);
    final onlineUserIds = ref.watch(onlineUserIdsProvider);

    final fam = familyAsync.value;
    final myUid = membershipAsync.value?.userId;
    final otherMembers = activeMembers.where((m) => m.userId != myUid).toList();

    return Scaffold(
      appBar: AppBar(
        title: const NestWordmark(fontSize: 26),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help & Guide',
            onPressed: () => context.push('/help'),
          ),
          IconButton(
            icon: const Icon(Icons.people_rounded),
            tooltip: 'Family Circle',
            onPressed: () => context.push('/family'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Section: The Family Group Chat Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.push('/chat/family'),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const NestLogoMark(size: 42),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    fam?.name ?? 'Family Group',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTeal,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Everyone',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              familyMessagesAsync.when(
                                data: (msgs) {
                                  if (msgs.isEmpty) {
                                    return Text(
                                      'No messages yet. Say hello to your family! 👋',
                                      style: Theme.of(context).textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }
                                  final last = msgs.last;
                                  return Text(
                                    '${last.isMine ? "You" : (last.senderName ?? "Family")}: ${last.displayText}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                                loading: () => const Text('Loading...'),
                                error: (_, __) => const Text(''),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: AppColors.primaryTeal),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Non-intrusive Native Family Sponsor Card (Zero messaging disturbance)
              const NativeSponsorCard(),
              const SizedBox(height: 22),

              // Section 2: Direct 1-to-1 Chats with Members
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  'Direct Messages',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondaryLight,
                      ),
                ),
              ),
              const SizedBox(height: 10),

              if (otherMembers.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.person_add_rounded,
                            size: 48, color: AppColors.primaryTeal),
                        const SizedBox(height: 12),
                        Text(
                          'No other members in your family yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Invite your family members to start 1-to-1 chats.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Invite Family'),
                          onPressed: () => context.push('/family'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...otherMembers.map((member) {
                  final isMemberOnline = onlineUserIds.contains(member.userId);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                AppColors.primaryTeal.withOpacity(0.12),
                            child: Text(
                              member.displayName.isNotEmpty
                                  ? member.displayName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isMemberOnline
                                    ? const Color(0xFF2ECC71)
                                    : Colors.grey.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Text(
                            member.displayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            member.formattedRelation,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primaryTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        isMemberOnline
                            ? '🟢 Online now • Tap to chat privately'
                            : '⚪ Offline • Tap to chat privately',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: const Icon(Icons.chat_bubble_outline_rounded,
                          color: AppColors.primaryTeal),
                      onTap: () => context.push('/chat/${member.userId}'),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
