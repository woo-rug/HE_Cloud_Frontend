# 💻 HE-Cloud Client Application (Frontend)

## 📌 프로젝트 소개 (Introduction)

본 프로젝트는 **동형암호(Homomorphic Encryption)** 기반 프라이버시 보존형 클라우드 검색 시스템의 클라이언트 애플리케이션입니다. 클라이언트 단에서 키 관리, 데이터 암호화, 한국어 전처리를 담당하는 **'신뢰 영역(Trusted Zone)'** 역할을 수행합니다.

* [cite_start]**핵심 목표:** 서버조차 파일 내용을 알 수 없는 **영지식(Zero-Knowledge)** 기반의 검색 기능 제공[cite: 33].
* [cite_start]**인덱스 모델:** **8192 차원 이진 벡터(Binary BoW)** 및 SIMD Batching 기법 사용[cite: 204, 211].

## 🛠️ 기술 스택 및 요구 사항 (Tech Stack)

| 구분 | 기술 | 역할 |
| :--- | :--- | :--- |
| **플랫폼** | Flutter (Dart) | [cite_start]크로스 플랫폼 데스크톱 UI 구현 [cite: 100] |
| **네이티브 브릿지** | Dart FFI (Foreign Function Interface) | [cite_start]Dart와 C++ 네이티브 모듈 연결 [cite: 102] |
| **암호화** | Microsoft SEAL Wrapper (C++) | [cite_start]동형암호 키 생성 및 벡터 암호화 [cite: 276] |
| **전처리** | Kiwi (C++) | [cite_start]클라이언트 측 경량 한국어 형태소 분석 [cite: 86] |

### 필수 설치 항목 (Prerequisites)

1.  **Flutter SDK**
2.  **C++ Build Tools** (CMake 및 C++ 컴파일러)
3.  **Backend Server:** `HE_Cloud_Backend` 서버가 **먼저 실행 중**이어야 합니다.

## 🚀 실행 가이드 (How to Run)

### Step 1. 종속성 설치 및 확인

프로젝트 폴더(`he_cloud_frontend/`)에서 다음 명령을 실행합니다.

```bash
flutter pub get
```
### Step 2. 서버 주소 설정 (API Configuration)
API 통신을 위해 백엔드 서버의 주소를 설정해야 합니다.

he_cloud_frontend/lib/services/api_service.dart 파일을 엽니다.

파일 상단에 정의된 BASE_URL이 백엔드 FastAPI 서버의 주소와 일치하는지 확인합니다. (로컬 테스트 시 기본값 유지)

```Dart

// lib/services/api_service.dart (예시)
const String BASE_URL = "[http://127.0.0.1:8000](http://127.0.0.1:8000)";
```

### Step 3. 애플리케이션 실행
다음 명령을 실행하여 데스크톱 환경(Windows 또는 macOS)에서 앱을 구동합니다.

```Bash

# macOS 데스크톱에서 실행
flutter run -d macos

# 또는 Windows 데스크톱에서 실행
flutter run -d windows
```
