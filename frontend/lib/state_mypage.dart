part of 'state.dart';

extension MyPageState on ArtlogState {
  List<ArtCollection> _demoCollections() {
    final raw = prefs.getString(_localKey('collections')) ?? '[]';
    try {
      return items(jsonDecode(raw)).map((e) {
        final c = ArtCollection.fromJson(object(e));
        return ArtCollection(
          id: c.id,
          name: c.name,
          description: c.description,
          count: c.artworkIds.length,
          artworkIds: c.artworkIds,
          previews: c.artworkIds
              .map(workFor)
              .whereType<Artwork>()
              .take(3)
              .toList(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _requireMember() {
    if (!authenticated) {
      throw const ApiException('로그인 후 이용할 수 있어요.', status: 401);
    }
  }

  void _checkMember(int revision) {
    if (revision != _identityRevision) {
      throw const ApiException('계정이 바뀌었어요. 다시 확인해 주세요.', status: 401);
    }
  }

  void _collectionsChanged() {
    ++collectionRevision;
    _requests.removeWhere((k, v) => k.startsWith('collections/'));
    _requestTimes.removeWhere((k, v) => k.startsWith('collections/'));
    notifyListeners();
  }

  Future<void> _persistCollections(List<ArtCollection> rows) async {
    if (!await prefs.setString(
      _localKey('collections'),
      jsonEncode(rows.map((c) => c.toJson()).toList()),
    )) {
      throw const ApiException('컬렉션을 저장하지 못했어요.');
    }
  }

  Future<List<ArtCollection>> collections({bool force = false}) async {
    _requireMember();
    return config.demo
        ? _demoCollections()
        : _cached(
            'collections/$_identityRevision/$collectionRevision',
            api.collections,
            force: force,
          );
  }

  Future<ArtCollection> saveCollection(
    String name,
    String description, {
    String? id,
  }) async {
    _requireMember();
    final revision = _identityRevision;
    if (name.trim().isEmpty ||
        name.trim().length > 80 ||
        description.length > 500) {
      throw const ApiException('컬렉션 이름은 1~80자, 소개는 500자까지 입력해 주세요.');
    }
    late ArtCollection result;
    if (config.demo) {
      final rows = _demoCollections();
      if (rows.any(
        (c) => c.id != id && c.name.toLowerCase() == name.trim().toLowerCase(),
      )) {
        throw const ApiException('같은 이름의 컬렉션이 있어요.');
      }
      if (id != null && !rows.any((c) => c.id == id)) {
        throw const ApiException('컬렉션을 찾을 수 없어요.');
      }
      if (id == null && rows.length >= 50) {
        throw const ApiException('컬렉션은 50개까지 만들 수 있어요.');
      }
      final old = rows.where((c) => c.id == id).firstOrNull;
      result = ArtCollection(
        id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        description: description.trim(),
        artworkIds: old?.artworkIds ?? [],
        count: old?.count ?? 0,
        previews: old?.previews ?? [],
      );
      await _persistCollections([
        result,
        ...rows.where((c) => c.id != result.id),
      ]);
    } else {
      result = await api.saveCollection(
        name.trim(),
        description.trim(),
        id: id,
      );
    }
    _checkMember(revision);
    _collectionsChanged();
    return result;
  }

  Future<void> deleteCollection(String id) async {
    _requireMember();
    final revision = _identityRevision;
    if (config.demo) {
      await _persistCollections(
        _demoCollections().where((c) => c.id != id).toList(),
      );
    } else {
      await api.deleteCollection(id);
    }
    _checkMember(revision);
    _collectionsChanged();
  }

  Future<void> collect(
    String id,
    String artworkId, {
    bool remove = false,
  }) async {
    _requireMember();
    final revision = _identityRevision;
    if (config.demo) {
      final rows = _demoCollections();
      final old = rows.where((c) => c.id == id).firstOrNull;
      if (old == null || workFor(artworkId) == null) {
        throw const ApiException('작품이나 컬렉션을 찾을 수 없어요.');
      }
      final ids = old.artworkIds.toSet();
      if (remove) {
        ids.remove(artworkId);
      } else {
        if (ids.length >= 500 && !ids.contains(artworkId)) {
          throw const ApiException('한 컬렉션에 500점까지 담을 수 있어요.');
        }
        ids.add(artworkId);
      }
      final updated = ArtCollection(
        id: old.id,
        name: old.name,
        description: old.description,
        artworkIds: ids.toList(),
        count: ids.length,
      );
      await _persistCollections([updated, ...rows.where((c) => c.id != id)]);
    } else {
      if (remove) {
        await api.uncollect(id, artworkId);
      } else {
        await api.collect(id, artworkId);
      }
    }
    _checkMember(revision);
    _collectionsChanged();
  }

  Future<ArtworkPage> collectionItems(String id, {String? cursor}) async {
    _requireMember();
    if (!config.demo) return api.collectionItems(id, cursor: cursor);
    final row = _demoCollections().where((c) => c.id == id).firstOrNull;
    if (row == null) throw const ApiException('컬렉션을 찾을 수 없어요.');
    final works = row.artworkIds.map(workFor).whereType<Artwork>().toList();
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    return ArtworkPage(
      works.skip(offset).take(12).toList(),
      works.length > offset + 12 ? '${offset + 12}' : null,
    );
  }

  Future<CritiquePage> critiques({String? cursor}) async {
    _requireMember();
    if (!config.demo) return api.critiques(cursor: cursor);
    final rows = _demoDiary()..sort((a, b) => b.id.compareTo(a.id));
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    return CritiquePage(
      rows.skip(offset).take(12).toList(),
      rows.length > offset + 12 ? '${offset + 12}' : null,
    );
  }

  Future<List<MemberActivity>> activity({int offset = 0}) async {
    _requireMember();
    if (!config.demo) return api.activity(offset: offset);
    final rows = <MemberActivity>[
      for (final day in views.entries)
        for (final id in day.value.toSet())
          MemberActivity(
            kind: 'view',
            title: workFor(id)?.title ?? '감상한 작품',
            at: '${day.key}T12:00:00+09:00',
            artworkId: id,
            date: day.key,
          ),
      for (final d in _demoDiary())
        MemberActivity(
          kind: 'diary',
          title: '감상·비평을 남겼어요',
          at: '${d.date}T12:00:00+09:00',
          date: d.date,
          artworkId: d.artwork?.id,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return rows.skip(offset).take(20).toList();
  }

  Future<TasteIntro> taste({bool generate = false}) async {
    _requireMember();
    if (config.demo) {
      if (generate) {
        throw const ApiException(
          '미리보기에서는 AI를 호출하지 않아요. 서버 연결 후 취향 소개를 만들 수 있어요.',
        );
      }
      return TasteIntro(
        evidence: [
          ...likedWorks,
          ..._demoCollections().expand(
            (c) => c.artworkIds.map(workFor).whereType<Artwork>(),
          ),
        ].take(100).toList(),
      );
    }
    return api.taste(generate: generate);
  }

  Future<CollectionReply> collectionChat(
    String message, {
    String? collectionId,
  }) async {
    _requireMember();
    if (message.trim().isEmpty || message.runes.length > 500) {
      throw const ApiException('요청은 1~500자로 적어 주세요.');
    }
    if (config.demo) {
      return const CollectionReply(
        '미리보기에서는 AI 채팅을 호출하지 않아요. 위의 컬렉션 만들기와 작품 담기는 직접 사용해 볼 수 있어요.',
      );
    }
    return api.collectionChat(message, collectionId: collectionId);
  }

  Future<void> applyCollectionProposal(CollectionProposal p) async {
    if (p.action == 'create' && p.name != null) {
      await saveCollection(p.name!, '');
    } else if (p.action == 'add' &&
        p.collectionId != null &&
        p.artworkId != null) {
      await collect(p.collectionId!, p.artworkId!);
    } else {
      throw const ApiException('요청 내용을 다시 확인해 주세요.');
    }
  }
}
