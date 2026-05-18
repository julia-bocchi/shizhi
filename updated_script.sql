SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS v_workout_type_items;
DROP TABLE IF EXISTS workout_record;
DROP TABLE IF EXISTS workout_plan;
DROP TABLE IF EXISTS workout_template;
DROP TABLE IF EXISTS workout_type;
DROP TABLE IF EXISTS food_plan;
DROP TABLE IF EXISTS food_option;
DROP TABLE IF EXISTS weight_record;
DROP TABLE IF EXISTS user_profile;
DROP TABLE IF EXISTS user_account;

CREATE TABLE user_account
(
    user_id    varchar(64)                         not null comment '用户ID，接口中的 userId',
    username   varchar(100)                        not null comment '登录账号',
    password   varchar(255)                        not null comment '登录密码',
    token      varchar(255)                        null comment '最近一次登录 token',
    created_at timestamp default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at timestamp default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (user_id),
    unique key uk_user_account_username (username)
)
    comment '用户账号表';

CREATE TABLE user_profile
(
    user_id    varchar(64)                         not null comment '用户ID',
    nickname   varchar(100)                        null comment '昵称',
    height_cm  varchar(20)                         null comment '身高(cm)',
    weight_kg  varchar(20)                         null comment '体重(kg)',
    age        varchar(10)                         null comment '年龄',
    gender     varchar(20)                         null comment '性别：男/女/未填写',
    created_at timestamp default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at timestamp default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (user_id),
    key idx_user_profile_gender (gender)
)
    comment '用户资料表';

CREATE TABLE weight_record
(
    id         varchar(64)                         not null comment '记录ID，接口中的 id',
    user_id    varchar(64)                         not null comment '用户ID',
    date       date                                not null comment '记录日期，YYYY-MM-DD',
    weight     decimal(5, 2)                       not null comment '体重(kg)',
    is_updated tinyint(1) default 0                not null comment '是否为更新记录：0-否，1-是',
    created_at timestamp  default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at timestamp  default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (id),
    unique key uk_weight_record_user_date (user_id, date),
    key idx_weight_record_date (date),
    key idx_weight_record_user_id (user_id),
    key idx_weight_record_user_date_range (user_id, date)
)
    comment '体重记录表';

CREATE TABLE food_option
(
    id              varchar(64)                         not null comment '食物ID，接口中的 id',
    user_id         varchar(64)                         null comment '用户ID，preset 类型为空',
    source          varchar(20)                         not null comment '来源：preset/custom',
    name            varchar(100)                        not null comment '食物名称',
    description     text                                null comment '食物描述',
    calories        decimal(8, 2)                       not null comment '卡路里(kcal)',
    serving         varchar(50)                         null comment '份量',
    meal_suggestion varchar(20)                         null comment '建议餐次：早餐/午餐/晚餐',
    image           varchar(255)                        null comment '图片URL',
    accent_color    varchar(20)                         null comment '强调色',
    created_at      timestamp default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at      timestamp default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (id),
    key idx_food_option_source (source),
    key idx_food_option_name (name),
    key idx_food_option_user_id (user_id),
    key idx_food_option_user_source (user_id, source)
)
    comment '食物选项表（预设 + 自定义）';

CREATE TABLE food_plan
(
    id           varchar(64)                         not null comment '计划ID，接口中的 id',
    user_id      varchar(64)                         not null comment '用户ID',
    date         date                                not null comment '日期，YYYY-MM-DD',
    food_id      varchar(64)                         not null comment '食物ID，接口中的 foodId',
    name         varchar(100)                        not null comment '食物名称（冗余字段）',
    description  text                                null comment '食物描述（冗余字段）',
    calories     decimal(8, 2)                       not null comment '卡路里（冗余字段）',
    serving      varchar(50)                         null comment '份量（冗余字段）',
    meal_type    varchar(20)                         not null comment '餐次：breakfast/lunch/dinner/snack',
    image        varchar(255)                        null comment '图片URL（冗余字段）',
    notes        text                                null comment '备注',
    accent_color varchar(20)                         null comment '强调色（冗余字段）',
    created_at   timestamp default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at   timestamp default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (id),
    key idx_food_plan_date (date),
    key idx_food_plan_food_id (food_id),
    key idx_food_plan_meal_type (meal_type),
    key idx_food_plan_user_id (user_id),
    key idx_food_plan_user_date (user_id, date)
)
    comment '饮食计划表';

