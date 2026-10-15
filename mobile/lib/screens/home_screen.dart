import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../l10n.dart';
import '../models.dart';

class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({
    super.key,
    required this.api,
    required this.user,
    required this.language,
    required this.onLanguageChanged,
    required this.onSignOut,
  });

  final ApiClient api;
  final AppUser user;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final Future<void> Function() onSignOut;

  @override
  State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  int _tab = 0;
  String t(String key) => AppCopy.t(widget.language, key);

  Future<void> _signOut() async {
    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _OverviewTab(api: widget.api, user: widget.user, language: widget.language, onBrowse: () => setState(() => _tab = 1)),
      _SchemesTab(api: widget.api, language: widget.language),
      _SavedTab(api: widget.api, language: widget.language),
      _ApplicationsTab(api: widget.api, language: widget.language),
      _ProfileTab(api: widget.api, user: widget.user, language: widget.language, onSignOut: _signOut),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFE5F0DC), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.eco_rounded, size: 21, color: Color(0xFF39734D))),
          const SizedBox(width: 9),
          const Text('Scheme Mitra', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: t('language'),
            initialValue: widget.language,
            onSelected: widget.onLanguageChanged,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'en', child: Text(t('english'))),
              PopupMenuItem(value: 'mr', child: Text(t('marathi'))),
              PopupMenuItem(value: 'hi', child: Text(t('hindi'))),
            ],
            icon: const Icon(Icons.translate_rounded),
          ),
          IconButton(tooltip: t('signOut'), onPressed: _signOut, icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: t('home')),
          NavigationDestination(icon: const Icon(Icons.search_rounded), label: t('schemes')),
          NavigationDestination(icon: const Icon(Icons.bookmark_border_rounded), selectedIcon: const Icon(Icons.bookmark_rounded), label: t('saved')),
          NavigationDestination(icon: const Icon(Icons.assignment_outlined), selectedIcon: const Icon(Icons.assignment_rounded), label: t('applications')),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: t('profile')),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.api, required this.user, required this.language, required this.onBrowse});
  final ApiClient api;
  final AppUser user;
  final String language;
  final VoidCallback onBrowse;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<_OverviewData> _future;
  String t(String key) => AppCopy.t(widget.language, key);

  @override
  void initState() { super.initState(); _future = _load(); }
  @override
  void didUpdateWidget(covariant _OverviewTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.language != widget.language) setState(() => _future = _load()); }
  Future<_OverviewData> _load() async {
    final results = await Future.wait([widget.api.listSchemes(), widget.api.readProfile()]);
    final profileEnvelope = results[1] as Map<String, dynamic>;
    final profile = profileEnvelope['profile'] is Map ? Map<String, dynamic>.from(profileEnvelope['profile'] as Map) : <String, dynamic>{};
    final completeness = profileEnvelope['completeness'] is Map ? Map<String, dynamic>.from(profileEnvelope['completeness'] as Map) : <String, dynamic>{};
    return _OverviewData(results[0] as List<SchemeRecord>, profile, completeness);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<_OverviewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _RetryState(message: snapshot.error.toString(), onRetry: _retry, language: widget.language);
          final data = snapshot.data!;
          final district = (data.profile['district'] ?? '').toString();
          final taluka = (data.profile['taluka'] ?? '').toString();
          final location = [taluka, district].where((value) => value.trim().isNotEmpty).join(', ');
          final complete = (data.completeness['percent'] as num?)?.toInt() ?? 0;
          final shownName = widget.user.fullName.trim().isEmpty ? 'Farmer' : widget.user.fullName;
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
              if (widget.user.isDemo) Align(alignment: Alignment.centerLeft, child: _Pill(text: t('demoBadge'), color: const Color(0xFFEEF3E8), textColor: const Color(0xFF557045))),
              const SizedBox(height: 8),
              Text('${t('hello')}, $shownName', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF173A2A))),
              const SizedBox(height: 7),
              Text(t('homeHeading'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.12)),
              const SizedBox(height: 7),
              Text(t('homeSubheading'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF617266))),
              const SizedBox(height: 18),
              _TrustNotice(text: t('notGovernment')),
              const SizedBox(height: 14),
              Card(child: Padding(padding: const EdgeInsets.all(17), child: Row(children: [
                const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE7F0DD), child: Icon(Icons.agriculture_rounded, color: Color(0xFF39734D))),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('profileTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(location.isEmpty ? 'Maharashtra' : '$location · Maharashtra', style: const TextStyle(color: Color(0xFF667568))),
                  const SizedBox(height: 3),
                  Text('${t('profileCompletion')} $complete%', style: const TextStyle(fontSize: 12, color: Color(0xFF748276))),
                ])),
                TextButton(onPressed: widget.onBrowse, child: Text(t('schemes'))),
              ]))),
              const SizedBox(height: 20),
              Row(children: [Expanded(child: Text(t('schemes'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), TextButton(onPressed: widget.onBrowse, child: Text(t('searchSchemes')))]),
              const SizedBox(height: 8),
              if (data.schemes.isEmpty)
                _EmptyPublished(language: widget.language, onBrowse: widget.onBrowse)
              else
                ...data.schemes.take(3).map((scheme) => Padding(padding: const EdgeInsets.only(bottom: 11), child: _SchemeCard(
                  api: widget.api, scheme: scheme, language: widget.language,
                  onTap: () => _openScheme(context, widget.api, scheme, widget.language),
                ))),
              const SizedBox(height: 12),
              Text(t('officialDisclaimer'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D7A70))),
            ]),
          );
        },
      );
}

