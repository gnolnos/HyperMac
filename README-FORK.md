# HyperMac — Fork bản Intel & cải tiến (Fork Release)

> Tài liệu bản quyền & phân phối cho **bản fork release** trên tài khoản `gnolnos`.
> Bản gốc: https://github.com/mrgoose000000-gif/HyperMac

## 🔒 Bản quyền (thỏa mãn GPL-3.0 + yêu cầu tác giả gốc)

Bản fork này được phân phối lại theo **[GNU General Public License v3.0 (GPLv3)](LICENSE)**.

**Giữ nguyên bản quyền gốc (bắt buộc):**
```
Copyright © 2026 Nguyễn Khắc Đại (@khacdai24, mrgoose000000-gif)  — Tác giả bản gốc
```

**Thêm bản quyền cho phần đóng góp của fork (không thay thế bản gốc):**
```
Copyright © 2026 Phan Sơn Long (gnolnos) — Bản fork Intel x86_64 + các cải tiến
```

### Tuân thủ bắt buộc theo GPLv3
1. ✅ **Giữ nguyên** thông báo bản quyền tác giả gốc, file `LICENSE` (GPL-3.0), và mọi thông báo pháp lý trong phần mềm/tài liệu.
2. ✅ **Ghi chú rõ ràng mọi chỉnh sửa** so với bản gốc, kèm ngày tháng (bảng bên dưới).
3. ✅ **Công khai toàn bộ mã nguồn** theo cùng GPL-3.0 (đã thỏa vì fork là public repo).
4. ℹ️ **Ghi rõ là fork**, không gây hiểu nhầm là bản chính thức của tác giả; link repo gốc.

## 🧩 Thay đổi so với bản gốc (kèm ngày tháng)

| Ngày | Thay đổi |
|---|---|
| 2026-11 | **Port Intel x86_64** — build chạy trên MacBook Air Intel (PR #7 gốc, hợp nhất); giữ nguyên đồng thời Apple Silicon |
| 2026-11 | **Fan control Intel** — cơ chế `F0Mn` min-clamp (MBA không có `F0Md`), persist natural-min per fan, **fan-curve theo nhiệt độ** (kiểu smcFanControl, chạy cả M lẫn Intel) |
| 2026-11 | **Power telemetry** (Activity Monitor POWER/ENERGY) — M1: `SystemLoad`/accumulators; Intel: SMC `VD0R×ID0R` (DC-in live) |
| 2026-11 | **Fix hiển thị pin Intel** — `CurrentCapacity`(mAh)→% đúng; fix nhận dạng adapter Intel |
| 2026-11 | **Quản lý loa & Âm thanh** — liệt kê/đổi thiết bị xuất âm + **Multi-Output group** (Core Audio, kiểu AudioSwitcher) + nút quét tìm loa |
| 2026-11 | **DDC/CI** — nghiên cứu + probe (không khả thi trên màn budget/DVI; giữ overlay, doc trong skill) |

## 📦 Release fork

Bản release trên fork là **bản xây dựng độc lập** (`HyperMac-Intel.app`) để phục vụ nhu cầu dùng sớm khi tác giả chậm release. Tất cả quyền lợi + nghĩa vụ GPL-3.0 thuộc về bản gốc được bảo toàn; phần thay đổi nêu ở bảng trên là của fork.

— *Phân phối theo GPL-3.0. Mọi thắc mắc bản quyền: repo gốc `mrgoose000000-gif/HyperMac`.*
