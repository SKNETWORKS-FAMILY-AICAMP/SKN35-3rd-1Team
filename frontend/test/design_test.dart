import 'package:artlog_web/ui/design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:artlog_web/ui/museum_artwork_images.dart';
import 'dart:io';

void main() {
  group('optimizedArtworkImageUrl', () {
    test('adds a bounded width to Commons special-file URLs', () {
      const original =
          'https://commons.wikimedia.org/wiki/Special:FilePath/Caravaggio_incredulity.jpg';

      expect(optimizedArtworkImageUrl(original), '$original?width=800');
    });

    test('keeps an existing Commons thumbnail width', () {
      const thumbnail =
          'https://commons.wikimedia.org/wiki/Special:Redirect/file/Van_Gogh.jpg?width=640';

      expect(optimizedArtworkImageUrl(thumbnail), thumbnail);
    });

    test('requests a browser-friendly thumbnail for Commons TIFF files', () {
      const original =
          'https://commons.wikimedia.org/wiki/Special:Redirect/file/Painting.tif';

      expect(optimizedArtworkImageUrl(original), '$original?width=800');
    });

    test('routes direct Commons uploads through the thumbnail endpoint', () {
      const original =
          'https://upload.wikimedia.org/wikipedia/commons/c/c1/Painting.jpg';

      expect(
        optimizedArtworkImageUrl(original),
        'https://commons.wikimedia.org/wiki/Special:Redirect/file/Painting.jpg?width=800',
      );
    });

    test('known museum originals use existing local copies', () {
      expect(museumArtworkImages.length, greaterThan(40));
      for (final entry in museumArtworkImages.entries) {
        expect(optimizedArtworkImageUrl(entry.key), entry.value);
        expect(File('web${entry.value}').existsSync(), isTrue);
      }
    });

    test('does not rewrite unknown museum or local image URLs', () {
      const museum = 'https://www.museum.go.kr/relic_image/example.jpg';

      expect(optimizedArtworkImageUrl(museum), museum);
      expect(
        optimizedArtworkImageUrl('public/artworks/example.jpg'),
        'public/artworks/example.jpg',
      );
    });
  });
}
