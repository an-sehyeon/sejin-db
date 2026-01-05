USE sejin;

-- [NH_ROW] 파싱 오류행 수정/재처리 기능용 컬럼 추가
-- - 원본값은 그대로 두고, 수정값은 *_fixed 컬럼에 따로 저장하는 방식
-- - correction_status로 "저장만 했는지 / 재처리까지 했는지" 상태 관리
-- - corrected_by/at, reprocessed_by/at 으로 누가 언제 했는지 로그만 남김

ALTER TABLE NH_ROW
ADD COLUMN correction_status VARCHAR(20) NOT NULL DEFAULT 'NONE' COMMENT 'NONE/SAVED/REPROCESSED' AFTER parse_status,
ADD COLUMN name_fixed VARCHAR(100) NULL DEFAULT NULL COMMENT '수정된 이름' AFTER name_raw,
ADD COLUMN mobile_fixed VARCHAR(20) NULL DEFAULT NULL COMMENT '수정된 핸드폰 번호' AFTER mobile,
ADD COLUMN region_fixed VARCHAR(100) NULL DEFAULT NULL COMMENT '수정된 읍/면/동' AFTER region,
ADD COLUMN village_fixed VARCHAR(100) NULL DEFAULT NULL COMMENT '수정된 마을/리' AFTER village,
ADD COLUMN address_fixed VARCHAR(255) NULL DEFAULT NULL COMMENT '수정된 기본주소' AFTER address,
ADD COLUMN road_address_fixed VARCHAR(255) NULL DEFAULT NULL COMMENT '수정된 도로명주소' AFTER road_address,
ADD COLUMN item_type_fixed VARCHAR(50) NULL DEFAULT NULL COMMENT '수정된 품목' AFTER item_type,
ADD COLUMN month_fixed VARCHAR(20) NULL DEFAULT NULL COMMENT '수정된 공급월' AFTER month,
ADD COLUMN qty_bags_fixed INT UNSIGNED NULL DEFAULT NULL COMMENT '수정된 포 수' AFTER qty_bags,
ADD COLUMN remark_fixed VARCHAR(255) NULL DEFAULT NULL COMMENT '수정 비고' AFTER err_msg,
ADD COLUMN corrected_by BIGINT UNSIGNED NULL DEFAULT NULL COMMENT '수정 저장한 사용자 ID' AFTER remark_fixed,
ADD COLUMN corrected_at DATETIME NULL DEFAULT NULL COMMENT '수정 저장 시각' AFTER corrected_by,
ADD COLUMN reprocessed_by BIGINT UNSIGNED NULL DEFAULT NULL COMMENT '재처리 실행한 사용자 ID' AFTER corrected_at,
ADD COLUMN reprocessed_at DATETIME NULL DEFAULT NULL COMMENT '재처리 완료 시각' AFTER reprocessed_by,
ADD COLUMN reprocess_err_msg VARCHAR(255) NULL DEFAULT NULL COMMENT '재처리 실패 사유' AFTER reprocessed_at;


-- [NH_ROW] 파싱 결과 행 조회 성능 개선
-- 특정 파일(nh_file_id)에서 상태(parse_status=SUCCESS/ERROR)별 행을 빠르게 조회하기 위한 인덱스
CREATE INDEX `idx_nh_row_file_parse_status`
ON `NH_ROW` (`nh_file_id`, `parse_status`);


-- [NH_ROW] 재처리 대기(저장된 오류행) 집계/조회 성능 개선
-- 특정 파일(nh_file_id)에서 correction_status=NONE/SAVED/REPROCESSED 조건을 빠르게 필터/카운트하기 위한 인덱스
-- (재처리 버튼 우측 상단 뱃지용 pending count 계산에 사용)
CREATE INDEX `idx_nh_row_file_correction_status`
ON `NH_ROW` (`nh_file_id`, `correction_status`);
