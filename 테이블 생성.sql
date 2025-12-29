-- [세진 프로젝트] 
-- - 포인트 : FK는 안 걸고(삭제/운영 복잡도 줄이려고), 필요한 건 트리거/인덱스/규칙으로 보완하는 방식

SET NAMES utf8mb4;
SET time_zone = '+09:00';

-- [TABLE 생성]
-- - FK는 안 씀 (ALTER TABLE ... FOREIGN KEY 부분은 전부 제거)
-- - 대신 PK/AUTO_INCREMENT는 CREATE TABLE 안에서 바로 정의
-- - soft delete(삭제표시) 컬럼 있는 테이블은 “실제 삭제”보단 is_deleted/deleted_at으로 처리하는 걸 기본으로 봄


-- [USER] 사용자(관리자/기사/직원/게스트) 계정 테이블
-- - 로그인/권한(ROLE) 기반으로 관리자 웹, 기사 앱, 직원 웹 등을 구분
-- - 소프트 삭제: is_deleted + deleted_at
CREATE TABLE IF NOT EXISTS `USER` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `email` VARCHAR(100) NOT NULL COMMENT '로그인 ID(이메일)',
  `password` VARCHAR(255) NOT NULL COMMENT '암호화된 비밀번호',
  `name` VARCHAR(50) NOT NULL COMMENT '사용자 이름',
  `phone` VARCHAR(20) NOT NULL COMMENT '전화번호',
  `role` VARCHAR(20) NOT NULL COMMENT 'ADMIN/DRIVER/EMP/GUEST',
  `registration_number` VARCHAR(20) NOT NULL COMMENT '사번/등록번호 등 내부 식별용',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  `is_deleted` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제전:0, 삭제후:1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='사용자';


-- [CUSTOMER] 고객 테이블(농협/직접주문 공통)
-- - 고객 자체 정보만 들고, 실제 배송지는 ADDRESS에서 관리
-- - 고객 특이사항은 memo에 남겨두는 용도
CREATE TABLE IF NOT EXISTS `CUSTOMER` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `name` VARCHAR(50) NOT NULL,
  `phone` VARCHAR(20) NOT NULL,
  `type` VARCHAR(20) NOT NULL COMMENT 'NH / DIRECT',
  `memo` VARCHAR(255) NULL DEFAULT NULL COMMENT '고객 특이사항',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  `is_deleted` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='고객';


-- [DELIVERY_ZONE] 배송 권역 테이블
-- - 영천시 내/외 같은 권역 관리용
-- - 단가정책(PRICE_RULE) + 주소(ADDRESS)에서 같이 씀
CREATE TABLE IF NOT EXISTS `DELIVERY_ZONE` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `code` VARCHAR(30) NOT NULL COMMENT 'YC_IN:영천시 내, YC_OUT:영천시 외',
  `name` VARCHAR(100) NOT NULL COMMENT '사용자가 보는 이름',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='배송 권역';


-- [PRODUCT] 상품 테이블
-- - 실제 상품 마스터(퇴비/유박)
-- - 이거 기준으로 재고(STOCK), 단가정책(PRICE_RULE), 주문품목(ORDER_ITEM)이 붙음
CREATE TABLE IF NOT EXISTS `PRODUCT` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `type` VARCHAR(20) NOT NULL COMMENT '퇴비:COMPOST, 유박:UBAK',
  `name` VARCHAR(100) NOT NULL COMMENT '실제로 사용하는 상품이름',
  `description` VARCHAR(255) NULL DEFAULT NULL COMMENT '상품설명',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='상품';


-- [PRICE_RULE] 단가 정책 테이블
-- - 권역 + 상품 + 연도 + 채널(NH/CALL) 기준으로 가격 정책을 저장
-- - 주문 생성할 때 이 정책을 찾아서 “주문 당시 단가”를 ORDER_ITEM에 복사(스냅샷)하는 구조
CREATE TABLE IF NOT EXISTS `PRICE_RULE` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `delivery_zone_id` BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `year` INT NOT NULL COMMENT '예: 2025',
  `channel` VARCHAR(20) NOT NULL COMMENT 'NH / CALL 등',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '현재 정책 사용 여부: 1=사용, 0=중지',
  `base_price` INT UNSIGNED NOT NULL COMMENT '1포 기준 정가',
  `sale_price` INT UNSIGNED NOT NULL COMMENT '1포 기준 실제 고객 판매가',
  `start_date` DATE NULL DEFAULT NULL COMMENT '정책 시작일(선택)',
  `end_date` DATE NULL DEFAULT NULL COMMENT '정책 종료일(선택)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='단가 정책';


