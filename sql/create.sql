create table tb_normal_account
(
player_id int(20),
telephone varchar(255),
account varchar(255),
password varchar(255),
create_time int(20),
PRIMARY KEY (`player_id`)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

create table tb_player
(
player_id int(20),
head_id int(20),
head_url varchar(255),
nickname varchar(255),
sex int(2),
gold int(20),
create_time int(20),
PRIMARY KEY (`player_id`)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

create table tb_visitor_account
(
player_id int(20),
visit_token varchar(255),
create_time int(20),
PRIMARY KEY (`player_id`)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

create table tb_weixin_account
(
player_id int(20),
union_id varchar(255),
create_time int(20),
PRIMARY KEY (`player_id`)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;

create table tb_role
(
role_id int(20),
player_id int(20),
game_id int(20),
head_id int(20),
head_url varchar(255),
nickname varchar(255),
sex int(2),
gold int(20),
create_time int(20),
PRIMARY KEY (`role_id`)
)ENGINE=InnoDB DEFAULT CHARSET=utf8;