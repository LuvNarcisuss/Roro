import data from "../../Assets/community/catalog.json";
import type { Photo, ShortVideo, Snapshot } from "./types";
export const authors = data.authors;
export const communityPhotos: Photo[] = data.photos;
export const communityShorts: ShortVideo[] = data.shorts;
export const sourceCredits = data.shorts;
const works = [...data.photos, ...data.shorts];
export function authorFor(id: string | undefined, state: Snapshot) {
  return (
    authors.find((author) => author.id === id) ?? {
      id: "you",
      name: state.profile.name || "You",
      handle: "",
      bio: state.profile.bio,
      avatar: "assets/icons/profile.png",
    }
  );
}
export function allShorts(state: Snapshot): ShortVideo[] {
  return [...(state.shorts ?? []), ...communityShorts];
}
export function isBlocked(authorID: string | undefined, state: Snapshot) {
  return !!authorID && (state.blocked ?? []).includes(authorID);
}
export function visibleShorts(state: Snapshot): ShortVideo[] {
  return allShorts(state).filter(
    (clip) =>
      !state.hidden.includes(clip.id) && !isBlocked(clip.authorID, state),
  );
}
export function commentsFor(id: string, state: Snapshot) {
  const seeded = (works.find((work) => work.id === id)?.comments ?? []).filter(
    (comment) => !isBlocked(comment.authorID, state),
  );
  const local = (state.comments ?? [])
    .filter((item) => item.postID === id)
    .map((item) => ({ ...item, authorID: "you", local: true }));
  return [...seeded.map((item) => ({ ...item, local: false })), ...local];
}
export function engagement(id: string, state: Snapshot) {
  const work = works.find((item) => item.id === id);
  return {
    likes: (work?.likes ?? 0) + Number(state.likes.includes(id)),
    saves: (work?.saves ?? 0) + Number(state.saves.includes(id)),
    comments: commentsFor(id, state).length,
  };
}
export function totals(items: { id: string }[], state: Snapshot) {
  return items.reduce(
    (sum, item) => {
      const count = engagement(item.id, state);
      return {
        works: sum.works + 1,
        likes: sum.likes + count.likes,
        saves: sum.saves + count.saves,
        comments: sum.comments + count.comments,
      };
    },
    { works: 0, likes: 0, saves: 0, comments: 0 },
  );
}
