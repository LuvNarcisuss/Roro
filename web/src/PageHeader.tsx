import React from "react";
import { Glyph } from "./Controls";

export function AppLogo() {
  return <img className="app-logo" src="assets/icons/roro-logo.png" alt="Roro" />;
}

export default function PageHeader({
  title,
  titleId,
  back,
  showLogo = false,
  overlay = false,
  children,
}: {
  title: string;
  titleId?: string;
  back?(): void;
  showLogo?: boolean;
  overlay?: boolean;
  children?: React.ReactNode;
}) {
  return (
    <header className={overlay ? "page-header feed-header" : "page-header"}>
      <div className="header-leading">
        {showLogo && <AppLogo />}
        {back && (
          <button type="button" className="back" aria-label="Back" onClick={back}>
            <Glyph name="back" />
          </button>
        )}
      </div>
      <h1 id={titleId}>{title}</h1>
      <div className="header-actions">{children}</div>
    </header>
  );
}
