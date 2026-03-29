# TaskFlow

**올인원 생산성 & 생활 관리 앱** — SwiftUI + SwiftData 기반 iOS/macOS 크로스플랫폼

GitHub 스타일 UI + 태스크 관리, 시간 커밋, 가계부, 시간표를 하나로.

---

## 주요 기능

### 1. 할 일 & 프로젝트 관리
- **Area → Project → Task** 계층 구조
- 태그(Tag) 기반 분류 (다대다 관계)
- 프로젝트 생성 시 동일 이름 태그 자동 생성
- 태스크에 직접 태그 입력/자동완성 지원
- GitHub Issue 스타일 아이콘 (open/closed)

### 2. 시간 커밋 (Git-style Study Time)
- **Stage → Commit** 워크플로우로 공부 시간 기록
- 시작/종료 시간 수동 입력 → Duration 자동 계산
- 완료/미완료 태스크 모두 시간 커밋 가능
- 커밋 히스토리 표시

### 3. 캘린더
- GitHub Contribution Graph 스타일 월간 캘린더
- 태스크 수에 따른 기여도 dot (Less → More)
- 태그별 필터 바로 태스크 필터링
- 시험 일정 표시 + Today 버튼

### 4. 시간표 / 학습 계획 / 가계부 / 위시리스트 / 통계

---

## 디자인

- **GitHub Green** (`#2DA44E`) 메인 컬러
- SF Mono 기반 모노스페이스 UI
- GitHub Octicons 스타일 SF Symbols
- Card 레이아웃 + Issue List (Open/Closed 카운트)
- Contribution Graph 범례

---

## 기술 스택

| 항목 | 내용 |
|------|------|
| 플랫폼 | iOS / macOS |
| 프레임워크 | SwiftUI, SwiftData, Charts, EventKit |
| 저장소 | iCloud Drive 자동 동기화 |

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-03-19 | 프로젝트 초기 설정 |
| 2026-03-20 | Things 3 스타일 UI, StatsView, Apple Calendar 연동 |
| 2026-03-27 | 시간표, 가계부, 위시리스트, 학습 계획 추가 |
| 2026-03-28 | GitHub 스타일 전면 리디자인 — #2DA44E, 모노스페이스, Issue/Repo 카드 |
| 2026-03-28 | 타이머 → Git-style 시간 커밋 (Stage → Commit) 전환 |
| 2026-03-28 | 캘린더 Contribution Graph + 태그 필터 바 |
| 2026-03-28 | GitHub 아이콘 전면 교체, 태그 직접 입력 지원 |
| 2026-03-28 | 노트 에디터 제거, 시간표 시드 데이터 제거 |
