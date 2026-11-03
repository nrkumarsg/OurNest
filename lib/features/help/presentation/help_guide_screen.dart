import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/nest_logo.dart';

class HelpGuideScreen extends StatefulWidget {
  const HelpGuideScreen({super.key});

  @override
  State<HelpGuideScreen> createState() => _HelpGuideScreenState();
}

class _HelpGuideScreenState extends State<HelpGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Setup & Family',
    'Family Tree & Peace',
    'Chat & Privacy',
    'Shared Alarms',
    'Reminders',
    'Media & Share',
    'Accessibility',
    'Troubleshooting',
  ];

  late final List<_HelpTopic> _topics = [
    const _HelpTopic(
      category: 'Setup & Family',
      title: '1. Getting Started & Sign In',
      icon: Icons.mark_email_read_rounded,
      color: AppColors.primaryTeal,
      summary: '100% Free Dynamic Email OTP login and rich personal family profile setup.',
      steps: [
        'Open OurNest and enter your email address for 100% free, dynamic verification.',
        'Enter the 6-digit verification code or tap the instant confirmation link in your email. No passwords to remember or lose.',
        'Set up your Rich Family Profile: upload your Photo, Display Name, Status Line, Sex, Blood Group, Date of Birth, Living Place, Education, Occupation, Working Place, Working Details, and Bio.',
        'OurNest securely generates your unique cryptographic device keys inside your phone\'s hardware vault (Android KeyStore / iOS Keychain).',
        'Your profile information is strictly private and only visible to approved members of your family circle.',
      ],
      quickActionLabel: 'Edit Profile in Settings',
      quickActionRoute: '/profile-setup?edit=true',
    ),
    const _HelpTopic(
      category: 'Setup & Family',
      title: '2. Creating & Joining a Family Circle',
      icon: Icons.family_restroom_rounded,
      color: AppColors.accentCoral,
      summary: 'How families connect, invite codes, QR scanning, and admin approvals.',
      steps: [
        'Create a Family: Tap "Create a Family", choose a family name (e.g. "The Sharma Family"), and select your role (e.g. Father). You become the Family Admin.',
        'Invite Code & QR: As the Admin, tap the QR icon on the Family screen to view your unique 6-character code (e.g. "SHRM92") and shareable QR code.',
        'Join a Family: New members tap "Join a Family", type the 6-character code or scan the Admin\'s QR code, and select their relation (e.g. Son, Daughter, Mother).',
        'Admin Approval Safety Gate: To keep strangers out, the Admin must tap "Approve" (✓) before the new member can see or send any messages.',
        '12 Family Relations: Father, Mother, Son, Daughter, Grandfather, Grandmother, Brother, Sister, Uncle, Aunt, Spouse, or Other with custom nickname.',
      ],
      quickActionLabel: 'Open Family Circle',
      quickActionRoute: '/family',
    ),
    const _HelpTopic(
      category: 'Chat & Privacy',
      title: '3. End-to-End Encryption (E2EE)',
      icon: Icons.security_rounded,
      color: AppColors.primaryTeal,
      summary: 'Military-grade privacy: zero outsiders, zero server eavesdropping.',
      steps: [
        'Device-Side Encryption: Every message, photo, and voice note is encrypted using libsodium (X25519 and XChaCha20-Poly1305) directly on your phone.',
        'Zero Server Knowledge: The server only ever stores encrypted ciphertext. Nobody—not even system admins—can read your family\'s conversations.',
        'Private Hardware Storage: Your encryption keys never leave your phone and are protected by your device\'s hardware security module.',
        'Old Message Isolation: For absolute security, new members cannot read messages sent before they joined, and new phones cannot read past history without device key transfer.',
        'Safe Push Notifications: Push notifications are data-only and never contain message text or media previews.',
      ],
    ),
    const _HelpTopic(
      category: 'Chat & Privacy',
      title: '4. Everyone vs. Selected (Audience Control)',
      icon: Icons.group_rounded,
      color: AppColors.accentCoral,
      summary: 'Choose who receives each message: the entire family or specific members.',
      steps: [
        'Look above the chat typing bar for the Audience toggle: "Everyone" | "Selected...".',
        'Everyone (Default): Sends the message to every approved member of the family.',
        'Selected: Opens a member picker. Check the boxes for the members you wish to include (e.g. Mom & Dad only).',
        'Guaranteed Cryptographic Isolation: Members who are not selected do not receive message keys. They cannot decrypt or see the message in their feed.',
        '1-to-1 Private Direct Chats: Tap any family member from the Home screen to open a private 1-on-1 encrypted chat channel.',
        'Delete for Everyone: Long-press any sent message and tap "Delete for Everyone" to replace it with a tombstone.',
      ],
      quickActionLabel: 'Open Family Chat',
      quickActionRoute: '/chat/family',
    ),
    const _HelpTopic(
      category: 'Shared Alarms',
      title: '5. Shared Wake-Up Alarms & Escalation',
      icon: Icons.alarm_rounded,
      color: AppColors.accentCoralDark,
      summary: 'Smart typing alarms that ring the owner\'s phone and escalate if they oversleep.',
      steps: [
        'Smart NLP Typing Detection: Type phrases like "wake me up 8am", "alarm 7:30", or "wake Rahul at 6am" in chat. A highlighted suggestion chip pops up immediately!',
        'Tap the Suggestion Chip to instantly schedule the alarm, or tap the "+" icon and choose "Set Shared Alarm".',
        'Interactive Chat Alarm Card: An interactive card appears in the family chat showing status, target time, owner, and escalation member.',
        'Exact Local Alarm: The owner\'s phone rings at the exact minute with a full-screen alarm, audio, and vibration.',
        'Owner Screen: Features a giant button "I\'M AWAKE ✓" and a Snooze option. Tapping "I\'M AWAKE" sends an automatic confirmation to the family chat.',
        'Escalation Alarm: If the person does NOT wake up within the grace period (e.g. 5 minutes), the parent\'s phone rings with a red alert and a prominent "[📞 Call Him]" phone dialer button!',
      ],
    ),
    const _HelpTopic(
      category: 'Reminders',
      title: '6. Family Reminders & Calendar Events',
      icon: Icons.event_note_rounded,
      color: AppColors.primaryTeal,
      summary: 'Remind parents about medicines, doctors, tuition, and family events.',
      steps: [
        'Tap the "+" icon on the left of the chat bar and select "Family Reminder / Event".',
        'Enter the title (e.g. "Grandma Doctor Appointment", "Rahul Tuition Fees Due", "Family Dinner").',
        'Pick the date, reminder time, and add optional notes.',
        'Choose whether to notify "All Family Members" or "Individual Members".',
        'An interactive Calendar Card appears in the chat with a one-tap "[📅 Add to Calendar]" button that syncs directly to Google Calendar or Apple Calendar.',
        'Tap the checkbox on the reminder card to mark it as completed for the whole family.',
      ],
    ),
    const _HelpTopic(
      category: 'Media & Share',
      title: '7. Voice Notes, Photos & YouTube Sharing',
      icon: Icons.mic_rounded,
      color: AppColors.accentCoral,
      summary: 'Hold-to-record voice notes, encrypted photos, and one-touch social sharing.',
      steps: [
        'Voice Notes: Press and hold the Microphone icon in the chat bar to record. Features a live wave timer. Slide left to the Trash Can to cancel.',
        'Audio Playback: Includes play/pause, duration display, and a seek scrubber.',
        'Encrypted Photos: Tap "+" and select "Take a Photo" or "Choose from Gallery". Photos are encrypted on-device with pinch-to-zoom fullscreen viewer.',
        'One-Touch Social Sharing: While watching YouTube or reading an article in Chrome/Safari, tap your phone\'s system "Share" button and select "OurNest". The link or photo will open straight in your family chat ready to send!',
      ],
    ),
    const _HelpTopic(
      category: 'Accessibility',
      title: '8. Elderly-Friendly Accessibility & Display',
      icon: Icons.accessibility_new_rounded,
      color: AppColors.primaryTeal,
      summary: 'Large text mode (+20%), warm contrast colors, and 48dp touch targets.',
      steps: [
        'Minimum 16sp Text: All body text throughout OurNest is kept at a minimum of 16sp for easy legibility.',
        'Large Text Mode: Open Settings (⚙️) and switch on "Large Text Mode" to increase all fonts by 20%.',
        'Dark Mode: Toggle Dark Mode in Settings to reduce glare and eye fatigue.',
        '48dp Minimum Touch Targets: All buttons and interactive icons are sized at 48dp or larger to prevent accidental clicks.',
        'Warm Color Palette: Deep Forest Teal (#1F5C57), Warm Terracotta (#E07A4F), and Soft Cream (#F7F4EE) for high contrast and calm aesthetics.',
      ],
      quickActionLabel: 'Configure in Settings',
      quickActionRoute: '/settings',
    ),
    const _HelpTopic(
      category: 'Troubleshooting',
      title: '9. FAQ & Troubleshooting Guide',
      icon: Icons.help_outline_rounded,
      color: AppColors.textSecondaryLight,
      summary: 'Answers to common questions and system permission guidelines.',
      steps: [
        'Why didn\'t my alarm ring? Open your phone\'s Settings > Apps > OurNest > Permissions > ensure "Alarms & Reminders" is set to Allowed.',
        'Battery Optimization: Set Battery to "Unrestricted" so Android Doze or iOS sleep doesn\'t delay alarms or push notifications.',
        'Why can\'t I see old messages? Because OurNest uses zero-knowledge encryption, only devices present when a message was sent hold the decryption keys.',
        'Can people outside my family message me? No. OurNest has no public directory, no stranger search, and no unsolicited messages.',
        'Where do ads appear? Non-intrusive family sponsor cards appear exclusively on the Home screen between Family Chat and Direct Messages. Zero pop-ups or chat disruptions.',
        'Attribution: Developed by ARKIS PTE LTD. All rights reserved.',
      ],
    ),
    const _HelpTopic(
      category: 'Setup & Family',
      title: '10. Rich Personal Profiles & Birthday Reminders',
      icon: Icons.badge_rounded,
      color: AppColors.primaryTeal,
      summary: 'Complete member cards with photo, DOB, age, mobile/WhatsApp numbers, home address, education, work details & automatic birthday alerts.',
      steps: [
        'Tap any family member in the Family screen to open their Rich Personal Profile Sheet.',
        'Includes Profile Photo, Display Name, Relation badge, Status Quote, Sex, Blood Group, Date of Birth, automatic Age, and Birthday Countdown.',
        'Shows Mobile Phone Number, WhatsApp Number (with 1-tap Call & WhatsApp buttons), Living Place / City, Full Home / Residential Address (with 1-tap [🗺️ Map Address] Google Maps navigation), Education, Occupation, Working Place, Working Details, and Bio.',
        'Open the "🎂 Birthdays" tab on the Family screen to see all upcoming family birthdays sorted by days remaining, with a 1-tap "Send Birthday Wish 🎂" button.',
      ],
      quickActionLabel: 'Edit My Personal Profile',
      quickActionRoute: '/profile-setup?edit=true',
    ),
    const _HelpTopic(
      category: 'Family Tree & Peace',
      title: '11. Connected Family Tree, Church/Temple Volunteers & Broadcasts',
      icon: Icons.account_tree_rounded,
      color: AppColors.accentCoral,
      summary: 'Link Relative Families, Friend Families, and Church/Temple Volunteer Groups (including single members) & send 1-tap multi-group broadcasts.',
      steps: [
        'Daily Chat Stays Private: By default, all messages in your family chat stay strictly inside your nuclear family ("🏠 My Family").',
        '3-Ring Connection System: In "🌳 Family Tree", tap "Link Family / Friend / Temple / Church" to connect: (1) 🌳 Relative Families, (2) 🤝 Friend & Neighbour Families, or (3) 🛕⛪ Church Fellowship / Temple Seva / Volunteer Groups.',
        'Single Member & Volunteer Support: Unmarried youth, solo seniors, church members, and temple volunteers can join any group directly using 1-tap role chips ("🛕 Temple Volunteer", "⛪ Church Member", "👑 Group Coordinator", "👤 Single Member").',
        '📢 Multi-Group Broadcast & Custom Circles: Tap "📢 Broadcast & Custom Groups" in the Family Tree to broadcast announcements to All Relatives, All Friends, All Church/Temple Volunteers, or Saved Custom Circles in 1 tap!',
        'Send Family-to-Family Invitations: Tap "Send Invitation / Message" on any linked group to message their Entire Group, Admins/Coordinators Only, or an Individual Member.',
      ],
      quickActionLabel: 'Open Family Tree',
      quickActionRoute: '/family',
    ),
    const _HelpTopic(
      category: 'Family Tree & Peace',
      title: '12. Silent Curtain (Peace & Hide Mode — Better Than Block)',
      icon: Icons.curtains_closed_rounded,
      color: AppColors.primaryTeal,
      summary: 'Had a disagreement between two families? Silently hide or pause a relative family with zero notification and zero drama.',
      steps: [
        'Why Not Block? In real families, blocking or deleting a relative\'s family causes embarrassment and escalates arguments. Silent Curtain gives you peace without notifying the other family.',
        '🪟 Curtain Mode (Hide Completely): Completely hides that relative family from your Family Tree, Chat, and Birthdays—tucking them into a discreet "Hidden Branches" drawer at the bottom.',
        '🕊️ Peace Pause (7 / 30 Days Cooling-Off): Keeps the family in your tree, but silently mutes their cross-family invitations and alerts while everyone cools down.',
        '🛡️ Privacy Shield (Hide Our Updates): Prevents your family\'s invitations, status, working/living details, and birthday alerts from being shared with that family.',
        'Two Scopes & 1-Tap Reconciliation: Apply Curtain Mode for your "🏠 Entire Family" (Admin) or "👤 Only On My Phone". Whenever the families make peace, tap "Lift Curtain" to restore instantly!',
      ],
      quickActionLabel: 'Manage in Family Tree',
      quickActionRoute: '/family',
    ),
    const _HelpTopic(
      category: 'Chat & Privacy',
      title: '13. Smart Family Composer & Action Hub',
      icon: Icons.chat_bubble_outline_rounded,
      color: AppColors.accentCoralDark,
      summary: 'Floating pill composer, 1-tap family quick phrases, emoji switcher, and 8-tile Family Action Hub.',
      steps: [
        'Floating Pill Input Bar: Expands smoothly from 1 to 5 lines with a built-in 😊/⌨️ Emoji & Quick Phrase toggle, 📎 Family Action Hub button, and auto-hiding 📷 quick camera.',
        'Morphing Action Orb: Shows 🎙️ (Hold to record encrypted voice note) when the box is empty, and smoothly morphs into ➤ (Send) the moment you type.',
        'Docked 8-Tile Family Action Hub: Tap 📎 to access Gallery, Camera, Wake Alarm, Family Event, Voice Note, Live Location, Family Ask, and Paste Link in one clean grid.',
        '📍 Live & Current GPS Location: Tap "Live Location" in the 📎 Action Hub (or the GPS icon in the chat top bar) to share your exact satellite coordinates with a 1-tap [🗺️ Open Live Location in Google Maps] button!',
        '1-Tap Family Quick Phrases: Tap 😊 to send instant warm family chips like "Reached safely ❤️", "Had food? 🍛", "Call me when free 📞", or "Wake me up ⏰".',
      ],
      quickActionLabel: 'Try Smart Composer',
      quickActionRoute: '/chat/family',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Instructions'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primaryTeal,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded, size: 20), text: 'Features Guide'),
            Tab(icon: Icon(Icons.account_tree_rounded, size: 20), text: 'Visual Flows'),
            Tab(icon: Icon(Icons.question_answer_rounded, size: 20), text: 'FAQ & Tips'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildFeaturesTab(),
            _buildVisualFlowsTab(),
            _buildFaqTab(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // TAB 1: FEATURES GUIDE
  // ---------------------------------------------------------
  Widget _buildFeaturesTab() {
    final filteredTopics = _topics.where((t) {
      final matchesCategory =
          _selectedCategory == 'All' || t.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.summary.toLowerCase().contains(q) ||
          t.steps.any((s) => s.toLowerCase().contains(q));
    }).toList();

    return Column(
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context).cardTheme.color,
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Search features (e.g. alarm, QR, voice, calendar)...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryTeal),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val.trim());
            },
          ),
        ),

        // Category Filter Chips
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(
                    cat,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryTeal,
                  backgroundColor: AppColors.cardLight,
                  onSelected: (val) {
                    setState(() => _selectedCategory = cat);
                  },
                ),
              );
            },
          ),
        ),

        // List of Topics
        Expanded(
          child: filteredTopics.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 48, color: AppColors.textSecondaryLight),
                        const SizedBox(height: 12),
                        Text(
                          'No topics found for "$_searchQuery"',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filteredTopics.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == filteredTopics.length) {
                      return _buildAttributionFooter();
                    }

                    final topic = filteredTopics[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: AppColors.dividerLight.withOpacity(0.8),
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: topic.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(topic.icon, color: topic.color, size: 24),
                          ),
                          title: Text(
                            topic.title,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          subtitle: Text(
                            topic.summary,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                bottom: 16,
                                top: 4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...topic.steps.asMap().entries.map((entry) {
                                    final stepIdx = entry.key + 1;
                                    final step = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            margin: const EdgeInsets.only(right: 8, top: 2),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: topic.color.withOpacity(0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '$stepIdx',
                                              style: GoogleFonts.nunito(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: topic.color,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              step,
                                              style: GoogleFonts.nunito(
                                                fontSize: 15,
                                                height: 1.45,
                                                color: AppColors.textPrimaryLight,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (topic.quickActionLabel != null &&
                                      topic.quickActionRoute != null) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                        label: Text(topic.quickActionLabel!),
                                        style: TextButton.styleFrom(
                                          foregroundColor: topic.color,
                                          textStyle: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onPressed: () {
                                          context.push(topic.quickActionRoute!);
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // TAB 2: VISUAL FLOWS
  // ---------------------------------------------------------
  Widget _buildVisualFlowsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildFlowCard(
          title: 'Shared Wake-Up Alarm Working Flow',
          color: AppColors.accentCoralDark,
          icon: Icons.alarm_rounded,
          description:
              'How alarms ring the sleeping family member and automatically escalate to relatives if they don\'t wake up.',
          steps: [
            const _FlowStep(
              number: '1',
              title: 'Trigger or Schedule',
              detail:
                  'Type "wake me up 7am" in chat, or tap "+" > Set Shared Alarm. An interactive Alarm Card is posted to the family chat.',
            ),
            const _FlowStep(
              number: '2',
              title: 'Exact Alarm Rings',
              detail:
                  'At the scheduled time, the owner\'s phone rings loudly with full-screen audio and vibration.',
            ),
            const _FlowStep(
              number: '3',
              title: 'Owner Taps "I\'M AWAKE ✓"',
              detail:
                  'Tapping the big awake button silences the alarm and broadcasts confirmation to the family.',
            ),
            const _FlowStep(
              number: '4',
              title: 'Escalation Alert (If Overslept)',
              detail:
                  'If the owner doesn\'t wake up within the grace period (e.g. 5 min), the family member\'s phone rings with an emergency alert and a one-tap [📞 Call Him] dialer button!',
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildFlowCard(
          title: 'Family Reminders & Calendar Sync Flow',
          color: AppColors.primaryTeal,
          icon: Icons.event_note_rounded,
          description:
              'How parents or members notify everyone about doctor visits, tuition fees, and events.',
          steps: [
            const _FlowStep(
              number: '1',
              title: 'Create Reminder',
              detail:
                  'Tap "+" in chat > "Family Reminder / Event". Set title, date, time, and target (All or Individual members).',
            ),
            const _FlowStep(
              number: '2',
              title: 'Interactive Chat Card',
              detail:
                  'The reminder appears in the family chat feed with date badge and target recipients.',
            ),
            const _FlowStep(
              number: '3',
              title: '1-Tap Native Calendar Add',
              detail:
                  'Recipients tap "[📅 Add to Calendar]" on the card to sync directly to Google Calendar or Apple Calendar.',
            ),
            const _FlowStep(
              number: '4',
              title: 'Mark as Completed',
              detail:
                  'Anyone can tap the checkbox to notify the family that the task is finished.',
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildFlowCard(
          title: 'Family Circle & Admin Safety Gate Flow',
          color: AppColors.accentCoral,
          icon: Icons.security_rounded,
          description:
              'How OurNest guarantees 100% safety with zero strangers and zero unsolicited messages.',
          steps: [
            const _FlowStep(
              number: '1',
              title: 'Admin Creates Family',
              detail:
                  'Generates a unique 6-character code (e.g. "SHRM92") and instant shareable QR code.',
            ),
            const _FlowStep(
              number: '2',
              title: 'Member Requests to Join',
              detail:
                  'Family member enters the code or scans the QR code and selects their relation (e.g. Son, Mother).',
            ),
            const _FlowStep(
              number: '3',
              title: 'Admin Approval Required',
              detail:
                  'Applicant waits at a safety screen until the Family Admin taps "Approve" (✓) in their circle management view.',
            ),
            const _FlowStep(
              number: '4',
              title: 'Encrypted Access Granted',
              detail:
                  'Keys are exchanged and the member can securely send and receive family messages and media.',
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildFlowCard(
          title: 'One-Touch Social & YouTube Share Flow',
          color: AppColors.primaryTeal,
          icon: Icons.share_rounded,
          description:
              'Share videos, recipes, or news articles straight to your family from other apps.',
          steps: [
            const _FlowStep(
              number: '1',
              title: 'Browse Anywhere',
              detail: 'Watch a video in YouTube, or browse an article in Chrome/Safari.',
            ),
            const _FlowStep(
              number: '2',
              title: 'Tap System "Share"',
              detail: 'Tap the native share button inside YouTube or your browser.',
            ),
            const _FlowStep(
              number: '3',
              title: 'Select "OurNest"',
              detail: 'Tap the OurNest icon in the list of share options.',
            ),
            const _FlowStep(
              number: '4',
              title: 'Instant Delivery',
              detail:
                  'OurNest opens into your family chat with the link pre-filled, ready to send with one tap!',
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildFlowCard(
          title: 'Connected Family Tree & Silent Curtain Flow',
          color: AppColors.primaryTeal,
          icon: Icons.account_tree_rounded,
          description:
              'How multiple relative families connect in a chain—and how Silent Curtain protects peace during family disagreements without blocking.',
          steps: [
            const _FlowStep(
              number: '1',
              title: 'Link Relative Family (QR or 6-Digit Code)',
              detail:
                  'In Family > "🌳 Family Tree", link Brother\'s, Sister\'s, or Grandparents\' family and set policy (All Members vs Admins Only).',
            ),
            const _FlowStep(
              number: '2',
              title: 'Send Cross-Family Invitations',
              detail:
                  'Daily chat stays private in your core family, while invitations and festival greetings can be sent across linked families.',
            ),
            const _FlowStep(
              number: '3',
              title: 'Activate Silent Curtain (If a Fight Happens)',
              detail:
                  'Tap "Hide / Peace" on any family branch to choose 🪟 Curtain Mode (Complete Hide), 🕊️ Peace Pause (7/30 Days), or 🛡️ Privacy Shield—with ZERO notification to the other family.',
            ),
            const _FlowStep(
              number: '4',
              title: '1-Tap Reconciliation',
              detail:
                  'When the families make peace, open the "🪟 Tucked Away / Hidden Branches" drawer at the bottom and tap "Lift Curtain" to restore everything seamlessly.',
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildAttributionFooter(),
      ],
    );
  }

  // ---------------------------------------------------------
  // TAB 3: FAQ & TIPS
  // ---------------------------------------------------------
  Widget _buildFaqTab() {
    final List<_FaqItem> faqs = [
      const _FaqItem(
        q: 'Why didn\'t my wake-up alarm ring on Android?',
        a: 'Android 12+ requires exact alarm permission. Go to your phone\'s Settings > Apps > OurNest > Permissions > ensure "Alarms & Reminders" is set to Allowed. Also set Battery to "Unrestricted" so the phone doesn\'t sleep through the alarm.',
      ),
      const _FaqItem(
        q: 'Why can\'t I see old messages after joining?',
        a: 'OurNest uses zero-knowledge End-to-End Encryption. Only phones present when a message was sent hold the cryptographic decryption keys. The server only holds ciphertext and cannot read or restore old keys to new devices.',
      ),
      const _FaqItem(
        q: 'How does "Selected" audience isolation work?',
        a: 'When you switch from "Everyone" to "Selected" and choose specific members (e.g. Mom & Dad), the message is encrypted solely with their public keys. Family members who were not selected never receive the keys and cannot see the message.',
      ),
      const _FaqItem(
        q: 'Can people outside my family find or message me?',
        a: 'No. OurNest has no public directory, no stranger search, and no unsolicited messages. Only people with your unique 6-character code who are approved by the Family Admin can interact with you.',
      ),
      const _FaqItem(
        q: 'How do I turn on Large Text Mode for grandparents?',
        a: 'Tap the Settings (⚙️) icon from the Home screen and switch on "Large Text Mode". This increases font sizes by 20% across all screens while maintaining WCAG AA high-contrast readability.',
      ),
      const _FaqItem(
        q: 'What should I do if a family member loses their phone?',
        a: 'The Family Admin can open the Family Circle screen, tap on the member, and select "Remove Member". This immediately revokes their access to the family circle.',
      ),
      const _FaqItem(
        q: 'Where do sponsor ads appear?',
        a: 'OurNest features clean, non-intrusive family sponsor cards located only on the Home screen between Family Chat and Direct Messages. There are zero pop-up ads, zero video interstitials, and zero distractions inside active chat bubbles.',
      ),
      const _FaqItem(
        q: 'What if two families in our Family Tree have a fight? Is there a way to hide them without "Blocking"?',
        a: 'Yes! OurNest includes "Silent Curtain (Peace & Hide Mode)" inside the 🌳 Family Tree tab. Unlike WhatsApp Block (which alerts the other person and creates more family drama), Curtain Mode completely hides that family from your Family Tree, Chat, and Birthdays—or puts them on a 7/30-day Peace Pause—while sending ZERO notification to the other family. When you reconcile, 1 tap on "Lift Curtain" restores them.',
      ),
      const _FaqItem(
        q: 'Can I hide a relative\'s family only on my phone, or for my whole family?',
        a: 'Both! Inside the Silent Curtain sheet, a Family Admin (Father/Mother) can hide a relative branch for "🏠 My Entire Family", or any individual member can select "👤 Only On My Phone" for personal peace of mind.',
      ),
      const _FaqItem(
        q: 'How do I add my Photo, Date of Birth, Living Place, Education, and Working Place?',
        a: 'Go to Settings > "Edit Personal Profile" (or tap the badge icon in the top bar of the Family screen). Once you add your Date of Birth, OurNest automatically calculates your age and adds a birthday countdown in the 🎂 Birthdays tab for your family.',
      ),
      const _FaqItem(
        q: 'Do Fathers/Mothers (Admins) and Sons/Daughters (Members) need separate APKs?',
        a: 'No! One single OurNest APK dynamically adapts its interface based on whether you created the family (Admin) or joined the family (Member).',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Quick help banner
        Card(
          color: AppColors.primaryTeal.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.primaryTeal.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: AppColors.primaryTeal, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Support & Assistance',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Have a question or need help setting up an elderly parent\'s device? We are here to help.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // FAQs
        ...faqs.map((faq) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.dividerLight.withOpacity(0.8)),
            ),
            child: ExpansionTile(
              title: Text(
                faq.q,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 18, right: 18, bottom: 16, top: 4),
                  child: Text(
                    faq.a,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 24),
        _buildAttributionFooter(),
      ],
    );
  }

  // ---------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------
  Widget _buildFlowCard({
    required String title,
    required Color color,
    required IconData icon,
    required String description,
    required List<_FlowStep> steps,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const Divider(height: 24),
            ...steps.map((st) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        st.number,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            st.title,
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            st.detail,
                            style: GoogleFonts.nunito(
                              fontSize: 13.5,
                              height: 1.4,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributionFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NestLogoMark(size: 20),
              const SizedBox(width: 8),
              Text(
                'OurNest v1.0.0',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '© 2026 OurNest • Developed by ARKIS PTE LTD',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTopic {
  final String category;
  final String title;
  final IconData icon;
  final Color color;
  final String summary;
  final List<String> steps;
  final String? quickActionLabel;
  final String? quickActionRoute;

  const _HelpTopic({
    required this.category,
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.steps,
    this.quickActionLabel,
    this.quickActionRoute,
  });
}

class _FlowStep {
  final String number;
  final String title;
  final String detail;

  const _FlowStep({
    required this.number,
    required this.title,
    required this.detail,
  });
}

class _FaqItem {
  final String q;
  final String a;

  const _FaqItem({required this.q, required this.a});
}
