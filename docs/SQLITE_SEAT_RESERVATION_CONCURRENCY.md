# SQLite 좌석 선점·결제 동시성 설계

## 요구사항과 결론

이 프로젝트는 Rails 8.1, SQLite, Docker만 사용한다. 같은 날짜의 같은 좌석을 100명이 동시에 선택해도 한 명만 선점하고 결제할 수 있어야 한다.

SQLite에는 MySQL·PostgreSQL의 `SELECT ... FOR UPDATE` 행 잠금이 없다. 따라서 다음 방어를 조합한다.

```text
동시 요청 100개
  -> 단일 Puma process
  -> SqliteWriteGate (process 내부 write 직렬화)
  -> Rails 8.1 BEGIN IMMEDIATE transaction
  -> 상태를 WHERE에 넣은 조건부 UPDATE
  -> UNIQUE / CHECK constraint
```

Ruby mutex는 경합을 줄이는 장치이고, 최종 정합성은 SQLite transaction, 조건부 UPDATE와 DB constraint가 담당한다.

## 좌석 상태 머신

```text
available
  -- 사용자 선택 --> held(user_id, hold_expires_at = now + 5분)
  -- 다른 사용자는 UPDATE 0건이므로 실패

held
  -- 5분 안에 결제 --> reserved(user_id, hold_expires_at = NULL)
  -- 5분 경과 --> available
  -- 명시적 취소 --> available
  -- 같은 사용자가 다른 좌석 선택 --> 기존 held를 available로 반환

reserved
  -- 관리자 환불 --> payment refunded + seat available
```

결제 완료 예약은 다른 자리 선택만으로 취소하지 않는다. 돈이 움직인 뒤에는 관리자 환불 transaction을 거쳐야 한다.

## 1차 경쟁: 원자적 선점

애플리케이션에서 먼저 읽고 나중에 저장하면 race condition이 생긴다.

```ruby
# 금지하는 패턴
slot.update!(status: "held") if slot.available?
```

실제 코드는 확인 조건을 UPDATE에 포함한다.

```ruby
updated = SeatSlot
  .where(id: slot.id)
  .where(
    "status = :available OR " \
    "(status = :held AND hold_expires_at <= :now)",
    available: "available",
    held: "held",
    now: Time.current
  )
  .update_all(
    user_id: user.id,
    status: "held",
    hold_expires_at: 5.minutes.from_now,
    lock_version: Arel.sql("lock_version + 1")
  )
```

writer가 순서대로 실행될 때 첫 요청만 `updated == 1`이다. 이후 요청은 상태 조건에 맞지 않아 `updated == 0`으로 충돌 응답을 받는다.

## 5분 만료와 이탈

브라우저 종료나 네트워크 단절은 서버가 신뢰성 있게 즉시 감지할 수 없다. 그래서 client disconnect가 아닌 server timestamp를 기준으로 한다.

- 좌석 조회 시 `SeatHolds::Expire`가 해당 날짜의 만료 선점을 정리한다.
- Solid Queue의 `ExpireSeatHoldsJob`이 1분마다 전체 만료 선점을 정리한다.
- 다른 사용자의 선점 요청은 만료된 `held`를 조건부 UPDATE로 즉시 가져갈 수 있다.
- 사용자가 다른 좌석을 선택하면 같은 transaction 안에서 기존 미결제 선점을 해제한다.
- 사용자가 선점 취소를 누르면 즉시 해제한다.

만료 correctness는 background job 실행 시각에만 의존하지 않는다. job이 잠깐 지연되어도 다음 조회·선점·결제가 timestamp를 다시 검사한다.

## 결제 확정

결제 버튼은 다음 조건만 예약으로 바꾼다.

```sql
UPDATE seat_slots
SET status = 'reserved', hold_expires_at = NULL
WHERE id = ?
  AND user_id = ?
  AND status = 'held'
  AND hold_expires_at > CURRENT_TIME;
```

좌석 UPDATE, `payments` INSERT, `reservation_events` INSERT는 한 transaction이다. 어느 하나라도 실패하면 모두 rollback된다.

현재 PG 동작은 `SIM-<UUID>` 거래번호를 만드는 시뮬레이션이다. 실제 PG를 붙일 때는 긴 외부 HTTP 요청을 SQLite write transaction 안에서 실행하지 않는다.

```text
PG 승인 요청 (transaction 밖)
  -> 짧은 SQLite transaction으로 hold 재검증 + payment/seat 확정
  -> PG webhook의 거래번호를 unique/idempotency key로 재검증
```

## 관리자 환불

환불 service는 관리자만 호출할 수 있다. 하나의 transaction에서 다음을 실행한다.

```text
payment paid -> refunded
seat_slot reserved -> available
reservation_event refunded INSERT
```

`UPDATE ... WHERE status = 'paid'` 조건 때문에 같은 결제를 동시에 두 번 환불해도 첫 요청만 성공한다. 현재는 PG 취소가 없는 시뮬레이션이며 실제 연동 시 PG 취소 성공/웹훅과 idempotency를 추가해야 한다.

## DB constraint

애플리케이션 코드를 우회해도 DB가 다음 규칙을 지킨다.

- `(seat_id, reservation_date)` unique: 좌석·날짜당 slot 하나
- `(user_id, reservation_date) WHERE user_id IS NOT NULL` unique: 사용자당 하루 한 선점/예약
- `payments(seat_slot_id) WHERE status = 'paid'` unique: 좌석당 활성 결제 하나
- status check: `available`, `held`, `reserved` 이외 값 차단
- state check: 상태별 user와 만료시간 조합 강제
- payment check: `paid`는 환불시간 없음, `refunded`는 환불시간 필수

## Rails 8.1과 SQLite transaction

Rails 8.1 SQLite adapter는 Active Record transaction을 `BEGIN IMMEDIATE TRANSACTION`으로 시작한다. transaction 시작 시 writer 자리를 확보하며 SQLite writer는 한 번에 하나다. WAL mode에서는 여러 reader와 writer 한 명이 함께 진행할 수 있다.

Rails의 `lock`, `lock!`, `with_lock` API는 존재하지만 SQLite adapter에서는 `FOR UPDATE` 행 잠금을 만들지 않는다. 이 프로젝트는 이를 좌석 정합성 장치로 사용하지 않는다.

## 단일 process 운영

`SqliteWriteGate`는 Ruby `Mutex`이므로 한 process의 thread만 공유한다. Docker 설정은 다음처럼 단일 Rails process를 유지한다.

```yaml
# WEB_CONCURRENCY는 설정하지 않아 Puma single mode 사용
RAILS_MAX_THREADS: "10"
```

요청 100개가 도착하면 Puma와 Active Record connection pool에서 대기하고 DB write는 짧게 직렬화된다. 여러 container/host로 수평 확장이 필요하면 SQLite 파일 공유 대신 PostgreSQL/MySQL 같은 server DB로 이전해야 한다.

## 100명 테스트

seed는 `loadtest001`부터 `loadtest100`까지 사용자 100명과 `TEST-100` 전용 좌석을 만든다.

관리자로 로그인해 `/admin/concurrency_test`에서 실행하면 전용 좌석의 이전 테스트 결과만 초기화한 뒤 100개 thread를 barrier에서 동시에 출발시킨다. 각 thread는 선점 후 결제까지 시도한다.

예상 결과:

```text
시도 100
예약/결제 성공 1
선점 충돌 99
최종 active payment 1
```

자동화된 HTTP 통합 테스트도 같은 규칙을 검증한다.

```bash
bin/rails test test/integration/seat_reservation_concurrency_test.rb
```
