# HyperMac — Bản Intel (x86_64) standalone

Nhánh này cung cấp **bản phát hành riêng dành cho Mac Intel (x86_64)**, tách khỏi
luồng phát hành Apple Silicon chính của `HyperMac` (vì README chính khẳng định
Intel không được hỗ trợ). Code kế thừa từ nhánh `feat/intel-support` (PR #7) —
toàn bộ theo **GPL-3.0**, ghi nguồn `mrgoose000000-gif/HyperMac`.

## Bạn được gì
Một `.app` đóng sẵn (`HyperMac-Intel-<VER>-x86_64.app.zip`) chạy trên Mac Intel:
pin, nhiệt độ (`sp78`), điều khiển quạt (`F0Mn` min-clamp), Screen Recording
primer, helper SMC — verified trên MacBookAir7,2 (macOS 14.8.7).

## Build
Trên Apple Silicon (cross-compile) hoặc Intel có CLT đầy đủ:
```bash
scripts/release-intel.sh              # mặc định 1.9.8
VER=1.9.8 scripts/release-intel.sh    # tự đặt version
# ~/dist/HyperMac-Intel-1.9.8-x86_64.app.zip
```

## Cài trên Mac Intel
```bash
unzip HyperMac-Intel-1.9.8-x86_64.app.zip -d /Applications
open /Applications/HyperMac-Intel.app
```
Lần chạy đầu: cấp Accessibility / Screen Recording / Bluetooth (vào System
Settings khi app hỏi); cài helper SMC (1 mật khẩu quản trị) để điều khiển quạt.
Ghi nhận: bản build ad-hoc không có Developer ID nên cần Đúng/Right-click để mở.

## Ghi chú kỹ thuật (ngắn)
- Kiến trúc: dùng `machdep.cpu.brand_string` (Rosetta-safe), không `uname -m`.
- SMC Intel: nhiệt `sp78`, quạt `fpe2` (MSB-first), pin mAh, khóa `BCLM`.
- Quạt MBA Intel: không có `F0Md` → dùng `F0Mn` min-clamp (cùng cơ chế smcFanControl).
- `Resources/smc` universal `[x86_64 + arm64]` cho privileged helper.

GPL-3.0 — xem `LICENSE` (của upstream) và `NOTICE` ghi nguồn.
