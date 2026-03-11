import random
import sqlite3
from telebot import types, TeleBot

print('Start telegram bot...')

token_bot = '8611152804:AAHv3WC69jz5G4AueQSaKtL4mITjE53WGrE'
bot = TeleBot(token_bot)

user_states = {}


class Buttons:
    ADD_WORD = '➕ Добавить слово'
    DELETE_WORD = '🗑 Удалить слово'
    NEXT = '➡️ Следующее слово'
    MENU = '📋 Главное меню'
    STATS = '📊 Статистика'


def init_database():
    conn = sqlite3.connect('words.db')
    cursor = conn.cursor()

    cursor.execute('''
                   CREATE TABLE IF NOT EXISTS users
                   (
                       user_id
                       INTEGER
                       PRIMARY
                       KEY,
                       username
                       TEXT,
                       first_name
                       TEXT,
                       registered_date
                       TIMESTAMP
                       DEFAULT
                       CURRENT_TIMESTAMP
                   )
                   ''')

    cursor.execute('''
                   CREATE TABLE IF NOT EXISTS common_words
                   (
                       id
                       INTEGER
                       PRIMARY
                       KEY
                       AUTOINCREMENT,
                       english
                       TEXT
                       UNIQUE,
                       russian
                       TEXT
                   )
                   ''')

    cursor.execute('''
                   CREATE TABLE IF NOT EXISTS user_words
                   (
                       id
                       INTEGER
                       PRIMARY
                       KEY
                       AUTOINCREMENT,
                       user_id
                       INTEGER,
                       english
                       TEXT,
                       russian
                       TEXT,
                       FOREIGN
                       KEY
                   (
                       user_id
                   ) REFERENCES users
                   (
                       user_id
                   ),
                       UNIQUE
                   (
                       user_id,
                       english
                   )
                       )
                   ''')

    common_words_data = [
        ('red', 'красный'),
        ('blue', 'синий'),
        ('green', 'зеленый'),
        ('yellow', 'желтый'),
        ('black', 'черный'),
        ('white', 'белый'),
        ('cat', 'кошка'),
        ('dog', 'собака'),
        ('house', 'дом'),
        ('car', 'машина'),
        ('i', 'я'),
        ('you', 'ты'),
        ('he', 'он'),
        ('she', 'она'),
        ('book', 'книга')
    ]

    for eng, rus in common_words_data:
        try:
            cursor.execute('INSERT OR IGNORE INTO common_words (english, russian) VALUES (?, ?)', (eng, rus))
        except:
            pass

    conn.commit()
    conn.close()


def add_user(user_id, username, first_name):
    conn = sqlite3.connect('words.db')
    cursor = conn.cursor()
    cursor.execute('''
                   INSERT
                   OR IGNORE INTO users (user_id, username, first_name)
        VALUES (?, ?, ?)
                   ''', (user_id, username, first_name))
    conn.commit()
    conn.close()


def add_user_word(user_id, english, russian):
    conn = sqlite3.connect('words.db')
    cursor = conn.cursor()
    try:
        cursor.execute('''
                       INSERT INTO user_words (user_id, english, russian)
                       VALUES (?, ?, ?)
                       ''', (user_id, english.lower(), russian.lower()))
        conn.commit()
        success = True
    except:
        success = False
    conn.close()
    return success


def delete_user_word(user_id, english):
    conn = sqlite3.connect('words.db')
    cursor = conn.cursor()
    cursor.execute('''
                   DELETE
                   FROM user_words
                   WHERE user_id = ?
                     AND english = ?
                   ''', (user_id, english.lower()))
    conn.commit()
    conn.close()


def get_user_words(user_id):
    """Получает все слова пользователя (общие + личные) - используется когда нужны сами слова"""
    conn = sqlite3.connect('words.db')
    cursor = conn.cursor()

    cursor.execute('SELECT english, russian FROM common_words')
    common = cursor.fetchall()

    cursor.execute('SELECT english, russian FROM user_words WHERE user_id = ?', (user_id,))
    personal = cursor.fetchall()

    conn.close()

    all_words = common + personal
    return [{'english': w[0], 'russian': w[1]} for w in all_words]


def get_random_word(user_id, exclude_word=None):
    """Получает случайное слово из словаря пользователя"""
    words = get_user_words(user_id)
    if exclude_word:
        words = [w for w in words if w['english'] != exclude_word]
    return random.choice(words) if words else None


def get_random_options(correct_word, all_words, count=3):
    """Генерирует случайные варианты ответов"""
    other_words = [w for w in all_words if w['english'] != correct_word['english']]
    if len(other_words) < count:
        # Добавляем запасные варианты
        fallback = ['hello', 'world', 'python', 'code']
        other_words.extend([{'english': f, 'russian': f} for f in fallback])

    selected = random.sample(other_words, min(count, len(other_words)))
    return [w['english'] for w in selected]


