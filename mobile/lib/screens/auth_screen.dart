import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../l10n.dart';
import '../models.dart';

const bool _enableReleaseDemo = bool.fromEnvironment('ENABLE_DEMO_LOGIN', defaultValue: false);

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.api,
    required this.language,
    required this.onLanguageChanged,
    required this.onAuthenticated,
  });

  final ApiClient api;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final Future<void> Function(AuthReply reply) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _district = TextEditingController();
  final _taluka = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  String t(String key) => AppCopy.t(widget.language, key);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _district.dispose();
    _taluka.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final AuthReply reply;
      if (_registering) {
        reply = await widget.api.register(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          district: _district.text.trim(),
          taluka: _taluka.text.trim(),
        );
      } else {
        reply = await widget.api.login(_email.text.trim(), _password.text);
      }
      await widget.onAuthenticated(reply);
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException ? error.message : 'Sign-in could not be completed. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDemo() async {
    setState(() { _busy = true; _error = null; });
    try {
      final reply = await widget.api.openDemo();
      await widget.onAuthenticated(reply);
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException ? error.message : 'The demo is unavailable.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLegal(String path) async {
    final base = widget.api.baseUrl;
    if (base == null) return;
    final uri = Uri.parse('$base$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final showDemo = !kReleaseMode || _enableReleaseDemo;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Align(alignment: Alignment.centerRight, child: PopupMenuButton<String>(
                  tooltip: t('language'),
                  onSelected: widget.onLanguageChanged,
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'en', child: Text(t('english'))),
                    PopupMenuItem(value: 'mr', child: Text(t('marathi'))),
                    PopupMenuItem(value: 'hi', child: Text(t('hindi'))),
                  ],
                  icon: const Icon(Icons.translate_rounded),
                )),
                Center(child: Image.asset('assets/icon/app_icon.png', width: 72, height: 72)),
                const SizedBox(height: 14),
                Text('Scheme Mitra', textAlign: TextAlign.center, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF173A2A))),
                const SizedBox(height: 4),
                Text(t('tagline'), textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF637466))),
                const SizedBox(height: 22),
                Card(child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(_registering ? t('createAccount') : t('signInTitle'), style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(t('signInBody'), style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF657568))),
                    const SizedBox(height: 18),
                    if (_registering) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        decoration: InputDecoration(labelText: t('fullName'), counterText: ''),
                        validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter your name.' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      maxLength: 254,
                      decoration: InputDecoration(labelText: t('email'), counterText: ''),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return email.contains('@') && email.contains('.') ? null : 'Enter a valid email address.';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      maxLength: 128,
                      decoration: InputDecoration(
                        labelText: t('password'),
                        counterText: '',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) return 'Enter your password.';
                        if (_registering && (value!.length < 12 || !RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value))) {
                          return 'Use 12+ characters with letters and numbers.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_registering) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(controller: _district, textCapitalization: TextCapitalization.words, maxLength: 100, decoration: InputDecoration(labelText: t('district'), counterText: ''))),
                        const SizedBox(width: 10),
                        Expanded(child: TextFormField(controller: _taluka, textCapitalization: TextCapitalization.words, maxLength: 100, decoration: InputDecoration(labelText: t('taluka'), counterText: ''))),
                      ]),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBox(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_registering ? t('registerAction') : t('loginAction')),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() { _registering = !_registering; _error = null; }),
                      child: Text(_registering ? t('switchLogin') : t('switchRegister')),
                    ),
                    if (showDemo) ...[
                      const Divider(height: 24),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _openDemo,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(t('tryDemo')),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(t('authNote'), textAlign: TextAlign.center, style: textTheme.bodySmall?.copyWith(color: const Color(0xFF69786C))),
                  ])),
                )),
                const SizedBox(height: 14),
                Text(t('independent'), textAlign: TextAlign.center, style: textTheme.labelMedium?.copyWith(color: const Color(0xFF607064))),
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.center, spacing: 18, children: [
                  TextButton(onPressed: () => _openLegal('/privacy'), child: Text(t('privacy'))),
                  TextButton(onPressed: () => _openLegal('/terms'), child: Text(t('terms'))),
                  TextButton(onPressed: () => _openLegal('/support'), child: Text(t('support'))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: const Color(0xFFFFF0ED), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF1D3CD))),
        padding: const EdgeInsets.all(12),
        child: Text(message, style: const TextStyle(color: Color(0xFF92382F))),
      );
}
