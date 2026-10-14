class AuthReply {
  const AuthReply({required this.accessToken, required this.user, required this.expiresIn});
  final String accessToken;
  final AppUser user;
  final int expiresIn;

  factory AuthReply.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (rawUser is! Map) throw const FormatException('The sign-in response did not include a user.');
    return AuthReply(
      accessToken: (json['access_token'] ?? '').toString(),
      user: AppUser.fromJson(Map<String, dynamic>.from(rawUser)),
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
    );
  }
}

class AppUser {
  const AppUser({required this.id, required this.email, required this.fullName, required this.role, required this.isDemo});
  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isDemo;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        fullName: (json['full_name'] ?? '').toString(),
        role: (json['role'] ?? 'FARMER').toString(),
        isDemo: json['is_demo'] == true,
      );
}

class SchemeRecord {
  const SchemeRecord({
    required this.slug,
    required this.name,
    required this.department,
    required this.category,
    required this.level,
    required this.summary,
    required this.benefitSummary,
    required this.sourceName,
    required this.sourceUrl,
    required this.applicationUrl,
    required this.sourceCheckedAt,
    required this.nameMr,
    required this.evaluation,
    required this.saved,
    required this.documents,
    required this.applicationProcess,
    required this.documentReviewNote,
  });

  final String slug;
  final String name;
  final String nameMr;
  final String department;
  final String category;
  final String level;
  final String summary;
  final String benefitSummary;
  final String sourceName;
  final String sourceUrl;
  final String applicationUrl;
  final String sourceCheckedAt;
  final Map<String, dynamic> evaluation;
  final bool saved;
  final List<Map<String, dynamic>> documents;
  final List<String> applicationProcess;
  final String documentReviewNote;

  int get profileMatch => (evaluation['profile_match'] as num?)?.toInt() ?? 0;
  String get eligibilityStatus => (evaluation['status'] ?? 'INSUFFICIENT_INFORMATION').toString();
  List<String> get matchReasons => _stringList(evaluation['match_reasons']);
  List<String> get decisionReasons => _stringList(evaluation['decision_reasons']);
  List<Map<String, dynamic>> get checks => _mapList(evaluation['eligibility_rules']);

  factory SchemeRecord.fromJson(Map<String, dynamic> json) {
    final rawEvaluation = json['evaluation'];
    final evaluation = rawEvaluation is Map ? Map<String, dynamic>.from(rawEvaluation) : const <String, dynamic>{};
    final evaluatedDocuments = _mapList(evaluation['documents']);
    return SchemeRecord(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? 'Scheme').toString(),
      nameMr: (json['name_mr'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      level: (json['level'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      benefitSummary: (json['benefit_summary'] ?? '').toString(),
      sourceName: (json['source_name'] ?? '').toString(),
      sourceUrl: (json['source_url'] ?? '').toString(),
      applicationUrl: (json['application_url'] ?? '').toString(),
      sourceCheckedAt: (json['source_checked_at'] ?? json['last_verified_at'] ?? '').toString(),
      evaluation: evaluation,
      saved: json['saved'] == true,
      documents: evaluatedDocuments.isNotEmpty ? evaluatedDocuments : _mapList(json['document_items']),
      applicationProcess: _stringList(json['application_process']),
      documentReviewNote: (json['document_review_note'] ?? '').toString(),
    );
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }
}
