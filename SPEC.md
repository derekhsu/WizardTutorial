# WizardTutorial — 概念驗證（PoC）規格書

> 單人、回合制、格子移動的第一人稱地牢探索 RPG。
> 參考系：Legend of Grimrock 的移動手感 × roguelike 的 energy 回合排程。

## Problem Statement

驗證「Grimrock 式格子移動＋速度驅動的回合制戰鬥」這個核心循環在 Godot 4 上是否成立且好玩。目前專案為空目錄，沒有任何可運行的東西；不做 PoC 就直接進入正式開發的風險是：回合排程與格子移動的手感問題會在內容變多之後才暴露，屆時修改成本最高。

## Goals

1. **核心循環可玩**：玩家能從地牢起點走到出口，途中經歷至少 3 場戰鬥，全程無需重啟或除錯介入。
2. **速度系統可感知**：速度不同的敵人在行動頻率上有可觀察的差異（快速敵人約每玩家 2 動時行動 3 次）。
3. **法術戰鬥成立**：法術是主要輸出手段，施放成本與 energy 系統互動（重法術施放時間長、有被打斷風險）。
4. **勝敗條件明確**：擊敗守關者並抵達出口＝勝利；HP 歸零＝失敗並可重新開始。
5. **技術驗證**：證明 Godot 4 的 `Tween`＋`AStarGrid2D`＋自訂排程器足以支撐此類型，無需外部工具或插件。
6. **資訊可讀**：玩家不看說明文件就能從 HUD 理解回合節奏、法術成本、敵人狀態——UI 是 PoC 驗證「系統是否可感知」的必要條件。

## Non-Goals

- **隊伍制**：單人角色。Actor 架構保留擴充性，但不做多角色控制、前後排站位。
- **程序化生成**：地牢手工設計一層。tile 資料格式保持生成器友善，但不寫生成器。
- **物品／裝備／背包系統**：最多允許拾取式補給（如 mana 水晶），不做裝備欄。
- **角色養成**：無等級、經驗值、技能樹。數值固定，便於調平衡。
- **正式美術與音效**:3D 場景全部使用引擎內建 primitive mesh+單色材質。UI 用預設主題+排版設計,不做法術圖示美術、自訂字體、皮膚。(PoC 階段;Phase 5 起由 R15/R16 接管視覺)
- **存檔／讀檔**：單層地牢，死亡即重來。
- **多層地牢**：出口即終點，不接下一層。
- **主選單／設定**：PoC 直接進遊戲，勝敗畫面即全部流程 UI。

## User Stories

**玩家（探索者）**
- As a player, I want to move forward/backward/strafe one tile and turn 90° with smooth animation, so that the dungeon feels like Grimrock rather than teleporting.
- As a player, I want walls and closed doors to block my movement, so that the dungeon layout has meaning.
- As a player, I want to see a message log of what happened each turn, so that I understand combat outcomes.

**玩家（戰鬥）**
- As a player, I want to cast spells that cost different amounts of time, so that choosing a heavy spell is a tactical risk.
- As a player, I want fast enemies to act more often than slow ones, so that enemy speed is a real threat axis.
- As a player, I want to see my HP and mana at all times, so that I can make informed decisions.
- As a player, I want to know when it's my turn vs. when enemies are acting, so that the turn flow is legible.
- As a player, I want damage numbers to appear on enemies I hit, so that I get immediate feedback on spell effectiveness.
- As a player, I want a clear visual warning when I take damage, so that I notice being attacked even while looking at the log.

**玩家（資訊）**
- As a player, I want the spell bar to show each spell's mana cost and time cost, so that I can weigh speed vs. power without memorizing.
- As a player, I want to see the name and HP of the enemy I'm facing, so that I can decide whether to engage or retreat.
- As a player, I want to see who acts next (turn order preview), so that the energy system is legible rather than arbitrary.

**玩家（目標）**
- As a player, I want the exit to be visibly guarded, so that I understand combat is required to win.
- As a player, I want a clear win screen on reaching the exit and a lose screen on death with restart, so that a run has closure.

