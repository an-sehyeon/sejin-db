-- [인덱스 / 유니크 / 체크]
-- - CHECK는 MySQL 8에서 동작(버전 낮으면 무시될 수 있음)
-- - 소프트 삭제( is_deleted ) 쓰는 테이블은 조회 조건에 자주 들어가서 인덱스가 꽤 도움이 됨


-- [USER] 사용자
-- - email은 중복 가입 방지(탈퇴해도 같은 email 재가입 막는 정책이면 그대로 유지)
ALTER TABLE `USER`
  ADD UNIQUE KEY `UK_USER_EMAIL` (`email`),
  ADD KEY `IDX_USER_IS_DELETED` (`is_deleted`);


-- [CUSTOMER] 고객
ALTER TABLE `CUSTOMER`
  ADD KEY `IDX_CUSTOMER_PHONE` (`phone`),
  ADD KEY `IDX_CUSTOMER_TYPE` (`type`),
  ADD KEY `IDX_CUSTOMER_IS_DELETED` (`is_deleted`);


-- [DELIVERY_ZONE] 배송 권역
ALTER TABLE `DELIVERY_ZONE`
  ADD UNIQUE KEY `UK_DELIVERY_ZONE_CODE` (`code`);


-- [PRODUCT] 상품 마스터
ALTER TABLE `PRODUCT`
  ADD UNIQUE KEY `UK_PRODUCT_TYPE_NAME` (`type`, `name`);


-- [PRICE_RULE] 단가 정책
-- - “권역+상품+연도+채널”로 정책 찾는 쿼리가 기본이라 묶음 인덱스로 잡음
ALTER TABLE `PRICE_RULE`
  ADD KEY `IDX_PRICE_RULE_LOOKUP` (`delivery_zone_id`, `product_id`, `year`, `channel`, `is_active`);


-- [STOCK] 재고 스냅샷
-- - product_id 당 1줄 유지(재고 스냅샷은 1:1로)
ALTER TABLE `STOCK`
  ADD UNIQUE KEY `UK_STOCK_PRODUCT` (`product_id`);


-- [NH_FILE] 농협 파일 업로드 이력
ALTER TABLE `NH_FILE`
  ADD KEY `IDX_NH_FILE_UPLOADED` (`uploaded_id`),
  ADD KEY `IDX_NH_FILE_YEAR` (`upload_year`),
  ADD KEY `IDX_NH_FILE_STATUS` (`status`);


-- [NH_ROW] 농협 행 파싱 결과
ALTER TABLE `NH_ROW`
  ADD KEY `IDX_NH_ROW_FILE` (`nh_file_id`),
  ADD KEY `IDX_NH_ROW_STATUS` (`parse_status`),
  ADD KEY `IDX_NH_ROW_ORDER` (`order_id`);


-- [ADDRESS] 배송지
ALTER TABLE `ADDRESS`
  ADD KEY `IDX_ADDRESS_CUSTOMER` (`customer_id`),
  ADD KEY `IDX_ADDRESS_ZONE` (`delivery_zone_id`),
  ADD KEY `IDX_ADDRESS_IS_DELETED` (`is_deleted`);


-- [ORDER_HEADER] 주문 헤더
ALTER TABLE `ORDER_HEADER`
  ADD UNIQUE KEY `UK_ORDER_HEADER_CODE` (`code`),
  ADD KEY `IDX_ORDER_HEADER_SOURCE` (`source`),
  ADD KEY `IDX_ORDER_HEADER_DATE` (`order_date`),
  ADD KEY `IDX_ORDER_HEADER_MONTH` (`month`),
  ADD KEY `IDX_ORDER_HEADER_CUSTOMER` (`customer_id`),
  ADD KEY `IDX_ORDER_HEADER_ADDRESS` (`address_id`),
  ADD KEY `IDX_ORDER_HEADER_PAYMENT_STATUS` (`payment_status`),
  ADD KEY `IDX_ORDER_HEADER_STATUS` (`status`),
  ADD KEY `IDX_ORDER_HEADER_NH_ROW` (`nh_row_id`);


-- [ORDER_ITEM] 주문 품목
ALTER TABLE `ORDER_ITEM`
  ADD KEY `IDX_ORDER_ITEM_ORDER` (`order_id`),
  ADD KEY `IDX_ORDER_ITEM_PRODUCT` (`product_id`),
  ADD KEY `IDX_ORDER_ITEM_RULE` (`rule_id`);


-- [PAYMENT_STATUS_HISTORY] 결제 상태 이력
-- - 조회는 보통 “특정 주문의 변경 이력”이라 (order_id, changed_at) 조합이 핵심
ALTER TABLE `PAYMENT_STATUS_HISTORY`
  ADD KEY `IDX_PSH_ORDER_CHANGED` (`order_id`, `changed_at`),
  ADD KEY `IDX_PSH_CHANGED_BY` (`changed_by`);


