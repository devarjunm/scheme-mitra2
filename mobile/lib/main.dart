import 'package:material_ui/material_ui.dart';

import 'api_client.dart';
import 'l10n.dart';
import 'models.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SchemeMitraApp());
}

class SchemeMitraApp extends StatefulWidget {
  const SchemeMitraApp({super.key});

  @override
  State<SchemeMitraApp> createState() => _SchemeMitraAppState();
}

class _SchemeMitraAppState extends State<SchemeMitraApp> {
  late final ApiClient _api = ApiClient(onSessionExpired: _handleExpiredSession);
  AppUser? _user;
  bool _starting = true;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (_api.configurationError != null) {
      if (mounted) setState(() => _starting = false);
      return;
    }
    final storedLanguage = await _api.readUiLanguage();
    if (storedLanguage == 'en' || storedLanguage == 'mr' || storedLanguage == 'hi') _language = storedLanguage!;
    final token = await _api.readToken();
    if (token != null && token.isNotEmpty) {
      try {
        final result = await _api.currentUser();
        if (result['authenticated'] == true && result['user'] is Map) {
          _user = AppUser.fromJson(Map<String, dynamic>.from(result['user'] as Map));
        } else {
          await _api.clearToken();
        }
      } catch (_) {
        await _api.clearToken();
      }
    }
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _onAuthenticated(AuthReply reply) async {
    if (!mounted) return;
    setState(() => _user = reply.user);
  }

  Future<void> _handleExpiredSession() async {
    if (mounted) setState(() => _user = null);
  }

  Future<void> _signOut() async {
    try {
      await _api.logout();
    } catch (_) {
      await _api.clearToken();
    }
    if (mounted) setState(() => _user = null);
  }

  Future<void> _setLanguage(String value) async {
    if (value != 'en' && value != 'mr' && value != 'hi') return;
    if (value != _language && mounted) setState(() => _language = value);
    await _api.saveUiLanguage(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF39734D),
      brightness: Brightness.light,
      surface: const Color(0xFFFFFEFB),
    );
    return MaterialApp(
      title: 'Scheme Mitra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F7EF),
          foregroundColor: Color(0xFF173A2A),
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDCE6D8))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDCE6D8))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF559164), width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: _starting
          ? const _StartupView()
          : _api.configurationError != null
              ? _ApiConfigurationView(message: _api.configurationError!)
              : _user == null
                  ? AuthScreen(api: _api, language: _language, onLanguageChanged: _setLanguage, onAuthenticated: _onAuthenticated)
                  : FarmerHomeScreen(
                      api: _api,
                      user: _user!,
                      language: _language,
                      onLanguageChanged: _setLanguage,
                      onSignOut: _signOut,
                    ),
    );
  }
}

class _StartupView extends StatelessWidget {
  const _StartupView();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ApiConfigurationView extends StatelessWidget {
  const _ApiConfigurationView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFF39734D)),
                const SizedBox(height: 16),
                Text(AppCopy.t('en', 'tagline'), style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('Release builds accept only a configured HTTPS API origin; no local server address is bundled.', textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}
