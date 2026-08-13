# NestJS·React 개발자를 위한 현재 Rails 구조

## 한 서버에서 프론트와 백엔드를 함께 실행한다

현재 애플리케이션은 Rails 풀스택 모놀리스다.

```text
React + NestJS
Browser -> React app -> JSON API -> NestJS -> DB

현재 Rails
Browser -> Rails router -> Controller -> Service/Model -> SQLite
                         -> ERB View -> HTML 응답
```

`bin/rails server` 하나가 HTML, CSS, JavaScript, 인증, 비즈니스 로직과 DB 접근을 모두 처리한다. 프론트와 백엔드 역할은 코드 안에서 분리하지만 별도 개발 서버로 띄우지 않는다. 화면 전환은 Turbo가 가속하고 작은 동작은 Stimulus controller가 담당한다.

## NestJS·React와 대응 관계

| Rails | NestJS·React에서 가까운 개념 | 현재 예시 |
|---|---|---|
| `config/routes.rb` | Nest Controller route decorator | `POST /seat_slots/:id/hold` |
| Controller | Nest Controller | `SeatSlotsController` |
| Service object | Nest Provider/Service | `SeatHolds::Acquire` |
| Active Record Model | Entity + Repository | `User`, `SeatSlot`, `Payment` |
| Migration | TypeORM/Prisma migration | 사용자·좌석·결제 테이블 |
| ERB View | React JSX page | 좌석 목록, 결제, 관리자 화면 |
| Stimulus Controller | 작은 React client component | 5분 countdown |
| `Current` | request-scoped current user | `Current.user` |
| Active Job/Solid Queue | BullMQ worker에 가까운 작업 큐 | 만료 선점 정리 |
| Action Mailer | mail provider/service | 비밀번호 재설정 메일 |

Active Record model은 단순 entity보다 책임이 많다. association, validation, query method와 persistence API가 한 클래스에 들어 있다. 복잡한 상태 변경은 model callback에 숨기지 않고 `app/services`의 명시적인 service object로 분리했다.

## 실제 디렉터리

```text
app/
  controllers/
    concerns/authentication.rb       # 세션 cookie 인증 공통 로직
    sessions_controller.rb           # 로그인/로그아웃
    registrations_controller.rb      # 회원가입
    username_lookups_controller.rb   # 아이디 찾기
    passwords_controller.rb          # 비밀번호 재설정
    seat_slots_controller.rb         # 좌석/결제 HTTP 요청
    admin/                            # 관리자 권한 영역
  models/
    user.rb                           # 사용자와 비밀번호 hash
    session.rb                        # 로그인 세션
    seat.rb                           # 물리 좌석
    seat_slot.rb                      # 좌석+날짜의 판매 단위
    payment.rb                        # 결제/환불 상태
    reservation_event.rb             # 감사 이력
  services/
    seat_holds/                       # 선점, 해제, 만료
    seat_payments/                    # 결제 확정
    payment_refunds/                  # 관리자 환불
    load_tests/                       # 100명 동시성 실험
  queries/seat_availability_query.rb  # 좌석 읽기 모델
  jobs/expire_seat_holds_job.rb       # 5분 만료 정리
  views/                              # 서버 렌더링 ERB
  javascript/controllers/             # Stimulus
config/
  routes.rb                           # 모든 URL
  database.yml                        # SQLite 연결
  recurring.yml                       # 1분 주기 작업
db/
  migrate/                            # DB 변경 이력
  schema.rb                           # 현재 최종 schema
  seeds.rb                            # 관리자/데모/100명 데이터
test/                                 # Minitest
compose.yaml                          # Rails web 단일 서비스
```

## 요청 한 건의 흐름

사용자가 좌석을 선택하면 다음 순서로 실행된다.

```text
POST /seat_slots/42/hold
  -> config/routes.rb
  -> Authentication이 session cookie 확인
  -> SeatSlotsController#hold
  -> SeatHolds::Acquire
  -> SQLite transaction + 조건부 UPDATE
  -> ReservationEvent INSERT
  -> checkout URL로 redirect
  -> checkout.html.erb 렌더링
```

NestJS에서는 Controller가 Service를 dependency injection으로 받는 경우가 많다. 여기서는 controller가 작은 service object를 생성해 호출한다. Rails autoloading 덕분에 `require`를 직접 작성하지 않는다.

## 핵심 데이터 모델

```text
User 1 --- N Session
User 1 --- N SeatSlot
Seat 1 --- N SeatSlot
SeatSlot 1 --- N Payment
SeatSlot 1 --- N ReservationEvent
Payment 1 --- N ReservationEvent
```

`Seat`는 A-01 같은 실제 자리다. `SeatSlot`은 A-01의 2026-08-10 이용권처럼 날짜가 결합된 예약 단위다. 따라서 `(seat_id, reservation_date)` unique index가 한 날짜 한 좌석을 하나로 고정한다.

`SeatSlot.status` 상태 전이는 다음과 같다.

```text
available --선택--> held --결제--> reserved
    ^                  |
    |                  +--5분 만료/다른 자리 선택/취소
    |
    +---------- 관리자 환불 -------- reserved
```

## 인증과 권한

비밀번호는 `has_secure_password`와 bcrypt로 hash한다. 원문 비밀번호는 DB에 저장하지 않는다. 로그인 성공 시 `sessions` row를 만들고 서명된 HttpOnly cookie에는 session id만 넣는다.

`ApplicationController`는 기본적으로 로그인을 요구한다. 회원가입·로그인·계정 찾기 controller만 `allow_unauthenticated_access`로 예외 처리한다. `Admin::BaseController`는 여기에 `current_user.admin?` 검사를 추가한다.

비밀번호 재설정 token은 15분 후 만료되고, 비밀번호를 변경하면 기존 token과 모든 로그인 session이 무효화된다.

## View와 JavaScript

ERB는 서버에서 Ruby 값을 HTML로 만든다.

```erb
<% @slots.each do |slot| %>
  <strong><%= slot[:label] %></strong>
<% end %>
```

- `<% ... %>`: Ruby 코드를 실행하지만 출력하지 않는다.
- `<%= ... %>`: 결과를 HTML에 출력하며 기본적으로 escape한다.
- `form_with`, `button_to`, `link_to`: CSRF token과 Rails route를 연결하는 view helper다.

현재 JavaScript는 `countdown_controller.js` 하나다. React 전체 앱 대신 해당 DOM에만 연결되어 선점 만료시간을 표시한다.

## SQLite 파일과 Rails 내장 DB 구성

로컬 개발 primary DB는 `storage/development.sqlite3`다. Docker 운영 DB는 volume 안의 `/rails/storage/production.sqlite3`다.

운영에서는 목적별 SQLite 파일을 나눈다.

```text
production.sqlite3        업무 데이터
production_cache.sqlite3  Solid Cache
production_queue.sqlite3  Solid Queue
production_cable.sqlite3  Solid Cable
```

Solid Queue는 별도 Kafka 서버가 아니라 SQLite queue table을 polling하는 Rails background job 시스템이다. 좌석 정합성의 최종 판단은 queue나 cache가 아니라 primary DB transaction과 constraint가 담당한다.

## 자주 쓰는 명령

```bash
bin/rails server
bin/rails routes
bin/rails console
bin/rails db:migrate
bin/rails db:seed
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

문제를 추적할 때는 `config/routes.rb`에서 URL을 찾고, 해당 controller action, 호출하는 service, model/schema, view 순으로 읽으면 된다.
