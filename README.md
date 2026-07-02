# My Wealth

แอปติดตามพอร์ตการลงทุนระยะยาว — เปิดทุกเดือนจนเกษียณ

## Tech Stack

- **Flutter** + **Riverpod** + **GoRouter**
- **Hive** — เก็บ holdings และ settings
- **Dio** — HTTP client
- **fl_chart** — กราฟพอร์ต
- **Financial Modeling Prep (FMP)** — ราคาหุ้น, ETF, คริปโต

## ฟีเจอร์

| Tab | รายละเอียด |
|-----|-----------|
| Dashboard | มูลค่าพอร์ต, กำไร, กราฟ, เป้าหมาย, ตลาดวันนี้ |
| Portfolio | สินทรัพย์ที่ถือ + Watchlist |
| DCA | คำนวณงบรายเดือน + Analyze Portfolio |
| Analysis | คะแนนพอร์ต, เป้าหมายเกษียณ, Statistics, ข่าว |
| Settings | FMP API Key, เป้าหมาย, Dark Mode |

## เริ่มใช้งาน

```bash
flutter pub get
flutter run
```

## FMP API Key

1. สมัครที่ [financialmodelingprep.com](https://financialmodelingprep.com)
2. ไปที่ **Settings** ในแอป → ใส่ API Key
3. ไม่มี Key ก็รันได้ — ใช้ข้อมูลตัวอย่าง (mock)

## โครงสร้าง

```
lib/
├── core/          # theme, router, constants
├── data/          # models, services (FMP, storage, portfolio)
├── features/      # หน้าจอแต่ละ tab
├── providers/     # Riverpod providers
└── shared/        # widgets ร่วม
```
