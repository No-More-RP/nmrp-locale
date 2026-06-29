/**
 * Ambient TypeScript declarations for `locale.js` — the WebUI-side locale bridge
 * exposed as the global `window.Locale`.
 *
 * Copy this file next to `locale.js` in your package's WebUI sources so TypeScript
 * picks it up (it augments the global `Window`). Mirrors Shared/locale.lua:
 * same store shape and same resolution rules.
 *
 * The types are also exported, so you can import them explicitly:
 *     import type { LocaleNamespace } from "./locale";
 */
export {};

/**
 * Common ISO 639-1 codes (optionally region-tagged, e.g. "en-US"). The
 * `(string & {})` member keeps autocomplete on the known codes while still
 * accepting any other string. Mirrors the `LocaleLanguage` Lua alias.
 */
export type LocaleLanguage =
  | "en"
  | "fr"
  | "de"
  | "es"
  | "it"
  | "pt"
  | "pt-BR"
  | "ru"
  | "pl"
  | "tr"
  | "nl"
  | "sv"
  | "da"
  | "fi"
  | "no"
  | "cs"
  | "hu"
  | "ro"
  | "el"
  | "uk"
  | "ja"
  | "ko"
  | "zh-CN"
  | "zh-TW"
  | "ar"
  | "th"
  | "vi"
  | "id"
  // eslint-disable-next-line @typescript-eslint/ban-types
  | (string & {});

/** Interpolation values for `{name}` / `{1}` tokens. */
export type LocaleParams = Record<string | number, unknown>;

/** Translation store: `data[namespace][language]["flat.key"] = "text"`. */
export type LocaleData = Record<
  string,
  Record<string, Record<string, string>>
>;

/** Payload of the Lua "locale:load" event (also accepted by `load()`). */
export interface LocalePayload {
  language?: LocaleLanguage;
  fallback?: LocaleLanguage;
  data?: LocaleData;
}

/** A per-script namespace handle returned by `Locale.namespace(name)`. */
export interface LocaleNamespace {
  readonly name: string;
  /** Translate a key within this namespace (falls back to the shared one). */
  t(key: string, params?: LocaleParams): string;
  /** Alias of `t`. */
  get(key: string, params?: LocaleParams): string;
  /** Whether a key exists in this namespace (or the shared one). */
  has(key: string): boolean;
}

/** The global `window.Locale` API exposed by `locale.js`. */
export interface LocaleApi {
  /** Reserved shared namespace name ("shared"). */
  readonly SHARED: string;
  /** Supported codes mapped to their native display name (for selectors). */
  readonly languages: Readonly<Record<LocaleLanguage, string>>;
  /** Translate a key in the shared namespace. */
  t(key: string, params?: LocaleParams): string;
  /** Translate a key in a given namespace (falls back to the shared one). */
  translate(namespace: string, key: string, params?: LocaleParams): string;
  /** Whether a key exists (in the namespace or the shared one). */
  has(namespace: string, key: string): boolean;
  /** Load a full store (usually wired automatically from Lua). */
  load(payload: LocalePayload): void;
  /** Change the displayed language (notifies Lua automatically). */
  setLanguage(language: LocaleLanguage): void;
  /** The active language. */
  getLanguage(): LocaleLanguage;
  /** Subscribe to load/language changes; returns an unsubscribe function. */
  onChange(callback: (language: LocaleLanguage) => void): () => void;
  /** Get a per-script namespace handle. */
  namespace(name: string): LocaleNamespace;
}

declare global {
  interface Window {
    /** Provided by `locale.js`. */
    Locale: LocaleApi;
  }
}