def get_common_words_count():
    """Возвращает количество общих слов в базе через SQL COUNT (эффективно)"""
    conn = sqlite3.connect('words.db')
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM common_words')
    count = cursor.fetchone()[0]
    conn.close()
    return count


def get_user_personal_words_count(user_id):
    """Возвращает количество личных слов пользователя через SQL COUNT (эффективно)"""
    conn = sqlite3.connect('words.db')
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM user_words WHERE user_id = ?', (user_id,))
    count = cursor.fetchone()[0]
    conn.close()
    return count


def get_user_stats(user_id):
    """Возвращает общее количество слов пользователя (общие + личные) - без выгрузки данных"""
    common_count = get_common_words_count()
    personal_count = get_user_personal_words_count(user_id)
    return common_count + personal_count


def create_main_keyboard():
    """Создает клавиатуру с основными кнопками (без вариантов ответов)"""
    markup = types.ReplyKeyboardMarkup(row_width=2, resize_keyboard=True)

    buttons = [
        types.KeyboardButton(Buttons.NEXT),
        types.KeyboardButton(Buttons.ADD_WORD),
        types.KeyboardButton(Buttons.DELETE_WORD),
        types.KeyboardButton(Buttons.STATS),
        types.KeyboardButton(Buttons.MENU)
    ]

    markup.add(*buttons)
    return markup


def create_training_keyboard(options):
    """Создает клавиатуру для тренировки с вариантами ответов"""
    markup = types.ReplyKeyboardMarkup(row_width=2, resize_keyboard=True)

    # Добавляем варианты ответов
    for opt in options:
        markup.add(types.KeyboardButton(opt))

    # Добавляем основные кнопки
    markup.add(
        types.KeyboardButton(Buttons.NEXT),
        types.KeyboardButton(Buttons.ADD_WORD),
        types.KeyboardButton(Buttons.DELETE_WORD),
        types.KeyboardButton(Buttons.STATS),
        types.KeyboardButton(Buttons.MENU)
    )

    return markup


@bot.message_handler(commands=['start'])
def start(message):
    user_id = message.from_user.id
    username = message.from_user.username or "NoUsername"
    first_name = message.from_user.first_name or "User"

    add_user(user_id, username, first_name)
    user_states[user_id] = {}

    common_count = get_common_words_count()

    welcome_text = f"""
👋 Привет, {first_name}!

Я бот для изучения английских слов. 📚

Что я умею:
✅ Спрашивать перевод слов с 4 вариантами ответа
➕ Добавлять твои собственные слова
🗑 Удалять слова (только из твоего личного словаря)
📊 Показывать статистику

Общие слова ({common_count} шт.: цвета, местоимения и т.д.) уже есть в базе.
Добавленные тобой слова будут видны только тебе!

Нажми кнопку "➡️ Следующее слово" чтобы начать тренировку!
    """

    markup = create_main_keyboard()
    bot.send_message(user_id, welcome_text, reply_markup=markup)


@bot.message_handler(func=lambda message: message.text == Buttons.MENU)
def main_menu(message):
    user_id = message.chat.id
    markup = create_main_keyboard()
    bot.send_message(
        user_id,
        "📋 Главное меню\n\nВыбери действие:",
        reply_markup=markup
    )


@bot.message_handler(func=lambda message: message.text == Buttons.STATS)
def show_stats(message):
    user_id = message.chat.id
    
    # Все подсчеты через COUNT на стороне БД - эффективно!
    total_words = get_user_stats(user_id)
    common_count = get_common_words_count()
    personal_count = get_user_personal_words_count(user_id)

    stats_text = f"""
📊 Твоя статистика:

📚 Всего слов в словаре: {total_words}
👤 Общие слова: {common_count}
➕ Твои слова: {personal_count}
    """

    bot.send_message(user_id, stats_text)


@bot.message_handler(func=lambda message: message.text == Buttons.ADD_WORD)
def add_word_start(message):
    user_id = message.chat.id
    user_states[user_id] = {'state': 'waiting_english'}
    msg = bot.send_message(
        user_id,
        "➕ Добавление нового слова\n\nВведите слово на АНГЛИЙСКОМ языке:"
    )
    bot.register_next_step_handler(msg, process_english_word)


def process_english_word(message):
    user_id = message.chat.id
    english = message.text.strip().lower()

    if not english.isalpha():
        msg = bot.send_message(
            user_id,
            "❌ Слово должно содержать только буквы. Попробуйте снова:"
        )
        bot.register_next_step_handler(msg, process_english_word)
        return

    user_states[user_id] = {'state': 'waiting_russian', 'english': english}
    msg = bot.send_message(
        user_id,
        f"Введите перевод слова '{english}' на РУССКОМ языке:"
    )
    bot.register_next_step_handler(msg, process_russian_word)


