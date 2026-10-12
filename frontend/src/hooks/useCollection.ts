import { useState } from 'react';
import type { ViewRecord } from '../types/catalog';
import { localDate } from '../data/catalog';

function useSavedState<T>(key: string, initial: T) {
  const [value, setValue] = useState<T>(() => {
    try { const stored = localStorage.getItem(key); return stored ? JSON.parse(stored) : initial; } catch { return initial; }
  });
  const update = (next: T | ((current: T) => T)) => setValue(current => {
    const result = typeof next === 'function' ? (next as (current: T) => T)(current) : next;
    try { localStorage.setItem(key, JSON.stringify(result)); } catch { /* Browsing remains available when storage is disabled. */ }
    return result;
  });
  return [value, update] as const;
}

export function useCollection() {
  const [likes, setLikes] = useSavedState<string[]>('artlog.likes.v1', []);
  const [follows, setFollows] = useSavedState<string[]>('artlog.follows.v1', []);
  const [views, setViews] = useSavedState<ViewRecord[]>('artlog.views.v1', []);
  const toggle = (items: string[], id: string) => items.includes(id) ? items.filter(item => item !== id) : [...items, id];
  return {
    likes, follows, views,
    toggleLike: (id: string) => setLikes(current => toggle(current, id)),
    toggleFollow: (id: string) => setFollows(current => toggle(current, id)),
    recordView: (artworkId: string) => setViews(current => current.some(v => v.artworkId === artworkId && v.date === localDate()) ? current : [...current, { artworkId, date: localDate() }]),
  };
}
export type Collection = ReturnType<typeof useCollection>;
