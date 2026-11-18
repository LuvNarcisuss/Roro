import React from "react";
import type { Photo, ShortVideo, Snapshot, Topic } from "./types";
import { totals } from "./community";
const descriptions: Record<string, string> = {
  "Little joys": "The small things that made you smile.",
  "On my walk": "Take the long way. Notice a little more.",
  "At home": "A favorite corner, a familiar kind of comfort.",
  "Today's sky": "Look up. There is always something new.",
  "Something delicious": "Something good, before the first bite.",
};
export default function Topics({
  orderedTopics,
  photos,
  shorts,
  open,
  state,
}: {
  orderedTopics: Topic[];
  state: Snapshot;
  photos: Photo[];
  shorts: ShortVideo[];
  open(topic: string): void;
}) {
  return (
    <div className="page topics-page">
      <div className="section-intro">
        <small>A LITTLE INSPIRATION</small>
        <h2>
          There is a story
          <br />
          in your everyday.
        </h2>
        <p>A few ideas to help you notice it.</p>
      </div>
      <div className="topic-list">
        {orderedTopics.map((topic, index) => {
          const matching = photos.filter((photo) => photo.topic === topic);
          const clips = shorts.filter((short) => short.topic === topic);
          const counts = totals([...matching, ...clips], state);
          const cover =
            matching[0]?.images[0] ??
            "assets/icons/topics.png";
          return (
            <button
              className={`topic-tile ${index === 0 ? "featured" : ""}`}
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
                <span>{descriptions[topic]}</span>
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
