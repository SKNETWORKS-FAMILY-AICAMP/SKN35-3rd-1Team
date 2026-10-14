import 'models.dart';

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.content,
    this.isPublic = false,
    this.author = '나',
    this.artwork,
  });
  final String id, date, content, author;
  final bool isPublic;
  final Artwork? artwork;
  factory DiaryEntry.fromJson(Json j) => DiaryEntry(
    id: text(j['id']),
    date: text(j['entry_date']),
    content: text(j['content']),
    isPublic: j['is_public'] == true,
    author: text(j['author_name'], '감상가'),
    artwork: j['artwork'] == null
        ? null
        : Artwork.fromJson(object(j['artwork'])),
  );
  Json toJson() => {
    'id': id,
    'entry_date': date,
    'content': content,
    'is_public': isPublic,
    'author_name': author,
    'artwork': artwork == null
        ? null
        : {
            'id': artwork!.id,
            'slug': artwork!.slug,
            'title': artwork!.title,
            'artist_id': artwork!.artistId,
            'artist_name': artwork!.artistName,
            'image_url': artwork!.image,
          },
  };
}

class DiaryFeed {
  const DiaryFeed(this.entries, this.nextCursor);
  final List<DiaryEntry> entries;
  final String? nextCursor;
  factory DiaryFeed.fromJson(Json j) => DiaryFeed(
    items(j).map((v) => DiaryEntry.fromJson(object(v))).toList(),
    j['next_cursor']?.toString(),
  );
}
