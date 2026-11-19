# barbet-slides

以 [typslides](https://typst.app/universe/package/typslides) 為底、供臺灣法學院口頭報告使用的 Typst 簡報主題：色票、圖示、版面元件與全域樣式，打包為 Typst local package。

名稱取自台灣特有種鳥類台灣擬啄木（五色鳥，_Psilopogon nuchalis_）。本專案最初設計來供個人使用，惟仍歡迎貢獻。

## 環境需求

- Typst 0.15 或以上
- 字型：Noto Sans TC
- Windows（附 `install.ps1`）；其他系統請自行把本資料夾放（或連結）到 Typst 的 local package 目錄
- 首次編譯時，Typst 會自動下載 `@preview/typslides`

## 安裝

```powershell
git clone https://github.com/zhenhuang-tw/barbet-slides.git
cd barbet-slides
.\install.ps1
```

腳本會讀取 `typst.toml` 的名稱與版本，在 `%APPDATA%\typst\packages\local\barbet-slides\<版本>` 建立指向本 repo 的目錄連接（junction）。因為是連接而非複製，repo 內的修改立即生效。可重複執行；遇到真實資料夾會中止而不刪除。

## 更新

```powershell
git pull
```

若 `typst.toml` 的版本有變，重跑 `.\install.ps1`，並把簡報內的 import 版本一併改掉。

## 快速開始

```typst
#import "@local/barbet-slides:0.1.0": *

#show: deck.with()

#front-slide(title: [標題], authors: [報告人])
#title-slide[壹、問題提出]
#slide(title: "範例")[
  #card(title: [卡片], icon: "scale")[內容 #hl[重點]]
  #src(cite(<key>))
]

#hidden-bibliography(read("/ref.bib", encoding: none))
```

完整範例見 [`examples/minimal.typ`](examples/minimal.typ)。

## 內容

| 模組                 | 內容                                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------------------- |
| `src/palette.typ`    | 色票 `c`（`c.accent`、`c.bg`…）                                                                               |
| `src/icons.typ`      | `ic("名稱")` 與內建 SVG 圖示                                                                                  |
| `src/components.typ` | `card`、`note`、`chip`／`achip`、`hl`、`mute`、`yes`／`no`／`maybe`、`step`、`rarr`／`darr`、`src`、`tl-node` |
| `src/deck.typ`       | `deck`（全域樣式）、`hidden-bibliography`                                                                     |
| `lib.typ`            | 入口；同時轉出 typslides 的 `slide`、`title-slide`、`front-slide`、`focus-slide` 等                           |

`deck` 可覆寫 `theme`、`font`、`font-size`、`back-color`、`lang`、`region`、`ratio`。

## 注意

- **參考文獻路徑：** 套件內函式收到的路徑字串，會相對於套件資料夾解析，而非你的簡報檔。因此 `hidden-bibliography` 接收的是 `read(..., encoding: none)` 讀入的位元組，而非路徑。
- **`c` 會進入你的命名空間：** `import *` 後，簡報內請勿再自行定義 `c`。
- **版本不等於 commit：** local package 以版本號定位，但 junction 指向的是 repo 工作樹；只要不改 `typst.toml` 的版本，修改會直接影響所有使用該版本的簡報。有破壞性變更時請升版。
- typslides 版本在 `lib.typ` 與 `src/deck.typ` 兩處釘選，升級時須一併修改。

## 授權

MIT，見 [LICENSE](LICENSE)。
