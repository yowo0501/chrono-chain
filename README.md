# Chrono Chain

my dream jrpg

드래곤 퀘스트풍의 기초적인 시스템을 가진 2D JRPG.

## 엔진

Godot 4.7 (GDScript, GL Compatibility 렌더러)

## 폴더 구조

- `scenes/` — 씬 파일(.tscn)
- `scripts/` — GDScript 코드(.gd)
- `assets/sprites`, `assets/tilesets`, `assets/audio`, `assets/fonts` — 리소스
- `data/` — 캐릭터/아이템/적 등 게임 데이터 리소스
- `addons/` — 에디터 플러그인 (필요 시)

## 실행 방법

1. [Godot 4.7 Standard 빌드](https://godotengine.org/download/windows/) 설치 (C# 안 씀, .NET 빌드 불필요)
2. Godot 실행 → Import → 이 저장소 폴더의 `project.godot` 선택
3. 우측 상단 Play 버튼(F5) — 콘솔에 `Chrono Chain — engine bootstrap OK` 출력되면 정상