class _OverviewData {
  const _OverviewData(this.schemes, this.profile, this.completeness);
  final List<SchemeRecord> schemes;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> completeness;
}

class _SchemesTab extends StatefulWidget {
  const _SchemesTab({required this.api, required this.language});
  final ApiClient api;
  final String language;
  @override
  State<_SchemesTab> createState() => _SchemesTabState();
}

class _SchemesTabState extends State<_SchemesTab> {
  late Future<_ListData> _future;
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  String t(String key) => AppCopy.t(widget.language, key);
  String _categoryLabel(String category) => switch (category) {
    'Livestock' => t('filterLivestock'),
    'Fisheries' => t('filterFisheries'),
    _ => category,
  };
  final List<String> _categories = const [
    'Irrigation', 'Horticulture', 'Farm machinery', 'Crop production', 'Farm development',
    'Agriculture development', 'Natural resources / agriculture', 'Farmer welfare', 'Crop insurance',
    'Income support', 'Agricultural credit', 'Pension / social security', 'Solar energy / irrigation',
    'Post-harvest / agri infrastructure', 'Livestock', 'Fisheries',
  ];

  @override
  void initState() { super.initState(); _future = _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  void didUpdateWidget(covariant _SchemesTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.language != widget.language) setState(() => _future = _load()); }

  Future<_ListData> _load() async {
    final schemes = await widget.api.listSchemes(query: _query, category: _category ?? '');
    final savedList = await widget.api.listSaved();
    return _ListData(schemes, savedList.map((item) => item.slug).toSet());
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('searchSchemes'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) { _query = value; _refresh(); },
            decoration: InputDecoration(hintText: t('searchHint'), prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: () { _search.clear(); _query = ''; _refresh(); }, icon: const Icon(Icons.close_rounded))),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(t('all')), selected: _category == null, onSelected: (_) { _category = null; _refresh(); })),
            ..._categories.map((category) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(_categoryLabel(category)), selected: _category == category, onSelected: (_) { _category = _category == category ? null : category; _refresh(); }))),
          ])),
        ])),
        Expanded(child: FutureBuilder<_ListData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _RetryState(message: snapshot.error.toString(), onRetry: _refresh, language: widget.language);
            final data = snapshot.data!;
            if (data.schemes.isEmpty) return _EmptyPublished(language: widget.language, onBrowse: _refresh);
            return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 20), children: data.schemes.map((scheme) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _SchemeCard(
                api: widget.api,
                scheme: scheme,
                language: widget.language,
                isSavedOverride: data.saved.contains(scheme.slug),
                onChanged: _refresh,
                onTap: () => _openScheme(context, widget.api, scheme, widget.language),
              ),
            )).toList()));
          },
        )),
      ]);
}

class _ListData {
  const _ListData(this.schemes, this.saved);
  final List<SchemeRecord> schemes;
  final Set<String> saved;
}

class _SavedTab extends StatefulWidget {
  const _SavedTab({required this.api, required this.language});
  final ApiClient api;
  final String language;
  @override
  State<_SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<_SavedTab> {
  late Future<List<SchemeRecord>> _future;
  String t(String key) => AppCopy.t(widget.language, key);
  @override
  void initState() { super.initState(); _future = widget.api.listSaved(); }
  @override
  void didUpdateWidget(covariant _SavedTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.language != widget.language) setState(() => _future = widget.api.listSaved()); }
  void _refresh() => setState(() => _future = widget.api.listSaved());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SchemeRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _RetryState(message: snapshot.error.toString(), onRetry: _refresh, language: widget.language);
          final items = snapshot.data ?? const <SchemeRecord>[];
          if (items.isEmpty) return _EmptyState(icon: Icons.bookmark_border_rounded, title: t('savedEmptyTitle'), body: t('savedEmptyBody'));
          return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 24), children: [
            Text(t('saved'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            ...items.map((scheme) => Padding(padding: const EdgeInsets.only(bottom: 11), child: _SchemeCard(
              api: widget.api,
              scheme: scheme,
              language: widget.language,
              isSavedOverride: true,
              onChanged: _refresh,
              onTap: () => _openScheme(context, widget.api, scheme, widget.language),
            ))),
          ]));
        },
      );
}

