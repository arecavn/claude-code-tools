# statusline-quota

Một dòng status cho Claude Code, nhìn là biết đang ở đâu, dùng model gì, còn bao nhiêu quota — kể cả khi bạn dùng nhiều account.

```
candidate-search  ⎇ dev/v1.02  Opus 5.5 ctx 15%  [account1] 5h 31%→15:00 · 7d 40%→Sat | [account2] 5h 0% · 7d 12%→Wed
```

**Trước đây một ngày tôi gõ `/usage` trong terminal hoặc mở trang usage trên web hơn 10 lần để xem còn bao nhiêu quota. Giờ không cần nữa: con số luôn nằm sẵn dưới mỗi tab.**

Use case chính: mở 5–10 session Claude Code ở các tab khác nhau (Tabby, iTerm, VS Code…), mỗi tab một repo, một branch. Liếc xuống là biết tab này đang làm repo nào, branch nào, context sắp đầy chưa, và account nào còn quota. Đổi account bằng `/login` ở một tab là mọi tab đang mở chuyển theo, status line của tất cả cập nhật theo account mới.

## Vì sao hữu ích

- **Đúng project, đúng branch**: mở 5–10 tab Claude Code cùng lúc vẫn không gõ nhầm tab. Nếu `~/.zshrc` có `alias cs="cd ~/code/candidate-search"` thì hiện tên alias cho ngắn.
- **Model + context (ngữ cảnh đã dùng)**: `ctx` chuyển vàng ở 60%, đỏ ở 80% — lúc đó nên `/compact` hoặc mở session mới.
- **Quota 5 giờ và 7 ngày**: % đã dùng + giờ/ngày reset. Xanh < 70%, vàng < 90%, đỏ ≥ 90%.
- **Nhiều account**: mỗi lần `/login` account khác, số của account cũ được nhớ lại và hiện tiếp sau dấu `|`. Không phải đoán account nào còn quota.
- **Gợi ý đổi account**: `⇄ [account2]` = account đó còn chỗ và reset tuần sớm nhất, nên dùng trước; `⇄ 5h almost out` = account hiện tại sắp hết.

Không gọi API nào, không gửi dữ liệu đi đâu: chỉ đọc JSON mà Claude Code đưa cho status line, cache ở `~/.claude/quota-cache/`.

## Cài đặt (1 lệnh)

Cần `jq` (`brew install jq` hoặc `sudo apt install jq`).

```bash
curl -fsSL https://raw.githubusercontent.com/arecavn/claude-code-tools/main/statusline-quota/install.sh | bash
```

Lệnh này tải `statusline.sh` về `~/.claude/claude-statusline-quota.sh`, backup `~/.claude/settings.json` rồi thêm:

```json
"statusLine": { "type": "command", "command": "~/.claude/claude-statusline-quota.sh", "refreshInterval": 60 }
```

Mở session Claude Code mới là thấy. Gỡ: xoá khối `statusLine` trong `settings.json`.

## Ghi chú

- Quota chỉ có với account Claude Pro/Max (đăng nhập bằng `/login`); dùng API key thì phần quota hiện `waiting for first response`.
- Số quota xuất hiện sau response đầu tiên của session.
- Ngay sau `/login` đổi account, dòng có thể hiện `7d ?` vài giây vì Claude Code còn giữ số của account trước — script tự bỏ qua để không ghi nhầm.
- Chạy được trên macOS và Linux.
