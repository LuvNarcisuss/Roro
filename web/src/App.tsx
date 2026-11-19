import ProfilePortrait from "./ProfilePortrait";
import React, { useEffect, useRef, useState } from "react";
import { flushSync } from "react-dom";
import {
  ActionButton,
  ReactionButton,
  Glyph,
  ToolbarSearch,
  emptySearch,
  type SearchState,
} from "./Controls";
import agreements from "../../Configuration/agreements.json";
import { native } from "./bridge";
import Topics from "./Topics";
import { ChatList, FindFriends, Conversation, type ChatScope } from "./Chats";
import TopicFilterDialog from "./TopicFilterDialog";
import SafetyMenu from "./SafetyMenu";
import SafetyRecord from "./SafetyRecord";
import PullToRefresh from "./PullToRefresh";
import PageHeader, { AppLogo } from "./PageHeader";
import Comments from "./Comments";
import photoManifest from "../../Assets/photos/manifest.json";
import MemberProfile from "./MemberProfile";
import WorkGrid from "./WorkGrid";
import {
  editorialCovers,
  authors,
  categoryPrices,
  isBlocked,
  allShorts,
  visibleShorts,
  authorFor,
  engagement,
  totals,
  sourceCredits,
  communityComments,
} from "./community";
import Shorts, { ShortList } from "./Shorts";
import { catalog, rotateItems, topicPrompts, topics } from "./catalog";
import type { Command, Moment, Photo, Snapshot, Wallet } from "./types";

type Route = {
  name:
    | "home"
    | "topics"
    | "shorts"
    | "chats"
    | "findFriends"
    | "me"
    | "settings"
    | "editProfile"
    | "compose"
    | "wallet"
    | "credits"
    | "hidden"
    | "topic"
    | "detail"
    | "collection"
    | "member"
    | "message"
    | "reportedPosts"
    | "reportedComments"
    | "reports"
    | "blocked";
  id?: string;
  videoID?: string;
  blockRevision?: number;
  search?: SearchState;
  access?: string;
};
const priceStatus = {
  loading: "Loading prices…",
  ready: "",
  partial: "Some offers are unavailable. Pull down to check again.",
  unavailable: "Offers are unavailable. Pull down to check again.",
  failed: "Prices could not be loaded. Pull down to try again.",
};
function Icon({ name }: { name: string }) {
  return <img className="icon" src={`assets/icons/${name}.png`} alt="" />;
}
function IconButton({
  name,
  label,
  onClick,
  count,
}: {
  name: string;
  label: string;
  onClick(): void;
  count?: number;
}) {
  return (
    <button
      className="icon-button"
      aria-label={label}
      onClick={onClick}
    >
      <Icon name={name} />
      {count !== undefined && <span className="action-count">{count}</span>}
    </button>
  );
}
function Empty({
  title,
  children,
}: {
  title: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="empty">
      <h2>{title}</h2>
      {children}
    </div>
  );
}

function coinUnit(amount?: number) {
  return amount === 1 ? "Coin" : "Coins";
}

const pexelsCredits = photoManifest.filter((item) => item.license === "Pexels License");

export default function App() {
  const [session, setSession] = useState(0);
  return <LocalSession key={session} onLogOut={() => setSession((value) => value + 1)} />;
}

