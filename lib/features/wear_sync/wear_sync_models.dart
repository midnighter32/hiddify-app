import 'dart:convert';

/// How a profile is carried over the Wear Data Layer.
enum SyncProfileKind { url, raw }

/// One profile pushed from the phone to the watch so the watch can run it
/// locally (proxy mode). Subscriptions travel as a URL; manual configs as raw.
class SyncProfile {
  const SyncProfile({required this.name, required this.kind, required this.payload});

  final String name;
  final SyncProfileKind kind;
  final String payload;

  Map<String, dynamic> toJson() => {'name': name, 'kind': kind.name, 'payload': payload};

  factory SyncProfile.fromJson(Map<String, dynamic> json) => SyncProfile(
        name: (json['name'] as String?) ?? '',
        kind: SyncProfileKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => SyncProfileKind.url,
        ),
        payload: (json['payload'] as String?) ?? '',
      );
}

const String kProfiles = 'profiles';
const String kTs = 'ts';

Map<String, dynamic> encodeSyncProfiles(List<SyncProfile> profiles) => {
      kProfiles: jsonEncode(profiles.map((p) => p.toJson()).toList()),
      kTs: DateTime.now().millisecondsSinceEpoch,
    };

List<SyncProfile> decodeSyncProfiles(Map<String, dynamic> mapData) {
  final raw = mapData[kProfiles];
  if (raw is! String || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((e) => SyncProfile.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();
}