-- [STOCK] 재고 테이블(현재 재고 스냅샷)
-- - product_id 당 1줄만 유지하는 방식(그래서 유니크 걸어둠)
-- - 실제 변동 이력은 PROD_LOG에 쌓고, PROD_LOG 입력 시 트리거로 STOCK.qty 반영
CREATE TABLE IF NOT EXISTS `STOCK` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `product_id` BIGINT UNSIGNED NOT NULL,
  `qty` INT UNSIGNED NULL DEFAULT 0 COMMENT '현재 재고 포 수',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='재고';


-- [NH_FILE] 농협 파일 업로드 이력
-- - 농협 엑셀 업로드 한 건 = 여기 1건
-- - 파싱 결과(행 단위)는 NH_ROW로 저장
CREATE TABLE IF NOT EXISTS `NH_FILE` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `uploaded_id` BIGINT UNSIGNED NOT NULL COMMENT '업로드한 사용자 ID',
  `name` VARCHAR(255) NOT NULL COMMENT '업로드한 실제 파일명',
  `upload_year` INT NOT NULL COMMENT '예: 2025',
  `total_rows` INT NOT NULL DEFAULT 0 COMMENT '데이터로 인식한 총 행 수',
  `success_rows` INT NOT NULL DEFAULT 0 COMMENT '성공 행 수',
  `fail_rows` INT NOT NULL DEFAULT 0 COMMENT '실패 행 수',
  `status` VARCHAR(20) NOT NULL DEFAULT 'UPLOADED' COMMENT 'UPLOADED/PARSED/FAILED',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '업로드 일시',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  `is_deleted` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '삭제전:0, 삭제후:1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='농협 파일 업로드';


-- [NH_ROW] 농협 파일 파싱 결과(엑셀 한 줄 = 여기 한 줄)
-- - 파싱 성공/실패를 parse_status로 구분
-- - 주문으로 변환되면 order_id에 매핑(실패면 err_msg에 이유)
CREATE TABLE IF NOT EXISTS `NH_ROW` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `nh_file_id` BIGINT UNSIGNED NOT NULL,
  `row_no` INT NOT NULL COMMENT '실제 엑셀 상 행 번호',
  `year` INT NOT NULL COMMENT '엑셀 사업년도',
  `region` VARCHAR(100) NULL DEFAULT NULL COMMENT '동부동, 고경면 등...',
  `village` VARCHAR(100) NULL DEFAULT NULL COMMENT '가수1리 등',
  `name_raw` VARCHAR(100) NULL DEFAULT NULL,
  `address` VARCHAR(255) NULL DEFAULT NULL COMMENT '기본주소',
  `road_address` VARCHAR(255) NULL DEFAULT NULL COMMENT '도로명주소',
  `tel` VARCHAR(20) NULL DEFAULT NULL COMMENT '집전화',
  `mobile` VARCHAR(20) NULL DEFAULT NULL COMMENT '핸드폰 번호',
  `nh_branch` VARCHAR(100) NULL DEFAULT NULL COMMENT '고경농협 등',
  `item_type` VARCHAR(50) NULL DEFAULT NULL COMMENT '퇴비 / 유박',
  `month` VARCHAR(20) NULL DEFAULT NULL COMMENT '1,3,10 등(원본)',
  `qty_bags` INT UNSIGNED NULL DEFAULT 0 COMMENT '실제 포 수',
  `parse_status` VARCHAR(20) NOT NULL DEFAULT 'SUCCESS' COMMENT 'SUCCESS / ERROR',
  `order_id` BIGINT UNSIGNED NULL DEFAULT NULL COMMENT '변환된 주문 ID(성공 시)',
  `err_msg` VARCHAR(255) NULL DEFAULT NULL COMMENT '파싱/변환 실패 이유',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='농협 행 파싱 결과';


-- [ADDRESS] 배송지 테이블
-- - customer_id(고객) 1명당 배송지가 여러 개 가능해서 분리
-- - delivery_zone_id로 권역 연결(단가/루트 필터에 쓰려고)
-- - 삭제는 is_deleted로 처리(실제 삭제는 되도록 안 하는 방향)
CREATE TABLE IF NOT EXISTS `ADDRESS` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `delivery_zone_id` BIGINT UNSIGNED NOT NULL,
  `region` VARCHAR(100) NOT NULL COMMENT '읍/면/동',
  `village` VARCHAR(100) NULL DEFAULT NULL COMMENT '마을/리',
  `address` VARCHAR(255) NULL DEFAULT NULL COMMENT '"해당연도전체"시트에서 받아온 주소 or 수정된 주소',
  `address_road` VARCHAR(255) NULL DEFAULT NULL,
  `recv_name` VARCHAR(50) NOT NULL COMMENT '수령자 이름',
  `recv_phone` VARCHAR(20) NOT NULL COMMENT '수령자 연락처',
  `note` VARCHAR(255) NULL DEFAULT NULL COMMENT '창고위치, "문 앞에 두기" 등',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  `is_deleted` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0:사용, 1:삭제',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='배송지';


