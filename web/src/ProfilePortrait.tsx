import React from "react";

export default function ProfilePortrait({ avatar, name }: { avatar?: string; name: string }) {
  return (
    <span className="profile-initial">
      {avatar ? <img src={avatar} alt="Profile photo" /> : name.slice(0, 1) || "R"}
    </span>
  );
}