class _ApplicationsTab extends StatefulWidget {
  const _ApplicationsTab({required this.api, required this.language});
  final ApiClient api;
  final String language;
  @override
  State<_ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<_ApplicationsTab> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _creating = false;
  String t(String key) => AppCopy.t(widget.language, key);
  @override
  void initState() { super.initState(); _future = widget.api.listApplications(); }
  @override
  void didUpdateWidget(covariant _ApplicationsTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.language != widget.language) setState(() => _future = widget.api.listApplications()); }
  void _refresh() => setState(() => _future = widget.api.listApplications());

  Future<void> _addEntry() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final schemes = await widget.api.listSchemes();
      if (!mounted) return;
      if (schemes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('noPublishedTitle'))));
        return;
      }
      String selected = schemes.first.slug;
      String selectedStatus = 'SUBMITTED';
      final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(t('applications')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: selected, isExpanded: true, items: schemes.map((item) => DropdownMenuItem(value: item.slug, child: Text(_schemeName(item, widget.language), maxLines: 2, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) setDialogState(() => selected = value); }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: selectedStatus, items: const [
            DropdownMenuItem(value: 'SUBMITTED', child: Text('Submitted (self-reported)')),
            DropdownMenuItem(value: 'UNDER_REVIEW', child: Text('Under review (self-reported)')),
            DropdownMenuItem(value: 'DOCUMENTS_REQUIRED', child: Text('Documents required (self-reported)')),
            DropdownMenuItem(value: 'UNKNOWN', child: Text('Not sure')),
          ], onChanged: (value) { if (value != null) setDialogState(() => selectedStatus = value); }),
          const SizedBox(height: 10),
          Text(t('applicationsEmptyBody'), style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('cancel'))), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t('save')))],
      )));
      if (confirmed == true) {
        await widget.api.createApplication({'scheme_slug': selected, 'status': selectedStatus, 'notes': ''});
        _refresh();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _RetryState(message: snapshot.error.toString(), onRetry: _refresh, language: widget.language);
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 24), children: [
            Row(children: [Expanded(child: Text(t('applications'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))), IconButton.filledTonal(onPressed: _creating ? null : _addEntry, tooltip: 'Add a tracker note', icon: const Icon(Icons.add_rounded))]),
            const SizedBox(height: 8),
            _TrustNotice(text: t('applicationsEmptyBody')),
            const SizedBox(height: 14),
            if (items.isEmpty)
              _EmptyState(icon: Icons.assignment_outlined, title: t('applicationsEmptyTitle'), body: t('applicationsEmptyBody'))
            else ...items.map((item) => Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE8F0E1), child: Icon(Icons.assignment_outlined, color: Color(0xFF39734D))),
              title: Text((item['scheme_name'] ?? 'Scheme').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${item['status'] ?? 'UNKNOWN'} · ${item['status_source'] ?? 'USER_ENTERED'}'),
              trailing: const Icon(Icons.edit_note_rounded),
            ))),
          ]));
        },
      );
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.api, required this.user, required this.language, required this.onSignOut});
  final ApiClient api;
  final AppUser user;
  final String language;
  final Future<void> Function() onSignOut;
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late Future<Map<String, dynamic>> _future;
  String t(String key) => AppCopy.t(widget.language, key);
  @override
  void initState() { super.initState(); _future = widget.api.readProfile(); }
  @override
  void didUpdateWidget(covariant _ProfileTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.language != widget.language) setState(() => _future = widget.api.readProfile()); }
  void _refresh() => setState(() => _future = widget.api.readProfile());

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _RetryState(message: snapshot.error.toString(), onRetry: _refresh, language: widget.language);
          final envelope = snapshot.data!;
          final profile = envelope['profile'] is Map ? Map<String, dynamic>.from(envelope['profile'] as Map) : <String, dynamic>{};
          return _ProfileForm(api: widget.api, user: widget.user, profile: profile, language: widget.language, onSignOut: widget.onSignOut, onRefresh: _refresh);
        },
      );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.api, required this.user, required this.profile, required this.language, required this.onSignOut, required this.onRefresh});
  final ApiClient api;
  final AppUser user;
  final Map<String, dynamic> profile;
  final String language;
  final Future<void> Function() onSignOut;
  final VoidCallback onRefresh;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final TextEditingController _district;
  late final TextEditingController _taluka;
  late final TextEditingController _village;
  late final TextEditingController _area;
  late final TextEditingController _crop;
  late String _farmerCategory;
  late String _socialCategory;
  late String _irrigation;
  late Set<String> _needs;
  bool _saving = false;
  String? _error;
  String t(String key) => AppCopy.t(widget.language, key);

  @override
  void initState() {
    super.initState();
    _district = TextEditingController(text: (widget.profile['district'] ?? '').toString());
    _taluka = TextEditingController(text: (widget.profile['taluka'] ?? '').toString());
    _village = TextEditingController(text: (widget.profile['village'] ?? '').toString());
    final area = widget.profile['land_area_acres'];
    _area = TextEditingController(text: area is num && area > 0 ? area.toString() : '');
    _crop = TextEditingController(text: (widget.profile['crop'] ?? '').toString());
    _farmerCategory = _allowed((widget.profile['farmer_category'] ?? 'unknown').toString(), const ['marginal','small','other','unknown'], 'unknown');
    _socialCategory = _allowed((widget.profile['social_category'] ?? 'not_provided').toString(), const ['not_provided','open','obc','sc','st','nav_buddhist','not_applicable'], 'not_provided');
    _irrigation = _allowed((widget.profile['irrigation'] ?? 'unknown').toString(), const ['yes','no','unknown'], 'unknown');
    final needs = widget.profile['support_needs'];
    _needs = needs is List ? needs.map((item) => item.toString()).toSet() : <String>{};
  }

  String _allowed(String value, List<String> options, String fallback) => options.contains(value) ? value : fallback;

  @override
  void dispose() {
    _district.dispose(); _taluka.dispose(); _village.dispose(); _area.dispose(); _crop.dispose(); super.dispose();
  }

  Future<void> _save() async {
    final area = _area.text.trim().isEmpty ? null : double.tryParse(_area.text.trim());
    if (_area.text.trim().isNotEmpty && (area == null || area < 0 || area > 100000)) {
      setState(() => _error = 'Enter a valid area in acres, or leave it blank.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.updateProfile({
        'district': _district.text.trim(),
        'taluka': _taluka.text.trim(),
        'village': _village.text.trim(),
        'land_area_acres': area,
        'crop': _crop.text.trim(),
        'farmer_category': _farmerCategory,
        'social_category': _socialCategory,
        'irrigation': _irrigation,
        'support_needs': _needs.toList(),
      });
      widget.onRefresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('profileSaved'))));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final deleted = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AccountDeletionScreen(
      api: widget.api, language: widget.language, isDemo: widget.user.isDemo,
    )));
    if (deleted == true) await widget.onSignOut();
  }

  Future<void> _openLegal(String path) async {
    final base = widget.api.baseUrl;
    if (base != null) await launchUrl(Uri.parse('$base$path'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 30), children: [
      Text(t('profileTitle'), style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(t('profileHelp'), style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF657568))),
      const SizedBox(height: 6),
      Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE6EFDE), child: Icon(Icons.person_rounded, color: Color(0xFF39734D))), title: Text(widget.user.fullName), subtitle: Text(widget.user.email), trailing: widget.user.isDemo ? _Pill(text: t('demoBadge'), color: const Color(0xFFEEF3E8), textColor: const Color(0xFF557045)) : null)),
      const SizedBox(height: 13),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(initialValue: 'Maharashtra', decoration: const InputDecoration(labelText: 'State'), items: const [DropdownMenuItem(value: 'Maharashtra', child: Text('Maharashtra'))], onChanged: null),
        const SizedBox(height: 10),
        TextFormField(controller: _district, textCapitalization: TextCapitalization.words, maxLength: 100, decoration: InputDecoration(labelText: t('district'), counterText: '')),
        const SizedBox(height: 10),
        TextFormField(controller: _taluka, textCapitalization: TextCapitalization.words, maxLength: 100, decoration: InputDecoration(labelText: t('taluka'), counterText: '')),
        const SizedBox(height: 10),
        TextFormField(controller: _village, textCapitalization: TextCapitalization.words, maxLength: 120, decoration: InputDecoration(labelText: t('village'), counterText: '')),
        const SizedBox(height: 10),
        TextFormField(controller: _area, keyboardType: const TextInputType.numberWithOptions(decimal: true), maxLength: 12, decoration: InputDecoration(labelText: t('landArea'), counterText: '')),
        const SizedBox(height: 10),
        TextFormField(controller: _crop, textCapitalization: TextCapitalization.words, maxLength: 100, decoration: InputDecoration(labelText: t('crop'), counterText: '')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: _farmerCategory, decoration: InputDecoration(labelText: t('farmSize')), items: [
          DropdownMenuItem(value: 'marginal', child: Text(t('marginal'))), DropdownMenuItem(value: 'small', child: Text(t('small'))), DropdownMenuItem(value: 'other', child: Text(t('other'))), DropdownMenuItem(value: 'unknown', child: Text(t('unknown'))),
        ], onChanged: (value) { if (value != null) setState(() => _farmerCategory = value); }),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: _socialCategory, decoration: InputDecoration(labelText: t('socialCategory')), items: [
          DropdownMenuItem(value: 'not_provided', child: Text(t('notProvided'))), DropdownMenuItem(value: 'open', child: Text(t('open'))), DropdownMenuItem(value: 'obc', child: Text(t('obc'))), DropdownMenuItem(value: 'sc', child: Text(t('sc'))), DropdownMenuItem(value: 'st', child: Text(t('st'))), DropdownMenuItem(value: 'nav_buddhist', child: Text(t('navBuddhist'))),
        ], onChanged: (value) { if (value != null) setState(() => _socialCategory = value); }),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: _irrigation, decoration: InputDecoration(labelText: t('irrigation')), items: [
          DropdownMenuItem(value: 'yes', child: Text(t('yes'))), DropdownMenuItem(value: 'no', child: Text(t('no'))), DropdownMenuItem(value: 'unknown', child: Text(t('unknown'))),
        ], onChanged: (value) { if (value != null) setState(() => _irrigation = value); }),
        const SizedBox(height: 12),
        Text(t('supportNeeds'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        ...[
          ('irrigation', 'needIrrigation'), ('horticulture', 'needHorticulture'), ('machinery', 'needMachinery'), ('income_support', 'needIncome'), ('crop_protection', 'needCropProtection'), ('livestock', 'needLivestock'), ('fisheries', 'needFisheries'),
        ].map((entry) => CheckboxListTile(
          value: _needs.contains(entry.$1),
          onChanged: (checked) => setState(() { if (checked == true) { _needs.add(entry.$1); } else { _needs.remove(entry.$1); } }),
          title: Text(t(entry.$2)),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        )),
        const SizedBox(height: 6),
        if (_error != null) _ErrorBox(message: _error!),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t('saveProfile'))),
      ]))),
      const SizedBox(height: 18),
      Text(t('accountPrivacy'), style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: Text(t('privacy')), trailing: const Icon(Icons.open_in_new), onTap: () => _openLegal('/privacy')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.description_outlined), title: Text(t('terms')), trailing: const Icon(Icons.open_in_new), onTap: () => _openLegal('/terms')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.support_agent_rounded), title: Text(t('support')), trailing: const Icon(Icons.open_in_new), onTap: () => _openLegal('/support')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFF9A332A)), title: Text(t('deleteAccount'), style: const TextStyle(color: Color(0xFF9A332A))), trailing: const Icon(Icons.chevron_right), onTap: _deleteAccount),
      ])),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: widget.onSignOut, icon: const Icon(Icons.logout_rounded), label: Text(t('signOut'))),
      const SizedBox(height: 10),
      Text(t('officialDisclaimer'), style: textTheme.bodySmall?.copyWith(color: const Color(0xFF68776B))),
    ]);
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1D3CD)),
        ),
        padding: const EdgeInsets.all(12),
        child: Text(message, style: const TextStyle(color: Color(0xFF92382F))),
      );
}

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key, required this.api, required this.language, required this.isDemo});
  final ApiClient api;
  final String language;
  final bool isDemo;
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;
  String t(String key) => AppCopy.t(widget.language, key);
  @override
  void dispose() { _password.dispose(); _confirmation.dispose(); super.dispose(); }

  Future<void> _delete() async {
    if (_confirmation.text != 'DELETE' || _password.text.isEmpty) {
      setState(() => _error = t('passwordRequired'));
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(t('deleteTitle')),
      content: Text(t('deleteWarning')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('cancel'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('deleteForever')))],
    ));
    if (confirmed != true) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.deleteAccount(password: _password.text);
      await widget.api.clearToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('deleteSuccess'))));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('deleteAccount'))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.delete_forever_outlined, size: 58, color: Color(0xFF9A332A)),
          const SizedBox(height: 12),
          Text(t('deleteTitle'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _TrustNotice(text: t('deleteWarning')),
          if (widget.isDemo) ...[
            const SizedBox(height: 12),
            const _ErrorBox(message: 'The synthetic demo account cannot be deleted.'),
          ] else ...[
            const SizedBox(height: 16),
            TextField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: t('confirmPassword'))),
            const SizedBox(height: 12),
            TextField(controller: _confirmation, textCapitalization: TextCapitalization.characters, autocorrect: false, decoration: InputDecoration(labelText: t('typeDelete'))),
            if (_error != null) ...[const SizedBox(height: 12), _ErrorBox(message: _error!)],
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _busy ? null : _delete, style: FilledButton.styleFrom(foregroundColor: const Color(0xFF9A332A)), child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(t('deleteForever'))),
          ],
        ]),
      );
}