## Requirements

### P0 — Must-Have（沒有這些就不是 PoC）

**R1 專案骨架**
- Godot 4 專案初始化（`project.godot`、主場景、輸入映射）。
- Git 初始化與 `.gitignore`（Godot 標準版）。
- 驗收：專案在 Godot 4 編輯器開啟並可 F5 運行到空地牢場景。

**R2 格子地牢與移動**
- Tile 資料模型：`Vector2i` → tile 型別（牆／地板／門／出口／守關者房）。資料與渲染分離。
- 第一人稱 `Camera3D`；移動＝前後一格、左右平移一格、原地轉向 ±90°。
- `Tween` 插值移動與轉向（約 150–250ms），動畫期間鎖輸入。
- 牆與關閉的門阻擋移動；不可離開地牢邊界。
- 驗收：
  - [ ] 按 W/A/S/D、方向鍵（↑↓ 移動、←→ 轉向）與 Q/E 可在地牢內移動，動畫平滑無瞬移。
  - [ ] 面對牆壁按前進，位置不變且無錯誤。
  - [ ] 移動動畫中連按按鍵不會插隊或位移錯格。
  - [ ] 敵人回合中按下的鍵被緩衝，輪到玩家時執行（輸入不被吞）。

**R3 Energy 回合排程器**
- 每個 actor 有 `speed` 與 `energy`；每 tick 所有 actor `energy += speed`，達門檻（100）者依序行動，行動後扣除行動成本。
- 玩家能量滿時排程器暫停等待輸入；敵人能量滿時立即執行 AI 行動。
- 行動成本：移動 100、普通攻擊 100、法術依設定（100–300）。
- 驗收：
  - [ ] 速度 200 的敵人在玩家行動 2 次的期間內行動約 3 次（可在 debug log 驗證 tick 序列）。
  - [ ] 玩家不行動時（站立等待指令），敵人照常累積能量並行動。
  - [ ] 多個敵人同 tick 滿能量時依固定順序（如 speed 高者先）行動，無死結。

**R4 敵人 AI**
- `AStarGrid2D` 尋路；敵人行動時：若玩家在攻擊範圍（相鄰格）→ 近戰攻擊；否則沿最短路徑接近一格。
- 至少 2 種敵人：慢速高血（speed 50）、快速低血（speed 200），用於展示速度差異。
- 驗收：
  - [ ] 敵人能繞過牆角追到玩家。
  - [ ] 敵人不會穿牆、不會進入玩家所在格、不會兩敵人擠進同格。
  - [ ] 敵人死亡後從排程器與網格移除。

**R5 法術系統**
- 至少 3 個法術，展示不同 energy 成本：
  - 飛彈術（成本 100，直線單體傷害）
  - 火球術（成本 200，目標格＋相鄰格範圍傷害）
  - 雷擊術（成本 300，高傷害單體）
- 施放消耗 mana；mana 不足時禁止施放並提示。
- 施放方向＝玩家面向；目標格為射線第一個敵人／指定範圍。
- 驗收：
  - [ ] 施放雷擊術後，速度 200 的敵人能在施法「空窗」內行動（體現高成本法術的風險）。
  - [ ] mana 不足時按施法鍵，訊息 log 顯示提示且不消耗回合。
  - [ ] 法術命中敵人扣血，擊殺後敵人移除。

**R6 守關者與勝敗**
- 出口格位於地牢深處，守關者（高 HP、speed 80 慢速高攻擊）站在出口前或巡邏出口房。
- 守關者存活時踩上出口格：訊息提示「出口被封印」之類，不觸發勝利。
- 守關者死亡後踩上出口格 → 勝利畫面（可重新開始）。
- 玩家 HP ≤ 0 → 失敗畫面（可重新開始）。
- 驗收：
  - [ ] 不殺守關者無法觸發勝利。
  - [ ] 殺死守關者後踩出口格顯示勝利畫面。
  - [ ] 死亡後按重新開始能重置整層地牢狀態。

**R7 HUD 與戰鬥回饋（UI 設計）**

