# MFPS (Metress For Pressure Sore)

욕창(압박손상) 예방/모니터링을 위한 의료 보조 앱입니다.  
병동/병실/침상 단위로 환자 상태를 확인하고, 센서 측정값(온도/습도/체온 등)을 조회·표시하고 주기마다 
움직임 변경 알림을 안전/위험/주의 라벨로 표시합니다.
> **담당 역할(Frontend):** 기획서 기반 UI/UX 설계 → Figma 디자인 → Flutter 프론트엔드 구현 → 백엔드와 API 연동 및 협업
>
> ## 🔥 Frontend 담당 범위

### 1) 기획 기반 화면/사용자 흐름 설계
- 기획 문서(요구사항/화면 정의/데이터 요구) 분석 후 화면 흐름(IA) 및 유저 시나리오 정리
- 병동 → 병실 → 침상 → 환자 상세까지 **정보 구조 설계** 및 상태 표시 규칙 정의

### 2) Figma UI/UX 디자인
- 의료 앱 특성에 맞춘 **화이트 톤 + 그린 포인트**의 일관된 디자인 시스템 구성
- Dialog/버튼/입력필드 등 공통 컴포넌트 스타일을 정의하여 화면별 재사용성 확보
- 태블릿/데스크톱 환경을 고려한 레이아웃 구성(사이드 패널 + 메인 콘텐츠 구조)

### 3) Flutter 프론트엔드 구현
- 기능 단위(feature) 폴더 구조로 화면/위젯 모듈화
- UI 컴포넌트 분리(TopHeader / SidePanel / SummaryCards / RoomCard 등)로 유지보수성 향상
- 상태 변경(선택 병동/층/환자 등)에 따른 UI 업데이트 처리
- 다양한 환경(Web/Android)에서 동작하도록 HTTP 계층 분리(IO/Web 클라이언트)

### 4) 백엔드와 협업(API 연동)
- API 명세 기반 요청/응답 DTO 구조 반영 및 예외 처리(네트워크 오류/빈 데이터 등)
- 쿠키/세션 유지 로직 적용 및 인증 흐름(로그인/권한) 연동
- 프론트에서 필요한 데이터 형태를 기준으로 백엔드와 **요구사항 조율 및 개선 제안**
  - 예: 리스트/그래프 렌더링에 필요한 필드 추가, 날짜 포맷 통일, 페이징/커서 처리 등

---

---

## ✨ 주요 기능
- 로그인/세션 유지
- 대시보드: 병동/층/병실/침상 구조 표시 및 환자 카드/상태 확인
- 환자 상세/추가/수정 다이얼로그
- API 통신 레이어 분리 (웹/모바일 환경 대응)
- Secure Storage 기반 로컬 저장(병원 코드/선택 병동 등)

---

## 🧱 기술 스택
- Flutter / Dart
- Riverpod(사용 시) / GoRouter(사용 시)
- HTTP 통신 + 쿠키/세션 유지 헬퍼
- Flutter Secure Storage

---

## 📁 폴더 구조 
```
medicalapp/
├─ android/ # Android 네이티브 설정/빌드
├─ ios/ # iOS 네이티브 설정/빌드
├─ web/ # Web 실행/배포 설정
├─ assets/ # 이미지/폰트 등 리소스
├─ lib/
│ ├─ api/ # 서버 API 호출/HTTP 클라이언트 계층
│ │ ├─ auth_api.dart # 인증/로그인 관련 API
│ │ ├─ hospital_structure_api.dart # 병원 구조 조회 API
│ │ ├─ http_helper.dart # 공통 HTTP 헬퍼
│ │ ├─ http_helper_io_client.dart # 모바일/데스크톱(IO)용 HTTP 클라이언트
│ │ └─ http_helper_web_client.dart # 웹용 HTTP 클라이언트
│ ├─ app/ # 앱 전역 설정(라우팅/테마/앱 루트)
│ │ ├─ app.dart # MaterialApp 등 앱 루트
│ │ ├─ router.dart # 라우팅 설정
│ │ └─ theme.dart # 테마/색상/폰트 등
│ ├─ features/ # 기능 단위(도메인) 화면/위젯
│ │ ├─ auth/
│ │ │ └─ login_screen.dart # 로그인 화면
│ │ └─ dashboard/
│ │ ├─ dashboard_screen.dart # 대시보드 메인 화면
│ │ └─ widgets/
│ │ ├─ dialogs/ # 다이얼로그 모음
│ │ │ ├─ patient_add_dialog.dart
│ │ │ ├─ patient_detail_dialog.dart
│ │ │ └─ patient_edit_dialog.dart
│ │ ├─ Settings_Dialog.dart # 설정 다이얼로그(프로젝트 기준 파일명)
│ │ ├─ room_card.dart # 병실/침상 카드 UI
│ │ ├─ bed_tile.dart # 침상 타일 UI
│ │ ├─ patient_list_card.dart # 환자 리스트 카드
│ │ ├─ side_panel.dart # 사이드 패널 UI
│ │ ├─ side_panel_action_button.dart # 패널 액션 버튼
│ │ ├─ summary_cards.dart # 요약 카드 UI
│ │ └─ top_header.dart # 상단 헤더 UI
│ ├─ storage/ # 로컬 저장/키/환경 설정
│ │ ├─ secure_kv.dart # Secure Storage 래퍼
│ │ ├─ storage_keys.dart # 저장 키 상수 모음
│ │ └─ urlConfig.dart # 서버 URL/환경 설정
│ └─ main.dart # 엔트리 포인트
├─ pubspec.yaml # 의존성/에셋/폰트 설정
├─ pubspec.lock # 의존성 락 파일
├─ analysis_options.yaml # 린트/분석 설정(있는 경우)
└─ .gitignore # Git 제외 파일 목록
```
## 🚀 실행 방법

### 1) 의존성 설치
flutter pub get