CREATE TABLE workout_type
(
    id               varchar(64)                         not null comment '训练类型ID，接口中的 id',
    source           varchar(20)                         not null comment '来源：preset/saved_template',
    exercise_id      varchar(50)                         not null comment '运动类型：hiit/running/cycling/jump_rope/yoga/strength/custom',
    saved_workout_id varchar(64)                         not null default '' comment '保存模板ID，预设为空字符串',
    name             varchar(100)                        not null comment '训练名称',
    description      varchar(255)                        null comment '训练描述',
    mode             varchar(50)                         not null comment '模式：duration/set_timer/distance_pace/distance_speed/count_rate',
    intensity        varchar(20)                         null comment '强度：light/moderate/intense',
    accent_color     varchar(20)                         null comment '强调色',
    created_at       timestamp default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at       timestamp default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (id),
    key idx_workout_type_source (source),
    key idx_workout_type_exercise_id (exercise_id)
)
    comment '训练类型基础表（用于返回预设训练类型）';

CREATE TABLE workout_template
(
    id                 varchar(64)                         not null comment '模板ID，接口中的 id',
    user_id            varchar(64)                         not null comment '用户ID',
    name               varchar(100)                        not null comment '模板名称',
    mode               varchar(50)                         not null comment '模式：duration/set_timer/distance_pace/distance_speed/count_rate',
    intensity          varchar(20)                         null comment '强度：light/moderate/intense',
    duration_minutes   varchar(20)                         null comment '时长(分钟)',
    distance_km        varchar(20)                         null comment '距离(km)',
    pace_minutes       varchar(20)                         null comment '配速(分钟/km)',
    speed_km_h         varchar(20)                         null comment '速度(km/h)',
    `count`            varchar(20)                         null comment '次数，对应接口字段 count',
    cadence_per_minute varchar(20)                         null comment '节奏(次/分钟)',
    sets               varchar(20)                         null comment '组数',
    work_seconds       varchar(20)                         null comment '工作时间(秒)',
    rest_seconds       varchar(20)                         null comment '休息时间(秒)',
    created_at         timestamp default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at         timestamp default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (id),
    key idx_workout_template_mode (mode),
    key idx_workout_template_intensity (intensity),
    key idx_workout_template_user_id (user_id),
    key idx_workout_template_user_mode (user_id, mode)
)
    comment '训练模板表';

CREATE TABLE workout_plan
(
    id               varchar(64)                         not null comment '计划ID，接口中的 id',
    user_id          varchar(64)                         not null comment '用户ID',
    date             date                                not null comment '计划日期，YYYY-MM-DD',
    title            varchar(200)                        not null comment '计划标题',
    summary          text                                null comment '计划摘要',
    notes            text                                null comment '备注',
    draft_text       text                                null comment '草稿文本，对应接口字段 draftText',
    saved_workout_id varchar(64)                         not null default '' comment '保存的训练模板ID',
    accent_color     varchar(20)                         null comment '强调色',
    created_at       timestamp default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at       timestamp default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (id),
    key idx_workout_plan_date (date),
    key idx_workout_plan_user_id (user_id),
    key idx_workout_plan_saved_workout_id (saved_workout_id),
    key idx_workout_plan_user_date (user_id, date)
)
    comment '训练计划表';

CREATE TABLE workout_record
(
    id               varchar(64)                         not null comment '记录ID，接口中的 id',
    user_id          varchar(64)                         not null comment '用户ID',
    date             date                                not null comment '训练日期，YYYY-MM-DD',
    exercise_id      varchar(50)                         not null comment '运动类型：hiit/running/cycling/jump_rope/yoga/strength/custom',
    name             varchar(100)                        not null comment '运动名称',
    calories         decimal(8, 2)                       null comment '消耗卡路里(kcal)',
    duration_seconds int                                 null comment '持续时间(秒)',
    plan_id          varchar(64)                         not null default '' comment '关联的训练计划ID',
    distance_km      decimal(8, 2)                       not null default 0.00 comment '距离(km)，对应接口字段 distanceKm',
    `count`          int                                 not null default 0 comment '次数，对应接口字段 count',
    config_snapshot  longtext                            null comment '配置快照(JSON格式)',
    created_at       timestamp default CURRENT_TIMESTAMP null comment '创建时间',
    updated_at       timestamp default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP comment '更新时间',
    primary key (id),
    key idx_workout_record_date (date),
    key idx_workout_record_exercise_id (exercise_id),
    key idx_workout_record_plan_id (plan_id),
    key idx_workout_record_user_id (user_id),
    key idx_workout_record_user_date (user_id, date)
)
    comment '训练记录表';

