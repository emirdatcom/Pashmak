-- +goose Up
-- In-app support chat (prompt 21, decision D-2). Message bodies are AES-GCM encrypted (body_enc).
CREATE TABLE support_operators (
    id            uuid PRIMARY KEY,
    username      text        NOT NULL UNIQUE,
    password_hash text        NOT NULL,
    display_name  text        NOT NULL,
    role          text        NOT NULL CHECK (role IN ('agent', 'admin')),
    active        boolean     NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL,
    last_login_at timestamptz
);

CREATE TABLE support_conversations (
    id                   uuid PRIMARY KEY,
    user_id              uuid        NOT NULL REFERENCES users (id),
    status               text        NOT NULL CHECK (status IN ('open', 'waiting_user', 'closed')),
    assigned_operator_id uuid REFERENCES support_operators (id),
    last_message_at      timestamptz NOT NULL,
    awaiting_since       timestamptz,            -- set by a user message, cleared by the first operator reply
    user_unread_count    integer     NOT NULL DEFAULT 0,
    operator_unread      integer     NOT NULL DEFAULT 0,
    device_meta          jsonb,                  -- only with the user's explicit consent
    created_at           timestamptz NOT NULL,
    closed_at            timestamptz
);
-- one non-closed conversation per user
CREATE UNIQUE INDEX support_conversations_user_open ON support_conversations (user_id) WHERE status <> 'closed';
CREATE INDEX support_conversations_queue ON support_conversations (status, last_message_at);
CREATE INDEX support_conversations_user ON support_conversations (user_id);

CREATE TABLE support_messages (
    id              uuid PRIMARY KEY,           -- UUIDv7: sortable, used as the paging cursor
    conversation_id uuid        NOT NULL REFERENCES support_conversations (id) ON DELETE CASCADE,
    sender          text        NOT NULL CHECK (sender IN ('user', 'operator', 'system')),
    operator_id     uuid REFERENCES support_operators (id),
    client_msg_id   uuid,
    body_enc        bytea       NOT NULL,
    created_at      timestamptz NOT NULL,
    read_at         timestamptz
);
CREATE INDEX support_messages_history ON support_messages (conversation_id, created_at);
CREATE UNIQUE INDEX support_messages_client_id ON support_messages (conversation_id, client_msg_id) WHERE client_msg_id IS NOT NULL;

CREATE TABLE support_canned_replies (
    id     uuid PRIMARY KEY,
    key    text    NOT NULL UNIQUE,
    title  text    NOT NULL,
    body   text    NOT NULL,
    active boolean NOT NULL DEFAULT true
);

CREATE TABLE operator_sessions (
    id          uuid PRIMARY KEY,
    operator_id uuid        NOT NULL REFERENCES support_operators (id),
    token_hash  text        NOT NULL UNIQUE,
    expires_at  timestamptz NOT NULL,
    revoked_at  timestamptz,
    created_at  timestamptz NOT NULL
);

-- Starter canned replies (operators can edit them in the panel). {market} is filled in by the panel.
INSERT INTO support_canned_replies (id, key, title, body) VALUES
 (gen_random_uuid(), 'welcome', 'خوشامد', 'سلام! ممنون که پیام دادی. بگو چه کمکی از دستم برمیاد؟'),
 (gen_random_uuid(), 'purchase_issue', 'مشکل خرید', 'متأسفیم که خرید درست انجام نشد. خرید فقط از داخل اپ و از طریق {market} انجام می‌شه. اگه مبلغی کم شده، توی اپ از بخش «اشتراک من» گزینه‌ی «بازگردانی خرید» رو بزن؛ اگه درست نشد، همین‌جا بنویس.'),
 (gen_random_uuid(), 'restore_purchase', 'بازگردانی خرید', 'برای بازگردانی خرید: اپ رو باز کن، «اشتراک من» رو بزن و «بازگردانی خرید» رو انتخاب کن. حواست باشه با همون حساب {market} وارد شده باشی که باهاش خرید کردی.'),
 (gen_random_uuid(), 'notifications', 'نوتیف نمی‌رسد', 'برای رسیدن یادآوری‌ها: ۱) اجازه‌ی اعلان رو توی تنظیمات گوشی روشن کن؛ ۲) اپ رو از «بهینه‌سازی باتری» مستثنی کن؛ ۳) توی تنظیمات خود اپ بخش یادآوری‌ها رو چک کن. بعد از ریبوت هم یه بار اپ رو باز کن.'),
 (gen_random_uuid(), 'delete_data', 'حذف داده', 'برای حذف همه‌ی داده‌ها: تنظیمات ← «داده‌های تو» ← «حذف همه‌ی داده‌ها». این کار برگشت نداره و درخواست حذف حساب هم به سرور فرستاده می‌شه.'),
 (gen_random_uuid(), 'distress', 'ناراحتی شدید', 'خیلی ممنون که اینو با ما در میون گذاشتی؛ لازم نیست تنهایی تحمل کنی. ما از طریق این گفتگو نمی‌تونیم مشاوره بدیم، ولی خوبه همین حالا با یه آدم مورد اعتمادت یا یه متخصص حرف بزنی. توی اپ، صفحه‌ی «تنها نیستی» شماره‌های اورژانسی رو داره و اگه خطر فوری هست، همین الان تماس بگیر.');

-- +goose Down
DROP TABLE operator_sessions;
DROP TABLE support_canned_replies;
DROP TABLE support_messages;
DROP TABLE support_conversations;
DROP TABLE support_operators;