PoC 的 UI 目標是「資訊設計正確」，不是視覺風格。用預設主題＋排版，但每個元素的位置與內容都經過設計：

- **佈局**（1280×720 基準）：
  - 左下：HP 條（紅）＋ mana 條（藍），顯示數值（如 38/50）。
  - 底部中央：訊息 log，最近 5 行，戰鬥訊息與系統訊息分色。
  - 右下：法術欄，3 格，每格顯示快捷鍵、名稱、mana 成本、energy 成本；mana 不足時整格變灰。
  - 頂部中央：回合指示（「你的回合」高亮／「敵人行動中」暗淡）。
  - 頂部右側：行動順序預覽——接下來 3 個行動者的名稱（依 energy 排序），讓速度系統可見。
- **戰鬥回饋**：
  - 敵人受擊時頭頂浮出傷害數字（3D 空間 `Label3D`，1 秒淡出上浮）。
  - 玩家受擊時螢幕邊緣紅閃（全螢幕 `ColorRect` 淡入淡出）。
  - 面向的敵人（射線第一個）在準星下方顯示名字＋HP 條。
- **勝敗畫面**：全螢幕 overlay＋結果文字＋「按 R 重新開始」。
- 驗收：
  - [ ] 所有 HUD 元素在 1280×720 與 1920×1080 下不遮擋第一人稱視野中央。
  - [ ] 法術欄在 mana 不足時即時變灰，恢復後變回。
  - [ ] 傷害數字出現在正確的敵人位置並淡出。
  - [ ] 玩家受擊紅閃在每次受擊時觸發。
  - [ ] 行動順序預覽與實際行動順序一致。

### P1 — Nice-to-Have（核心驗證完後再加）

- **R8 等待指令**：玩家可主動按鍵跳過回合（成本 100），用於戰術等待。
- **R9 狀態效果**：緩速術（降低敵人 speed N tick）——最能展示 energy 系統深度的機制。
- **R10 施法打斷**：高成本法術在累積期間受擊則施放失敗（能量照扣）。
- **R11 門與機關**：可開啟的門、拉桿開遠處門——驗證格子互動系統。
- **R12 Automap**：已探索區域的小地圖（右上角，跟隨玩家旋轉或固定北向）。
- **R13 音效**：移動、施法、受擊、勝敗（免費音效庫即可）。
- **R14 法術圖示與 UI 美術**：法術欄換成真圖示、自訂字體、邊框風格——PoC 驗證完資訊設計後再做。


### P2 — Future Considerations（現在不寫，但架構要留路）

- **隊伍制**：Actor 已是陣列結構；屆時需加「前排/後排」位置語義與角色切換 UI。
- **程序化生成**：tile 資料模型已是純資料，生成器只需產出同格式。
- **多層地牢**：出口改為載入下一層資料；需要樓層定義格式。
- **物品／裝備／角色養成**：需要 entity 組件化與資料表。
- **即時制模式**：排程器改為連續時間；現有 energy 模型可直接映射（Grimrock 本質是連續 energy）。
- **完整流程 UI**：主選單、暫停、設定、統計畫面。

### Phase 5 — 視覺升級(風格化低多邊形)

**方向**:KayKit/Quaternius 式低多邊形+手繪感貼圖,取代 primitive 色塊。資產全部 CC0,不裝 Blender。

**R15 環境視覺**
- 牆壁/地板/天花板換成模組化地牢件(KayKit Dungeon Pack 或同級 CC0 `.glb`),維持現有 tile 資料模型——渲染層替換,邏輯層不動。
- 燈光氛圍:環境光調暗、玩家火把 `OmniLight3D` 閃爍、`Fog` 深度衰減、陰影開啟。
- 出口格視覺化(樓梯/傳送門模型或發光標記)。
- 驗收:
  - [ ] 地牢不再是單色方塊;牆壁有磚石/石材質感,風格統一。
  - [ ] 走廊有明暗層次,遠處沒入黑暗(fog),近處被火把照亮。
  - [ ] 移動/轉向動畫與碰撞行為不變(純視覺替換)。