-- data.json 中 demo 用户未显式保存 password，这里按联调文档登录示例补齐为 123456。
INSERT INTO user_account (user_id, username, password, token)
VALUES ('user-demo', 'demo', '123456', 'mock-token-user-demo'),
       ('user-bocchi', 'bocchi', '123456', 'mock-token-user-bocchi');

INSERT INTO user_profile (user_id, nickname, height_cm, weight_kg, age, gender)
VALUES ('user-demo', 'Julia', '168', '58.2', '27', '女'),
       ('user-bocchi', 'bocchi', '170', '68.5', '26', '男');

INSERT INTO weight_record (id, user_id, date, weight, is_updated)
VALUES ('weight-1', 'user-demo', '2026-04-15', 58.90, 0),
       ('weight-2', 'user-demo', '2026-04-16', 58.70, 0),
       ('weight-3', 'user-demo', '2026-04-17', 58.50, 0),
       ('weight-4', 'user-demo', '2026-04-18', 58.40, 0),
       ('weight-5', 'user-demo', '2026-04-19', 58.20, 0),
       ('weight-1776777363698-546', 'user-demo', '2026-04-21', 60.00, 0),
       ('weight-1776938837534-577', 'user-demo', '2026-04-23', 68.50, 0),
       ('weight-1777015231719-432', 'user-bocchi', '2026-04-24', 68.50, 0);

INSERT INTO food_option (id, user_id, source, name, description, calories, serving, meal_suggestion, image, accent_color)
VALUES ('preset-oatmeal', null, 'preset', '燕麦牛奶杯', '适合早餐或训练前补充碳水，饱腹感稳定。', 280.00, '1 杯', '早餐', '', '#D86C3D'),
       ('preset-chicken-salad', null, 'preset', '鸡胸肉沙拉', '高蛋白、轻负担，适合作为午餐或减脂晚餐。', 320.00, '1 份', '午餐', '', '#10B981'),
       ('preset-salmon', null, 'preset', '香煎三文鱼', '补充优质脂肪和蛋白质，适合主餐搭配。', 410.00, '180 g', '晚餐', '', '#0F6BFF'),
       ('missing-food-002', 'user-demo', 'custom', '自动补建食物(missing-food-002)', '根据计划保存请求自动补建，方便联调测试。', 0.00, '1 份', '晚餐', '', '#F59E0B'),
       ('missing-food-001', 'user-demo', 'custom', '自动补建食物(missing-food-001)', '根据计划保存请求自动补建，方便联调测试。', 0.00, '1 份', '午餐', '', '#F59E0B'),
       ('custom-food-demo-1', 'user-demo', 'custom', '鸡胸肉卷', '自定义高蛋白轻食。', 310.00, '1 份', '午餐', '', '#10B981'),
       ('preset-egg-toast', 'user-bocchi', 'custom', '自动补建食物(preset-egg-toast)', '根据计划保存请求自动补建，方便联调测试。', 0.00, '1 份', '早餐', '', '#F59E0B');

