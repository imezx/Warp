import { F as FontStyle } from './chunk-types.mjs';
export { I as IGrammar, a5 as IGrammarConfiguration, a2 as INITIAL, a6 as IOnigLib, m as IRawGrammar, a4 as IRawTheme, a8 as IRawThemeSetting, a1 as Registry, a7 as RegistryOptions, a3 as StateStack } from './chunk-types.mjs';
import './chunk-index.mjs';

declare const enum TemporaryStandardTokenType {
    Other = 0,
    Comment = 1,
    String = 2,
    RegEx = 4,
    MetaEmbedded = 8
}
declare const enum StandardTokenType {
    Other = 0,
    Comment = 1,
    String = 2,
    RegEx = 4
}
declare class StackElementMetadata {
    static toBinaryStr(metadata: number): string;
    static getLanguageId(metadata: number): number;
    static getTokenType(metadata: number): number;
    static getFontStyle(metadata: number): number;
    static getForeground(metadata: number): number;
    static getBackground(metadata: number): number;
    static containsBalancedBrackets(metadata: number): boolean;
    static set(metadata: number, languageId: number, tokenType: TemporaryStandardTokenType, fontStyle: FontStyle, foreground: number, background: number): number;
}

export { StackElementMetadata, StandardTokenType, TemporaryStandardTokenType };
