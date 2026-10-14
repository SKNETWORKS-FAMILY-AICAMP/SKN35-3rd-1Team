"""Owner filtering is shared by HTTP, the collection assistant and MCP tools."""

import json
from datetime import UTC
from hashlib import sha256

from fastapi import HTTPException
from sqlalchemy import delete, func, literal, select, union_all
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.timeutil import utcnow
from app.models import (
    Artist,
    Artwork,
    ArtworkLike,
    ArtworkView,
    Collection,
    CollectionItem,
    DiaryEntry,
    UserPreference,
)
from app.repositories import diary_repository
from app.schemas.mypage import (
    ActivityOut,
    ArtworkPage,
    CollectionOut,
    CollectionWrite,
    CritiquePage,
    ProfileOut,
    ProfileWrite,
    TasteOut,
)
from app.services import catalog_service, diary_service


def preference(db: Session, user_id: int) -> UserPreference | None:
    return db.get(UserPreference, user_id)


def get_profile(db, user) -> ProfileOut:
    p = preference(db, user.id)
    defaults = ProfileWrite(onboarding_completed=False)
    return ProfileOut(
        nickname=user.nickname,
        **{
            key: getattr(p, key)
            if p is not None and getattr(p, key) is not None
            else value
            for key, value in defaults.model_dump().items()
        },
    )


def save_profile(db, user, body: ProfileWrite) -> ProfileOut:
    p = preference(db, user.id)
    if p is None:
        p = UserPreference(user_id=user.id)
        db.add(p)
    for key, value in body.model_dump().items():
        setattr(p, key, value)
    p.birth_year = body.birth_date.year if body.birth_date else None
    p.tone = body.conversation_style
    p.explanation_level = (
        "deep" if body.conversation_style == "professional" else "easy"
    )
    p.updated_at = utcnow()
    try:
        db.commit()
    except IntegrityError:
        # Concurrent first-time onboarding: retry the owner row once.
        db.rollback()
        p = preference(db, user.id)
        if p is None:
            raise
        for key, value in body.model_dump().items():
            setattr(p, key, value)
        p.birth_year = body.birth_date.year if body.birth_date else None
        p.tone = body.conversation_style
        p.explanation_level = (
            "deep" if body.conversation_style == "professional" else "easy"
        )
        p.updated_at = utcnow()
        db.commit()
    return get_profile(db, user)


def own_collection(db, user_id, collection_id):
    row = db.scalar(
        select(Collection).where(
            Collection.id == collection_id, Collection.user_id == user_id
        )
    )
    if row is None:
        raise HTTPException(404, "컬렉션을 찾을 수 없어요.")
    return row


def card_rows(db, query):
    return [
        catalog_service.to_artwork_card(a, name) for a, name in db.execute(query).all()
    ]


def collection_cards(db, collection_id, limit=3, before_id=None):
    q = (
        select(Artwork, Artist.name)
        .join(Artist, Artist.id == Artwork.artist_id)
        .join(CollectionItem, CollectionItem.artwork_id == Artwork.id)
        .where(CollectionItem.collection_id == collection_id)
    )
    if before_id is not None:
        q = q.where(Artwork.id < before_id)
    return card_rows(db, q.order_by(Artwork.id.desc()).limit(limit))


def serialize_collection(db, row):
    return CollectionOut(
        id=row.id,
        name=row.name,
        description=row.description,
        artwork_count=db.scalar(
            select(func.count())
            .select_from(CollectionItem)
            .where(CollectionItem.collection_id == row.id)
        ),
        previews=collection_cards(db, row.id),
    )


def collections(db, user_id):
    rows = db.scalars(
        select(Collection)
        .where(Collection.user_id == user_id)
        .order_by(Collection.updated_at.desc(), Collection.id.desc())
        .limit(50)
    ).all()
    if not rows:
        return []
    ids = [r.id for r in rows]
    counts = dict(
        db.execute(
            select(CollectionItem.collection_id, func.count())
            .where(CollectionItem.collection_id.in_(ids))
            .group_by(CollectionItem.collection_id)
        ).all()
    )
    ranked = (
        select(
            CollectionItem.collection_id,
            CollectionItem.artwork_id,
            func.row_number()
            .over(
                partition_by=CollectionItem.collection_id,
                order_by=CollectionItem.artwork_id.desc(),
            )
            .label("rank"),
        )
        .where(CollectionItem.collection_id.in_(ids))
        .subquery()
    )
    previews = {i: [] for i in ids}
    for cid, art, name in db.execute(
        select(ranked.c.collection_id, Artwork, Artist.name)
        .join(Artwork, Artwork.id == ranked.c.artwork_id)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(ranked.c.rank <= 3)
        .order_by(ranked.c.collection_id, ranked.c.rank)
    ):
        previews[cid].append(catalog_service.to_artwork_card(art, name))
    return [
        CollectionOut(
            id=r.id,
            name=r.name,
            description=r.description,
            artwork_count=counts.get(r.id, 0),
            previews=previews[r.id],
        )
        for r in rows
    ]


def save_collection(db, user_id, body: CollectionWrite, collection_id=None):
    row = (
        own_collection(db, user_id, collection_id)
        if collection_id is not None
        else None
    )
    if row is None:
        count = db.scalar(
            select(func.count())
            .select_from(Collection)
            .where(Collection.user_id == user_id)
        )
        if count >= 50:
            raise HTTPException(409, "컬렉션은 50개까지 만들 수 있어요.")
        row = Collection(user_id=user_id, name=body.name, description=body.description)
        db.add(row)
    row.name, row.description, row.updated_at = body.name, body.description, utcnow()
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "같은 이름의 컬렉션이 있어요.") from None
    return serialize_collection(db, row)


