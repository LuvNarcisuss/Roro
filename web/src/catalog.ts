import type { Photo, Topic } from "./types";
export const topics: Topic[] = [
  "Little joys",
  "On my walk",
  "At home",
  "Today's sky",
  "Something delicious",
];
export { communityPhotos as catalog } from "./community";

export const topicPrompts: Record<Topic, string> = {
  "Little joys": "What made you smile today?",
  "On my walk": "What caught your eye along the way?",
  "At home": "Which corner feels most like you?",
  "Today's sky": "What color is the sky right now?",
  "Something delicious": "What was worth a photo before the first bite?",
};

export function rotateItems<T>(items: T[], turn: number): T[] {
  if (items.length < 2) return items;
  const start = turn % items.length;
  return start === 0 ? items : [...items.slice(start), ...items.slice(0, start)];
}
