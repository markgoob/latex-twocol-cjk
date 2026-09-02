[English](README.md) | **繁體中文**

# latex-twocol-cjk

一個 Claude skill，用來寫 A4 雙欄、IEEE 風格、中英混排的 LaTeX 文件。內部白皮書、技術報告、課堂論文這類東西都適用。

會做這個 skill，是因為網路上最常見的那套設定根本編不出檔案。CJK 配 babel 的標準寫法是 `bidi=basic` 加 `onchar=ids fonts` 再搭 XeLaTeX，但這個組合產不出 PDF。`bidi=basic` 只有 LuaTeX 支援，babel 會直接報錯停機；`onchar` 同樣只有 LuaTeX 支援，卻是安靜失效，於是整套設定賴以成立的逐字換字型從來沒有真的發生過。

## 它擋掉什麼

三個失敗模式，每一個都先在 TeX Live 2026 上實際重現，才寫進規則。

### 引擎選錯

改用 LuaLaTeX 編譯，並且把 `bidi=` 整個拿掉。純左至右的中英文件用不到雙向文字演算法。

### 語系選錯

babel 有 `chinese-traditional`（zh-Hant）和 `chinese-simplified`（zh-Hans）。改用 `japanese` 語系的話，圖說會變成「図」、表格變成「表」、參考文獻變成「参考文献」，日期也是日式格式。對中文文件來說這既是語言錯誤，字形也錯：繁體該是「圖」和「參考文獻」。

這個 skill 讓 `english` 當主語言，把中文語系掛成次語言。這樣圖表標題與日期維持英文（IEEE 要的），中文照樣拿到正確字型、正確斷行，以及 PDF 裡正確的 `zh-Hant` 語言標記。

### 字型，而且錯兩次

同一套字型在不同發行管道叫不同名字。noto-cjk 專案、Linux 套件與 Overleaf 給的是 `Noto Serif CJK TC`，Google Fonts 給的是 `Noto Serif TC`，而後者才是 Windows 使用者實際會裝到的。名字寫死哪一個都會讓 fontspec 直接中止。

更麻煩的是第二層。Google Fonts 把 Noto TC 做成單一可變字型檔，它第一個具名實例的樣式叫 `ExtraLight,Regular`，權重只有 40。照家族名查找就會命中這個實例，於是中文內文被排成 ExtraLight，明顯比旁邊的拉丁文字細，而且不產生任何警告。

範本兩件事都處理掉了：`\PickFont` 逐一探測候選家族，一路退到 Windows 內建的新細明體與微軟正黑體；權重軸則直接釘死。

```latex
UprightFeatures = {RawFeature={axis={wght=400}}},
BoldFont = {*}, BoldFeatures = {RawFeature={axis={wght=700}}},
```

釘軸還順帶換來真正的粗體，不是描邊假粗，而靜態字型會安靜地忽略這個設定，所以同一行寫法對兩類字型都安全。

有個診斷上的坑值得先講：`pdffonts` 看不出軸有沒有釘對。子集名稱沿用字型檔的 PostScript name，所以就算設定正確，報出來的仍然是 `NotoSerifTC-ExtraLight`。要判斷只能量渲染後的墨量。

## 適用範圍

這套建在 `article` 上，不是 `IEEEtran`。產出看起來像 IEEE 論文，拿來寫內部報告或課堂論文很合適，但它**不是**可以投稿的 camera-ready 格式：邊界、摘要寬度、圖說度量都跟真正的 IEEE 規格不同，投稿檢查會擋下來。真要投稿請用 `IEEEtran`，只把字型那一段移植過去。

有兩處是刻意偏離真 IEEE 的，知道理由才好向人解釋：摘要橫跨兩欄（`IEEEtran` 是單欄寬），內文字型用 Noto Serif 而不是 Times，為的是跟中文字型搭得起來。

## 安裝

把 repo 內容複製到 skill 目錄：

```bash
git clone https://github.com/markgoob/latex-twocol-cjk
mkdir -p ~/.claude/skills/latex-twocol-cjk
cp -r latex-twocol-cjk/{SKILL.md,references,scripts} ~/.claude/skills/latex-twocol-cjk/
```

