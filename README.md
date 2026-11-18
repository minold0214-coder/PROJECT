# Verilog / SystemVerilog Projects

김민석의 부트캠프 RTL 설계·검증 프로젝트 모음입니다. 로컬 아카이브의 통합 프로젝트, 테스트벤치 확장본, 실행 근거를 비교해 대표 소스를 정리했습니다.

| 프로젝트 | 주요 내용 | 대표 설계 / 테스트 |
|---|---|---|
| [01 Stopwatch & Watch](stopwatch_watch/) | 시계·스톱워치, 모드 전환, 기록, 디바운싱, 7세그먼트 표시 | `top_module_sw_w` |
| [02 UART / DHT11 / SR04](uart_dht11_sr04/) | DHT11·SR04 센서 제어, UART·FIFO, 팀 프로젝트 보존 소스 | `TOP_DHT11`, `lec_sr04_controller`, `uart_fifo_loopback` |
| [03 FIFO UVM](fifo_uvm/) | FIFO 경계 조건·랜덤 자극, 독립 모델, 기능 커버리지 | `fifo`, `tb_fifo` |
| [04 RV32I UVM](rv32i_cpu/) | R형 10개·I형 ALU 9개 검증, scoreboard, 시프트 오류 분석 | `rv32i_cpu`, `tb_rv32i` |

각 프로젝트는 `rtl/`, `tb/`, `scripts/`, `docs/`와 필요한 `constraints/`로 구성했습니다. 실행 방법·대표 구조·결과·한계·출처는 각 README에 있습니다.

설계·검증은 부트캠프 수업 및 팀 프로젝트 맥락의 자료입니다. 모든 RTL의 독자 작성이나 팀 전체 기능을 개인 성과로 주장하지 않습니다. RV32I의 개인 담당은 R/I ALU UVM 검증이며, 나머지 프로젝트도 발표자료와 소스를 구분해 설명합니다.

## 자료 보관 방식

코드·테스트·설정의 원본 바이트를 유지하고, 실행 보조 스크립트와 README를 새 구조에 맞췄습니다. 각 `docs/source_manifest.json`에 아카이브 상대경로와 SHA256을 기록했습니다. `scripts/check_repository.py`는 파일 해시·의존 입력·문서 링크·선택한 top을 검사합니다.

대용량 영상 내장 PPT, 전체 VCS 로그, 시뮬레이터 캐시와 컴파일 실행파일은 개인 아카이브에 보관합니다. 이 저장소에는 대표 이미지·구조도·결과 발췌를 제공합니다. 기능 검증 결과와 과거 보고서 수치는 각 프로젝트에서 범위를 명시합니다.

## 확인

```sh
python scripts/check_repository.py
```

이번 정리는 소스·파일 목록·의존성·해시를 검사하는 작업입니다. 새 합성·보드 실험·UVM 실행 결과를 만들지 않았습니다. 과거 실행 기록과 현재 소스의 관계 및 재현 제한은 각 프로젝트 README에 적었습니다.
