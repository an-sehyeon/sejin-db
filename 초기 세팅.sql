/* 
  1 프로젝트용 데이터베이스(스키마) 생성
 */

-- sejin 이름의 데이터베이스 생성
-- 앞으로 테이블/데이터를 해당 데이터베이스에 모아서 관리하기 위함
-- 기본 문자 인코딩을 utf8mb4로 설정
-- ci: 대소문자 구분X		ai: 악센트 구분X
CREATE DATABASE sejin
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;


/* 
  2) 프로젝트 전용 DB 계정(유저) 생성
*/

-- sejin_app 이라는 DB 사용자 계정 생성
-- 내 PC에서 접속하는 것만 허용
CREATE USER 'sejin_app'@'localhost' IDENTIFIED BY 'shan334';
GRANT ALL PRIVILEGES ON sejin.* TO 'sejin_app'@'localhost';
FLUSH PRIVILEGES;
