import 'dart:convert';

class SampleEntry {
  const SampleEntry(this.title, this.content);

  final String title;
  final String content;
}

class SampleCategory {
  const SampleCategory(this.name, this.entries, [this.children = const []]);

  final String name;
  final List<SampleEntry> entries;
  final List<SampleCategory> children;
}

String _block(String type, Map<String, Object> data) =>
    '::entry-$type ${jsonEncode(data)}';

String checklist(String title, List<String> items, {int checked = 0}) =>
    _block('checklist', {
      'title': title,
      'items': [
        for (final (index, text) in items.indexed)
          {'text': text, 'checked': index < checked},
      ],
    });

String table(String title, List<List<String>> rows) =>
    _block('table', {'title': title, 'rows': rows});

String numbered(String title, List<String> items) =>
    _block('list', {'title': title, 'marker': 'number', 'items': items});

final sampleCategories = [
  SampleCategory(
    'English',
    const [
      SampleEntry(
        'A quieter Sunday',
        'Leave the morning unplanned. Walk to the park, pick up lunch and read outside if it stays dry.',
      ),
      SampleEntry(
        'Books to lend',
        'Maya asked for Piranesi. Check whether Ben still has The Dispossessed before promising it to anyone else.',
      ),
    ],
    [
      SampleCategory('Tasks', [
        SampleEntry(
          'Saturday reset',
          checklist('Before noon', [
            'Put a load of laundry on',
            'Return library books',
            'Pick up bread and eggs',
            'Water the balcony plants',
          ], checked: 2),
        ),
        const SampleEntry(
          'Renew the passport',
          'Find the previous passport, check photo requirements, and leave 30 minutes to get to the appointment.',
        ),
        const SampleEntry(
          'Call the bike shop',
          'Ask about a rear brake adjustment and whether the bike can be collected the same day.',
        ),
        SampleEntry(
          'Kitchen shopping list',
          checklist('This week', [
            'Oats',
            'Lemons',
            'Dish soap',
            'Frozen peas',
          ], checked: 1),
        ),
        const SampleEntry(
          'Cancel old subscriptions',
          'Review the last two bank statements. Cancel the unused storage plan before it renews on the 21st.',
        ),
      ]),
      SampleCategory(
        'Work',
        [
          const SampleEntry(
            'Handoff before lunch',
            'Send Nina the approved layout and the open questions. Use the PDF for review and keep the editable original in the shared folder.',
          ),
          SampleEntry(
            'Release checklist',
            checklist('Before publishing', [
              'Read the release notes on a small screen',
              'Check the download link',
              'Ask support to review the FAQ',
            ], checked: 1),
          ),
          const SampleEntry(
            'Budget follow-up',
            'Confirm the quote includes delivery. If it does, book the smaller meeting room for Thursday.',
          ),
          const SampleEntry(
            'Notes from the design review',
            'Keep the search box on the first screen. Move secondary filters into the existing menu. Bring an example with real data next time.',
          ),
        ],
        [
          SampleCategory('Planning', [
            SampleEntry(
              'Next sprint',
              table('Milestones', [
                ['Deliverable', 'Owner', 'Due'],
                ['Prototype for keyboard navigation', 'Nina', 'Tuesday'],
                [
                  'Check Android layout at larger text sizes',
                  'Sam',
                  'Thursday',
                ],
                ['Review feedback and choose the next steps', 'Alex', 'Friday'],
              ]),
            ),
            const SampleEntry(
              'Questions for the kickoff',
              'Who owns the final approval? Which screens must be ready first? Confirm whether Friday is a hard deadline.',
            ),
            const SampleEntry(
              'Reserve a review slot',
              'Keep 25 minutes at the end of Wednesday for the mobile demo. Invite Maya and leave time for questions.',
            ),
          ]),
        ],
      ),
      SampleCategory('Travel', [
        SampleEntry(
          'Train weekend',
          checklist('Pack tonight', [
            'Ticket',
            'Phone charger',
            'Rain jacket',
            'Water bottle',
          ]),
        ),
        const SampleEntry(
          'A walk around Edinburgh',
          'Start at the station, follow the Royal Mile, then stop for coffee before heading up Calton Hill.',
        ),
        SampleEntry(
          'Two-day itinerary',
          table('Times', [
            ['Day', 'Morning', 'Afternoon'],
            [
              'Saturday',
              'Train at 08:40',
              'Museum, then dinner near the station',
            ],
            ['Sunday', 'Coffee and a walk', 'Return at 17:20'],
          ]),
        ),
        const SampleEntry(
          'Split the cabin costs',
          'The deposit is already paid. Divide the remaining amount by four and share the receipt after checkout.',
        ),
      ]),
      SampleCategory('Recipes', [
        SampleEntry(
          'Lemon pasta in 20 minutes',
          numbered('Method', [
            'Cook the pasta and save half a cup of the water.',
            'Warm butter, lemon zest and black pepper.',
            'Toss with the pasta and loosen the sauce with the reserved water.',
          ]),
        ),
        const SampleEntry(
          'Overnight oats',
          'Mix 50 g oats, 120 ml milk, a spoon of yogurt and a pinch of cinnamon. Add berries in the morning.',
        ),
        const SampleEntry(
          'Roasted tomato soup',
          'Roast tomatoes, onion and garlic at 200°C until browned. Blend with stock and finish with a little cream.',
        ),
        const SampleEntry(
          'Lunches for three days',
          'Cook one tray of vegetables and a pot of rice. Use chickpeas on day one and add the leftovers to a wrap on day three.',
        ),
      ]),
      SampleCategory('Creative', [
        const SampleEntry(
          'One-page comic idea',
          'A courier delivers a letter to the wrong apartment and finds a reply written ten years ago. Keep the dialogue to two lines.',
        ),
        const SampleEntry(
          'Palette for a rainy evening',
          'Start with blue-gray shadows and a muted amber highlight. Try reflecting the warm light in the puddles.',
        ),
        const SampleEntry(
          'Practice session',
          'Draw ten small silhouettes, then pick the clearest three. Check how they read when viewed as a thumbnail.',
        ),
      ]),
    ],
  ),
  SampleCategory(
    'Українська',
    const [
      SampleEntry(
        'Плани на неділю',
        'Вранці прогулятися біля річки, зайти за кавою і подзвонити бабусі. Увечері підготувати одяг на понеділок.',
      ),
      SampleEntry(
        'Що почитати',
        'Почати «Тигролови». Виписати кілька улюблених уривків і перевірити, чи є в бібліотеці «Місто».',
      ),
    ],
    [
      SampleCategory('Справи', [
        SampleEntry(
          'Що зробити до вечора',
          checklist('На сьогодні', [
            'Забрати посилку',
            'Оплатити інтернет',
            'Записатися до стоматолога',
            'Поставити телефон на зарядку',
          ], checked: 2),
        ),
        const SampleEntry(
          'Передати показники лічильника',
          'Записати цифри з лічильників води й електрики. Зберегти фото на випадок помилки в рахунку.',
        ),
        const SampleEntry(
          'Подарунок на день народження',
          'Запитати Олену, чи вже хтось купив книгу. Якщо так, обрати сертифікат у книгарню.',
        ),
        SampleEntry(
          'Закупи на вихідні',
          checklist('Список покупок', [
            'Картопля',
            'Сметана',
            'Яблука',
            'Гречка',
          ], checked: 1),
        ),
        const SampleEntry(
          'Підготувати велосипед',
          'Підкачати колеса, змастити ланцюг і перевірити задній ліхтар перед поїздкою.',
        ),
      ]),
      SampleCategory('Рецепти', [
        SampleEntry(
          'Борщ із квасолею',
          numbered('Як готувати', [
            'Замочити квасолю на ніч і зварити до м’якості.',
            'Окремо протушкувати буряк із томатом і ложкою оцту.',
            'Додати картоплю, капусту й засмажку. Дати настоятися 20 хвилин.',
          ]),
        ),
        SampleEntry(
          'Сирники на двох',
          [
            table('Інгредієнти', [
              ['Продукт', 'Кількість'],
              ['Кисломолочний сир', '300 г'],
              ['Яйце', '1 шт.'],
              ['Борошно', '2 ст. л.'],
            ]),
            'Сформувати невеликі сирники й смажити на середньому вогні до золотистої скоринки.',
          ].join('\n'),
        ),
        const SampleEntry(
          'Деруни зі сметаною',
          'Натерти картоплю й половину цибулини. Відтиснути зайвий сік, додати яйце та смажити тонкими порціями.',
        ),
        const SampleEntry(
          'Печені яблука',
          'Вийняти серцевину, додати горіхи й трохи меду. Запікати приблизно 25 хвилин при 180°C.',
        ),
        const SampleEntry(
          'Вареники з вишнями',
          'На кожне кружальце тіста покласти три вишні й дрібку цукру. Варити невеликими порціями.',
        ),
      ]),
      SampleCategory(
        'Навчання',
        [
          const SampleEntry(
            'Як запам’ятовувати матеріал',
            'Спочатку прочитати розділ, потім закрити конспект і переказати основне. Повернутися до складних місць наступного дня.',
          ),
          SampleEntry(
            'Підготовка до семінару',
            checklist('До п’ятниці', [
              'Прочитати розділ 4',
              'Виписати два приклади',
              'Підготувати запитання',
            ], checked: 1),
          ),
          const SampleEntry(
            'Запитання до викладача',
            'Уточнити формат презентації та чи можна використовувати власні дані в прикладі.',
          ),
        ],
        [
          SampleCategory('Англійська мова', [
            SampleEntry(
              'Слова для подорожі',
              table('Слово · переклад · приклад', [
                ['English', 'Українською', 'Example'],
                [
                  'boarding pass',
                  'посадковий талон',
                  'I have my boarding pass on my phone.',
                ],
                ['delay', 'затримка', 'There is a delay of twenty minutes.'],
                ['luggage', 'багаж', 'Can I leave my luggage here?'],
                [
                  'platform',
                  'платформа',
                  'The train leaves from platform four.',
                ],
              ]),
            ),
            SampleEntry(
              'Take, bring чи fetch?',
              table('Коли вживати', [
                ['Слово', 'Значення', 'Приклад'],
                ['take', 'узяти із собою туди', 'Take an umbrella with you.'],
                ['bring', 'принести сюди', 'Can you bring your notebook?'],
                [
                  'fetch',
                  'піти по щось і повернутися',
                  'I’ll fetch some water.',
                ],
              ]),
            ),
            const SampleEntry(
              'Фрази для кав’ярні',
              'Could I have a flat white, please? — Можна флет-вайт, будь ласка?\nIs this for here or to go? — Тут чи з собою?',
            ),
            SampleEntry(
              'Повторення на тиждень',
              checklist('15 хвилин на день', [
                'Понеділок — 10 нових слів',
                'Середа — повторити без підказок',
                'П’ятниця — скласти 5 речень',
              ], checked: 1),
            ),
          ]),
        ],
      ),
      SampleCategory('Подорожі', [
        const SampleEntry(
          'Вихідні у Львові',
          'Зранку прогулятися центром, після обіду — Шевченківський гай. На неділю залишити книгарні й каву.',
        ),
        SampleEntry(
          'Речі в ручну поклажу',
          checklist('Перевірити перед виїздом', [
            'Документи',
            'Навушники',
            'Зарядка',
            'Ліки',
            'Порожня пляшка для води',
          ]),
        ),
        const SampleEntry(
          'Квитки на зворотний потяг',
          'Перевірити рейси після 16:00. Зберегти квиток офлайн і закласти пів години на дорогу до вокзалу.',
        ),
      ]),
      SampleCategory('Дім', const [
        SampleEntry(
          'Що посадити на балконі',
          'Базилік і м’яту залишити в окремих горщиках. Для помідорів вибрати найсонячніше місце.',
        ),
        SampleEntry(
          'Заміри для полиці',
          'Ширина ніші 82 см, глибина 28 см. Залишити невеликий зазор біля розетки.',
        ),
        SampleEntry(
          'План прибирання',
          'У суботу розібрати стіл і протерти кухню. Прання перенести на неділю, щоб встигло висохнути.',
        ),
      ]),
    ],
  ),
];
