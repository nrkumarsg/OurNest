import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../family/presentation/family_controller.dart';

class MemberPickerSheet extends ConsumerStatefulWidget {
  final List<String> initiallySelectedIds;
  final ValueChanged<List<String>> onSelected;

  const MemberPickerSheet({
    super.key,
    required this.initiallySelectedIds,
    required this.onSelected,
  });

  @override
  ConsumerState<MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<MemberPickerSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initiallySelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers = ref.watch(activeMembersProvider);
    final myMembership = ref.watch(currentMembershipProvider).value;

    // Filter out oneself from the selectable recipient list
    final otherMembers =
        activeMembers.where((m) => m.userId != myMembership?.userId).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Send to Selected Members',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Only selected family members will receive and be able to decrypt this message.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: otherMembers.length,
              itemBuilder: (ctx, i) {
                final member = otherMembers[i];
                final isSelected = _selectedIds.contains(member.userId);

                return CheckboxListTile(
                  value: isSelected,
                  activeColor: AppColors.primaryTeal,
                  contentPadding: EdgeInsets.zero,
                  secondary: CircleAvatar(
                    backgroundColor: AppColors.primaryTeal.withOpacity(0.12),
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                  title: Text(
                    member.displayName,
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    member.formattedRelation,
                    style: GoogleFonts.nunito(fontSize: 14),
                  ),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedIds.add(member.userId);
                      } else {
                        _selectedIds.remove(member.userId);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.onSelected(_selectedIds.toList());
              Navigator.pop(context);
            },
            child: Text('Done (${_selectedIds.length} selected)'),
          ),
        ],
      ),
    );
  }
}
