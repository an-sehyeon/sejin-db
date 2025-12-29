-- [TRIGGER]
-- - FK 없이 운영할 때 “이력 자동 기록 / 자동 반영 / 알림 자동 생성” 이런 건 트리거로 처리해두면 편함
--
-- [중요] changed_by 같은 “누가 처리했는지”는 DB가 자동으로 모름
--        그래서 업데이트/삽입 전에 세션 변수로 값을 넣는 방식으로 맞춤
--
-- 예시)
--   SET @app_user_id = 3;               -- 로그인한 사용자 PK
--   SET @change_source = 'ADMIN_WEB';   -- 출처(선택)
--   SET @change_memo = '입금 확인';     -- 메모(선택)
--   SET @paid_amount = 120000;          -- 입금액(선택)
--   UPDATE ORDER_HEADER SET payment_status='PAID' WHERE id=10;

DELIMITER $$

-- (1) ORDER_HEADER month 자동 채우기
-- - month 값이 비어있으면 order_date에서 월만 뽑아서 넣음(필터용)
CREATE TRIGGER `TRG_ORDER_HEADER_SET_MONTH_BI`
BEFORE INSERT ON `ORDER_HEADER`
FOR EACH ROW
BEGIN
  IF NEW.`month` IS NULL THEN
    SET NEW.`month` = MONTH(NEW.`order_date`);
  END IF;
END$$

CREATE TRIGGER `TRG_ORDER_HEADER_SET_MONTH_BU`
BEFORE UPDATE ON `ORDER_HEADER`
FOR EACH ROW
BEGIN
  IF NEW.`order_date` <> OLD.`order_date` THEN
    SET NEW.`month` = MONTH(NEW.`order_date`);
  END IF;
END$$


-- (2) ORDER_HEADER 결제상태 변경 이력 자동 기록
-- - payment_status가 바뀌면 PAYMENT_STATUS_HISTORY에 기록 1줄 추가
-- - @app_user_id 없으면 누가 바꿨는지 기록 못하니까 에러로 막아둠
CREATE TRIGGER `TRG_ORDER_HEADER_PAYMENT_HISTORY_BU`
BEFORE UPDATE ON `ORDER_HEADER`
FOR EACH ROW
BEGIN
  IF NEW.`payment_status` <> OLD.`payment_status` THEN

    IF @app_user_id IS NULL THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'payment_status 변경 시 @app_user_id(변경자) 세팅이 필요함';
    END IF;

    -- 결제 완료 처리로 바뀌면 paid_at 자동 세팅(원하면 정책 바꿔도 됨)
    IF NEW.`payment_status` = 'PAID' AND NEW.`paid_at` IS NULL THEN
      SET NEW.`paid_at` = CURRENT_TIMESTAMP;
    END IF;

    INSERT INTO `PAYMENT_STATUS_HISTORY`
      (`order_id`, `from_status`, `to_status`, `paid_amount`, `changed_by`, `memo`, `changed_at`)
    VALUES
      (OLD.`id`,
       OLD.`payment_status`,
       NEW.`payment_status`,
       COALESCE(@paid_amount, NEW.`paid_amount`),
       @app_user_id,
       COALESCE(@change_memo, NEW.`payment_memo`),
       CURRENT_TIMESTAMP);
  END IF;
END$$


-- (3) DELIVERY 상태 변경 이력 자동 기록 + last_at 갱신
-- - 배송 상태 바뀌면 DELIVERY_STATUS_HISTORY에 기록 1줄 추가
-- - last_at은 “최근 상태 변경시간”이라서 여기서 같이 갱신
CREATE TRIGGER `TRG_DELIVERY_STATUS_HISTORY_BU`
BEFORE UPDATE ON `DELIVERY`
FOR EACH ROW
BEGIN
  IF NEW.`status` <> OLD.`status` THEN

    IF @app_user_id IS NULL THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'delivery status 변경 시 @app_user_id(변경자) 세팅이 필요함';
    END IF;

    SET NEW.`last_at` = CURRENT_TIMESTAMP;

    INSERT INTO `DELIVERY_STATUS_HISTORY`
      (`delivery_id`, `from_status`, `to_status`, `changed_by`, `source`, `memo`, `changed_at`)
    VALUES
      (OLD.`id`,
       OLD.`status`,
       NEW.`status`,
       @app_user_id,
       COALESCE(@change_source, 'SYSTEM'),
       COALESCE(@change_memo, NULL),
       CURRENT_TIMESTAMP);
  END IF;
END$$


-- (4) PROD_LOG 입력 시 재고(STOCK) 자동 반영
-- - MAKE/ADJ+ : 재고 증가
-- - OUT/ADJ-  : 재고 감소
-- - STOCK에 product_id 줄이 없으면 먼저 만들어주고 시작
CREATE TRIGGER `TRG_PROD_LOG_STOCK_AI`
AFTER INSERT ON `PROD_LOG`
FOR EACH ROW
BEGIN
  DECLARE v_exists INT DEFAULT 0;

  SELECT COUNT(*) INTO v_exists
  FROM `STOCK`
  WHERE `product_id` = NEW.`product_id`;

  IF v_exists = 0 THEN
    INSERT INTO `STOCK` (`product_id`, `qty`)
    VALUES (NEW.`product_id`, 0);
  END IF;

  IF NEW.`type` IN ('MAKE','ADJ+') THEN
    UPDATE `STOCK`
       SET `qty` = `qty` + COALESCE(NEW.`qty`, 0)
     WHERE `product_id` = NEW.`product_id`;
  ELSEIF NEW.`type` IN ('OUT','ADJ-') THEN
    UPDATE `STOCK`
       SET `qty` = CASE
                     WHEN `qty` >= COALESCE(NEW.`qty`, 0) THEN `qty` - COALESCE(NEW.`qty`, 0)
                     ELSE 0
                   END
     WHERE `product_id` = NEW.`product_id`;
  END IF;
END$$


-- (5) ISSUE 등록되면 관리자 알림 자동 생성(선택 기능)
-- - ISSUE.admin_notice=0인 경우만 알림 생성(중복 방지)
-- - NOTIFICATION 1건 만들고, ADMIN 전원에게 NOTIFICATION_USER로 뿌림
CREATE TRIGGER `TRG_ISSUE_CREATE_NOTIFICATION_AI`
AFTER INSERT ON `ISSUE`
FOR EACH ROW
BEGIN
  DECLARE v_noti_id BIGINT UNSIGNED;

  IF NEW.`admin_notice` = 0 THEN

    INSERT INTO `NOTIFICATION` (`type`, `ref_id`, `title`, `message`, `created_at`, `is_deleted`)
    VALUES (
      NEW.`type`,
      NEW.`id`,
      CONCAT('[이슈] ', NEW.`title`),
      LEFT(NEW.`content`, 255),
      CURRENT_TIMESTAMP,
      0
    );

    SET v_noti_id = LAST_INSERT_ID();

    INSERT INTO `NOTIFICATION_USER` (`notification_id`, `user_id`, `is_read`, `created_at`, `is_deleted`)
    SELECT v_noti_id, U.`id`, 0, CURRENT_TIMESTAMP, 0
      FROM `USER` U
     WHERE U.`role` = 'ADMIN'
       AND U.`is_deleted` = 0;

    -- 중복 알림 방지용 플래그 업데이트
    UPDATE `ISSUE`
       SET `admin_notice` = 1
     WHERE `id` = NEW.`id`;

  END IF;
END$$

DELIMITER ;

