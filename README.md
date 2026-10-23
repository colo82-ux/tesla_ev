# 테슬라_ev (개인용 테슬라 전비 분석 및 차계부 모바일 앱)

스마트폰 내장형 로컬 DB(`sqflite` SQLite)를 중심으로 **오프라인 우선(Offline-first)**으로 동작하며, 외부 데이터 소스로 **TeslaMate REST API**와 **Tesla 공식 Fleet API(직접 호출)**를 선택적으로 연동해 주행/충전/대기전력(Vampire Drain) 데이터를 동기화하는 Flutter 모바일 앱입니다.

## 주요 기능 및 아키텍처
1. **오프라인 우선 SQLite 로컬 DB (`lib/data/local/database_helper.dart`)**
   - `drive_logs` (주행 기록), `charge_logs` (충전 기록), `expense_logs` (차계부 지출 내역), `maintenance_items` (소모품 관리), `vampire_drain_logs` (주차 중 대기 전력 손실) 테이블 자동 생성 및 CRUD Repository 패턴 구현
   - 최초 실행 시 차트와 타임라인을 즉시 테스트할 수 있는 현실적인 테슬라 주행/충전/소모품 더미 데이터(`MockDataSeeder`) 자동 시딩
2. **듀얼 외부 데이터 동기화 (`lib/data/remote/sync_service.dart`)**
   - **모드 A (`TeslaMateApiClient`):** `GET /api/v1/cars/1/drives`, `GET /api/v1/cars/1/charges` 증분 동기화 및 `Wh/km` → `km/kWh` 자동 변환
   - **모드 B (`TeslaDirectApiClient`):** `GET /api/1/vehicles/{id}`로 차량 슬립(`asleep`) 여부를 먼저 확인해 불필요한 웨이크업(Vampire Drain)을 방지하고, `vehicle_data` 스냅샷 비교를 통해 주행/충전/대기전력 손실 로그를 자동 생성
3. **핵심 4탭 UI 및 폴드(Fold) 대화면 반응형 레이아웃**
   - 일반 스마트폰에서는 하단 `NavigationBar`(4탭), 갤럭시 폴드 펼침/태블릿(`>= 600dp`)에서는 좌측 `NavigationRail` 및 4열 요약 그리드로 자동 전환

## 실행 방법
```bash
flutter pub get
flutter run
```
