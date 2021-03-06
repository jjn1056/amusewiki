-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Jan 22 17:33:21 2015
-- 
SET foreign_key_checks=0;

DROP TABLE IF EXISTS roles;

--
-- Table: roles
--
CREATE TABLE roles (
  id integer NOT NULL auto_increment,
  role varchar(128) NULL,
  PRIMARY KEY (id),
  UNIQUE role_unique (role)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS site;

--
-- Table: site
--
CREATE TABLE site (
  id varchar(16) NOT NULL,
  mode varchar(16) NOT NULL DEFAULT 'blog',
  locale varchar(3) NOT NULL DEFAULT 'en',
  magic_question varchar(255) NOT NULL DEFAULT '',
  magic_answer varchar(255) NOT NULL DEFAULT '',
  fixed_category_list varchar(255) NULL,
  sitename varchar(255) NOT NULL DEFAULT '',
  siteslogan varchar(255) NOT NULL DEFAULT '',
  theme varchar(32) NOT NULL DEFAULT '',
  logo varchar(255) NULL,
  mail_notify varchar(255) NULL,
  mail_from varchar(255) NULL,
  canonical varchar(255) NOT NULL,
  secure_site integer(1) NOT NULL DEFAULT 0,
  sitegroup varchar(255) NOT NULL DEFAULT '',
  sitegroup_label varchar(255) NULL,
  catalog_label varchar(255) NULL,
  specials_label varchar(255) NULL,
  cgit_integration integer(1) NOT NULL DEFAULT 0,
  multilanguage varchar(255) NOT NULL DEFAULT '',
  bb_page_limit integer NOT NULL DEFAULT 1000,
  tex integer(1) NOT NULL DEFAULT 1,
  pdf integer(1) NOT NULL DEFAULT 1,
  a4_pdf integer(1) NOT NULL DEFAULT 1,
  lt_pdf integer(1) NOT NULL DEFAULT 1,
  html integer(1) NOT NULL DEFAULT 1,
  bare_html integer(1) NOT NULL DEFAULT 1,
  epub integer(1) NOT NULL DEFAULT 1,
  zip integer(1) NOT NULL DEFAULT 1,
  ttdir varchar(255) NOT NULL DEFAULT '',
  papersize varchar(64) NOT NULL DEFAULT '',
  division integer NOT NULL DEFAULT 12,
  bcor varchar(16) NOT NULL DEFAULT '0mm',
  fontsize integer NOT NULL DEFAULT 10,
  mainfont varchar(255) NOT NULL DEFAULT 'Linux Libertine O',
  nocoverpage integer(1) NOT NULL DEFAULT 0,
  logo_with_sitename integer(1) NOT NULL DEFAULT 0,
  opening varchar(16) NOT NULL DEFAULT 'any',
  twoside integer(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE canonical_unique (canonical)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS users;

--
-- Table: users
--
CREATE TABLE users (
  id integer NOT NULL auto_increment,
  username varchar(255) NOT NULL,
  password varchar(255) NOT NULL,
  email varchar(255) NULL,
  active integer(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE username_unique (username)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS attachment;

--
-- Table: attachment
--
CREATE TABLE attachment (
  id integer NOT NULL auto_increment,
  f_path text NOT NULL,
  f_name varchar(255) NOT NULL,
  f_archive_rel_path varchar(32) NOT NULL,
  f_timestamp datetime NOT NULL,
  f_timestamp_epoch integer NOT NULL DEFAULT 0,
  f_full_path_name text NOT NULL,
  f_suffix varchar(16) NOT NULL,
  f_class varchar(16) NOT NULL,
  uri varchar(255) NOT NULL,
  site_id varchar(16) NOT NULL,
  INDEX attachment_idx_site_id (site_id),
  PRIMARY KEY (id),
  UNIQUE uri_site_id_unique (uri, site_id),
  CONSTRAINT attachment_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS category;

--
-- Table: category
--
CREATE TABLE category (
  id integer NOT NULL auto_increment,
  name text NULL,
  uri varchar(255) NOT NULL,
  type varchar(16) NOT NULL,
  sorting_pos integer NOT NULL DEFAULT 0,
  text_count integer NOT NULL DEFAULT 0,
  site_id varchar(16) NOT NULL,
  INDEX category_idx_site_id (site_id),
  PRIMARY KEY (id),
  UNIQUE uri_site_id_type_unique (uri, site_id, type),
  CONSTRAINT category_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS job;

--
-- Table: job
--
CREATE TABLE job (
  id integer NOT NULL auto_increment,
  site_id varchar(16) NOT NULL,
  task varchar(32) NULL,
  payload text NULL,
  status varchar(32) NULL,
  created datetime NOT NULL,
  completed datetime NULL,
  priority integer NULL,
  produced varchar(255) NULL,
  errors text NULL,
  INDEX job_idx_site_id (site_id),
  PRIMARY KEY (id),
  CONSTRAINT job_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS redirection;

--
-- Table: redirection
--
CREATE TABLE redirection (
  id integer NOT NULL auto_increment,
  uri varchar(255) NOT NULL,
  type varchar(16) NOT NULL,
  redirect varchar(255) NOT NULL,
  site_id varchar(16) NOT NULL,
  INDEX redirection_idx_site_id (site_id),
  PRIMARY KEY (id),
  UNIQUE uri_type_site_id_unique (uri, type, site_id),
  CONSTRAINT redirection_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS site_options;

--
-- Table: site_options
--
CREATE TABLE site_options (
  site_id varchar(16) NOT NULL,
  option_name varchar(64) NOT NULL,
  option_value varchar(255) NULL,
  INDEX site_options_idx_site_id (site_id),
  PRIMARY KEY (site_id, option_name),
  CONSTRAINT site_options_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS title;

--
-- Table: title
--
CREATE TABLE title (
  id integer NOT NULL auto_increment,
  title text NOT NULL DEFAULT '',
  subtitle text NOT NULL DEFAULT '',
  lang varchar(3) NOT NULL DEFAULT 'en',
  date text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  source text NOT NULL DEFAULT '',
  list_title text NOT NULL DEFAULT '',
  author text NOT NULL DEFAULT '',
  uid varchar(255) NOT NULL DEFAULT '',
  attach text NULL,
  pubdate datetime NOT NULL,
  status varchar(16) NOT NULL DEFAULT 'unpublished',
  f_path text NOT NULL,
  f_name varchar(255) NOT NULL,
  f_archive_rel_path varchar(32) NOT NULL,
  f_timestamp datetime NOT NULL,
  f_timestamp_epoch integer NOT NULL DEFAULT 0,
  f_full_path_name text NOT NULL,
  f_suffix varchar(16) NOT NULL,
  f_class varchar(16) NOT NULL,
  uri varchar(255) NOT NULL,
  deleted text NOT NULL DEFAULT '',
  sorting_pos integer NOT NULL DEFAULT 0,
  site_id varchar(16) NOT NULL,
  INDEX title_idx_site_id (site_id),
  PRIMARY KEY (id),
  UNIQUE uri_f_class_site_id_unique (uri, f_class, site_id),
  CONSTRAINT title_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS vhost;

--
-- Table: vhost
--
CREATE TABLE vhost (
  name varchar(255) NOT NULL,
  site_id varchar(16) NOT NULL,
  INDEX vhost_idx_site_id (site_id),
  PRIMARY KEY (name),
  CONSTRAINT vhost_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS revision;

--
-- Table: revision
--
CREATE TABLE revision (
  id integer NOT NULL auto_increment,
  site_id varchar(16) NOT NULL,
  title_id integer NOT NULL,
  f_full_path_name text NULL,
  message text NULL,
  status varchar(16) NOT NULL DEFAULT 'editing',
  session_id varchar(255) NULL,
  updated datetime NOT NULL,
  INDEX revision_idx_site_id (site_id),
  INDEX revision_idx_title_id (title_id),
  PRIMARY KEY (id),
  CONSTRAINT revision_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT revision_fk_title_id FOREIGN KEY (title_id) REFERENCES title (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS user_role;

--
-- Table: user_role
--
CREATE TABLE user_role (
  user_id integer NOT NULL,
  role_id integer NOT NULL,
  INDEX user_role_idx_role_id (role_id),
  INDEX user_role_idx_user_id (user_id),
  PRIMARY KEY (user_id, role_id),
  CONSTRAINT user_role_fk_role_id FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT user_role_fk_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS user_site;

--
-- Table: user_site
--
CREATE TABLE user_site (
  user_id integer NOT NULL,
  site_id varchar(16) NOT NULL,
  INDEX user_site_idx_site_id (site_id),
  INDEX user_site_idx_user_id (user_id),
  PRIMARY KEY (user_id, site_id),
  CONSTRAINT user_site_fk_site_id FOREIGN KEY (site_id) REFERENCES site (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT user_site_fk_user_id FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS title_category;

--
-- Table: title_category
--
CREATE TABLE title_category (
  title_id integer NOT NULL,
  category_id integer NOT NULL,
  INDEX title_category_idx_category_id (category_id),
  INDEX title_category_idx_title_id (title_id),
  PRIMARY KEY (title_id, category_id),
  CONSTRAINT title_category_fk_category_id FOREIGN KEY (category_id) REFERENCES category (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT title_category_fk_title_id FOREIGN KEY (title_id) REFERENCES title (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

SET foreign_key_checks=1;