class _SchemeCard extends StatefulWidget {
  const _SchemeCard({required this.api, required this.scheme, required this.language, required this.onTap, this.isSavedOverride, this.onChanged});
  final ApiClient api;
  final SchemeRecord scheme;
  final String language;
  final VoidCallback onTap;
  final bool? isSavedOverride;
  final VoidCallback? onChanged;
  @override
  State<_SchemeCard> createState() => _SchemeCardState();
}

class _SchemeCardState extends State<_SchemeCard> {
  bool _saving = false;
  bool? _localSaved;
  @override
  Widget build(BuildContext context) {
    final saved = _localSaved ?? widget.isSavedOverride ?? widget.scheme.saved;
    final title = _schemeName(widget.scheme, widget.language);
    return Card(child: InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE8F0E1), borderRadius: BorderRadius.circular(13)), child: Icon(_schemeIcon(widget.scheme.category), color: const Color(0xFF39734D))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2)),
            const SizedBox(height: 4),
            Text(widget.scheme.department, style: const TextStyle(color: Color(0xFF68766A), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: AppCopy.t(widget.language, saved ? 'removeSaved' : 'saveScheme'),
            onPressed: _saving ? null : () async {
              setState(() => _saving = true);
              try {
                await widget.api.saveScheme(widget.scheme.slug, save: !saved);
                if (!mounted) return;
                setState(() { _localSaved = !saved; _saving = false; });
                widget.onChanged?.call();
              } catch (error) {
                if (!mounted) return;
                setState(() => _saving = false);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved ? const Color(0xFF39734D) : null),
          ),
        ]),
        const SizedBox(height: 11),
        Text(widget.scheme.summary, style: const TextStyle(height: 1.45, color: Color(0xFF526256)), maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _Pill(text: widget.scheme.category.isEmpty ? 'Agriculture' : widget.scheme.category, color: const Color(0xFFF0F4EA), textColor: const Color(0xFF526B4C)),
          _Pill(text: AppCopy.eligibilityLabel(widget.language, widget.scheme.eligibilityStatus), color: _statusBackground(widget.scheme.eligibilityStatus), textColor: _statusForeground(widget.scheme.eligibilityStatus)),
        ]),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: Text(AppCopy.t(widget.language, 'eligibility'), style: const TextStyle(fontSize: 11, color: Color(0xFF778579)))),
      ])),
    ));
  }
}