-- [ORDER_HEADER] 주문 헤더(주문 1건)
-- - 사람이 보기 쉬운 주문번호(code) 저장
-- - 농협 주문이면 nh_row_id로 “원본행”만 연결해 둠(필요할 때 추적하려고)
-- - 결제상태(payment_status) 변경은 이력(PAYMENT_STATUS_HISTORY)을 꼭 남겨야 해서 트리거로 자동 기록
CREATE TABLE IF NOT EXISTS `ORDER_HEADER` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `code` VARCHAR(50) NOT NULL COMMENT '사람이 보기 쉬운 주문번호',
  `source` VARCHAR(20) NOT NULL COMMENT 'NH / CALL 등',
  `nh_row_id` BIGINT UNSIGNED NULL DEFAULT NULL COMMENT 'NH에서 온 주문일 경우 원본행(NH_ROW)',
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `address_id` BIGINT UNSIGNED NOT NULL,
  `order_date` DATE NOT NULL COMMENT '실제 주문/등록 날짜',
  `month` TINYINT UNSIGNED NULL DEFAULT NULL COMMENT '월(1~12) - 보통 order_date에서 뽑아서 씀',
  `price_base` INT NOT NULL DEFAULT 0 COMMENT '정가 기준 총 금액',
  `price_sale` INT NOT NULL DEFAULT 0 COMMENT '고객 판매가 기준 총 금액',
  `paid_amount` INT UNSIGNED NULL DEFAULT NULL COMMENT '실제 입금 금액(부분입금/추가입금 대비)',
  `payment_memo` VARCHAR(255) NULL DEFAULT NULL COMMENT '입금자명/확인/특이사항',
  `status` VARCHAR(20) NOT NULL DEFAULT 'NEW' COMMENT '주문 상태: NEW/HOLD/CANCEL 등',
  `payment_status` VARCHAR(20) NOT NULL DEFAULT 'UNPAID' COMMENT '결제 상태: UNPAID/PAID/PARTIAL/REFUNDED/CANCELED',
  `paid_at` DATETIME NULL DEFAULT NULL COMMENT '결제 완료로 변경된 시각',
  `memo` VARCHAR(255) NULL DEFAULT NULL COMMENT '주문 관련 메모',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='주문 헤더';


-- [ORDER_ITEM] 주문 품목(주문 1건에 여러 줄)
-- - unit_base/unit_sale은 “주문 시점 단가”를 저장(정책 바뀌어도 기존 주문 금액 유지하려고)
-- - rule_id는 직원이 단가 수기로 넣는 케이스 대비해서 NULL 허용
CREATE TABLE IF NOT EXISTS `ORDER_ITEM` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `order_id` BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `rule_id` BIGINT UNSIGNED NULL DEFAULT NULL COMMENT '직원이 단가 수기로 직접 입력할 때 대비(NULL 허용)',
  `qty` INT NOT NULL DEFAULT 0 COMMENT '포 수량',
  `unit_base` INT NOT NULL COMMENT '주문 시점 정가(1포)',
  `unit_sale` INT NOT NULL COMMENT '주문 시점 판매가(1포)',
  `price_base` INT NOT NULL COMMENT 'unit_base * qty',
  `price_sale` INT NOT NULL COMMENT 'unit_sale * qty',
  `price_edit` TINYINT(1) NOT NULL COMMENT '1이면 직원이 단가 수정한 주문',
  `item_type_raw` VARCHAR(30) NULL DEFAULT NULL COMMENT '농협 "세진전체"시트 비종 구분 원본',
  `prod_name_raw` VARCHAR(100) NULL DEFAULT NULL COMMENT '농협 희망제품명 원본',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='주문 품목';


