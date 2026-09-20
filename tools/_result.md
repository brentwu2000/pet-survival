已完成：

- [生成腳本](tools/gen_player_sprites.py)
- 64 張 PNG：`assets/player/yellow_robot/`
- [總覽圖](tools/player_contact_sheet.png)
- README 已追加說明，保留既有內容。

已確認尺寸全部為 64×64、內容高 58 px、底部 y=59、alpha 僅 0／255，重跑雜湊一致。側面眼睛不同，背面無臉。僅寫入指定兩個目錄。

為維持固定 bbox，頭頂保持固定；Walk 1／3 幀採交替抬腿過渡，並非雙腳完全騰空。