**R16 敵人模型**
- 三種敵人換成低模 glb:Slime→史萊姆/軟泥,Wisp→幽靈/鬼火,Guardian→重甲守衛/魔像。
- 保留現有 `Enemy` 腳本與 `Label3D` 傷害浮字;模型掛在既有節點下。
- 敵人有基礎待機/受擊回饋(縮放彈跳或材質閃爍即可,不做骨骼動畫綁定除非資產自帶)。
- 驗收:
  - [ ] 三種敵人外觀可區分,風格與環境一致。
  - [ ] 面向敵人資訊(名字+HP)仍正確對應。
  - [ ] 死亡移除、傷害浮字、AI 行為全部不變。

**Non-goals(本階段)**:法術 VFX 粒子、UI 美術翻新、音效——列後續階段。

## Success Metrics

PoC 的「使用者」是開發者本人與試玩者，指標以驗證為導向：

**Leading（開發中即可量測）**
- 從起點到勝利的完整 run 無 crash、無卡死（排程器無死結）。
- 一場 run 長度 10–15 分鐘；戰鬥 3–6 場。
- Debug log 中速度 200 敵人的行動頻率 ≈ 速度 100 敵人的 2 倍（±10%）。
- 移動動畫期間 0 次輸入插隊 bug。

**Lagging（試玩後評估）**
- 試玩者不看說明能理解「輪到我才能動」的回合節奏（回合指示＋行動順序預覽的驗證點）。
- 試玩者能說出「那隻快的怪比較煩」——速度差異被感知。
- 至少一名試玩者選擇過「用快法術還是賭重法術」的決策——法術成本產生張力。
- 試玩者能從法術欄讀出 mana 與時間成本，不需要額外說明。
- 開發者判斷：核心循環值得擴成完整遊戲（go/no-go）。

## Open Questions

| 問題 | 負責 | 阻塞？ |
|---|---|---|
| 施法中的「累積期」是否可被打斷？（R10 做不做的前置） | 設計 | 否——PoC 先做法術瞬發＋高成本，打斷列 P1 |
| Mana 回復方式：隨時間／拾取／不回復？ | 設計 | 是——影響 R5 平衡，建議 PoC 用「緩慢自動回復」最省事 |
| 敵人是否有遠程攻擊？ | 設計 | 否——PoC 全近戰即可驗證排程器 |
| 格子尺寸與移動時長的手感參數 | 工程 | 否——做成可調常數，試玩後調 |
| 守關者是站樁還是巡邏？ | 設計 | 否——建議站樁，最簡單且意圖清楚 |
| 行動順序預覽顯示幾個？3 個夠嗎？ | 設計 | 否——先 3 個，試玩後調 |
| 敵人 HP 條是常駐還是面向才顯示？ | 設計 | 否——先面向才顯示（準星下方），資訊量最小 |

## Timeline Considerations

無硬性期限。建議按以下階段推進，每階段結束都可運行：

- **Phase 1 — 骨架與移動**：R1＋R2。成果：能在色塊地牢裡走。✅
- **Phase 2 — 回合與敵人**：R3＋R4。成果：敵人會追會打，速度差異可見。✅
- **Phase 3 — 法術與勝敗**：R5＋R6＋R7 基礎版。成果：完整可贏可輸的 run。✅
- **Phase 3b — UI 補強**:R7 完整版——法術欄(成本顯示+變灰)、傷害浮字、受擊紅閃、面向敵人資訊、行動順序預覽。✅
- **Phase 4 — 驗證與調參**:試玩、調 speed/成本/血量,決定 go/no-go 與 P1 取捨。✅(已調參一輪:guardian 慢速化、輸入修復)
- **Phase 5 — 視覺升級**:R15+R16。成果:低多邊形地牢+敵人模型+燈光氛圍,玩法不變。

Phase 3b 完成即達 PoC 定義的「done」;Phase 5 是 PoC 通過後的視覺迭代,P1 項目依試玩回饋決定是否納入。