Windows 的位置是 `C:\Users\<你>\.claude\skills\latex-twocol-cjk\`。skill 會在執行中的 session 立刻註冊，不用重啟。

也可以直接到 [Releases](https://github.com/markgoob/latex-twocol-cjk/releases) 下載 `.skill` 檔，改副檔名為 `.zip` 後解壓，壓縮檔根目錄就是 skill 資料夾，解出來的結構是對的。

不用 Claude 也能用：`references/template.tex` 本身就是一份完整可編譯的 LaTeX 文件。

## 編譯

```bash
latexmk -lualatex -interaction=nonstopmode main.tex
```

第一次編譯之前先檢查字型。少一個家族是 fatal error，不是警告，早點發現省事。

```bash
scripts/check-fonts.sh          # Linux、macOS、Overleaf、容器
scripts\check-fonts.ps1         # Windows
```

本機沒裝 TeX 的話，`scripts/build.ps1 main.tex` 會在 TeX Live 容器裡編譯，並且掛載本機字型，所以看到的是真實的字型環境，不是一套通用的 Linux 環境。

Overleaf 會忽略 `% !TeX program` 那行，要自己到 Menu → Compiler 選 LuaLaTeX。Overleaf 本身已經內建 Noto CJK 字型。

## 讀 log

exit code 是 0 不代表文件沒問題。`Missing character` 的意思是有字被丟掉了，而編譯依然算成功。

| 訊息 | 意思 |
|---|---|
| `Missing character` | 字被默默丟出 PDF，字型設定不對 |
| `Font shape … undefined` | 某個字面被替代，中文的粗體或斜體是假的 |
| 參考文獻出現 `Overfull \hbox` | 少了 `\raggedright` 包裹 |
| `Too many unprocessed floats` | 補一個 `\FloatBarrier` |
| `There were undefined references` | 再跑一次就好 |

`references/troubleshooting.md` 收了 19 條錯誤，每條都附實際會出現的 log 片段、成因與修法。

## 中文行文

把中文頁面排對，跟把中文寫好，是兩件事，而後者才是審閱者第一眼會有反應的部分。`SKILL.md` 第 9 節管跟 LaTeX 有交集的那一半：臺灣用語而非大陸用語、全形標點，以及 LaTeX 會偷偷換成拉丁形式的兩個地方（反引號輸入會排成 `“ ”` 而不是「」，`\ldots` 會排成拉丁省略號而不是 ⋯⋯），還有中英交界的半形空格，跟摘要特別容易招來的那種空話。

如果同時裝了 [be-human-v1](https://github.com/markgoob/be-human-v1)，散文的部分預設交給它，不必特地呼叫，第 9 節在用詞與標點上讓位；凡是會影響版面怎麼排的判斷仍歸這個 skill。兩者互不相依，各自單獨裝都能用。

## 內容

| 路徑 | 內容 |
|---|---|
| `SKILL.md` | 規則本體，按寫文件的實際順序排列 |
| `references/template.tex` | 完整且驗證過的文件，preamble 直接複製 |
| `references/troubleshooting.md` | 錯誤 → 成因 → 修法 |
| `scripts/check-fonts.ps1`、`.sh` | 列出候選字型家族裝了哪些 |
| `scripts/build.ps1` | 給沒裝 TeX 的機器用的容器化編譯 |

## 驗證

`references/template.tex` 在 TeX Live 2026（LuaHBTeX 1.24.0）下編譯出兩頁 PDF，`Missing character`、未定義字面、over/underfull box，以及 LaTeX、Package、Class 警告全部為零。兩套字型命名都測過：Windows 11 上的 Google Fonts Noto TC，以及 Debian 的 `fonts-noto-cjk`。

CI 在每次改動 `references/template.tex` 時重跑同一套檢查，**任何一項警告都會讓 build 失敗**。這條規則有必要，因為 LuaLaTeX 找不到字型時照樣 exit 0，只是把字默默丟掉。

有兩條規則來自一份 12 頁的繁體論文，不是從範本推導出來的。原始碼在兩個漢字之間斷行會印出一個可見的空格（TeX 在 tokenise 階段就把換行變成空格，比 babel 看到文字更早），以及中文行距鬆散時該動的是語系的 `intraspace`，不是 `\sloppy`。兩條都寫在 `SKILL.md` 第 8 節與 `troubleshooting.md` 的 E17 至 E19。

## 授權

MIT，見 `LICENSE`。
