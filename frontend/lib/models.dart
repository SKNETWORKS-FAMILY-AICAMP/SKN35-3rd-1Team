typedef Json = Map<String, dynamic>;

String text(Object? value, [String fallback = '']) =>
    value?.toString() ?? fallback;
Json object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<dynamic> items(Object? value) {
  if (value is List) return value;
  final map = object(value);
  final nested = map['items'] ?? map['data'];
  if (nested is List) return nested;
  throw const FormatException('목록 응답은 배열 또는 items/data 배열이어야 합니다.');
}

class Movement {
  const Movement({required this.id, required this.name});
  final String id, name;
  factory Movement.fromJson(Json j) =>
      Movement(id: text(j['id']), name: text(j['name']));
}

class Artist {
  const Artist({
    required this.id,
    required this.slug,
    required this.name,
    this.english = '',
    this.years = '',
    this.movementId = '',
    this.movement = '',
    this.summary = '',
    this.portrait = '',
  });
  final String id,
      slug,
      name,
      english,
      years,
      movementId,
      movement,
      summary,
      portrait;
  factory Artist.fromJson(Json j) => Artist(
    id: text(j['id']),
    slug: text(j['slug']),
    name: text(j['name']),
    english: text(j['name_en']),
    years: text(
      j['years'],
      '${j['birth_year'] ?? '?'}–${j['death_year'] ?? '?'}',
    ),
    movementId: text(j['movement_id']),
    movement: text(j['movement_name'], text(object(j['movement'])['name'])),
    summary: text(j['summary']),
    portrait: text(j['portrait_url']),
  );
}

class Artwork {
  const Artwork({
    required this.id,
    required this.slug,
    required this.title,
    required this.artistId,
    this.titleEn = '',
    this.artistName = '',
    this.artistEnglish = '',
    this.year = '',
    this.movementId = '',
    this.movement = '',
    this.image = '',
    this.description = '',
    this.medium = '',
    this.dimensions = '',
    this.collection = '',
    this.sourceUrl = '',
    this.imageLicense = '',
    this.asset = false,
  });
  final String id,
      slug,
      title,
      titleEn,
      artistId,
      artistName,
      artistEnglish,
      year,
      movementId,
      movement,
      image,
      description,
      medium,
      dimensions,
      collection,
      sourceUrl,
      imageLicense;
  final bool asset;
  factory Artwork.fromJson(Json j) {
    final artist = object(j['artist']);
    return Artwork(
      id: text(j['id']),
      slug: text(j['slug']),
      title: text(j['title']),
      titleEn: text(j['title_en']),
      artistId: text(j['artist_id'], text(artist['id'])),
      artistName: text(j['artist_name'], text(artist['name'])),
      artistEnglish: text(j['artist_name_en'], text(artist['name_en'])),
      year: text(j['year_label'], text(j['year_start'])),
      movementId: text(j['movement_id']),
      movement: text(j['movement_name'], text(object(j['movement'])['name'])),
      image: text(j['image_url']),
      description: text(j['description']),
      medium: text(j['medium']),
      dimensions: text(j['dimensions']),
      collection: text(j['collection']),
      sourceUrl: text(j['image_source_url']),
      imageLicense: text(j['image_license']),
      asset: j['is_asset'] == true,
    );
  }
}

class BasisSource {
  const BasisSource({required this.name, required this.url});

  final String name, url;

  factory BasisSource.fromJson(Json j) => BasisSource(
    name: text(j['source_name']),
    url: text(j['source_url']),
  );
}

class Source {
  const Source({
    required this.id,
    required this.title,
    required this.name,
    required this.url,
    required this.type,
    this.license = '',
    this.basisSources = const [],
  });
  final String id, title, name, url, type, license;
  final List<BasisSource> basisSources;
  factory Source.fromJson(Json j) => Source(
    id: text(j['document_id']),
    title: text(j['title']),
    name: text(j['source_name']),
    url: text(j['source_url']),
    type: text(j['doc_type']),
    license: text(j['license']),
    basisSources: j['basis_sources'] is List
        ? (j['basis_sources'] as List)
              .map((s) => BasisSource.fromJson(object(s)))
              .toList()
        : const [],
  );
}

class ChatTurn {
  const ChatTurn(
    this.role,
    this.content, {
    this.sources = const [],
    this.refused = false,
  });
  final String role, content;
  final List<Source> sources;
  final bool refused;
  Json toHistory() => {'role': role, 'content': content};
}

class ChatReply {
  const ChatReply(this.answer, this.refused, this.sources);
  final String answer;
  final bool refused;
  final List<Source> sources;
  factory ChatReply.fromJson(Json j) {
    if (j['answer'] is! String ||
        j['refused'] is! bool ||
        j['sources'] is! List) {
      throw const FormatException(
        '도슨트 응답의 answer/refused/sources 형식을 확인해 주세요.',
      );
    }
    return ChatReply(
      j['answer'],
      j['refused'],
      (j['sources'] as List).map((s) => Source.fromJson(object(s))).toList(),
    );
  }
}

String seoulDate([DateTime? now]) {
  final day = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