-- [PAYMENT_STATUS_HISTORY] 결제 상태 변경 이력
-- - 결제상태는 정산/분쟁이랑 직결돼서 “누가 언제 바꿨는지” 반드시 남기는 용도
-- - ORDER_HEADER.payment_status 업데이트 시 트리거로 자동 insert 되게 구성
CREATE TABLE IF NOT EXISTS `PAYMENT_STATUS_HISTORY` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `order_id` BIGINT UNSIGNED NOT NULL,
  `from_status` VARCHAR(20) NOT NULL COMMENT '변경 전 결제 상태',
  `to_status` VARCHAR(20) NOT NULL COMMENT '변경 후 결제 상태',
  `paid_amount` INT UNSIGNED NULL DEFAULT NULL COMMENT '입금 확인 금액',
  `changed_by` BIGINT UNSIGNED NOT NULL COMMENT '상태 변경한 사용자',
  `memo` VARCHAR(255) NULL DEFAULT NULL COMMENT '특이사항 메모',
  `changed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '상태 변경 시각',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='결제 상태 이력';


-- [DELIVERY] 배송(배달) 테이블
-- - 주문(order_id)을 실제 배달 단위로 관리
-- - user_id는 배차 전에는 NULL(미배차)
-- - 배송 상태(status) 변경은 이력(DELIVERY_STATUS_HISTORY)으로 남기려고 트리거로 자동 기록
CREATE TABLE IF NOT EXISTS `DELIVERY` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `order_id` BIGINT UNSIGNED NOT NULL,
  `address_id` BIGINT UNSIGNED NOT NULL,
  `user_id` BIGINT UNSIGNED NULL DEFAULT NULL COMMENT '배달 기사(USER.id), 미배차는 NULL',
  `date_plan` DATE NULL DEFAULT NULL COMMENT '배달 예정일',
  `status` VARCHAR(20) NOT NULL DEFAULT 'READY' COMMENT 'READY/ASSIGNED/GOING/DONE/FAIL/CLAIM',
  `qty_total` INT NOT NULL DEFAULT 0 COMMENT '이 배달에서 내려야 할 전체 포 수',
  `month` TINYINT UNSIGNED NULL DEFAULT NULL COMMENT '필터용 공급월',
  `last_at` DATETIME NULL DEFAULT NULL COMMENT '최근 상태 변경 시각',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='배송';


-- [DELIVERY_STATUS_HISTORY] 배송 상태 변경 이력
-- - 배송은 상태 변경이 많아서 “변경 로그”가 필요함
-- - DELIVERY.status 업데이트 시 트리거로 자동 insert
CREATE TABLE IF NOT EXISTS `DELIVERY_STATUS_HISTORY` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `delivery_id` BIGINT UNSIGNED NOT NULL,
  `from_status` VARCHAR(20) NOT NULL COMMENT '변경 전 배송 상태',
  `to_status` VARCHAR(20) NOT NULL COMMENT '변경 후 배송 상태',
  `changed_by` BIGINT UNSIGNED NOT NULL COMMENT '상태 변경한 사용자',
  `source` VARCHAR(20) NOT NULL DEFAULT 'SYSTEM' COMMENT 'ADMIN_WEB/DRIVER_APP/EMP_WEB/SYSTEM',
  `memo` VARCHAR(255) NULL DEFAULT NULL COMMENT '특이사항 메모',
  `changed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '상태 변경 시각',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='배송 상태 이력';


-- [DELIVERY_GROUP] 배달 루트 그룹(기사 1명 + 날짜 기준)
-- - 기사별로 특정 날짜에 묶어서 루트(코스)를 만든다고 보면 됨
CREATE TABLE IF NOT EXISTS `DELIVERY_GROUP` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT 'role=DRIVER 사용자 ID',
  `name` VARCHAR(100) NOT NULL COMMENT '예: 2025-01-10 오전',
  `date` DATE NOT NULL COMMENT '해당 루트 배달 날짜',
  `sort_opt` VARCHAR(20) NOT NULL DEFAULT 'MANUAL' COMMENT 'QTY / DIST / MANUAL 등',
  `status` VARCHAR(20) NOT NULL DEFAULT 'PLAN' COMMENT 'PLAN / GOING / DONE',
  `started_at` DATETIME NULL DEFAULT NULL COMMENT '루트 시작 시각',
  `finished_at` DATETIME NULL DEFAULT NULL COMMENT '루트 종료 시각',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='배달 루트 그룹';


-- [DELIVERY_GROUP_ITEM] 루트에 들어가는 배송 목록 + 순서
-- - group_id(루트) 안에 delivery_id(배송)를 넣고 seq로 순서 관리
CREATE TABLE IF NOT EXISTS `DELIVERY_GROUP_ITEM` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `group_id` BIGINT UNSIGNED NOT NULL,
  `delivery_id` BIGINT UNSIGNED NOT NULL,
  `seq` INT NOT NULL DEFAULT 1 COMMENT '그룹 내 순서',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='루트 그룹 항목';


