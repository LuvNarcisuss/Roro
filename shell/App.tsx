import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  AppState,
  NativeModules,
  StyleSheet,
  Text,
  View,
  Pressable,
  ActivityIndicator,
  Image,
} from "react-native";
import { WebView } from "react-native-webview";
import type { WebViewMessageEvent } from "react-native-webview";
const service = NativeModules.RoroNative as {
  prepare(): Promise<{ uri: string; directory: string }>;
  execute(command: string, payload: Record<string, unknown>): Promise<unknown>;
};
const commands = new Set([
  "snapshot",
  "consent",
  "toggleLike",
  "toggleSave",
  "toggleFollow",
  "toggleBlock",
  "hide",
  "addComment",
  "deleteComment",
  "openSource",
  "addNote",
  "deleteNote",
  "saveMoment",
  "deleteMoment",
  "profile",
  "pickPhotos",
  "pickVideo",
  "playVideo",
  "videoSource",
  "discardVideo",
  "saveShort",
  "deleteShort",
  "openAgreement",
  "sharePhoto",
  "wallet",
  "walletSnapshot",
  "purchase",
  "retryPurchases",
  "clearLibrary",
]);
export default function App() {
  const web = useRef<WebView<object>>(null);
  const [entry, setEntry] = useState<{ uri: string; directory: string }>();
  const [error, setError] = useState("");
  const [generation, setGeneration] = useState(0);
  const processed = useRef(new Set<string>());
  const epoch = useRef(0);
  const prepare = useCallback(async () => {
    setError("");
    try {
      setEntry(await service.prepare());
    } catch (e) {
      setError((e as Error).message);
    }
  }, []);
  useEffect(() => {
    void prepare();
  }, [prepare]);
  useEffect(() => {
    const listener = AppState.addEventListener("change", (state) => {
      web.current?.injectJavaScript(
        `window.roroActive = ${state === "active"}; window.dispatchEvent(new Event("roro-playback")); true;`,
      );
      if (state === "active")
        void service.execute("retryPurchases", {}).catch(() => {});
    });
    return () => listener.remove();
  }, []);
  async function receive(event: WebViewMessageEvent) {
    if (
      !entry ||
      event.nativeEvent.url.split("#")[0] !== entry.uri ||
      event.nativeEvent.data.length > 65536
    )
      return;
    let message: {
      id: string;
      command: string;
      payload: Record<string, unknown>;
    };
    try {
      message = JSON.parse(event.nativeEvent.data);
    } catch {
      return;
    }
    if (!message || typeof message !== "object" || Array.isArray(message))
      return;
    if (
      typeof message.id !== "string" ||
      message.id.length > 64 ||
      !commands.has(message.command) ||
      !message.payload ||
      typeof message.payload !== "object" ||
      Array.isArray(message.payload) ||
      processed.current.has(message.id)
    )
      return;
    processed.current.add(message.id);
    if (processed.current.size > 10000) {
      setError("Please reopen your library to continue.");
      return;
    }
    const current = epoch.current;
    let reply: Record<string, unknown>;
    try {
      reply = {
        id: message.id,
        result: await service.execute(message.command, message.payload),
      };
    } catch (e) {
      reply = {
        id: message.id,
        error: (e as Error).message || "Please try again.",
      };
    }
    if (current !== epoch.current) return;
    web.current?.injectJavaScript(
      `window.roroReply && window.roroReply(${JSON.stringify(reply).replace(/</g, "\\u003c")}); true;`,
    );
  }
  if (error || !entry)
    return (
      <View style={styles.loading}>
        <Text style={styles.brand}>roro.</Text>
        {error ? (
          <>
            <Text style={styles.message}>{error}</Text>
            <Pressable
              style={styles.button}
              accessibilityLabel="Try opening Roro again"
              onPress={() => {
                setEntry(undefined);
                setGeneration((v) => v + 1);
                void prepare();
              }}
            >
              <Image
                source={require("../Assets/icons/home.png")}
                style={{ width: 32, height: 32 }}
              />
            </Pressable>
          </>
        ) : (
          <ActivityIndicator color="#B95138" />
        )}
      </View>
    );
  return (
    <View style={styles.root}>
      <WebView<object>
        key={generation}
        ref={web}
        source={{ uri: entry.uri }}
        allowingReadAccessToURL={entry.directory}
        originWhitelist={["file://*"]}
        onMessage={receive}
        javaScriptEnabled
        allowsInlineMediaPlayback
        mediaPlaybackRequiresUserAction={false}
        onLoadEnd={() =>
          web.current?.injectJavaScript(
            `window.roroActive = ${AppState.currentState === "active"}; window.dispatchEvent(new Event("roro-playback")); true;`,
          )
        }
        domStorageEnabled={false}
        allowFileAccess
        allowUniversalAccessFromFileURLs={false}
        allowFileAccessFromFileURLs={false}
        setSupportMultipleWindows={false}
        onShouldStartLoadWithRequest={(request) =>
          request.url.split("#")[0] === entry.uri
        }
        onLoadStart={() => {
          epoch.current += 1;
          processed.current.clear();
        }}
        onError={() =>
          setError("Your photo library could not open. Please try again.")
        }
        onContentProcessDidTerminate={() => {
          setGeneration((v) => v + 1);
        }}
        scrollEnabled={false}
        contentInsetAdjustmentBehavior="never"
        style={styles.root}
      />
    </View>
  );
}
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: "#FAF8F5" },
  loading: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    padding: 28,
    backgroundColor: "#FAF8F5",
  },
  brand: {
    fontFamily: "Nunito",
    fontSize: 48,
    fontWeight: "800",
    color: "#B95138",
    marginBottom: 24,
  },
  message: {
    fontFamily: "Nunito",
    fontSize: 16,
    color: "#292724",
    textAlign: "center",
    marginBottom: 20,
  },
  button: {
    minWidth: 44,
    minHeight: 44,
    alignItems: "center",
    justifyContent: "center",
  },
  buttonText: { fontFamily: "Nunito", color: "white", fontWeight: "700" },
});
