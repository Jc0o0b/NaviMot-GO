/// Zasady przyznawania punktów i poziomy użytkownika.
class PointsRules {
  PointsRules._();

  static const int report = 10;
  static const int confirmation = 2;
  static const int placeAdded = 5;

  /// Progi punktowe kolejnych poziomów (indeks = poziom, wartość = min. punktów).
  static const List<int> levelThresholds = [0, 50, 150, 350, 700, 1200, 2000];

  static const List<String> levelNames = [
    'Nowicjusz',
    'Kierowca',
    'Podróżnik',
    'Wyga',
    'Ekspert',
    'Mistrz',
    'Legenda',
  ];

  /// Numer poziomu (1-based) dla danej liczby punktów.
  static int levelForPoints(int points) {
    var level = 1;
    for (var i = 0; i < levelThresholds.length; i++) {
      if (points >= levelThresholds[i]) {
        level = i + 1;
      } else {
        break;
      }
    }
    return level;
  }

  static String levelName(int level) {
    final idx = (level - 1).clamp(0, levelNames.length - 1);
    return levelNames[idx];
  }

  /// Minimalna liczba punktów na następny poziom (null = maksymalny poziom).
  static int? pointsForNextLevel(int points) {
    for (final t in levelThresholds) {
      if (points < t) return t;
    }
    return null;
  }

  /// Postęp 0..1 do następnego poziomu.
  static double progressToNextLevel(int points) {
    final next = pointsForNextLevel(points);
    if (next == null) return 1.0;
    final current = levelThresholds[levelForPoints(points) - 1];
    if (next <= current) return 1.0;
    return ((points - current) / (next - current)).clamp(0.0, 1.0);
  }
}

class UserProfile {
  final String uid;
  final String? email;
  final String displayName;
  final bool isGuest;
  final int points;
  final int reports;
  final int confirmations;

  const UserProfile({
    required this.uid,
    this.email,
    required this.displayName,
    this.isGuest = false,
    this.points = 0,
    this.reports = 0,
    this.confirmations = 0,
  });

  int get level => PointsRules.levelForPoints(points);
  String get levelName => PointsRules.levelName(level);
  int? get pointsForNextLevel => PointsRules.pointsForNextLevel(points);
  double get progressToNextLevel => PointsRules.progressToNextLevel(points);

  UserProfile copyWith({
    String? displayName,
    int? points,
    int? reports,
    int? confirmations,
  }) =>
      UserProfile(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        isGuest: isGuest,
        points: points ?? this.points,
        reports: reports ?? this.reports,
        confirmations: confirmations ?? this.confirmations,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        if (email != null) 'email': email,
        'displayName': displayName,
        'isGuest': isGuest,
        'points': points,
        'reports': reports,
        'confirmations': confirmations,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uid: json['uid'] as String? ?? '',
        email: json['email'] as String?,
        displayName: json['displayName'] as String? ?? 'Użytkownik',
        isGuest: json['isGuest'] as bool? ?? false,
        points: (json['points'] as num?)?.toInt() ?? 0,
        reports: (json['reports'] as num?)?.toInt() ?? 0,
        confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      );
}