def process_russian_word(message):
    user_id = message.chat.id
    russian = message.text.strip().lower()

    if not russian.isalpha():
        msg = bot.send_message(
            user_id,
            "❌ Перевод должен содержать только буквы. Попробуйте снова:"
        )
        bot.register_next_step_handler(msg, process_russian_word)
        return

    english = user_states[user_id]['english']

    success = add_user_word(user_id, english, russian)

    if success:
        bot.send_message(
            user_id,
            f"✅ Слово '{english}' - '{russian}' успешно добавлено в твой словарь!"
        )
    else:
        bot.send_message(
            user_id,
            f"❌ Слово '{english}' уже есть в твоем словаре!"
        )

    del user_states[user_id]
    main_menu(message)


@bot.message_handler(func=lambda message: message.text == Buttons.DELETE_WORD)
def delete_word_start(message):
    user_id = message.chat.id

    # Используем COUNT для проверки наличия слов (эффективно)
    personal_count = get_user_personal_words_count(user_id)

    if personal_count == 0:
        bot.send_message(
            user_id,
            "📭 У тебя пока нет добавленных слов. Общие слова удалить нельзя!"
        )
        main_menu(message)
        return

    # Получаем список личных слов для отображения (здесь действительно нужны сами слова)
    conn = sqlite3.connect('words.db')
    cursor = conn.cursor()
    cursor.execute('SELECT english, russian FROM user_words WHERE user_id = ?', (user_id,))
    personal_words = cursor.fetchall()
    conn.close()

    markup = types.ReplyKeyboardMarkup(row_width=2, resize_keyboard=True)
    for eng, rus in personal_words:
        markup.add(types.KeyboardButton(f"🗑 {eng} - {rus}"))

    markup.add(types.KeyboardButton(Buttons.MENU))

    user_states[user_id] = {'state': 'deleting'}
    bot.send_message(
        user_id,
        "🗑 Выбери слово для удаления:",
        reply_markup=markup
    )


@bot.message_handler(func=lambda message: message.text == Buttons.NEXT)
def next_word(message):
    user_id = message.chat.id

    current_word = get_random_word(user_id)

    if not current_word:
        bot.send_message(
            user_id,
            "📭 В словаре нет слов. Добавь свои слова через меню!"
        )
        return

    all_words = get_user_words(user_id)

    wrong_options = get_random_options(current_word, all_words, 3)

    options = [current_word['english']] + wrong_options
    random.shuffle(options)

    markup = create_training_keyboard(options)

    user_states[user_id] = {
        'state': 'training',
        'current_word': current_word['english'],
        'russian': current_word['russian']
    }

    bot.send_message(
        user_id,
        f"🇷🇺 {current_word['russian'].capitalize()}\n\nВыбери правильный перевод:",
        reply_markup=markup
    )


@bot.message_handler(func=lambda message: True)
def handle_answer(message):
    user_id = message.chat.id
    text = message.text

    # Обработка удаления слова
    if user_id in user_states and user_states[user_id].get('state') == 'deleting':
        if text.startswith('🗑'):
            try:
                word_part = text.split(' - ')[0].replace('🗑', '').strip()
                delete_user_word(user_id, word_part)
                bot.send_message(
                    user_id,
                    f"✅ Слово '{word_part}' удалено из твоего словаря!"
                )
            except:
                bot.send_message(
                    user_id,
                    "❌ Ошибка при удалении слова"
                )
        main_menu(message)
        return

    # Обработка ответа на тренировке
    if user_id in user_states and user_states[user_id].get('state') == 'training':
        current_word = user_states[user_id]['current_word']
        russian = user_states[user_id]['russian']

        if text.lower() == current_word.lower():
            bot.send_message(
                user_id,
                f"✅ Правильно! {current_word} - {russian}\n\nМолодец! 🎉"
            )
        else:
            bot.send_message(
                user_id,
                f"❌ Неправильно!\nПравильный ответ: {current_word} - {russian}\n\nПопробуй ещё раз:"
            )
            # Сразу показываем следующее слово
            next_word(message)
            return

        # Показываем следующее слово
        next_word(message)
    else:
        main_menu(message)


if __name__ == '__main__':
    init_database()
    common_count = get_common_words_count()
    print("✅ Бот запущен...")
    print(f"📚 База данных инициализирована (общих слов: {common_count})")
    print("🤖 Ожидание сообщений...")
    bot.infinity_polling(skip_pending=True)
