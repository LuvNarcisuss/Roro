import React from "react";
import type { Photo, ShortVideo } from "./types";

export default function WorkGrid({ items, open, collection = false }: {
  items: (Photo | ShortVideo)[];
  open(id: string, work: Photo | ShortVideo): void;
  collection?: boolean;
}) {
  return (
    <div className={collection ? "work-grid collection-work-grid" : "work-grid"}>
      {items.map((work) => {
        const video = "poster" in work;
        return (
          <button
            key={work.id}
            type="button"
            className={`work-thumbnail${video ? " is-video" : ""}`}
            aria-label={`${video ? "Play" : "View"} ${work.caption || (video ? "short" : "moment")}`}
            onClick={() => open(work.id, work)}
          >
            <img
              className="work-thumbnail-image"
              src={video ? work.poster : work.images[0]}
              alt=""
              loading="lazy"
            />
            {(video || collection) && (
              <img className="work-type-marker" src={video ? "assets/icons/shorts.png" : "assets/icons/topics.png"} alt="" />
            )}
          </button>
        );
      })}
    </div>
  );
}