INSERT INTO food_plan (id, user_id, date, food_id, name, description, calories, serving, meal_type, image, notes, accent_color)
VALUES ('food-plan-1', 'user-demo', '2026-04-19', 'preset-oatmeal', '燕麦牛奶杯', '适合早餐或训练前补充碳水，饱腹感稳定。', 280.00, '1 杯', 'breakfast', '', '训练前吃', '#D86C3D'),
       ('food-plan-2', 'user-demo', '2026-04-19', 'custom-food-demo-1', '鸡胸肉卷', '自定义高蛋白轻食。', 310.00, '1 份', 'lunch', '', '午休后吃', '#10B981'),
       ('food-plan-1776777405862-799', 'user-demo', '2026-04-21', 'preset-chicken-salad', '鸡胸肉沙拉', '高蛋白、轻负担，适合作为午餐或减脂晚餐。', 320.00, '1 份', 'breakfast', '', '', '#10B981'),
       ('food-plan-1776777407914-723', 'user-demo', '2026-04-21', 'preset-chicken-salad', '鸡胸肉沙拉', '高蛋白、轻负担，适合作为午餐或减脂晚餐。', 320.00, '1 份', 'breakfast', '', '', '#10B981'),
       ('food-plan-1776777411471-909', 'user-demo', '2026-04-21', 'preset-chicken-salad', '鸡胸肉沙拉', '高蛋白、轻负担，适合作为午餐或减脂晚餐。', 320.00, '1 份', 'breakfast', '', '', '#10B981'),
       ('food-plan-1776777413244-429', 'user-demo', '2026-04-21', 'preset-chicken-salad', '鸡胸肉沙拉', '高蛋白、轻负担，适合作为午餐或减脂晚餐。', 320.00, '1 份', 'breakfast', '', '', '#10B981'),
       ('food-plan-1776938837728-632', 'user-demo', '2026-04-23', 'preset-oatmeal', '燕麦牛奶杯', '适合早餐或训练前补充碳水，饱腹感稳定。', 280.00, '1 杯', 'breakfast', '', '', '#D86C3D'),
       ('food-plan-1776938928463-11', 'user-demo', '2026-04-23', 'custom-food-demo-1', '鸡胸肉卷', '自定义高蛋白轻食。', 310.00, '1 份', 'lunch', '', '', '#10B981'),
       ('food-plan-1776952947892-824', 'user-demo', '2026-04-23', 'missing-food-001', '自动补建食物(missing-food-001)', '根据计划保存请求自动补建，方便联调测试。', 0.00, '1 份', 'lunch', '', 'test auto create', '#F59E0B'),
       ('food-plan-1776953256120-672', 'user-demo', '2026-04-23', 'missing-food-002', '自动补建食物(missing-food-002)', '根据计划保存请求自动补建，方便联调测试。', 0.00, '1 份', 'dinner', '', '?????', '#F59E0B'),
       ('food-plan-1777015593681-18', 'user-bocchi', '2026-04-24', 'preset-egg-toast', '自动补建食物(preset-egg-toast)', '根据计划保存请求自动补建，方便联调测试。', 0.00, '1 份', 'breakfast', '', '', '#F59E0B'),
       ('food-plan-1777015593713-554', 'user-bocchi', '2026-04-24', 'preset-oatmeal', '燕麦牛奶杯', '适合早餐或训练前补充碳水，饱腹感稳定。', 280.00, '1 杯', 'breakfast', '', '', '#D86C3D');

INSERT INTO workout_type (id, source, exercise_id, saved_workout_id, name, description, mode, intensity, accent_color)
VALUES ('hiit', 'preset', 'hiit', '', 'HIIT 间歇', '按组训练，适合燃脂和爆发力练习。', 'set_timer', '', '#FF6B57'),
       ('running', 'preset', 'running', '', '跑步', '根据配速和路程估算总时长与热量。', 'distance_pace', '', '#0F6BFF'),
       ('cycling', 'preset', 'cycling', '', '骑行', '根据均速和路程估算本次运动时长。', 'distance_speed', '', '#10B981'),
       ('jump_rope', 'preset', 'jump_rope', '', '跳绳', '根据总个数和频率估算训练时长。', 'count_rate', '', '#FF4FA3'),
       ('yoga', 'preset', 'yoga', '', '瑜伽', '按持续时长估算消耗，适合拉伸和放松。', 'duration', '', '#7B61FF'),
       ('strength', 'preset', 'strength', '', '力量循环', '适合自重或器械训练，支持按组计时。', 'set_timer', '', '#14B8A6');

INSERT INTO workout_template (id, user_id, name, mode, intensity, duration_minutes, distance_km, pace_minutes, speed_km_h, `count`, cadence_per_minute, sets, work_seconds, rest_seconds)
VALUES ('missing-template-003', 'user-demo', '????', 'distance_pace', 'moderate', '25', '5', '6', '0', '0', '0', '0', '0', '0'),
       ('missing-template-002', 'user-demo', '????', 'distance_pace', 'moderate', '25', '5', '6', '0', '0', '0', '0', '0', '0'),
       ('missing-template-001', 'user-demo', '??????', 'duration', 'moderate', '25', '0', '0', '0', '0', '0', '0', '0', '0'),
       ('template-1001', 'user-demo', '下班后跳绳', 'count_rate', 'moderate', '20', '0', '0', '0', '500', '120', '4', '40', '20'),
       ('local-workout-template-1777015680046-698', 'user-bocchi', '爬楼梯', 'count_rate', 'moderate', '30', '5', '6', '18', '300', '120', '4', '40', '20');