class _SchemeDetailScreen extends StatefulWidget {
  const _SchemeDetailScreen({required this.api, required this.scheme, required this.language});
  final ApiClient api;
  final SchemeRecord scheme;
  final String language;
  @override
  State<_SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<_SchemeDetailScreen> {
  late Future<SchemeRecord> _future;
  bool _saving = false;
  String? _error;
  String t(String key) => AppCopy.t(widget.language, key);
  @override
  void initState() { super.initState(); _future = widget.api.readScheme(widget.scheme.slug); }
  Future<void> _reload() async {
    setState(() { _future = widget.api.readScheme(widget.scheme.slug); });
    await _future;
  }

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the official page.')));
    }
  }

  Future<void> _toggleSave(SchemeRecord scheme) async {
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.saveScheme(scheme.slug, save: !scheme.saved);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.language == 'mr' && widget.scheme.nameMr.isNotEmpty ? widget.scheme.nameMr : widget.scheme.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
        body: FutureBuilder<SchemeRecord>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _RetryState(message: snapshot.error.toString(), language: widget.language, onRetry: () => setState(() => _future = widget.api.readScheme(widget.scheme.slug)));
            final scheme = snapshot.data!;
            final title = _schemeName(scheme, widget.language);
            final evaluation = scheme.evaluation;
            return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 26), children: [
              Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: const Color(0xFFEAF2E3), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(scheme.category, style: const TextStyle(color: Color(0xFF557148), fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF173A2A))),
                const SizedBox(height: 7),
                Text('${scheme.department} · ${scheme.level}', style: const TextStyle(color: Color(0xFF5F7163))),
                const SizedBox(height: 14),
                _Pill(text: AppCopy.eligibilityLabel(widget.language, scheme.eligibilityStatus), color: _statusBackground(scheme.eligibilityStatus), textColor: _statusForeground(scheme.eligibilityStatus)),
              ])),
              const SizedBox(height: 13),
              _TrustNotice(text: t('notDecision')),
              if (_error != null) ...[const SizedBox(height: 8), _ErrorBox(message: _error!)],
              const SizedBox(height: 18),
              _Section(title: t('decisionReasons'), icon: Icons.rule_rounded, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ...scheme.decisionReasons.map((reason) => _Bullet(text: reason)),
                if (scheme.decisionReasons.isEmpty) _Bullet(text: t('notDecision')),
                _Bullet(text: evaluation['source_verified'] == true ? t('sourceVerified') : '${t('reviewStatus')}: not published or not verified.'),
              ])),
              const SizedBox(height: 12),
              _Section(title: t('eligibilityRules'), icon: Icons.fact_check_outlined, child: scheme.checks.isEmpty
                  ? Text(t('rulesUnavailable'), style: const TextStyle(color: Color(0xFF5F6E62), height: 1.45))
                  : Column(children: scheme.checks.map((rule) => _RuleTile(rule: rule, language: widget.language, onOpen: _open)).toList())),
              const SizedBox(height: 12),
              _Section(title: t('whyShown'), icon: Icons.lightbulb_outline_rounded, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: scheme.matchReasons.map((reason) => _Bullet(text: reason)).toList())),
              const SizedBox(height: 12),
              _Section(title: t('benefits'), icon: Icons.volunteer_activism_outlined, child: Text(scheme.benefitSummary.isEmpty ? 'Check the linked official source for current benefits.' : scheme.benefitSummary, style: const TextStyle(height: 1.5))),
              const SizedBox(height: 12),
              _Section(title: t('documents'), icon: Icons.description_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (scheme.documentReviewNote.isNotEmpty) ...[
                  Text(scheme.documentReviewNote, style: const TextStyle(color: Color(0xFF5F6E62), height: 1.45)),
                  const SizedBox(height: 8),
                ],
                if (scheme.documents.isEmpty)
                  Text(t('noDocs'), style: const TextStyle(color: Color(0xFF5F6E62), height: 1.45))
                else ...[
                  ...scheme.documents.map((document) => _DocumentTile(document: document, language: widget.language)),
                  const SizedBox(height: 6),
                  Text(t('selfReported'), style: const TextStyle(fontSize: 12, color: Color(0xFF6F7D71))),
                ],
              ])),
              if (scheme.applicationProcess.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(title: t('nextSteps'), icon: Icons.directions_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: scheme.applicationProcess.map((step) => _Bullet(text: step)).toList())),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: () => _open(scheme.sourceUrl), icon: const Icon(Icons.open_in_new_rounded), label: Text(t('officialPortal'))),
              if (scheme.applicationUrl.isNotEmpty) ...[
                const SizedBox(height: 9),
                FilledButton.icon(onPressed: () => _open(scheme.applicationUrl), icon: const Icon(Icons.open_in_new_rounded), label: Text(t('officialApply'))),
              ],
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _toggleSave(scheme),
                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(scheme.saved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
                label: Text(t(scheme.saved ? 'removeSaved' : 'saveScheme')),
              ),
              const SizedBox(height: 12),
              Text('${t('source')}: ${scheme.sourceName}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B796E))),
              if (scheme.sourceCheckedAt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('${t('lastChecked')}: ${scheme.sourceCheckedAt}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B796E))),
              ],
            ]);
          },
        ),
      );
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.language, required this.onOpen});
  final Map<String, dynamic> rule;
  final String language;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final status = (rule['status'] ?? 'unknown').toString();
    final color = switch (status) {
      'pass' => const Color(0xFF357448),
      'fail' => const Color(0xFF9A332A),
      _ => const Color(0xFF8A671D),
    };
    final icon = switch (status) {
      'pass' => Icons.check_circle_outline_rounded,
      'fail' => Icons.cancel_outlined,
      'not_applicable' => Icons.remove_circle_outline_rounded,
      _ => Icons.help_outline_rounded,
    };
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((rule['label'] ?? 'Rule').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text((rule['explanation'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF657367), height: 1.45)),
        if (rule['source_fact'] is String && (rule['source_fact'] as String).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${AppCopy.t(language, 'sourceFact')}: ${rule['source_fact']}', style: const TextStyle(fontSize: 11, color: Color(0xFF7A867C))),
        ],
        if (rule['source_url'] is String && (rule['source_url'] as String).isNotEmpty)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () => onOpen((rule['source_url'] as String)),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(AppCopy.t(language, 'ruleSource')),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact),
          )),
      ])),
    ]));
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.language});
  final Map<String, dynamic> document;
  final String language;
  @override
  Widget build(BuildContext context) {
    final state = (document['state'] ?? 'not_provided').toString();
    final stateKey = switch (state) {
      'self_reported_available' => 'docSelfReported',
      'needs_verification' => 'docNeedsVerification',
      'not_yet_required' => 'docNotYetRequired',
      'not_yet_issued' => 'docNotYetIssued',
      _ => 'docNotProvided',
    };
    final stage = (document['stage'] ?? '').toString();
    final subtitleParts = [if (stage.isNotEmpty) stage, AppCopy.t(language, stateKey)];
    if (document['validated'] == false) subtitleParts.add(AppCopy.t(language, 'docNotValidated'));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.description_outlined, color: Color(0xFF53734E)),
      title: Text((document['label'] ?? document['id'] ?? 'Document').toString()),
      subtitle: Text(subtitleParts.join(' · ')),
    );
  }
}