function LocalSession({ onLogOut }: { onLogOut(): void }) {
  const [state, setState] = useState<Snapshot>();
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [consentChoice, setConsentChoice] = useState<boolean>();
  const [entered, setEntered] = useState(false);
  const [routes, setRoutes] = useState<Route[]>([{ name: "home" }]);
  const [scope, setScope] = useState("Discover");
  const [collection, setCollection] = useState("Moments");
  const [feedTurns, setFeedTurns] = useState({ home: 0, topics: 0 });
  const [chatScope, setChatScope] = useState<ChatScope>("Recent");
  const [chatSearch, setChatSearch] = useState(emptySearch);
  const [friendSearch, setFriendSearch] = useState(emptySearch);
  function findFriends() {
    setFriendSearch(emptySearch);
    push({ name: "findFriends" });
  }
  const [topicsSearch, setTopicsSearch] = useState(emptySearch);
  const [topicCategory, setTopicCategory] = useState("");
  const [accessFilter, setAccessFilter] = useState("All");
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [homeSearch, setHomeSearch] = useState(emptySearch);
  const [fullImage, setFullImage] = useState<string>();
  const [wallet, setWallet] = useState<Wallet>();
  const [walletLoading, setWalletLoading] = useState(false);
  const [walletError, setWalletError] = useState("");
  const [selectedOfferID, setSelectedOfferID] = useState<string>();
  const walletRequest = useRef<Promise<void> | undefined>(undefined);
  const [caption, setCaption] = useState("");
  const [topic, setTopic] = useState("");
  const [images, setImages] = useState<string[]>([]);
  const [surface, setSurface] = useState("home");
  const [coinPrice, setCoinPrice] = useState("0");
  const [draftID, setDraftID] = useState<string>();
  const [name, setName] = useState("");
  const [bio, setBio] = useState("");
  const [avatar, setAvatar] = useState<string>();
  const [options, setOptions] = useState<Photo>();
  const contentRef = useRef<HTMLElement>(null);
  const route = routes[routes.length - 1];
  const lastBlockAlert = useRef<number | undefined>(undefined);
  useEffect(() => {
    const revision = route.blockRevision;
    if (revision === undefined || lastBlockAlert.current === revision) return;
    // Let the refreshed root paint before the native alert pauses WebKit.
    let frame = requestAnimationFrame(() => {
      frame = requestAnimationFrame(() => {
        lastBlockAlert.current = revision;
        window.alert("User blocked.");
      });
    });
    return () => cancelAnimationFrame(frame);
  }, [route.blockRevision]);
  const shortSearch = route.search ?? emptySearch;
  function setShortSearch(search: SearchState) {
    setRoutes((current) =>
      current.map((item, index) =>
        index === current.length - 1 ? { ...item, search } : item,
      ),
    );
  }
  const showNotice = (text: string) => setNotice(text);
  useEffect(() => {
    const timer = setTimeout(() => setNotice(""), 4000);
    return () => clearTimeout(timer);
  }, [notice]);
  const latest = useRef<Snapshot | undefined>(undefined);
  function apply(next: Snapshot) {
    if (!latest.current || next.revision >= latest.current.revision) {
      latest.current = next;
      setState(next);
    }
    return latest.current;
  }
  async function reloadLibrary() {
    return apply(await native<Snapshot>("snapshot", { reload: true }));
  }
  async function load() {
    try {
      setError("");
      apply(await native<Snapshot>("snapshot"));
    } catch (e) {
      setError((e as Error).message);
    }
  }
  useEffect(() => {
    void load();
  }, []);
  useEffect(() => {
    contentRef.current?.scrollTo(0, 0);
  }, [route.name, route.id]);
  useEffect(() => {
    if (!["message", "detail", "shorts"].includes(route.name)) return;
    const viewport = window.visualViewport;
    const content = contentRef.current;
    const app = content?.parentElement;
    if (!viewport || !content || !app) return;
    const fitComposer = () => {
      const inset = viewport.scale === 1
        ? Math.max(0, app.getBoundingClientRect().bottom - viewport.offsetTop - viewport.height)
        : 0;
      content.style.setProperty("--chat-keyboard-inset", inset + "px");
    };
    fitComposer();
    viewport.addEventListener("resize", fitComposer);
    viewport.addEventListener("scroll", fitComposer);
    return () => {
      viewport.removeEventListener("resize", fitComposer);
      viewport.removeEventListener("scroll", fitComposer);
      content.style.removeProperty("--chat-keyboard-inset");
    };
  }, [route.name]);
  useEffect(() => {
    if (route.name !== "wallet") return;
    setSelectedOfferID(undefined);
    void loadWallet().catch(() => {});
    const refreshSnapshot = () => {
      void native<Wallet>("walletSnapshot")
        .then(setWallet)
        .catch(() => {});
    };
    refreshSnapshot();
    const timer = setInterval(refreshSnapshot, 3000);
    return () => clearInterval(timer);
  }, [route.name]);
  async function act(command: Command, payload: Record<string, unknown> = {}) {
    if (busy) return false;
    setBusy(true);
    try {
      const next = await native<Snapshot>(command, payload);
      if (command === "setReport" && payload.enabled === true) {
        flushSync(() => { apply(next); });
      } else {
        const saved = apply(next);
        if (command === "setBlock" && payload.enabled === true &&
            typeof payload.id === "string" && saved.blocked?.includes(payload.id)) {
          // Keep the originating tab, including when its detail stack contains another feed.
          setRoutes(current => current[current.length - 1] === route
            ? [{ name: current[0].name, blockRevision: saved.revision }]
            : current);
        }
      }
      if (next.cleanupPending)
        showNotice(
          "Your library was cleared. Reopen Roro to finish removing its media files.",
        );
      return true;
    } catch (e) {
      showNotice((e as Error).message);
      return false;
    } finally {
      setBusy(false);
    }
  }
  async function call(command: Command, payload: Record<string, unknown> = {}) {
    try {
      await native(command, payload);
    } catch (e) {
      showNotice((e as Error).message);
    }
  }
  function push(next: Route) {
    setRoutes((current) => [...current, next]);
  }
  function back() {
    if (
      route.name === "compose" &&
      (images.length || caption) &&
      !confirm(
        "Leave this moment? Choose Cancel to keep editing or save a draft.",
      )
    )
      return;
    setRoutes((current) =>
      current.length > 1 ? current.slice(0, -1) : current,
    );
  }
  function root(next: Route["name"]) {
    setRoutes([{ name: next }]);
  }
  function compose(moment?: Moment) {
    setSurface(moment?.surface ?? (route.name === "topic" || route.name === "topics" ? "topics" : "home"));
    setImages(moment?.images ?? []);
    setCaption(moment?.caption ?? "");
    setTopic(moment?.topic ?? (route.name === "topics" ? topicCategory : ""));
    setCoinPrice(String(moment?.coinPrice ?? 0));
    setDraftID(moment?.id);
    push({ name: "compose" });
  }
  async function pick(purpose: "moment" | "avatar" = "moment") {
    setBusy(true);
    try {
      const selected = await native<string[]>("pickPhotos", { purpose });
      if (selected.length) {
        if (purpose === "avatar") setAvatar(selected[0]);
        else setImages(selected);
      }
    } catch (e) {
      showNotice((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function save(draft: boolean) {
    if (!images.length) {
      showNotice("Choose at least one photo.");
      return;
    }
    const price = surface === "topics" ? Number(coinPrice) : 0;
    if (surface === "topics" && ((!draft && !topic) || (!coinPrice || (coinPrice !== "0" && price === 0)) || !Number.isInteger(price) || price < 0 || price > 9999 || (price > 0 && price >= categoryPrices[topic]))) {
      showNotice("Choose a category. A paid work needs a whole coin price below its category pass.");
      return;
    }
    const success = await act("saveMoment", {
      surface, coinPrice: price,
      id: draftID ?? crypto.randomUUID(),
      images,
      caption,
      topic,
      draft,
    });
    if (success) {
      setImages([]);
      setCaption("");
      root("me");
      setCollection(draft ? "Drafts" : "Moments");
      showNotice(draft ? "Draft saved." : "Moment saved to your library.");
    }
  }
  function loadWallet(): Promise<void> {
    if (walletRequest.current) return walletRequest.current;
    setWalletLoading(true);
    setWalletError("");
    const request = native<Wallet>("wallet").then(result => {
      setWallet(result);
      if (result.status === "failed" || result.status === "unavailable") throw new Error(priceStatus[result.status]);
    }).catch((e: Error) => {
      setWalletError(e.message);
      throw e;
    }).finally(() => {
      walletRequest.current = undefined;
      setWalletLoading(false);
    });
    walletRequest.current = request;
    return request;
  }
  async function buy(id: string) {
    if (busy || walletRequest.current || wallet?.checkoutBlocked) return;
    setBusy(true);
    try {
      await native("purchase", { id });
    } catch (e) {
      showNotice((e as Error).message);
    } finally {
      await native<Wallet>("walletSnapshot").then(setWallet).catch(() => {});
      setBusy(false);
    }
  }
  const loadingPrices =
    !walletError && (walletLoading || !wallet || wallet.status === "loading");
  const selectedOffer = wallet?.products.find(
    (offer) => offer.id === selectedOfferID && offer.price,
  );
  const pricesUnavailable =
    loadingPrices ||
    !!walletError ||
    wallet?.status === "failed" ||
    wallet?.status === "unavailable";
  const moments: Photo[] = (state?.moments ?? [])
    .filter((m) => !m.draft)
    .map((m) => ({
      ...m,
      author: state?.profile.name || "You",
      editorial: false,
    }));
  useEffect(() => {
    if (!entered) return;
    let active = true;
    native<Wallet>("walletSnapshot").then((value) => { if (active) setWallet(value); })
      .catch(() => { if (active) setWallet(undefined); });
    return () => { active = false; };
  }, [entered, route.name, route.id]);
  function locked(photo: Photo) {
    return photo.editorial && (photo.coinPrice ?? 0) > 0 && !wallet?.unlockedTopics.includes(photo.id) && !wallet?.unlockedCategories.includes(photo.topic);
  }
  async function unlock(photo: Photo, scope: "work" | "category") {
    const price = scope === "work" ? photo.coinPrice : categoryPrices[photo.topic];
    if (!price || busy) return;
    const subject = scope === "work" ? "this work" : `all current and future works in ${photo.topic}`;
    if (!confirm(`Spend ${price} Coins to unlock ${subject} on this iPhone?`)) return;
    setBusy(true);
    try { setWallet(await native<Wallet>("unlockTopicWork", { id: photo.id, scope, price })); }
    catch (error) { showNotice((error as Error).message); }
    finally { setBusy(false); }
  }
  const all = [...moments, ...catalog].map((p) => locked(p) ? { ...p, images: [p.preview ?? "assets/icons/credit-coin.png"] } : p);
  const visible = all.filter(
    (p) =>
      !state?.hidden.includes(p.id) && !state?.reportedPosts?.includes(p.id) &&
      (!state || !isBlocked(p.authorID, state)),
  );
  const homePhotos = visible.filter((photo) => photo.surface !== "topics");
  const topicPhotos = visible.filter((photo) => photo.surface === "topics");
  const listingAccess = route.name === "topic" ? (route.access ?? "All") : accessFilter;
  const listedTopicPhotos = topicPhotos.filter((p) => listingAccess === "All" || (listingAccess === "Paid") === ((p.coinPrice ?? 0) > 0));
  const categoryOffer = listedTopicPhotos.find((p) => p.topic === route.id && p.editorial && (p.coinPrice ?? 0) > 0);
  const selected = visible.find(p => p.id === route.id);
  useEffect(() => {
    if (route.name !== "detail" || !state || selected) return;
    const post = catalog.find(p => p.id === route.id);
    if (post && (state.reportedPosts?.includes(post.id) || isBlocked(post.authorID, state))) back();
  }, [route, state, selected]);
  const clips = state ? visibleShorts(state) : [];
  const listedTopicClips = listingAccess === "Paid" ? [] : clips;
  function openMember(id?: string) {
    if (!id || id === "you") push({ name: "me" });
    else push({ name: "member", id });
  }
  function rememberShort(videoID: string, topic: string) {
    setRoutes((current) =>
      current.map((item, index) =>
        index === current.length - 1 && item.name === "shorts"
          ? { ...item, videoID, id: topic || undefined }
          : item,
      ),
    );
  }
  function openMessage(id: string) {
    if (busy) return;
    if (state?.unreadChats?.includes(id)) void act("setChatUnread", { peerID: id, enabled: false });
    push({ name: "message", id });
  }
  function openShort(videoID: string) {
    push({ name: "shorts", videoID });
  }
  function PhotoCard({ photo }: { photo: Photo }) {
    if (!state) return null;
    if (locked(photo)) return (
      <article className="topic-lock">
        <img className="locked-preview" src={photo.images[0]} alt="Work preview" />
        <small>{photo.author} · {photo.topic}</small>
        <h3>{photo.caption}</h3>
        <button onClick={() => push({ name: "detail", id: photo.id })}>
          <Glyph name="credit-coin" />{photo.coinPrice} Coins
        </button>
      </article>
    );
    const count = engagement(photo.id, state);
    return (
      <article className="photo-card">
        <div className="author-row">
          <button className="author" onClick={() => openMember(photo.authorID)}>
            <img src={authorFor(photo.authorID, state).avatar} alt="" />
            <span>
              <strong>{photo.author}</strong>
              <small>
                {photo.editorial
                  ? "Everyday inspiration"
                  : new Date(photo.createdAt!).toLocaleDateString("en", {
                      month: "short",
                      day: "numeric",
                    })}
              </small>
            </span>
          </button>
          {photo.surface === "topics" && photo.authorID ? (
            <SafetyMenu postID={photo.id} authorID={photo.authorID} author={photo.author} act={act} busy={busy}
              share={() => void call("sharePhoto", { image: photo.images[0] })} hide={() => void act("hide", { id: photo.id })} />
          ) : <ActionButton
            icon="more"
            className="text-button"
            aria-label="Photo options"
            onClick={() => setOptions(photo)}
          >
            More
          </ActionButton>}
        </div>
        <div className="journal-print">
          <div className="photo-strip">
          {photo.images.map((src, index) => (
            <button
              className="photo-open"
              key={src}
              aria-label={`View photo ${index + 1}`}
              onClick={() => push({ name: "detail", id: photo.id })}
            >
              <img
                src={src}
                alt={photo.caption || "A saved everyday moment"}
                loading="lazy"
              />
            </button>
          ))}
        </div>
        </div>
        {photo.images.length > 1 && (
          <p className="photo-count">
            {photo.images.length} photos · Swipe to explore
          </p>
        )}
        <div className="actions">
          <ReactionButton
            className="icon-button"
            kind="like"
            aria-label="Like photo"
            selected={state.likes.includes(photo.id)}
            count={count.likes}
            disabled={busy}
            onClick={() => void act("toggleLike", { id: photo.id })}
          />
          <IconButton
            name="comment"
            count={count.comments}
            label="Open photo and comments"
            onClick={() => push({ name: "detail", id: photo.id })}
          />
          <ReactionButton
            className="icon-button"
            kind="save"
            aria-label="Save photo"
            selected={state.saves.includes(photo.id)}
            count={count.saves}
            disabled={busy}
            onClick={() => void act("toggleSave", { id: photo.id })}
          />
        </div>
        <p className="caption">{photo.caption}</p>
        {photo.topic && (
          <button
            className="topic-link"
            onClick={() => push({ name: "topic", id: photo.topic })}
          >
            {photo.topic}
          </button>
        )}
      </article>
    );
  }
  function Grid({ photos }: { photos: Photo[] }) {
    return (
      <div className="photo-grid">
        {photos.map((p) => (
          <button key={p.id} onClick={() => push({ name: "detail", id: p.id })}>
            <img
              src={p.images[0]}
              alt={p.caption || "Your moment"}
              loading="lazy"
            />
          </button>
        ))}
      </div>
    );
  }
  if (!state)
    return (
      <div className="startup">
        <AppLogo />
        <p>{error || "Opening your little moments…"}</p>
        {error && <>
          <p>Pull down to try again.</p>
          <PullToRefresh refresh={reloadLibrary} />
        </>}
      </div>
    );
  const consentChecked = consentChoice ?? state.consent;
  if (!entered || !state.consent)
    return (
      <main className="welcome">
        <AppLogo />
        <div className="welcome-photo">
          <img
            src={editorialCovers.welcome}
            alt="Two hands meeting over coffee"
          />
          <span className="welcome-stamp">A little moment, kept.</span>
        </div>
        <div className="welcome-copy">
          <h1>Welcome to Roro</h1>
          <p>Keep your photos. Find a little inspiration.</p>
          <div className="consent">
            <label className="consent-target">
              <input
                id="consent"
                type="checkbox"
                aria-labelledby="consent-description"
                checked={consentChecked}
                onChange={(e) => setConsentChoice(e.target.checked)}
              />
            </label>
            <span id="consent-description">
              <label htmlFor="consent">I agree to the </label>
              <a
                href={agreements.terms}
                onClick={(event) => {
                  event.preventDefault();
                  void call("openAgreement", { kind: "terms" });
                }}
              >
                Terms of Service
              </a>
              {" and "}
              <a
                href={agreements.privacy}
                onClick={(event) => {
                  event.preventDefault();
                  void call("openAgreement", { kind: "privacy" });
                }}
              >
                Privacy Policy
              </a>
              .
            </span>
          </div>
          <button
            type="button"
            className="primary wide"
            disabled={!consentChecked || busy}
            onClick={async () => {
              if (state.consent || (await act("consent"))) setEntered(true);
            }}
          >
            {busy ? "Opening…" : "Log in"}
          </button>
          <p className="status" role="status">
            {notice}
          </p>
        </div>
      </main>
    );
  const title: Record<string, string> = {
    home: "Home",
    topics: "Topics",
    shorts: "Shorts",
    chats: "Chats",
    findFriends: "Find friends",
    me: "Me",
    message: "Message",
    blocked: "Blocked people",
    reports: "Reported videos",
    reportedPosts: "Reported posts",
    reportedComments: "Reported comments",
    settings: "Settings",
    editProfile: "Edit profile",
    compose: draftID ? "Your draft" : "A new moment",
    wallet: "Wallet",
    credits: "Artwork & credits",
    hidden: "Hidden works",
    topic: route.id ?? "",
    detail: "A little moment",
    collection: "Roro inspiration",
    member: "Profile",
  };
  const topLevel = ["home", "topics", "shorts", "chats", "me"].includes(
    route.name,
  );
  const reactionIDs = route.name === "me" && (collection === "Liked" || collection === "Saved")
    ? new Set(collection === "Liked" ? state.likes : state.saves)
    : undefined;
  const reactionWorks = reactionIDs
    ? [...visible, ...clips].filter(work => reactionIDs.has(work.id))
    : undefined;
  const pullPage = route.name === "home" || route.name === "topics" || route.name === "chats"
    ? route.name : undefined;
  const query = homeSearch.query.trim().toLowerCase();
  const matchingPhotos = homePhotos.filter((photo) =>
    (scope === "Discover" || (photo.authorID && state.following.includes(photo.authorID)) ||
      (photo.editorial && state.following.includes("roro"))) &&
    `${photo.caption} ${photo.topic} ${photo.author}`.toLowerCase().includes(query)
  );
  const orderedPhotos = scope === "Discover" ? rotateItems(matchingPhotos, feedTurns.home) : matchingPhotos;
  const followedClips = clips.filter((clip) =>
    clip.authorID && state.following.includes(clip.authorID) &&
    `${clip.caption} ${clip.topic} ${authorFor(clip.authorID, state).name}`.toLowerCase().includes(query)
  );
  const featuredTopic = topics[feedTurns.home % topics.length];
  const isRootTab = topLevel && routes.length === 1;
  return (
    <div
      className={`app ${route.name === "shorts" ? "immersive-shorts" : ""}`}
    >
      {route.name !== "shorts" && (
        <PageHeader
          title={title[route.name]}
          showLogo={isRootTab}
          back={isRootTab ? undefined : back}
        >
          {route.name === "detail" && selected?.authorID && (
            <SafetyMenu postID={selected.id} authorID={selected.authorID} author={selected.author} act={act} busy={busy} />
          )}
          {route.name === "chats" && (
            <>
              <ToolbarSearch label="Search chats" value={chatSearch} change={setChatSearch} />
              <IconButton name="add-friend" label="Find friends" onClick={findFriends} />
            </>
          )}
          {route.name === "findFriends" && (
            <ToolbarSearch label="Search people" value={friendSearch} change={setFriendSearch} />
          )}
          {route.name === "topics" && (
            <>
              <IconButton name="topics" label="Filter topics" onClick={() => setFiltersOpen(true)} />
              <ToolbarSearch value={topicsSearch} change={setTopicsSearch} label="Search topics" />
              <IconButton name="plus" label="Create topic work" onClick={() => compose()} />
            </>
          )}
          {route.name === "home" && (
            <>
              <ToolbarSearch
                value={homeSearch}
                change={setHomeSearch}
                label="Search photos or people"
              />
              <IconButton
                name="plus"
                label="Add a moment"
                onClick={() => compose()}
              />
            </>
          )}
          {route.name === "me" && (
            <IconButton
              name="settings"
              label="Settings"
              onClick={() => push({ name: "settings" })}
            />
          )}
        </PageHeader>
      )}
      <main
        ref={contentRef}
        className={`content ${topLevel ? "with-tabs" : ""}`}
      >
        {route.name !== "shorts" && (
          <PullToRefresh
            key={route.name}
            refresh={async () => {
              if (route.name === "wallet") {
                if (wallet?.canRetry) await native("retryPurchases");
                await loadWallet();
                return;
              }
              await reloadLibrary();
              if (pullPage && pullPage !== "chats") setFeedTurns((turns) => ({ ...turns, [pullPage]: turns[pullPage] + 1 }));
            }}
          />
        )}
        {route.name === "home" && (
          <>
            <div className="segmented">
              {["Discover", "Following"].map((item) => (
                <button
                  key={item}
                  className={scope === item ? "selected" : ""}
                  onClick={() => setScope(item)}
                >
                  {item}
                </button>
              ))}
            </div>
            <button
              className="topic-banner"
              onClick={() => push({ name: "topic", id: featuredTopic })}
            >
              <span>
                <strong>{topicPrompts[featuredTopic]}</strong>
              </span>
              <span className="sr-only">{featuredTopic}</span>
            </button>
            {orderedPhotos.map((p) => <PhotoCard key={p.id} photo={p} />)}
            {scope === "Following" && (
              <div className="page">
                <ShortList
                  items={followedClips}
                  open={openShort}
                  profile={openMember}
                  state={state}
                  busy={busy}
                  act={act}
                  notify={showNotice}
                />
              </div>
            )}
            {homeSearch.query.trim() && !orderedPhotos.length &&
              !(scope === "Following" && followedClips.length) && (
                <Empty title="No matching moments">
                  <p>Try another name, topic or detail.</p>
                </Empty>
              )}
            {scope === "Following" &&
              !state.following.length &&
              !homeSearch.query.trim() && (
                <Empty title="Make this space yours">
                  <p>
                    Follow Roro inspiration to keep its photo collection close.
                  </p>
                  <ActionButton
                    icon="topics"
                    className="primary"
                    onClick={() => push({ name: "collection" })}
                  >
                    Explore the collection
                  </ActionButton>
                </Empty>
              )}
          </>
        )}
        {route.name === "topics" && (
          <>
            <Topics
              orderedTopics={rotateItems(topics, feedTurns.topics).filter((t) => !topicCategory || topicCategory === t)}
              query={topicsSearch.query}
              access={accessFilter}
              photos={listedTopicPhotos}
              shorts={listedTopicClips}
              state={state}
              open={(id) => push({ name: "topic", id, access: accessFilter })}
            />
            {filtersOpen && (
              <TopicFilterDialog
                category={topicCategory}
                access={accessFilter}
                dismiss={() => setFiltersOpen(false)}
                apply={(category, access) => {
                  setTopicCategory(category);
                  setAccessFilter(access);
                }}
              />
            )}
          </>
        )}
        {route.name === "shorts" && (
          <Shorts
            reloadLibrary={reloadLibrary}
            key={`${route.id ?? "all"}-${route.videoID ?? "feed"}-${route.blockRevision ?? 0}`}
            initialTopic={route.id}
            selectedID={route.videoID}
            profile={openMember}
            onLeave={rememberShort}
            back={isRootTab ? undefined : back}
            search={shortSearch}
            changeSearch={setShortSearch}
            openTopic={(id) => push({ name: "topic", id })}
            state={state}
            busy={busy}
            act={act}
            notify={showNotice}
          />
        )}
        {route.name === "topic" && (
          <>
            <div className="topic-cover">
              <p>Little things worth keeping.</p>
              <h2>{route.id}</h2>
              <p className="topic-summary">
                {(() => {
                  const count = totals(
                    [...listedTopicPhotos, ...listedTopicClips].filter(
                      (item) => item.topic === route.id,
                    ),
                    state,
                  );
                  return `${count.works} works · ${count.likes} likes · ${count.saves} saves · ${count.comments} comments`;
                })()}
              </p>
              {categoryOffer && (
                <div className="category-offer">
                  {wallet?.unlockedCategories.includes(categoryOffer.topic) ? <span>Category unlocked</span> :
                    <button disabled={busy} onClick={() => {
                      if (wallet && wallet.balance < categoryPrices[categoryOffer.topic]) push({ name: "wallet" });
                      else void unlock(categoryOffer, "category");
                    }}><Glyph name="credit-coin" />Category pass · {categoryPrices[categoryOffer.topic]} Coins</button>}
                  <small>Includes current and future paid works in this category.</small>
                </div>
              )}
              <div className="topic-cover-actions">
                <ActionButton
                  icon="camera"
                  onClick={() => {
                    compose();
                    setTopic(route.id ?? "");
                  }}
                >
                  Add a photo
                </ActionButton>
                {listedTopicClips.some((clip) => clip.topic === route.id) && <ActionButton
                  icon="shorts"
                  onClick={() => push({ name: "shorts", id: route.id })}
                >
                  Explore shorts ·{" "}
                  {listedTopicClips.filter((short) => short.topic === route.id).length}
                </ActionButton>}
              </div>
            </div>
            {listedTopicPhotos
              .filter((p) => p.topic === route.id)
              .map((p) => (
                <PhotoCard key={p.id} photo={p} />
              ))}
            {listedTopicClips.filter((clip) => clip.topic === route.id).map((clip) => (
              <div className="setting-row page" key={clip.id}>
                <span>{clip.caption || "Short video"}</span>
                <ActionButton icon="shorts" onClick={() => openShort(clip.id)}>
                  Play {clip.caption || "short video"}
                </ActionButton>
              </div>
            ))}
            {!listedTopicPhotos.some((p) => p.topic === route.id) &&
              !listedTopicClips.some((clip) => clip.topic === route.id) && (
                <Empty title="Your moment belongs here">
                  <p>Save a photo with this topic to start your collection.</p>
                </Empty>
              )}
          </>
        )}
        {route.name === "detail" &&
          (selected && locked(selected) ? (
            <section className="page topic-lock">
              <small>{selected.author} · {selected.topic}</small>
              <h2>{selected.caption}</h2>
              <p>{wallet ? `Your balance: ${wallet.balance} Coins` : "Checking balance…"}</p>
              <div className="unlock-choices">
                <button disabled={busy || (!!wallet && wallet.balance < (selected.coinPrice ?? 0))}
                  onClick={() => void unlock(selected, "work")}>
                  <Glyph name="credit-coin" /><span>This work · {selected.coinPrice} Coins</span>
                </button>
                <button disabled={busy || (!!wallet && wallet.balance < categoryPrices[selected.topic])}
                  onClick={() => void unlock(selected, "category")}>
                  <Glyph name="topics" /><span>Category pass · {categoryPrices[selected.topic]} Coins</span>
                </button>
              </div>
              <p className="muted">The pass includes current and future works in {selected.topic} on this iPhone.</p>
              {(!wallet || wallet.balance < Math.max(selected.coinPrice ?? 0, categoryPrices[selected.topic])) && (
                <button onClick={() => push({ name: "wallet" })}><Glyph name="wallet" />Add coins</button>
              )}
            </section>
          ) : selected ? (
            <div className="detail">
              <div className="detail-images">
                {selected.images.map((src, i) => (
                  <button
                    key={src}
                    onClick={() => setFullImage(src)}
                    aria-label={`Open full photo ${i + 1}`}
                  >
                    <img src={src} alt={selected.caption || "Your photo"} />
                  </button>
                ))}
              </div>
              <div className="page">
                <button
                  className="detail-author text-button"
                  aria-label={`Open ${selected.author}'s profile`}
                  onClick={() => openMember(selected.authorID)}
                >
                  <ProfilePortrait
                    avatar={selected.authorID && selected.authorID !== "you"
                      ? authorFor(selected.authorID, state).avatar
                      : state.profile.avatar}
                    name={selected.author}
                  />
                  <span>{selected.author}</span>
                </button>
                <h2>{selected.caption || "A little moment"}</h2>
                {selected.topic && (
                  <button
                    className="topic-link"
                    onClick={() => push({ name: "topic", id: selected.topic })}
                  >
                    {selected.topic}
                  </button>
                )}
                <div className="detail-actions">
                  <ReactionButton
                    className="icon-button detail-like"
                    kind="like"
                    aria-label="Like photo"
                    selected={state.likes.includes(selected.id)}
                    count={engagement(selected.id, state).likes}
                    disabled={busy}
                    onClick={() => void act("toggleLike", { id: selected.id })}
                  />
                  <ReactionButton
                    className="icon-button detail-save"
                    kind="save"
                    aria-label="Save photo"
                    selected={state.saves.includes(selected.id)}
                    count={engagement(selected.id, state).saves}
                    disabled={busy}
                    onClick={() => void act("toggleSave", { id: selected.id })}
                  />
                  <ActionButton
                    icon="share"
                    className="detail-share"
                    onClick={() =>
                      void call("sharePhoto", { image: selected.images[0] })
                    }
                  >
                    Share
                  </ActionButton>
                </div>
                <Comments
                  key={selected.id}
                  showStorageNotice={false}
                  postID={selected.id}
                  profile={openMember}
                  state={state}
                  busy={busy}
                  act={act}
                  notify={showNotice}
                />
              </div>
            </div>
          ) : (
            <Empty title="Photo unavailable">
              <p>This photo may have been removed.</p>
            </Empty>
          ))}
        {route.name === "member" && route.id && (
          <MemberProfile
            id={route.id}
            message={openMessage}
            photos={visible}
            shorts={clips}
            open={openShort}
            openPhoto={(id) => push({ name: "detail", id })}
            state={state}
            busy={busy}
            act={act}
            notify={showNotice}
          />
        )}
        {route.name === "collection" && (
          <div className="page">
            <div className="collection-cover">
              <img
                src={editorialCovers.collection}
                alt="Sunlit green fern fronds"
              />
              <h2>
                Small things.
                <br />A fresh perspective.
              </h2>
              <p>A curated collection of everyday inspiration.</p>
              <ActionButton
                icon={state.following.includes("roro") ? "check" : "plus"}
                aria-pressed={state.following.includes("roro")}
                disabled={busy}
                className="primary"
                onClick={() => void act("toggleFollow", { id: "roro" })}
              >
                {state.following.includes("roro")
                  ? "Following"
                  : "Follow collection"}
              </ActionButton>
            </div>
            <Grid photos={homePhotos.filter((p) => p.editorial)} />
          </div>
        )}
        {route.name === "compose" && (
          <div className="page compose">
            <button
              className="photo-picker"
              disabled={busy}
              onClick={() => void pick()}
            >
              {images.length ? (
                <img src={images[0]} alt="Selected photo" />
              ) : (
                <>
                  <Icon name="camera" />
                  <strong className="sr-only">Choose a little moment</strong>
                  <span className="sr-only">Up to 3 photos</span>
                </>
              )}
            </button>
            {images.length > 0 && (
              <div className="selected-images">
                {images.map((src, i) => (
                  <button
                    key={src}
                    aria-label={`Remove photo ${i + 1}`}
                    onClick={() =>
                      setImages((current) => current.filter((x) => x !== src))
                    }
                  >
                    <img src={src} alt={`Selected photo ${i + 1}`} />
                    <Icon name="close" />
                  </button>
                ))}
              </div>
            )}
            <label className="field">
              <span>
                A few words <small>Optional</small>
              </span>
              <textarea
                value={caption}
                maxLength={500}
                onChange={(e) => setCaption(e.target.value)}
                placeholder="What would you like to remember?"
              />
            </label>
            <label className="field">
              <span>
                Topic {surface !== "topics" && <small>Optional</small>}
              </span>
              <select value={topic} onChange={(e) => setTopic(e.target.value)}>
                <option value="">Choose a topic</option>
                {topics.map((t) => (
                  <option key={t}>{t}</option>
                ))}
              </select>
            </label>
            {surface === "topics" && (
              <>
                <label className="field">Reader access
                  <select value={coinPrice === "0" ? "free" : "paid"} onChange={(e) => setCoinPrice(e.target.value === "free" ? "0" : "10")}>
                    <option value="free">Free</option><option value="paid">Paid</option>
                  </select>
                </label>
                {coinPrice !== "0" && topic && <p className="muted">{topic} category pass: {categoryPrices[topic]} Coins</p>}
                {coinPrice !== "0" && <label className="field">Unlock price in coins
                  <input inputMode="numeric" type="text" maxLength={4} value={coinPrice}
                    onChange={(e) => { if (/^\d*$/.test(e.target.value)) setCoinPrice(e.target.value.replace(/^0+/, "")); }} />
                </label>}
              </>
            )}
            <p className="muted">
              Your photos stay in your library on this iPhone.
            </p>
            <ActionButton
              icon="check"
              className="primary wide"
              disabled={busy || !images.length}
              onClick={() => void save(false)}
            >
              {busy ? "Saving…" : "Save moment"}
            </ActionButton>
            <ActionButton
              icon="bookmark"
              className="secondary wide"
              disabled={busy || !images.length}
              onClick={() => void save(true)}
            >
              Save draft
            </ActionButton>
          </div>
        )}
        {route.name === "chats" && (
          <ChatList state={state} scope={chatScope} select={setChatScope} query={chatSearch.query}
            open={openMessage} profile={openMember} findFriends={findFriends} act={act} busy={busy} />
        )}
        {route.name === "findFriends" && (
          <FindFriends state={state} query={friendSearch.query} profile={openMember} open={openMessage} act={act} busy={busy} />
        )}
        {route.name === "me" && (
          <>
            <div className="profile-cover personal-cover">
              <ProfilePortrait avatar={state.profile.avatar} name={state.profile.name} />
              <h1>{state.profile.name || "Your little moments"}</h1>
              <p>{state.profile.bio || "The everyday, through your eyes."}</p>
              <div className="stats">
                <span>
                  <strong>{moments.length}</strong>Moments
                </span>
                <span>
                  <strong>
                    {
                      [...visible, ...clips].filter((item) =>
                        state.saves.includes(item.id),
                      ).length
                    }
                  </strong>
                  Saved
                </span>
                <span>
                  <strong>{state.following.length}</strong>Following
                </span>
              </div>
              <button
                className="profile-wallet-card"
                type="button"
                onClick={() => push({ name: "wallet" })}
              >
                <Glyph name="wallet" />
                <strong>Wallet</strong>
                <span>{wallet?.balance.toLocaleString("en") ?? "—"} {coinUnit(wallet?.balance)}</span>
              </button>
            </div>
            <div className="segmented me-collections" role="group" aria-label="Personal collections">
              {["Moments", "Shorts", "Liked", "Saved", "Drafts"].map((item) => (
                <button
                  key={item}
                  className={collection === item ? "selected" : ""}
                  aria-pressed={collection === item}
                  onClick={() => setCollection(item)}
                >
                  {item}
                </button>
              ))}
            </div>
            {collection === "Moments" || collection === "Shorts" ? (
              <div className="page">
                {collection === "Moments" && moments.length > 0 ? (
                  <Grid photos={moments} />
                ) : collection === "Shorts" && state.shorts?.length ? (
                  <WorkGrid items={state.shorts} open={openShort} />
                ) : (
                  <Empty title="No posts yet">
                    <p>{collection === "Moments" ? "Your photos will appear here." : "Your videos will appear here."}</p>
                  </Empty>
                )}
              </div>
            ) : collection === "Drafts" ? (
              <div className="page">
                {state.moments
                  .filter((m) => m.draft)
                  .map((m) => (
                    <div className="draft-row" key={m.id}>
                      <button onClick={() => compose(m)}>
                        <img src={m.images[0]} alt="Draft" />
                        <span>{m.caption || "An unfinished moment"}</span>
                      </button>
                      <ActionButton
                        icon="trash"
                        className="text-button"
                        onClick={() => {
                          if (confirm("Delete this draft?"))
                            void act("deleteMoment", { id: m.id });
                        }}
                      >
                        Delete
                      </ActionButton>
                    </div>
                  ))}
                {!state.moments.some((m) => m.draft) && (
                  <Empty title="Room for an idea">
                    <p>Your unfinished moments will be kept here.</p>
                  </Empty>
                )}
              </div>
            ) : reactionWorks && (
              <div className="page">
                <WorkGrid collection items={reactionWorks} open={(id, work) => {
                  if ("poster" in work) openShort(id);
                  else push({ name: "detail", id });
                }} />
                {reactionWorks.length === 0 && (
                  <Empty title={collection === "Liked" ? "No likes yet" : "Keep what catches your eye"}>
                    <p>{collection === "Liked" ? "Photos, topic posts and shorts you like appear here." : "Save a photo or short to find it here."}</p>
                    <ActionButton icon="plus" className="primary" onClick={() => root("home")}>
                      Find inspiration
                    </ActionButton>
                  </Empty>
                )}
              </div>
            )}
          </>
        )}
        {route.name === "settings" && (
          <div className="page settings">
            <button
              type="button"
              className="setting-row"
              onClick={() => {
                setName(state.profile.name);
                setBio(state.profile.bio);
                setAvatar(state.profile.avatar);
                push({ name: "editProfile" });
              }}
            >
              <span>Edit profile</span>
              <Glyph name="edit" />
            </button>
            <button
              type="button"
              className="setting-row"
              onClick={() => push({ name: "hidden" })}
            >
              <span>
                Hidden works ·{" "}
                {
                  [...all, ...allShorts(state)].filter(
                    (item) =>
                      state.hidden.includes(item.id) &&
                      !isBlocked(item.authorID, state),
                  ).length
                }
              </span>
              <Glyph name="eye" />
            </button>
            <button
              type="button"
              className="setting-row"
              onClick={() => push({ name: "blocked" })}
            >
              <span>Blocked people · {state.blocked?.length ?? 0}</span>
              <span className="blocked-glyph" aria-hidden="true">🚫</span>
            </button>
            <button type="button" className="setting-row" onClick={() => push({ name: "reports" })}>
              <span>Reported videos · {state.reports?.length ?? 0}</span>
              <Glyph name="info" />
            </button>
            <button type="button" className="setting-row" onClick={() => push({ name: "reportedPosts" })}>
              <span>Reported posts · {state.reportedPosts?.length ?? 0}</span>
              <Glyph name="info" />
            </button>
            <button type="button" className="setting-row" onClick={() => push({ name: "reportedComments" })}>
              <span>Reported comments · {state.reportedComments?.length ?? 0}</span>
              <Glyph name="info" />
            </button>
            <a
              className="setting-row"
              href={agreements.terms}
              onClick={(event) => {
                event.preventDefault();
                void call("openAgreement", { kind: "terms" });
              }}
            >
              Terms of Service
            </a>
            <a
              className="setting-row"
              href={agreements.privacy}
              onClick={(event) => {
                event.preventDefault();
                void call("openAgreement", { kind: "privacy" });
              }}
            >
              Privacy Policy
            </a>
            <button
              type="button"
              className="setting-row"
              onClick={() => push({ name: "credits" })}
            >
              <span>Artwork &amp; credits</span>
              <Glyph name="info" />
            </button>
            <p className="muted">
              Roro keeps your moments on this iPhone. Sharing opens your
              iPhone’s share sheet.
            </p>
            <button
              type="button"
              className="setting-row"
              disabled={busy}
              onClick={onLogOut}
            >
              <span>Log out</span>
              <Glyph name="close" />
            </button>
            <button
              type="button"
              className="setting-row danger"
              disabled={busy}
              onClick={async () => {
                if (
                  confirm(
                    "Delete your Roro photos, shorts, drafts, comments, notes, relationships and profile from this iPhone? Original photos, videos and purchase records are kept.",
                  )
                ) {
                  if (await act("clearLibrary")) {
                    setEntered(false);
                    setConsentChoice(undefined);
                    setHomeSearch(emptySearch);
                    setShortSearch(emptySearch);
                    root("home");
                  }
                }
              }}
            >
              <span>Delete local account</span>
              <Glyph name="trash" />
            </button>
            <p className="version">Roro 0.1.0</p>
          </div>
        )}
        {(route.name === "blocked" || route.name === "reports") && (
          <div className="page">
            {route.name === "blocked" ? <>
              {(state.blocked ?? []).map(id => {
                const label = authors.find(author => author.id === id)?.name ?? "Community member";
                return <SafetyRecord key={id} blocked openProfile={() => openMember(id)} label={label} action={`Unblock ${label}`} busy={busy}
                  undo={() => void act("setBlock", { id, enabled: false })} />;
              })}
              {!state.blocked?.length && <Empty title="No blocked people" />}
            </> : <>
              <p className="muted">Reports are saved only on this iPhone.</p>
              {(state.reports ?? []).map(id => {
                const label = allShorts(state).find(item => item.id === id)?.caption || "Community video";
                return <SafetyRecord key={id} label={label} action={`Withdraw report for ${label}`} busy={busy}
                  undo={() => void act("setReport", { id, enabled: false })} />;
              })}
              {!state.reports?.length && <Empty title="No reported videos" />}
            </>}
          </div>
        )}
        {route.name === "reportedPosts" && (
          <div className="page">
            <p className="muted">Reports are saved only on this iPhone.</p>
            {(state.reportedPosts ?? []).map(id => {
              const label = catalog.find(post => post.id === id)?.caption ?? "Community post";
              return <SafetyRecord key={id} label={label} action={`Withdraw report for ${label}`} busy={busy}
                undo={() => void act("setReport", { kind: "post", id, enabled: false })} />;
            })}
            {!state.reportedPosts?.length && <Empty title="No reported posts" />}
          </div>
        )}
        {route.name === "reportedComments" && (
          <div className="page">
            <p className="muted">Reports are saved only on this iPhone.</p>
            {(state.reportedComments ?? []).map(id => {
              const comment = communityComments.find(item => item.id === id);
              if (!comment) return null;
              const label = `${authorFor(comment.authorID, state).name} — ${comment.text}`;
              return <SafetyRecord key={id} label={label} action={`Withdraw report for ${label}`} busy={busy}
                undo={() => void act("setReport", { kind: "comment", id, enabled: false })} />;
            })}
            {!state.reportedComments?.length && <Empty title="No reported comments" />}
          </div>
        )}
        {route.name === "message" && route.id && (
          <Conversation preview={(peerID, mode) => void call("openCallPreview", {peerID, mode})} key={route.id} peerID={route.id} state={state} profile={openMember} act={act} busy={busy} />
        )}
        {route.name === "editProfile" && (
          <div className="page">
            <button type="button" className="edit-avatar" aria-label="Change profile photo"
              disabled={busy} onClick={() => void pick("avatar")}>
              <ProfilePortrait avatar={avatar} name={name} />
              <span className="edit-avatar-badge"><Glyph name="camera" /></span>
            </button>
            <label className="field">
              <span>Name</span>
              <input
                value={name}
                maxLength={40}
                onChange={(e) => setName(e.target.value)}
                placeholder="Your name"
              />
            </label>
            <label className="field">
              <span>About you</span>
              <textarea
                value={bio}
                maxLength={160}
                onChange={(e) => setBio(e.target.value)}
                placeholder="A little about your everyday"
              />
            </label>
            <ActionButton
              icon="check"
              className="primary wide"
              disabled={busy || (!name.trim() && (!!state.profile.name || !avatar))}
              onClick={async () => {
                if (await act("profile", { name, bio, avatar })) back();
              }}
            >
              Save profile
            </ActionButton>
          </div>
        )}
        {route.name === "hidden" && (
          <div className="page">
            {all
              .filter(
                (p) =>
                  state.hidden.includes(p.id) && !isBlocked(p.authorID, state),
              )
              .map((p) => (
                <div className="draft-row" key={p.id}>
                  <img src={p.images[0]} alt="Hidden photo" />
                  <span>{p.caption}</span>
                  <ActionButton
                    icon="eye"
                    className="text-button"
                    onClick={() => void act("hide", { id: p.id })}
                  >
                    Show
                  </ActionButton>
                </div>
              ))}
            {allShorts(state)
              .filter(
                (clip) =>
                  state.hidden.includes(clip.id) &&
                  !isBlocked(clip.authorID, state),
              )
              .map((clip) => (
                <div className="draft-row" key={clip.id}>
                  <img src={clip.poster} alt="Hidden short" />
                  <span>{clip.caption}</span>
                  <ActionButton
                    icon="eye"
                    className="text-button"
                    onClick={() => void act("hide", { id: clip.id })}
                  >
                    Show
                  </ActionButton>
                </div>
              ))}
            {![...all, ...allShorts(state)].some(
              (item) =>
                state.hidden.includes(item.id) &&
                !isBlocked(item.authorID, state),
            ) && (
              <Empty title="Nothing hidden">
                <p>Photos and shorts you hide can be shown again here.</p>
              </Empty>
            )}
          </div>
        )}
        {route.name === "wallet" && (
          <div className="page wallet-page">
            <div className="wallet-balance">
              <span>Your balance</span>
              <div className="wallet-balance-amount">
                <img src="assets/icons/credit-coin.png" width={36} height={36} alt="" />
                <strong>{wallet?.balance.toLocaleString("en") ?? "—"}</strong>
              </div>
              <span>{coinUnit(wallet?.balance)}</span>
            </div>
            <section aria-labelledby="wallet-offers">
              <h2 id="wallet-offers">Buy coins</h2>
              <div className="offers" aria-busy={loadingPrices}>
                {wallet?.products.map((offer) => {
                  const amount = offer.credits.toLocaleString("en");
                  const price = pricesUnavailable ? null : offer.price;
                  const selected = !!price && selectedOfferID === offer.id;
                  const priceLabel = loadingPrices ? "—" : price ?? "Unavailable";
                  return (
                    <button
                      key={offer.id}
                      className="offer"
                      disabled={!price || busy || wallet.checkoutBlocked}
                      aria-pressed={selected}
                      aria-label={`${amount} ${coinUnit(offer.credits).toLowerCase()}, ${loadingPrices ? "loading price" : priceLabel}`}
                      onClick={() => setSelectedOfferID(offer.id)}
                    >
                      <span className="offer-credits">
                        <img src="assets/icons/credit-coin.png" width={32} height={32} alt="" />
                        <strong>{amount}</strong>
                        <span>{coinUnit(offer.credits)}</span>
                      </span>
                      <span className="offer-price">{priceLabel}</span>
                      {selected && <Glyph name="check" />}
                    </button>
                  );
                })}
              </div>
              <div className="wallet-status muted" role="status">
                {walletError || priceStatus[loadingPrices ? "loading" : wallet?.status ?? "unavailable"]}
              </div>
              {selectedOffer?.price && !pricesUnavailable && (
                <div className="setting-row wallet-checkout">
                  <span>
                    Purchase · <strong>{selectedOffer.price}</strong>
                  </span>
                  <ActionButton
                    icon="wallet"
                    disabled={busy || wallet?.checkoutBlocked}
                    onClick={() => void buy(selectedOffer.id)}
                  >
                    Buy {selectedOffer.credits.toLocaleString("en")} {coinUnit(selectedOffer.credits).toLowerCase()} for {selectedOffer.price}
                  </ActionButton>
                </div>
              )}
              {wallet?.canRetry && (
                <div className="setting-row">
                  <span>Pending purchase</span>
                  <span>Pull down to check again.</span>
                </div>
              )}
              <div className="wallet-status muted" role="status">
                {wallet?.notice}
              </div>
            </section>
            <h2>Wallet activity</h2>
            {wallet?.activity.length ? (
              wallet.activity.map((a) => (
                <div className="history" key={a.id}>
                  <span>{a.label && a.label + " · "}{new Date(a.date).toLocaleDateString("en")}</span>
                  <strong>{a.credits > 0 ? "+" : ""}{a.credits.toLocaleString("en")} {coinUnit(a.credits).toLowerCase()}</strong>
                </div>
              ))
            ) : wallet ? (
              <p className="muted">No wallet activity yet.</p>
            ) : null}
          </div>
        )}
        {route.name === "credits" && (
          <div className="page credits">
            <h2>Everyday inspiration</h2>
            <p>
              Home features photography from Unsplash and Pexels. Topic photographs, editorial covers and member avatars are licensed from Pexels.
              These images are editorial material. Photo subjects are not
              presented as Roro members.
            </p>
            <p>
              Source URLs, file hashes and license information are included in
              the app’s asset manifest.
            </p>
            <h2>Pexels photography</h2>
            {pexelsCredits.map((item) => (
              <p key={item.id}>{item.title} · {item.author}</p>
            ))}
            <h2>Shorts sources</h2>
            <p>
              Videos are licensed from Pexels. Community profiles and
              conversations are locally curated fictional personas. Source
              creators and people in the footage are not represented as Roro
              members.
            </p>
            {sourceCredits.map((clip) => (
              <div className="source-credit" key={clip.id}>
                <strong>{clip.sourceAuthor}</strong>
                <span>Pexels License</span>
                <ActionButton
                  icon="share"
                  className="text-button"
                  onClick={() => void call("openSource", { id: clip.id })}
                >
                  View original video
                </ActionButton>
              </div>
            ))}
            <p>Typography — Kalam and Courgette, SIL Open Font License 1.1.</p>
            <p>Interface artwork — original images generated for Roro.</p>
            <p>Your imported photographs and videos remain yours.</p>
          </div>
        )}
      </main>
      {topLevel && (
        <nav className="tabbar" aria-label="Main navigation">
          {[
            { name: "home", icon: "home", label: "Home" },
            { name: "topics", icon: "topics", label: "Topics" },
            { name: "shorts", icon: "shorts", label: "Shorts" },
            { name: "chats", icon: "chat", label: "Chats" },
            { name: "me", icon: "profile", label: "Me" },
          ].map((tab) => (
            <button
              key={tab.name}
              className={route.name === tab.name ? "selected" : ""}
              aria-current={route.name === tab.name ? "page" : undefined}
              onClick={() => root(tab.name as Route["name"])}
            >
              <Icon name={tab.icon} />
              <span>{tab.label}</span>
            </button>
          ))}
        </nav>
      )}
      {notice && (
        <div className="toast" role="status">
          {notice}
        </div>
      )}
      {fullImage && (
        <div
          className="lightbox"
          role="dialog"
          aria-modal="true"
          aria-label="Full photo"
        >
          <ActionButton icon="close" onClick={() => setFullImage(undefined)}>
            Close
          </ActionButton>
          <img src={fullImage} alt="Full photo" />
        </div>
      )}
      {options && (
        <div
          className="sheet-shade"
          role="dialog"
          aria-modal="true"
          aria-label="Photo options"
        >
          <div className="sheet">
            <h2>This moment</h2>
            <div className="menu-actions">
              <ActionButton
                labelPosition="below"
                icon="share"
                onClick={() => {
                  void call("sharePhoto", { image: options.images[0] });
                  setOptions(undefined);
                }}
              >
                Share photo
              </ActionButton>
              {options.editorial ? (
                <ActionButton
                  labelPosition="below"
                  icon="eye"
                  onClick={() => {
                    void act("hide", { id: options.id });
                    setOptions(undefined);
                  }}
                >
                  Hide photo
                </ActionButton>
              ) : (
                <ActionButton
                  labelPosition="below"
                  icon="trash"
                  className="danger"
                  onClick={() => {
                    if (
                      confirm(
                        "Delete this moment from Roro? Your original photos are kept.",
                      )
                    ) {
                      void act("deleteMoment", { id: options.id });
                      setOptions(undefined);
                    }
                  }}
                >
                  Delete moment
                </ActionButton>
              )}
              <ActionButton labelPosition="below" icon="close" onClick={() => setOptions(undefined)}>
                Cancel
              </ActionButton>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
