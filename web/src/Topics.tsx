import React from "react";
import type { Photo, ShortVideo, Snapshot, Topic } from "./types";
import { categoryCovers, totals } from "./community";
const descriptions: Record<string, string> = {
  "Little joys": "The small things that made you smile.",
  "On my walk": "Take the long way. Notice a little more.",
  "At home": "A favorite corner, a familiar kind of comfort.",
  "Today's sky": "Look up. There is always something new.",
  "Something delicious": "Something good, before the first bite.",
};
export default function Topics({
  orderedTopics,
  query,
  access,
  photos,
  shorts,
  open,
  state,
}: {
  orderedTopics: Topic[];
  query: string;
  access: string;
  state: Snapshot;
  photos: Photo[];
  shorts: ShortVideo[];
  open(topic: string): void;
}) {
  const term = query.trim().toLowerCase();
  const results = orderedTopics.filter((topic) => access === "All" || photos.some((p) => p.topic === topic) || shorts.some((clip) => clip.topic === topic)).filter((topic) => [topic, descriptions[topic],
    ...photos.filter((p) => p.topic === topic).map((p) => p.caption + " " + p.author),
    ...shorts.filter((s) => s.topic === topic).map((s) => s.caption),
  ].some((value) => value.toLowerCase().includes(term)));
  return (
    <div className="page topics-page">
      <div className="topic-list">
        {!results.length && <p className="muted" role="status">No matching topics.</p>}
        {results.map((topic, index) => {
          const matching = photos.filter((photo) => photo.topic === topic);
          const clips = shorts.filter((short) => short.topic === topic);
          const works = [...matching, ...clips];
          const counts = totals(works, state);
          const contributors = new Set(works.map((work) => work.authorID || "you")).size;
          const cover =
            matching.length ? categoryCovers[topic] : "assets/icons/topics.png";
          return (
            <button
              className="topic-tile"
              key={topic}
              onClick={() => open(topic)}
            >
              <img
                className={
                  !matching.length ? "empty-topic-cover" : ""
                }
                src={cover}
                alt=""
                loading={index ? "lazy" : "eager"}
              />
              <span className="topic-tile-copy">
                <strong>{topic}</strong>
                <span>{contributors} {contributors === 1 ? "photographer" : "photographers"}</span>
                <small>{Array.from(new Set([
                  ...matching.map((p) => p.coinPrice ? p.coinPrice + " Coins" : "Free"),
                  ...(clips.length ? ["Free"] : []),
                ])).join(" · ")}</small>
                <small>
                  {matching.length} {matching.length === 1 ? "photo" : "photos"}{" "}
                  · {clips.length} {clips.length === 1 ? "short" : "shorts"}
                </small>
                <small>
                  {counts.likes} likes · {counts.saves} saves ·{" "}
                  {counts.comments} comments
                </small>
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
