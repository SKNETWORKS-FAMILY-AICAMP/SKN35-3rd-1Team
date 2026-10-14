import 'models.dart';
import 'models.dart' as data;
import 'diary.dart';

class ArtCollection {
  const ArtCollection({
    required this.id,
    required this.name,
    this.description = '',
    this.count = 0,
    this.previews = const [],
    this.artworkIds = const [],
  });
  final String id, name, description;
  final int count;
  final List<Artwork> previews;
  final List<String> artworkIds;
  factory ArtCollection.fromJson(Json j) => ArtCollection(
    id: text(j['id']),
    name: text(j['name']),
    description: text(j['description']),
    count: (j['artwork_count'] as num?)?.toInt() ?? 0,
    previews: items(
      j['previews'] ?? [],
    ).map((e) => Artwork.fromJson(object(e))).toList(),
    artworkIds: items(j['artwork_ids'] ?? []).map(text).toList(),
  );
  Json toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'artwork_count': count,
    'artwork_ids': artworkIds,
  };
}

/// A collection computed from view history (recent, frequent, artist, month).
/// Not stored on the server; [key] identifies it, e.g. `recent` or `artist-10`.
class AutoCollection {
  const AutoCollection({
    required this.key,
    required this.name,
    this.description = '',
    this.count = 0,
    this.cover,
  });
  final String key, name, description;
  final int count;
  final Artwork? cover;
  factory AutoCollection.fromJson(Json j) => AutoCollection(
    key: text(j['key']),
    name: text(j['name']),
    description: text(j['description']),
    count: (j['artwork_count'] as num?)?.toInt() ?? 0,
    cover: j['cover'] == null ? null : Artwork.fromJson(object(j['cover'])),
  );
}

class ArtworkPage {
  const ArtworkPage(this.items, this.cursor);
  final List<Artwork> items;
  final String? cursor;
  factory ArtworkPage.fromJson(Json j) => ArtworkPage(
    data.items(j['items']).map((e) => Artwork.fromJson(object(e))).toList(),
    j['next_cursor']?.toString(),
  );
}

class CritiquePage {
  const CritiquePage(this.entries, this.cursor);
  final List<DiaryEntry> entries;
  final String? cursor;
  factory CritiquePage.fromJson(Json j) => CritiquePage(
    items(j['items']).map((e) => DiaryEntry.fromJson(object(e))).toList(),
    j['next_cursor']?.toString(),
  );
}

class MemberActivity {
  const MemberActivity({
    required this.kind,
    required this.title,
    required this.at,
    this.artworkId,
    this.date,
  });
  final String kind, title, at;
  final String? artworkId, date;
  String get displayDate {
    final d = DateTime.tryParse(at);
    return d == null ? at : dateKey(d.toUtc().add(const Duration(hours: 9)));
  }

  factory MemberActivity.fromJson(Json j) => MemberActivity(
    kind: text(j['kind']),
    title: text(j['title']),
    at: text(j['occurred_at']),
    artworkId: j['artwork_id']?.toString(),
    date: j['entry_date']?.toString(),
  );
}

class TasteIntro {
  const TasteIntro({
    this.summary,
    this.evidence = const [],
    this.stale = false,
    this.generatedAt,
  });
  final String? summary, generatedAt;
  final List<Artwork> evidence;
  final bool stale;
  factory TasteIntro.fromJson(Json j) => TasteIntro(
    summary: j['summary'] as String?,
    generatedAt: j['generated_at'] as String?,
    stale: j['stale'] == true,
    evidence: items(
      j['evidence'],
    ).map((e) => Artwork.fromJson(object(e))).toList(),
  );
}

class CollectionProposal {
  const CollectionProposal({
    required this.action,
    this.collectionId,
    this.artworkId,
    this.name,
    this.artworkIds = const [],
  });
  final String action;
  final String? collectionId, artworkId, name;
  // create: artworks to put in the new collection, first one is the cover.
  final List<String> artworkIds;
  factory CollectionProposal.fromJson(Json j) => CollectionProposal(
    action: text(j['action']),
    collectionId: j['collection_id']?.toString(),
    artworkId: j['artwork_id']?.toString(),
    name: j['name'] as String?,
    artworkIds: items(j['artwork_ids'] ?? []).map(text).toList(),
  );
}

class CollectionReply {
  const CollectionReply(this.answer, [this.proposal]);
  final String answer;
  final CollectionProposal? proposal;
  factory CollectionReply.fromJson(Json j) => CollectionReply(
    text(j['answer']),
    j['proposal'] == null
        ? null
        : CollectionProposal.fromJson(object(j['proposal'])),
  );
}