class _EmptyPublished extends StatelessWidget {
  const _EmptyPublished({required this.language, required this.onBrowse});
  final String language;
  final VoidCallback onBrowse;
  @override
  Widget build(BuildContext context) => _EmptyState(
        icon: Icons.fact_check_outlined,
        title: AppCopy.t(language, 'noPublishedTitle'),
        body: AppCopy.t(language, 'noPublishedBody'),
        action: TextButton.icon(onPressed: onBrowse, icon: const Icon(Icons.refresh_rounded), label: Text(AppCopy.t(language, 'retry'))),
      );
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry, required this.language});
  final String message;
  final VoidCallback onRetry;
  final String language;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, size: 42, color: Color(0xFF718074)),
        const SizedBox(height: 10),
        Text(AppCopy.t(language, 'errorTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF617065))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(AppCopy.t(language, 'retry'))),
      ])));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
        Icon(icon, size: 42, color: const Color(0xFF66815C)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        const SizedBox(height: 7),
        Text(body, style: const TextStyle(color: Color(0xFF637166), height: 1.45), textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 7), action!],
      ])));
}

class _TrustNotice extends StatelessWidget {
  const _TrustNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFFFFF9E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEDE1B8))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF86651B), size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF64552C), height: 1.4, fontSize: 13))),
        ]),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 20, color: const Color(0xFF52734B)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))]),
        const SizedBox(height: 11),
        child,
      ])));
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.circle, size: 7, color: Color(0xFF65875A))),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45, color: Color(0xFF46564A)))),
      ]));
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.textColor});
  final String text;
  final Color color;
  final Color textColor;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
      );
}

