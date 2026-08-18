# Crux UI

[English](README.md) | 日本語

デザイントークンとテーマレイヤー、そしてバネのように弾む18個のコンポーネント —
素の Flutter らしく見えない Flutter アプリのために。

![status: under development](https://img.shields.io/badge/status-under%20development-orange)

> **開発中です。** まだ pub.dev には公開されていません。1.0 までは API が変更される
> 可能性があります。詳細は[ステータス](#ステータス)をご覧ください。

![Screens from the example app, built entirely from Crux components](https://raw.githubusercontent.com/4armsxlr8/crux_ui/main/doc/mimosa-screens.png)

*`example/` の画面 — AI コンパニオン付きの生活整理モックアプリ「ミモザ」: ログイン、
ホーム、チャット、ダークモード。見えているピクセルはすべて Crux のトークンと
コンポーネントで描かれています。*

## なぜ

標準の Material ウィジェットだけで画面を組むと、ひと目で「Flutter アプリだ」と
わかってしまいます。デフォルトのタイプスケール、形状、モーションがそれだけ
特徴的だからです。この印象の原因の一つを追いかけた結果生まれたのが
[cupertino_typography](https://pub.dev/packages/cupertino_typography) で、iOS 上での
タイプスケール部分を解決するパッケージです。Crux は同じ違和感から生まれ、それを
より広い範囲に広げたものです。つまり、Material のデフォルトを引き継ぐのでは
なく、見た目と操作感を意図して設計したコンポーネント群です。

そのため Crux は自己完結したキットです —— 独自の色・スペーシング・タイポグラフィ・
角丸・シャドウのトークン、独自の `CruxTheme` レイヤー、独自のウィジェット群を持ち、
**Material の `ThemeData` を読み取ることも書き換えることも一切しません**。
`CruxTheme` を与えても `Material` や `Scaffold` など他の Material ウィジェットの
見た目は変わらず、逆に Material のテーマが Crux コンポーネントに漏れ込むことも
ありません。

サンプルアプリのパレットはたまたま温かみのあるクリーム色になっていますが、それは
数ある `CruxThemeData` の一つにすぎません。このキットが本当に重視しているのは、
テーマが変わっても変わらない部分 —— バネのように丁寧にチューニングされた
モーションと、各コンポーネントの細部です。コンポーネントの形状に合った押下
フィードバック、はみ出さないラベル、バリデーションでレイアウトが動かないこと、
といった点です。

キット全体を貫くもう一つの方針があります。**タイポグラフィはホストプラットフォーム
自身のタイプスケールに解決されます** —— iOS と macOS では Apple の Human
Interface Guidelines（HIG）のサイズに、それ以外では Material 3 のサイズに解決
されるため、テキストを含むコンポーネントはプラットフォームごとに意図的にサイズが
変わります。

## ステータス

**開発中です。** まだ pub.dev には公開されていません。トークンレイヤーと以下の
18個のコンポーネントは実装済みです。画面の残りの部分（ボトムシートなど）は、
`example/` が示すとおり、素の Flutter ウィジェットと Crux のトークンを組み合わせて
構成します。

**トークン** — 色、スペーシング、タイポグラフィ（プラットフォーム別に解決）、
角丸、シャドウ（エレベーションシャドウ、モーダルのスクリム、ダークモードの
ヘアライン）。これらは `CruxTheme` / `CruxThemeData` のペアによってサブツリーに
提供されます。

**コンポーネント** — 17個の atom と、それらから組み立てられた2個の molecule。
2つのダイアログレイヤーを1個として数えると、合計18個です。

| Component | 説明 |
|---|---|
| `CruxButton` | ピル型のボタン。`filled` / `tonal` / `ghost` × `small` / `medium` / `large` の組み合わせがあり、`loading` 状態も持ちます |
| `CruxChip` | `selected` フラグを持つ、フィルター・タグ用のピル |
| `CruxCard` | 枠線付きのコンテンツコンテナ。デフォルトでは装飾用ですが、`onTap` を渡すと押下可能になります |
| `CruxListTile` | `leading` / `title` / `subtitle` / `trailing` を持つリスト行 |
| `CruxSwitch` | ピル型のオン/オフトグル |
| `CruxCheckbox` | チェックボックス |
| `CruxDivider` | 任意の `indent` を指定できる、1px の区切り線 |
| `CruxTextFormField` | `Form` と統合された1行のテキスト入力（実体は `FormField<String>`）。パスワードの表示/非表示を切り替えるトグルをオプションで持てます |
| `CruxInputBar` | 検索・チャット用の入力バー |
| `CruxComposer` | 投稿本文用のコンポーザー。周囲を囲む枠がなく画面いっぱいに広がる複数行入力（molecule） |
| `CruxSpinner` | ローディングインジケーター |
| `CruxIconButton` | アイコンボタン |
| `CruxDialog` / `CruxConfirmDialog` | ダイアログと、その上に構築済みの確認レイヤー（molecule） |
| `CruxToast` | トースト。アプリのルートに置く単一の `CruxToastHost` を通して表示します |
| `CruxSegmentedControl` | セグメンテッドコントロール |
| `CruxSlider` | スライダー |
| `CruxNavBar` | フローティングのボトムナビゲーションバー。スクロールするコンテンツをページ端に溶け込ませる背景フェード帯を持ちます |
| `CruxTopFade` | スクロールするコンテンツの上端用の、段階的なフェード/ぼかし帯 |

## 設計方針

- **インポートは1つだけ。** `lib/crux_ui.dart` が唯一の公開エントリーポイントであり、
  すべてのコンポーネントはこの1ファイルからエクスポートされます。
- **Material には一切触れません。** Crux のコンポーネントはすべての色とテキスト
  スタイルを `CruxTheme.of` から読み取り、このキットは `ThemeData` を読み取ることも
  カスタマイズすることもありません。`CruxTextFormField` が Material の `TextField`
  ではなく `CupertinoTextField` の上に構築されているのも同じ理由からです ——
  ホストアプリの Material テーマがその見た目に入り込む経路が存在しません。
- **プラットフォーム別に解決されるタイプスケール。** 9個のタイポグラフィトークンは
  iOS/macOS では HIG のサイズに、それ以外では Material 3 のサイズに解決されます。
  トークンごとの上書き（マージ方式）と `copyWith` によって、アプリ固有のチューニング
  も可能です。
- **コントロールドウィジェット。** `CruxSwitch` や `CruxCheckbox` などは Flutter
  自身の慣習に従っています。自分自身を変更するのではなく、常に `value` を反映し、
  `onChanged(!value)` を呼び出します。コールバックに null を渡すとコンポーネントは
  無効化されます。
- **押下フィードバックは形状に合わせています。** 幅が内容に合わせて縮む
  （width-hugging）コンポーネント（`CruxButton`、`CruxCard`）には押下時のバネ状
  スケールを適用し、幅いっぱいの行（`CruxListTile`）にはステートレイヤーのみを
  適用します —— 幅いっぱいの行がタップで縮むと、不自然な揺れに見えてしまうため
  です。
- **ラベルがはみ出すことはありません。** テキストラベルは省略記号（ellipsis）付きの
  1行で描画されるため、制約やラベルの長さによってコンポーネントが崩れることは
  ありません。
- **タップ領域は常に 44px。** `CruxChip` の見た目のピルは高さ 36px ですが、ヒット
  領域は 44 論理ピクセルの最小値を保っています。
- **バリデーションでレイアウトが動くことはありません。** `CruxTextFormField` は
  常にヘルパー/エラーのキャプション行のための領域を確保しているため、エラーの
  表示・解消によってレイアウトが動くことはありません。

## 使い方

```dart
import 'package:flutter/widgets.dart';
import 'package:crux_ui/crux_ui.dart';

void main() {
  runApp(
    CruxTheme(
      data: CruxThemeData.light(),
      child: Builder(
        builder: (context) {
          final theme = CruxTheme.of(context);
          return Container(
            color: theme.colors.background,
            padding: const EdgeInsets.all(CruxSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, Crux', style: theme.typography.subheading),
                const SizedBox(height: CruxSpacing.s16),
                CruxButton(label: 'はじめる', onPressed: () {}),
              ],
            ),
          );
        },
      ),
    ),
  );
}
```

<details>
<summary>英語以外のアプリでテキスト選択メニュー（貼り付け/コピー）をローカライズする</summary>

`CruxTextFormField` の選択/コピー＆ペーストメニューの文言には2つの出所があり、
英語以外のアプリではその両方に対応する必要があります。iOS 16 以降では、この
メニューは iOS 自身が描画するため、その文言は **アプリバンドル** が宣言する言語
—— `Info.plist` の `CFBundleLocalizations` 配列 —— に従います。動作する設定例は
`example/ios/Runner/Info.plist` を参照してください。それ以外の環境（iOS の旧
バージョン、Android、デスクトップ）では Flutter がメニューを描画し、ホストアプリが
提供する `CupertinoLocalizations` から文言を読み取ります（未設定の場合は英語に
フォールバックします）。アプリに `flutter_localizations` とその
`GlobalCupertinoLocalizations.delegate`（対応する Material/Widgets 版、および
一致する `supportedLocales` とあわせて）を追加してください。詳しくは
`example/lib/main.dart` を参照してください。`crux_ui` 自体は `flutter_localizations`
に依存しません。この設定はアプリ側の責務です。

</details>

## サンプルアプリとコンポーネントカタログ

- **`example/`** — 「ミモザとの暮らし」という単一のモックアプリです。ログイン画面
  から、4タブ構成のシェル（ホーム/タスク、チャット、家計簿、設定）と、日記投稿用の
  モーダルへと続きます。各画面は `example/lib/screens/` にあり、すべて1つのアプリ
  という文脈の中で Crux のコンポーネントから組み立てられています。
- **`widgetbook/`** — 開発用カタログです。すべてのトークンスケールと、各 atom の
  Playground / States matrix / Edge cases の全ページを網羅しています。
  `cd widgetbook && flutter run -d macos` で起動できます。

## 開発を始める（開発者向け）

Dart SDK `^3.12.2` と、対応する範囲の Dart を含む Flutter SDK が必要です。

```sh
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

## ロードマップ

上記の18個のコンポーネントはすでに実装済みです。残りのウィジェット群 ——
ボトムシート、スナックバー、その他必要になったもの —— はまだ設計されていません。
今後追加される各コンポーネントも、同じトークンの上でテストとドキュメントを伴って
実装されます。

## ライセンス

[MIT](LICENSE)