-- [DELIVERY] 배송
ALTER TABLE `DELIVERY`
  ADD KEY `IDX_DELIVERY_ORDER` (`order_id`),
  ADD KEY `IDX_DELIVERY_ADDRESS` (`address_id`),
  ADD KEY `IDX_DELIVERY_DRIVER` (`user_id`),
  ADD KEY `IDX_DELIVERY_DATE_PLAN` (`date_plan`),
  ADD KEY `IDX_DELIVERY_STATUS` (`status`),
  ADD KEY `IDX_DELIVERY_MONTH` (`month`);


-- [DELIVERY_STATUS_HISTORY] 배송 상태 이력
ALTER TABLE `DELIVERY_STATUS_HISTORY`
  ADD KEY `IDX_DSH_DELIVERY_CHANGED` (`delivery_id`, `changed_at`),
  ADD KEY `IDX_DSH_CHANGED_BY` (`changed_by`);


-- [DELIVERY_GROUP] 배달 루트 그룹
ALTER TABLE `DELIVERY_GROUP`
  ADD KEY `IDX_DG_DRIVER_DATE` (`user_id`, `date`),
  ADD KEY `IDX_DG_STATUS` (`status`);


-- [DELIVERY_GROUP_ITEM] 루트 항목
-- - 같은 루트에 같은 배송이 중복으로 들어가는 걸 막기 위해 (group_id, delivery_id) 유니크
-- - 루트 순서 조회는 (group_id, seq)로 빠르게
ALTER TABLE `DELIVERY_GROUP_ITEM`
  ADD UNIQUE KEY `UK_DGI_GROUP_DELIVERY` (`group_id`, `delivery_id`),
  ADD KEY `IDX_DGI_GROUP_SEQ` (`group_id`, `seq`);


-- [DELIVERY_PHOTO] 배송 사진
ALTER TABLE `DELIVERY_PHOTO`
  ADD KEY `IDX_DP_DELIVERY` (`delivery_id`),
  ADD KEY `IDX_DP_USER` (`user_id`);


-- [PROD_LOG] 생산/출고 로그
ALTER TABLE `PROD_LOG`
  ADD KEY `IDX_PL_PRODUCT_DATE` (`product_id`, `date`),
  ADD KEY `IDX_PL_USER_DATE` (`user_id`, `date`);


-- [ISSUE] 이슈
ALTER TABLE `ISSUE`
  ADD KEY `IDX_ISSUE_USER` (`user_id`),
  ADD KEY `IDX_ISSUE_TYPE` (`type`),
  ADD KEY `IDX_ISSUE_STATUS` (`status`),
  ADD KEY `IDX_ISSUE_DELIVERY` (`delivery_id`),
  ADD KEY `IDX_ISSUE_PROD_LOG` (`prod_log_id`),
  ADD KEY `IDX_ISSUE_ADMIN_NOTICE` (`admin_notice`);


-- [NOTIFICATION] 알림
ALTER TABLE `NOTIFICATION`
  ADD KEY `IDX_NOTI_TYPE_CREATED` (`type`, `created_at`),
  ADD KEY `IDX_NOTI_REF` (`ref_id`),
  ADD KEY `IDX_NOTI_IS_DELETED` (`is_deleted`);


-- [NOTIFICATION_USER] 사용자별 알림 상태
ALTER TABLE `NOTIFICATION_USER`
  ADD UNIQUE KEY `UK_NU_NOTI_USER` (`notification_id`, `user_id`),
  ADD KEY `IDX_NU_USER_READ` (`user_id`, `is_read`),
  ADD KEY `IDX_NU_NOTI` (`notification_id`);


-- [CHECK] 최소한으로만 걸어둠
-- - FK가 없으니까 “값 자체가 이상하게 들어오는 것”을 1차로 막는 용도
-- - 최종 검증은 서버에서도 한 번 더 해야 함(특히 MySQL 8 미만이면 CHECK가 무시될 수 있음)

ALTER TABLE `USER`
  ADD CONSTRAINT `CHK_USER_ROLE` CHECK (`role` IN ('ADMIN','DRIVER','EMP','GUEST')),
  ADD CONSTRAINT `CHK_USER_IS_DELETED` CHECK (`is_deleted` IN (0,1));

ALTER TABLE `ORDER_HEADER`
  ADD CONSTRAINT `CHK_ORDER_STATUS` CHECK (`status` IN ('NEW','HOLD','CANCEL','DONE')),
  ADD CONSTRAINT `CHK_ORDER_PAYMENT_STATUS` CHECK (`payment_status` IN ('UNPAID','PAID','PARTIAL','REFUNDED','CANCELED'));

ALTER TABLE `DELIVERY`
  ADD CONSTRAINT `CHK_DELIVERY_STATUS` CHECK (`status` IN ('READY','ASSIGNED','GOING','DONE','FAIL','CLAIM'));

ALTER TABLE `ISSUE`
  ADD CONSTRAINT `CHK_ISSUE_STATUS` CHECK (`status` IN ('OPEN','DOING','DONE'));

ALTER TABLE `NOTIFICATION_USER`
  ADD CONSTRAINT `CHK_NU_IS_READ` CHECK (`is_read` IN (0,1)),
  ADD CONSTRAINT `CHK_NU_IS_DELETED` CHECK (`is_deleted` IN (0,1));