def delete_collection(db, user_id, collection_id):
    row = own_collection(db, user_id, collection_id)
    db.execute(delete(CollectionItem).where(CollectionItem.collection_id == row.id))
    db.delete(row)
    db.commit()


def add_artwork(db, user_id, collection_id, artwork_id):
    row = own_collection(db, user_id, collection_id)
    catalog_service.ensure_artwork(db, artwork_id)
    key = (collection_id, artwork_id)
    if db.get(CollectionItem, key) is None:
        count = db.scalar(
            select(func.count())
            .select_from(CollectionItem)
            .where(CollectionItem.collection_id == collection_id)
        )
        if count >= 500:
            raise HTTPException(409, "컬렉션에는 작품을 500점까지 담을 수 있어요.")
        db.add(CollectionItem(collection_id=collection_id, artwork_id=artwork_id))
        row.updated_at = utcnow()
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            if db.get(CollectionItem, key) is None:
                raise
    return serialize_collection(db, row)


def remove_artwork(db, user_id, collection_id, artwork_id):
    row = own_collection(db, user_id, collection_id)
    db.execute(
        delete(CollectionItem).where(
            CollectionItem.collection_id == collection_id,
            CollectionItem.artwork_id == artwork_id,
        )
    )
    row.updated_at = utcnow()
    db.commit()


def collection_page(db, user_id, collection_id, limit, before_id):
    own_collection(db, user_id, collection_id)
    cards = collection_cards(db, collection_id, limit + 1, before_id)
    return ArtworkPage(
        items=cards[:limit],
        next_cursor=cards[limit - 1].id if len(cards) > limit else None,
    )


def critiques(db, user_id, limit, before_id):
    q = diary_repository.rows().where(DiaryEntry.user_id == user_id)
    if before_id is not None:
        q = q.where(DiaryEntry.id < before_id)
    rows = db.execute(q.order_by(DiaryEntry.id.desc()).limit(limit + 1)).all()
    return CritiquePage(
        items=[diary_service.serialize(r) for r in rows[:limit]],
        next_cursor=rows[limit - 1][0].id if len(rows) > limit else None,
    )


def activity(db, user_id, limit, offset):
    def art_events(model, kind, timestamp):
        return (
            select(
                literal(kind).label("kind"),
                Artwork.title.label("title"),
                timestamp.label("time"),
                Artwork.id.label("artwork_id"),
                (
                    ArtworkView.viewed_on if model is ArtworkView else literal(None)
                ).label("entry_date"),
            )
            .join(Artwork, Artwork.id == model.artwork_id)
            .where(model.user_id == user_id)
        )

    q = union_all(
        art_events(ArtworkView, "view", ArtworkView.last_viewed_at),
        art_events(ArtworkLike, "like", ArtworkLike.created_at),
        select(
            literal("diary"),
            literal("감상·비평을 남겼어요"),
            DiaryEntry.updated_at,
            DiaryEntry.artwork_id,
            DiaryEntry.entry_date,
        ).where(DiaryEntry.user_id == user_id),
        select(
            literal("collection"),
            Collection.name,
            Collection.updated_at,
            literal(None),
            literal(None),
        ).where(Collection.user_id == user_id),
    ).subquery()
    from datetime import date

    return [
        ActivityOut(
            kind=r.kind,
            title=r.title,
            occurred_at=r.time.replace(tzinfo=UTC),
            artwork_id=r.artwork_id,
            entry_date=date.fromisoformat(r.entry_date)
            if isinstance(r.entry_date, str)
            else r.entry_date,
        )
        for r in db.execute(
            select(q)
            .order_by(q.c.time.desc(), q.c.kind, q.c.artwork_id, q.c.title)
            .offset(offset)
            .limit(limit)
        )
    ]


def taste_evidence(db, user_id):
    # Every supplied work belongs to the caller's likes or collections. No diary text,
    # birth date, email or Firebase identifiers are sent to the language model.
    liked = select(ArtworkLike.artwork_id).where(ArtworkLike.user_id == user_id)
    collected = (
        select(CollectionItem.artwork_id)
        .join(Collection, Collection.id == CollectionItem.collection_id)
        .where(Collection.user_id == user_id)
    )
    return card_rows(
        db,
        select(Artwork, Artist.name)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(Artwork.id.in_(liked.union(collected)))
        .order_by(Artwork.id)
        .limit(100),
    )


def taste_fingerprint(evidence):
    return sha256(
        json.dumps(
            [e.model_dump() for e in evidence], ensure_ascii=False, sort_keys=True
        ).encode()
    ).hexdigest()


def get_taste(db, user_id):
    p = preference(db, user_id)
    evidence = taste_evidence(db, user_id)
    return TasteOut(
        summary=p.taste_summary if p else None,
        evidence=evidence,
        generated_at=p.taste_generated_at.replace(tzinfo=UTC)
        if p and p.taste_generated_at
        else None,
        stale=bool(
            p and p.taste_summary and p.taste_fingerprint != taste_fingerprint(evidence)
        ),
    )


def search_artworks(db, query, limit=8):
    # Escape LIKE metacharacters; user text is data, never SQL or tool instructions.
    term = query.strip()[:80]
    return card_rows(
        db,
        select(Artwork, Artist.name)
        .join(Artist, Artist.id == Artwork.artist_id)
        .where(
            Artwork.title.contains(term, autoescape=True)
            | Artist.name.contains(term, autoescape=True)
        )
        .order_by(Artwork.id)
        .limit(limit),
    )
