import React from "react";
import type { Photo, ShortVideo } from "./types";

export default function WorkGrid({ items, open }: {
  items: (Photo | ShortVideo)[];
  open(id: string): void;
}) {
  return (
    <div className="work-grid">
      {items.map((work) => {
        const video = "poster" in work;
        return (
          <button
            key={work.id}
            type="button"
            className={`work-thumbnail${video ? " is-video" : ""}`}
            aria-label={`${video ? "Play" : "View"} ${work.caption || (video ? "short" : "moment")}`}
            onClick={() => open(work.id)}
          >
            <img
              className="work-thumbnail-image"
              src={video ? work.poster : work.images[0]}
              alt=""
              loading="lazy"
            />
            {video && (
              <img className="work-video-marker" src="assets/icons/shorts.png" alt="" />
            )}
          </button>
        );
      })}
    </div>
  );
}
