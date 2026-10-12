"""Movements, artists and artworks. Lists return card models; details extend them."""

from pydantic import BaseModel, ConfigDict


class Movement(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    name: str
    name_en: str | None
    description: str | None


class ArtistCard(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    name: str
    name_en: str | None
    movement_id: int | None
    birth_year: int | None
    death_year: int | None
    summary: str | None
    portrait_url: str | None


class ArtistDetail(ArtistCard):
    nationality: str | None


class ArtworkCard(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    title: str
    title_en: str | None
    artist_id: int
    artist_name: str
    movement_id: int | None
    year_label: str | None
    image_url: str | None
    is_featured: bool


class ArtworkDetail(ArtworkCard):
    medium: str | None
    dimensions: str | None
    collection: str | None
    description: str | None
    image_source_url: str | None
    image_license: str | None