INSERT INTO workout_plan (id, user_id, date, title, summary, notes, draft_text, saved_workout_id, accent_color)
VALUES ('plan-1776953312422-872', 'user-demo', '2026-04-23', '????', '跑步 5 km，配速 6 分/km，预计用时 30 分钟。', '', 'running||duration|moderate|25|5|6|0|0|0|0|0|0', 'missing-template-003', '#0F6BFF'),
       ('plan-1776953256137-869', 'user-demo', '2026-04-23', '????', '跑步 5 km，配速 6 分/km，预计用时 30 分钟。', '', 'running||duration|moderate|25|5|6|0|0|0|0|0|0', 'missing-template-002', '#0F6BFF'),
       ('plan-1776952947910-440', 'user-demo', '2026-04-23', '??????', '自动补建运动 持续 25 分钟。', '', 'custom|%E8%87%AA%E5%8A%A8%E8%A1%A5%E5%BB%BA%E8%BF%90%E5%8A%A8|duration|moderate|25|0|0|0|0|0|0|0|0', 'missing-template-001', '#FF7A59'),
       ('plan-1776938837762-117', 'user-demo', '2026-04-23', '瑜伽', '瑜伽 持续 30 分钟。', '', 'yoga||duration|moderate|30|5|6|18|300|120|4|40|20', '', '#7B61FF'),
       ('plan-1776938837743-340', 'user-demo', '2026-04-23', 'HIIT 间歇', '4 组训练，每组 40 秒，组间休息 20 秒，总时长约 4 分钟。', '', 'hiit||duration|moderate|30|5|6|18|300|120|4|40|20', '', '#FF7A59'),
       ('plan-1001', 'user-demo', '2026-04-19', '晚间跑步', '配速 + 路程 · 30 分钟 · 286 kcal', '下班后训练', 'running%7C%7Cduration%7Cmoderate%7C30%7C5%7C6%7C18%7C300%7C120%7C4%7C40%7C20', '', '#0F6BFF'),
       ('plan-1777015762207-546', 'user-bocchi', '2026-04-24', '爬楼梯', '爬楼梯 共 300 次，节奏 120 次/分，预计用时 3 分钟。', '', 'custom|%E7%88%AC%E6%A5%BC%E6%A2%AF|count_rate|moderate|30|5|6|18|300|120|4|40|20', 'local-workout-template-1777015680046-698', '#FF7A59'),
       ('plan-1777015755108-811', 'user-bocchi', '2026-04-24', 'HIIT 间歇', '4 组训练，每组 40 秒，组间休息 20 秒，总时长约 4 分钟。', '', 'hiit||duration|moderate|30|5|6|18|300|120|4|40|20', '', '#FF7A59'),
       ('plan-1777015405643-43', 'user-bocchi', '2026-04-24', '跑步', '跑步 5 km，配速 6 分/km，预计用时 30 分钟。', '', 'running||duration|moderate|30|5|6|18|300|120|4|40|20', '', '#0F6BFF'),
       ('plan-1777015384766-598', 'user-bocchi', '2026-04-24', 'HIIT 间歇', '4 组训练，每组 40 秒，组间休息 20 秒，总时长约 4 分钟。', '', 'hiit||duration|moderate|30|5|6|18|300|120|4|40|20', '', '#FF7A59');

INSERT INTO workout_record (id, user_id, date, exercise_id, name, calories, duration_seconds, plan_id, distance_km, `count`, config_snapshot)
VALUES ('record-1', 'user-demo', '2026-04-18', 'running', '跑步', 286.40, 1800, '', 5.00, 0, null),
       ('record-2', 'user-demo', '2026-04-19', 'custom', '跳绳', 210.50, 1200, '', 0.00, 500, null);

CREATE VIEW v_workout_type_items AS
SELECT
    null AS user_id,
    id,
    source,
    exercise_id,
    saved_workout_id,
    name,
    description,
    mode,
    coalesce(intensity, '') AS intensity,
    accent_color
FROM workout_type
UNION ALL
SELECT
    user_id,
    id,
    'saved_template' AS source,
    'custom' AS exercise_id,
    id AS saved_workout_id,
    name,
    '自定义模板' AS description,
    mode,
    coalesce(intensity, '') AS intensity,
    '#7B61FF' AS accent_color
FROM workout_template;

SET FOREIGN_KEY_CHECKS = 1;