Color _statusBackground(String status) => switch (status) {
  'LIKELY_ELIGIBLE' => const Color(0xFFE8F5E9),
  'POTENTIALLY_ELIGIBLE' => const Color(0xFFFFF3D8),
  'NOT_ELIGIBLE' => const Color(0xFFFFEAE6),
  _ => const Color(0xFFEFF1ED),
};
Color _statusForeground(String status) => switch (status) {
  'LIKELY_ELIGIBLE' => const Color(0xFF2E7143),
  'POTENTIALLY_ELIGIBLE' => const Color(0xFF826019),
  'NOT_ELIGIBLE' => const Color(0xFF983A30),
  _ => const Color(0xFF5D6B60),
};

String _schemeName(SchemeRecord scheme, String language) => language == 'mr' && scheme.nameMr.isNotEmpty ? scheme.nameMr : scheme.name;
IconData _schemeIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('irrig') || value.contains('water')) return Icons.water_drop_outlined;
  if (value.contains('horticulture') || value.contains('fruit')) return Icons.spa_outlined;
  if (value.contains('machinery') || value.contains('mechan')) return Icons.agriculture_outlined;
  if (value.contains('insurance') || value.contains('crop')) return Icons.grass_outlined;
  return Icons.eco_outlined;
}

void _openScheme(BuildContext context, ApiClient api, SchemeRecord scheme, String language) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SchemeDetailScreen(api: api, scheme: scheme, language: language)));
}
