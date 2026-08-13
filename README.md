# Rails SQLite 도서관 좌석 예약

Rails 8.1, SQLite, Docker만 사용하는 회원 기반 일자별 좌석 예약 시스템입니다. 별도의 React·NestJS 서버, Redis, MySQL, Kafka는 없습니다.

## 기능

- 회원가입, 로그인, 로그아웃
- 아이디 찾기, 15분 만료 비밀번호 재설정 링크
- 일자별 좌석 조회
- 좌석 5분 임시 선점
- 테스트 결제 후 예약 확정
- 관리자 좌석·결제·감사 이벤트 현황
- 관리자 전액 환불 후 좌석 반환
- 샘플 사용자 100명의 단일 좌석 동시 예약 테스트 페이지
- Solid Queue를 이용한 1분 주기 만료 선점 정리

결제와 환불은 현재 PG사 없이 상태 전이를 확인하는 시뮬레이션입니다. 실제 서비스에서는 `SeatPayments::Complete`와 `PaymentRefunds::Create` 앞에 PG 승인·취소 API와 웹훅 검증을 연결해야 합니다.

## 로컬 실행

```bash
bin/setup
bin/rails db:seed
bin/rails server
```

<http://127.0.0.1:3000>에 접속합니다.

샘플 계정:

| 역할 | 아이디 | 비밀번호 |
|---|---|---|
| 관리자 | `admin` | `admin123!` |
| 일반 사용자 | `demo_user` | `password123!` |
| 동시성 사용자 | `loadtest001` ~ `loadtest100` | `loadtest123!` |

관리자로 로그인한 뒤 `/test`에서 기능 안내를, `/admin/concurrency_test`에서 100명 동시 예약을 실행할 수 있습니다.

개발 및 Docker 데모 모드에서는 비밀번호 찾기 요청 후 화면에 데모용 재설정 링크가 표시됩니다. 실제 운영에서는 SMTP를 설정하고 `DEMO_MODE`를 끕니다.

## Docker 실행

```bash
export RAILS_MASTER_KEY="$(sed -n '1p' config/master.key)"
docker compose up --build -d
docker compose exec -T web bin/rails db:seed
```

웹은 <http://127.0.0.1:3000>에서 열립니다. SQLite primary DB와 Solid Cache·Queue·Cable DB는 `board_storage` Docker volume의 `/rails/storage`에 보존됩니다.

## 검증

```bash
bin/rails test
bin/rails test test/integration/seat_reservation_concurrency_test.rb
bin/rubocop
bin/brakeman --no-pager
```

동시성 통합 테스트는 로그인된 사용자 100명이 같은 좌석에 동시에 HTTP 요청을 보내고 다음 결과를 검증합니다.

```text
선점 성공 1건
선점 충돌 99건
결제 완료 1건
최종 예약 1건
```

## 문서

- [NestJS·React 개발자를 위한 Rails 구조](docs/RAILS_FOR_NEST_REACT_DEVELOPERS.md)
- [SQLite 좌석 선점·결제 동시성 설계](docs/SQLITE_SEAT_RESERVATION_CONCURRENCY.md)
