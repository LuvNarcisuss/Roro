export type Topic =
  | "Little joys"
  | "On my walk"
  | "At home"
  | "Today's sky"
  | "Something delicious";
export interface Moment {
  coinPrice?: number;
  surface?: string;
  id: string;
  images: string[];
  caption: string;
  topic: string;
  createdAt: string;
  draft: boolean;
}
export interface ImportedVideo {
  video: string;
  poster: string;
  duration: number;
}
export interface ShortVideo extends ImportedVideo {
  authorID?: string;
  sourceAuthor?: string;
  sourceURL?: string;
  id: string;
  caption: string;
  topic: string;
  createdAt: string;
}
export interface Note {
  id: string;
  postID: string;
  text: string;
  createdAt: string;
}
export interface ChatEntry {
  id: string;
  peerID: string;
  text: string;
  createdAt: string;
}
export interface Snapshot {
  contacts?: string[];
  incomingRequests?: string[];
  verifiedFriends?: string[];
  messagingPeers?: string[];
  followers?: string[];
  chatEntries?: ChatEntry[];
  archivedChats?: string[];
  pinnedChats?: string[];
  unreadChats?: string[];
  revision: number;
  consent: boolean;
  cleanupPending?: boolean;
  profile: { name: string; bio: string; avatar?: string };
  moments: Moment[];
  shorts?: ShortVideo[];
  likes: string[];
  saves: string[];
  following: string[];
  hidden: string[];
  blocked?: string[];
  reports?: string[];
  reportedPosts?: string[];
  reportedComments?: string[];
  notes: Note[];
  comments?: (Note & { parentID?: string })[];
}
export interface Photo {
  preview?: string;
  coinPrice?: number;
  surface?: string;
  authorID?: string;
  id: string;
  images: string[];
  caption: string;
  topic: string;
  author: string;
  editorial: boolean;
  createdAt?: string;
}
export interface Offer {
  id: string;
  price: string | null;
  credits: number;
}
export interface Wallet {
  unlockedTopics: string[];
  unlockedCategories: string[];
  notice: string;
  balance: number;
  products: Offer[];
  status: "loading" | "ready" | "partial" | "unavailable" | "failed";
  checkoutBlocked: boolean;
  canRetry: boolean;
  activity: { id: string; label?: string; credits: number; date: string }[];
}
export type Command =
  | "snapshot"
  | "consent"
  | "toggleLike"
  | "toggleSave"
  | "toggleFollow"
  | "setContact"
  | "respondFriendRequest"
  | "removeFriend"
  | "openCallPreview"
  | "saveChatEntry"
  | "setChatArchived"
  | "setChatPinned"
  | "setChatUnread"
  | "deleteConversation"
  | "setReport"
  | "setBlock"
  | "toggleBlock"
  | "hide"
  | "addComment"
  | "deleteComment"
  | "openSource"
  | "addNote"
  | "deleteNote"
  | "saveMoment"
  | "deleteMoment"
  | "profile"
  | "pickPhotos"
  | "pickVideo"
  | "playVideo"
  | "videoSource"
  | "discardVideo"
  | "saveShort"
  | "deleteShort"
  | "openAgreement"
  | "sharePhoto"
  | "wallet"
  | "unlockTopicWork"
  | "walletSnapshot"
  | "purchase"
  | "retryPurchases"
  | "clearLibrary";