-- [DELIVERY_PHOTO] 배송 사진(증빙)
-- - 배송 완료 사진, 위치, 촬영시간 등을 저장
CREATE TABLE IF NOT EXISTS `DELIVERY_PHOTO` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `delivery_id` BIGINT UNSIGNED NOT NULL,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `url` VARCHAR(255) NOT NULL,
  `lat` DECIMAL(10,6) NULL DEFAULT NULL COMMENT '촬영 위치 위도',
  `lng` DECIMAL(10,6) NULL DEFAULT NULL COMMENT '촬영 위치 경도',
  `shot_at` DATETIME NULL DEFAULT NULL COMMENT '앱/서버 기준 촬영 시간',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='배송 사진';


-- [PROD_LOG] 생산/출고/조정 로그(재고 변동 원장)
-- - MAKE/OUT/ADJ+/ADJ- 같은 이벤트를 쌓는 테이블
-- - 입력되면 트리거로 STOCK.qty 자동 반영(현재 재고 유지하려고)
CREATE TABLE IF NOT EXISTS `PROD_LOG` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `product_id` BIGINT UNSIGNED NOT NULL,
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT 'role=EMP 작업자 ID',
  `date` DATE NOT NULL,
  `type` VARCHAR(20) NOT NULL COMMENT 'MAKE / OUT / ADJ+ / ADJ- 등',
  `qty` INT UNSIGNED NULL DEFAULT 0 COMMENT '타입에 따라 + / - 의미',
  `memo` VARCHAR(255) NULL DEFAULT NULL COMMENT '작업 관련 메모',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='생산/출고 로그';


-- [ISSUE] 이슈 테이블
-- - 기계/품질/안전/배송 등 현장에서 발생한 이슈 기록
-- - prod_log_id, delivery_id는 상황에 따라 NULL 가능
-- - admin_notice는 “알림 생성했는지” 체크하는 플래그(중복 방지용)
CREATE TABLE IF NOT EXISTS `ISSUE` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT 'role=EMP/DRIVER 등록자 ID',
  `type` VARCHAR(20) NOT NULL COMMENT 'MACHINE / QUALITY / SAFETY / DELIVERY / ETC',
  `title` VARCHAR(100) NOT NULL COMMENT '이슈 제목',
  `content` TEXT NOT NULL COMMENT '상세 내용',
  `photo_url` VARCHAR(255) NULL DEFAULT NULL,
  `prod_log_id` BIGINT UNSIGNED NULL DEFAULT NULL COMMENT '생산 관련 이슈일 때',
  `delivery_id` BIGINT UNSIGNED NULL DEFAULT NULL COMMENT '배달 관련 이슈일 때',
  `status` VARCHAR(20) NOT NULL DEFAULT 'OPEN' COMMENT 'OPEN / DOING / DONE',
  `done_at` DATETIME NULL DEFAULT NULL COMMENT '이슈 해결 시각',
  `admin_notice` TINYINT(1) NULL DEFAULT 0 COMMENT '0:알림 미생성, 1:알림 생성됨(중복방지)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='이슈';


-- [NOTIFICATION] 알림 마스터(알림 1건)
-- - ref_id는 “무슨 데이터 때문에 알림이 생겼는지” 연결하는 용도
-- - 여기서는 ISSUE.id를 ref_id로 쓰는 컨셉(필요하면 type별로 확장 가능)
CREATE TABLE IF NOT EXISTS `NOTIFICATION` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `type` VARCHAR(20) NOT NULL COMMENT 'MACHINE / QUALITY / SAFETY / DELIVERY / ETC',
  `ref_id` BIGINT UNSIGNED NOT NULL COMMENT '참조 대상 ID(현재는 ISSUE.id로 사용)',
  `title` VARCHAR(100) NOT NULL,
  `message` VARCHAR(255) NOT NULL COMMENT '한 줄 요약 메시지',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL,
  `is_deleted` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0: 사용, 1: 삭제(숨김)',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='알림';


-- [NOTIFICATION_USER] 사용자별 알림 상태
-- - 알림을 “누가 받았는지 / 읽었는지 / 숨겼는지” 저장
-- - 관리자 알림이면 ADMIN 계정들한테 여기로 뿌리면 됨
CREATE TABLE IF NOT EXISTS `NOTIFICATION_USER` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `notification_id` BIGINT UNSIGNED NOT NULL,
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '알림을 받은 사용자(보통 ADMIN)',
  `is_read` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0: 미읽음, 1: 읽음',
  `read_at` DATETIME NULL DEFAULT NULL COMMENT '실제로 알림을 클릭/열어본 시각',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL DEFAULT NULL COMMENT '사용자가 알림을 숨기거나 삭제했을 때 시간',
  `is_deleted` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '0: 사용, 1: 삭제(숨김)',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='사용자별 알림 상태';



