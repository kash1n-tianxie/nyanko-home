# v0.4.1 の検証記録

Godot 4.7 stable / Compatibility で実行しました。

- 公開用フォルダーを別に作り、素材の初回インポートから検証。
- `python3 tests/v041_verify.py`：25スイートが終了コード0、エラーログなし。
- ハンマー猫：有限射程、5種類の固定ボス、地上／空中判定、発射位置、単体／範囲の役割を検証。
- 手持ちの資源だけで進める自動方針で、軽い難度と難しい難度の最初の4ステージを完了。
- UIとガイドは実際のControl入力を送って、購入、装備、拠点強化、仲間選び、出発、必殺技、スキップを検証。
- 描画ありの開発工程でも日本語／中国語、960×540・1280×720・1440×600、1～5匹の表示を目視確認。
- 旧予約魚・配送中の魚を含むセーブを移行し、魚・装備・所持金を保持することを確認。
- BGMのインポート設定を同梱し、4曲すべてのループを検証。
- ソースの静的チェックはエラー・警告0件。

戦闘数値と通過結果は自動テストの結果です。実際のユーザーの勝率や、人間による通しプレイの評価ではありません。

検証対象の各スイート：

- `editor-import`
- `v041_meal_retirement`
- `v041_save_balance`
- `v041_guidance_contract`
- `v041_combat_roles`
- `v039_encounter_contract`
- `v039_shop_advisor`
- `v039_boss_contract`
- `v039_review_logic`
- `v039_review_carrier`
- `v038_shop_contract`
- `v038_migration`
- `v038_cinema_contract`
- `v035_fixed_bosses`
- `v035_cat_contract`
- `v034_toys`
- `v034_toys_reward_migration`
- `v036_stage_art`
- `v040_locale_contract`
- `v040_audio_assets`
- `v041_audio_loops`
- `v041-ui-input`
- `v041-guidance-input`
- `v041-earned-campaign-easy`
- `v041-earned-campaign-hard`
