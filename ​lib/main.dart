import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CryptoPulseApp());
}

class CryptoPulseApp extends StatefulWidget {
  const CryptoPulseApp({super.key});

  @override
  State<CryptoPulseApp> createState() => _CryptoPulseAppState();
}

class _CryptoPulseAppState extends State<CryptoPulseApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Светлая тема — синий акцент, темная тема — золотой акцент
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A73E8),
        brightness: Brightness.light,
        primary: const Color(0xFF1A73E8),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFEAB308),
        brightness: Brightness.dark,
        primary: const Color(0xFFEAB308),
        surface: const Color(0xFF161B22),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF161B22),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return MaterialApp(
      title: 'CryptoPulse AI',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: HomeScreen(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class CoinModel {
  final String id;
  final String symbol;
  final String name;
  double price;
  double change24h;
  int rank;

  CoinModel({
    required this.id,
    required this.symbol,
    required this.name,
    this.price = 0.0,
    this.change24h = 0.0,
    this.rank = 1,
  });
}

class NewsArticle {
  final String title;
  final String url;
  final String source;
  final String body;
  final String category; // official | media
  final int sentimentDelta;
  final String sentimentLabel;

  NewsArticle({
    required this.title,
    required this.url,
    required this.source,
    required this.body,
    required this.category,
    required this.sentimentDelta,
    required this.sentimentLabel,
  });
}

class HomeScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CoinModel> _coins = [
    CoinModel(id: 'bitcoin', symbol: 'BTC', name: 'Bitcoin', price: 89000, change24h: 1.5, rank: 1),
    CoinModel(id: 'ethereum', symbol: 'ETH', name: 'Ethereum', price: 3100, change24h: 0.9, rank: 2),
    CoinModel(id: 'the-open-network', symbol: 'TON', name: 'Toncoin', price: 5.4, change24h: 2.3, rank: 9),
    CoinModel(id: 'solana', symbol: 'SOL', name: 'Solana', price: 190, change24h: 3.1, rank: 4),
    CoinModel(id: 'binancecoin', symbol: 'BNB', name: 'BNB', price: 640, change24h: -0.4, rank: 5),
    CoinModel(id: 'ripple', symbol: 'XRP', name: 'XRP', price: 1.4, change24h: 1.2, rank: 6),
  ];

  late CoinModel _selectedCoin;
  bool _loading = false;

  // Индикаторы
  double _rsi = 50.0;
  double _ema9 = 0.0;
  double _ema21 = 0.0;
  double _volatilityPct = 3.5;
  double _slopePctPerDay = 0.2;
  int _fearGreed = 55;
  String _fearGreedLabel = 'Neutral';

  // Итоговый сигнал и прогноз
  int _totalScore = 50;
  String _verdict = 'ДЕРЖАТЬ / ОЖИДАНИЕ';
  double _forecast24hPrice = 0.0;
  double _forecast24hPct = 0.0;
  double _forecast7dPrice = 0.0;
  double _forecast7dPct = 0.0;
  double _forecast30dPrice = 0.0;
  double _forecast30dPct = 0.0;

  // Официальные ссылки и новости
  Map<String, String> _officialLinks = {};
  String? _githubRepo;
  String _officialDesc = '';
  List<NewsArticle> _news = [];
  String _newsFilter = 'all';

  static const List<String> _bullWords = [
    'surge', 'soar', 'bull', 'bullish', 'approval', 'approved', 'etf',
    'partnership', 'launch', 'upgrade', 'release', 'mainnet', 'adoption',
    'record', 'high', 'inflow', 'buy', 'accumulate', 'growth', 'rally',
    'breakout', 'institutional', 'integration'
  ];

  static const List<String> _bearWords = [
    'hack', 'hacked', 'exploit', 'vulnerability', 'crash', 'drop', 'plunge',
    'bear', 'bearish', 'ban', 'lawsuit', 'sued', 'sec', 'outflow', 'sell',
    'dump', 'fraud', 'scam', 'delay', 'reject', 'liquidation', 'delist'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCoin = _coins.first;
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCoinId = prefs.getString('selected_coin_id');
    await _loadTop100Coins();
    if (savedCoinId != null) {
      final found = _coins.where((c) => c.id == savedCoinId).toList();
      if (found.isNotEmpty) {
        _selectedCoin = found.first;
      }
    }
    await _loadFearAndGreed();
    await _refreshSelectedCoin();
  }

  Future<void> _loadTop100Coins() async {
    try {
      final res = await http.get(Uri.parse(
          'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          setState(() {
            _coins = data.map((e) => CoinModel(
              id: e['id'] ?? 'bitcoin',
              symbol: (e['symbol'] ?? 'btc').toString().toUpperCase(),
              name: e['name'] ?? 'Bitcoin',
              price: (e['current_price'] as num?)?.toDouble() ?? 0.0,
              change24h: (e['price_change_percentage_24h'] as num?)?.toDouble() ?? 0.0,
              rank: (e['market_cap_rank'] as num?)?.toInt() ?? 99,
            )).toList();
            _selectedCoin = _coins.first;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadFearAndGreed() async {
    try {
      final res = await http.get(Uri.parse('https://api.alternative.me/fng/?limit=1'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final item = data['data']?[0];
        if (item != null) {
          _fearGreed = int.tryParse(item['value'].toString()) ?? 55;
          _fearGreedLabel = item['value_classification'] ?? 'Neutral';
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshSelectedCoin() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_coin_id', _selectedCoin.id);

    await Future.wait([
      _fetchCoinDetailsAndLinks(),
      _fetchIndicators(),
    ]);
    await _fetchOfficialNews();
    _calculateSignalAndForecast();
    await _updateAndroidHomeWidget();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchCoinDetailsAndLinks() async {
    _officialLinks = {};
    _githubRepo = null;
    _officialDesc = '';
    try {
      final res = await http.get(Uri.parse(
          'https://api.coingecko.com/api/v3/coins/${_selectedCoin.id}?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final md = data['market_data'];
        if (md != null) {
          _selectedCoin.price = (md['current_price']?['usd'] as num?)?.toDouble() ?? _selectedCoin.price;
          _selectedCoin.change24h = (md['price_change_percentage_24h'] as num?)?.toDouble() ?? _selectedCoin.change24h;
        }
        final links = data['links'] ?? {};
        if (links['homepage'] is List && (links['homepage'] as List).isNotEmpty && links['homepage'][0].toString().isNotEmpty) {
          _officialLinks['🌐 Сайт'] = links['homepage'][0];
        }
        if (links['whitepaper'] != null && links['whitepaper'].toString().isNotEmpty) {
          _officialLinks['📄 Whitepaper'] = links['whitepaper'];
        }
        if (links['twitter_screen_name'] != null && links['twitter_screen_name'].toString().isNotEmpty) {
          _officialLinks['𝕏 Twitter'] = 'https://x.com/${links['twitter_screen_name']}';
        }
        if (links['telegram_channel_identifier'] != null && links['telegram_channel_identifier'].toString().isNotEmpty) {
          _officialLinks['✈️ Telegram'] = 'https://t.me/${links['telegram_channel_identifier']}';
        }
        if (links['subreddit_url'] != null && links['subreddit_url'].toString().isNotEmpty) {
          _officialLinks['👽 Reddit'] = links['subreddit_url'];
        }
        if (links['repos_url']?['github'] is List && (links['repos_url']['github'] as List).isNotEmpty) {
          final gh = links['repos_url']['github'][0].toString();
          if (gh.isNotEmpty) {
            _officialLinks['💻 GitHub'] = gh;
            final match = RegExp(r'github\.com/([^/]+/[^/]+)').firstMatch(gh);
            if (match != null) {
              _githubRepo = match.group(1)?.replaceAll('.git', '');
            }
          }
        }
        final rawDesc = (data['description']?['en'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '');
        if (rawDesc.isNotEmpty) {
          _officialDesc = rawDesc.length > 260 ? '${rawDesc.substring(0, 260)}...' : rawDesc;
        }
      }
    } catch (_) {}
    if (_officialLinks.isEmpty) {
      _officialLinks['🌐 CoinGecko'] = 'https://www.coingecko.com/en/coins/${_selectedCoin.id}';
    }
  }

  Future<void> _fetchIndicators() async {
    try {
      final res = await http.get(Uri.parse(
          'https://api.coingecko.com/api/v3/coins/${_selectedCoin.id}/market_chart?vs_currency=usd&days=14'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List rawPrices = data['prices'] ?? [];
        final prices = rawPrices.map((e) => (e[1] as num).toDouble()).toList();
        if (prices.length >= 22) {
          _rsi = _calcRSI(prices, 14);
          _ema9 = _calcEMA(prices, 9);
          _ema21 = _calcEMA(prices, 21);
          _volatilityPct = _calcVolatility(prices);
          _slopePctPerDay = _calcLinearSlopePct(prices);
          return;
        }
      }
    } catch (_) {}

    // Резервный расчет по суточному импульсу
    final chg = _selectedCoin.change24h;
    final p = _selectedCoin.price > 0 ? _selectedCoin.price : 100.0;
    _rsi = (50.0 + chg * 2.1).clamp(20.0, 80.0);
    _ema9 = p * (1.0 - (chg / 100.0) * 0.12);
    _ema21 = p * (1.0 - (chg / 100.0) * 0.30);
    _volatilityPct = (chg.abs() * 0.8 + 2.5).clamp(2.0, 14.0);
    _slopePctPerDay = (chg * 0.25).clamp(-5.0, 5.0);
  }

  double _calcRSI(List<double> prices, int period) {
    double gains = 0, losses = 0;
    final slice = prices.sublist(prices.length - period - 1);
    for (int i = 1; i < slice.length; i++) {
      final diff = slice[i] - slice[i - 1];
      if (diff >= 0) {
        gains += diff;
      } else {
        losses -= diff;
      }
    }
    final avgLoss = losses / period;
    if (avgLoss == 0) return 100.0;
    final rs = (gains / period) / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  double _calcEMA(List<double> prices, int period) {
    final k = 2.0 / (period + 1);
    double ema = prices.first;
    for (int i = 1; i < prices.length; i++) {
      ema = prices[i] * k + ema * (1.0 - k);
    }
    return ema;
  }

  double _calcVolatility(List<double> prices) {
    final recent = prices.length > 24 ? prices.sublist(prices.length - 24) : prices;
    final minP = recent.reduce(min);
    final maxP = recent.reduce(max);
    if (minP <= 0) return 3.5;
    return (((maxP - minP) / minP) * 100.0).clamp(1.5, 16.0);
  }

  double _calcLinearSlopePct(List<double> prices) {
    final n = prices.length;
    if (n < 5) return 0.0;
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += prices[i];
      sumXY += i * prices[i];
      sumXX += i * i;
    }
    final slopePerPoint = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    final pointsPerDay = n / 14.0;
    final lastPrice = prices.last > 0 ? prices.last : 1.0;
    return (((slopePerPoint * pointsPerDay) / lastPrice) * 100.0).clamp(-5.0, 5.0);
  }

  Future<void> _fetchOfficialNews() async {
    final List<NewsArticle> gathered = [];
    final sym = _selectedCoin.symbol.toUpperCase();

    // 1. Официальные релизы GitHub монеты
    if (_githubRepo != null) {
      try {
        final ghRes = await http.get(
            Uri.parse('https://api.github.com/repos/$_githubRepo/releases?per_page=3'));
        if (ghRes.statusCode == 200) {
          final List releases = jsonDecode(ghRes.body);
          for (final r in releases) {
            final title = '[Официальный релиз $sym] ${r['name'] ?? r['tag_name'] ?? 'Update'}';
            final body = (r['body'] ?? 'Официальное обновление исходного кода протокола.')
                .toString()
                .replaceAll(RegExp(r'[#*`]'), '');
            final sent = _evalSentiment('$title $body');
            gathered.add(NewsArticle(
              title: title,
              url: r['html_url'] ?? 'https://github.com/$_githubRepo',
              source: 'GitHub Official ($_githubRepo)',
              body: body.length > 180 ? '${body.substring(0, 180)}...' : body,
              category: 'official',
              sentimentDelta: sent.key,
              sentimentLabel: sent.value,
            ));
          }
        }
      } catch (_) {}
    }

    // 2. Новости по тикеру из CryptoCompare
    try {
      final ccRes = await http.get(Uri.parse(
          'https://min-api.cryptocompare.com/data/v2/news/?categories=$sym&lang=EN'));
      if (ccRes.statusCode == 200) {
        final data = jsonDecode(ccRes.body);
        final List items = data['Data'] ?? [];
        for (final item in items.take(8)) {
          final title = (item['title'] ?? '').toString();
          final body = (item['body'] ?? '').toString();
          final sent = _evalSentiment('$title $body');
          gathered.add(NewsArticle(
            title: title,
            url: item['url'] ?? 'https://www.coingecko.com',
            source: item['source_info']?['name'] ?? item['source'] ?? 'Crypto Media',
            body: body.length > 180 ? '${body.substring(0, 180)}...' : body,
            category: 'media',
            sentimentDelta: sent.key,
            sentimentLabel: sent.value,
          ));
        }
      }
    } catch (_) {}

    // 3. Официальная документация проекта
    if (_officialDesc.isNotEmpty) {
      final sent = _evalSentiment(_officialDesc);
      gathered.insert(
        0,
        NewsArticle(
          title: '${_selectedCoin.name} ($sym) — Официальная архитектура и документация',
          url: 'https://www.coingecko.com/en/coins/${_selectedCoin.id}',
          source: '${_selectedCoin.name} Official',
          body: _officialDesc,
          category: 'official',
          sentimentDelta: sent.key,
          sentimentLabel: sent.value,
        ),
      );
    }

    _news = gathered;
  }

  MapEntry<int, String> _evalSentiment(String text) {
    final lower = text.toLowerCase();
    int score = 0;
    for (final w in _bullWords) {
      if (lower.contains(w)) score += 1;
    }
    for (final w in _bearWords) {
      if (lower.contains(w)) score -= 1;
    }
    if (score > 0) return MapEntry(score, 'Бычий (Позитив)');
    if (score < 0) return MapEntry(score, 'Медвежий (Риск)');
    return const MapEntry(0, 'Нейтрально');
  }

  void _calculateSignalAndForecast() {
    double techDelta = 0;
    if (_rsi < 32) {
      techDelta += 14;
    } else if (_rsi > 68) {
      techDelta -= 14;
    } else {
      techDelta += (50 - _rsi) * 0.2;
    }

    if (_ema9 >= _ema21) {
      techDelta += 12;
    } else {
      techDelta -= 12;
    }

    int newsDelta = 0;
    for (final n in _news) {
      newsDelta += n.sentimentDelta * 6;
    }
    newsDelta = newsDelta.clamp(-25, 25);

    final momentumDelta = (_selectedCoin.change24h * 1.5).clamp(-12.0, 12.0);
    _totalScore = (50 + newsDelta + techDelta + momentumDelta).round().clamp(5, 95);

    if (_totalScore >= 68) {
      _verdict = 'АКТИВНО ПОКУПАТЬ';
    } else if (_totalScore >= 56) {
      _verdict = 'ПОКУПАТЬ (ЛОНГ)';
    } else if (_totalScore <= 32) {
      _verdict = 'АКТИВНО ПРОДАВАТЬ';
    } else if (_totalScore <= 44) {
      _verdict = 'ПРОДАВАТЬ (ШОРТ)';
    } else {
      _verdict = 'ДЕРЖАТЬ / ОЖИДАНИЕ';
    }

    final price = _selectedCoin.price;
    final signalBias = (_totalScore - 50) / 50.0;
    final dailyDriftPct = (_slopePctPerDay * 0.45) + (signalBias * _volatilityPct * 0.35);

    _forecast24hPct = dailyDriftPct.clamp(-18.0, 18.0);
    _forecast7dPct = (dailyDriftPct * 4.2).clamp(-45.0, 55.0);
    _forecast30dPct = (dailyDriftPct * 11.5).clamp(-75.0, 120.0);

    _forecast24hPrice = price * (1.0 + _forecast24hPct / 100.0);
    _forecast7dPrice = price * (1.0 + _forecast7dPct / 100.0);
    _forecast30dPrice = price * (1.0 + _forecast30dPct / 100.0);
  }

  // ПЕРЕДАЧА ДАННЫХ В НАТИВНЫЙ ВИДЖЕТ РАБОЧЕГО СТОЛА ANDROID
  Future<void> _updateAndroidHomeWidget() async {
    try {
      final pDigits = _selectedCoin.price < 1 ? 4 : 2;
      final priceStr = '\$${_selectedCoin.price.toStringAsFixed(pDigits)} (${_selectedCoin.change24h >= 0 ? '+' : ''}${_selectedCoin.change24h.toStringAsFixed(2)}%)';
      final fcStr = 'Прогноз 24ч: \$${_forecast24hPrice.toStringAsFixed(pDigits)} | 7д: \$${_forecast7dPrice.toStringAsFixed(pDigits)} (${_forecast7dPct >= 0 ? '+' : ''}${_forecast7dPct.toStringAsFixed(1)}%)';

      await HomeWidget.saveWidgetData<String>('coin_name', '${_selectedCoin.name} (${_selectedCoin.symbol})');
      await HomeWidget.saveWidgetData<String>('coin_price', priceStr);
      await HomeWidget.saveWidgetData<String>('signal_verdict', '$_verdict ($_totalScore/100)');
      await HomeWidget.saveWidgetData<String>('forecast_text', fcStr);
      await HomeWidget.updateWidget(
        name: 'CryptoWidgetProvider',
        androidName: 'CryptoWidgetProvider',
      );
    } catch (_) {}
  }

  String _fmtPrice(double val) {
    if (val < 1.0) return '\$${val.toStringAsFixed(5)}';
    return '\$${val.toStringAsFixed(2)}';
  }

  void _openSearchCoinModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CoinSearchSheet(
        initialCoins: _coins,
        onSelect: (coin) {
          Navigator.pop(ctx);
          setState(() {
            if (!_coins.any((c) => c.id == coin.id)) {
              _coins.insert(0, coin);
            }
            _selectedCoin = coin;
          });
          _refreshSelectedCoin();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isBuy = _totalScore >= 56;
    final isSell = _totalScore <= 44;
    final signalColor = isBuy
        ? const Color(0xFF22C55E)
        : (isSell ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    final filteredNews = _newsFilter == 'all'
        ? _news
        : _news.where((n) => n.category == _newsFilter).toList();

    final slPrice = _selectedCoin.price * (1.0 - max(2.0, _volatilityPct * 0.75) / 100.0);
    final tpPrice = _selectedCoin.price * (1.0 + max(4.0, _volatilityPct * 1.6) / 100.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CryptoPulse AI', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Поиск любой монеты (15 000+)',
            icon: const Icon(Icons.search),
            onPressed: _openSearchCoinModal,
          ),
          IconButton(
            tooltip: 'Обновить виджет на рабочем столе',
            icon: const Icon(Icons.widgets_outlined),
            onPressed: () async {
              await _updateAndroidHomeWidget();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Виджет Android обновлен для ${_selectedCoin.symbol}! Добавьте его через меню виджетов рабочего стола.',
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(widget.isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSelectedCoin,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Горизонтальный выбор монет
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _coins.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final c = _coins[i];
                  final selected = c.id == _selectedCoin.id;
                  return ChoiceChip(
                    label: Text('${c.symbol} • ${c.name}'),
                    selected: selected,
                    selectedColor: cs.primary.withOpacity(0.22),
                    onSelected: (_) {
                      setState(() => _selectedCoin = c);
                      _refreshSelectedCoin();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),

            // 1. Карточка монеты и официальных ресурсов
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedCoin.name} (${_selectedCoin.symbol})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text('Rank #${_selectedCoin.rank}',
                            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _fmtPrice(_selectedCoin.price),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_selectedCoin.change24h >= 0 ? Colors.green : Colors.red)
                                .withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_selectedCoin.change24h >= 0 ? '+' : ''}${_selectedCoin.change24h.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: _selectedCoin.change24h >= 0 ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _officialLinks.entries.map((e) {
                        return ActionChip(
                          label: Text(e.key, style: const TextStyle(fontSize: 12)),
                          onPressed: () => launchUrl(Uri.parse(e.value), mode: LaunchMode.externalApplication),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Индикатор сигнала ПОКУПАТЬ / ПРОДАВАТЬ
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ИНДИКАТОР АНАЛИЗА',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Счет: $_totalScore / 100',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: signalColor.withOpacity(0.15),
                        border: Border.all(color: signalColor, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _verdict,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: signalColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RSI(14): ${_rsi.toStringAsFixed(1)} • Тренд: ${_ema9 >= _ema21 ? "Бычий (EMA9>EMA21)" : "Медвежий (EMA9<EMA21)"}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildLevelBox('Вход', _fmtPrice(_selectedCoin.price), Colors.grey),
                        const SizedBox(width: 8),
                        _buildLevelBox('Stop-Loss', _fmtPrice(slPrice), Colors.redAccent),
                        const SizedBox(width: 8),
                        _buildLevelBox('Take-Profit', _fmtPrice(tpPrice), Colors.greenAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 3. Прогноз курса на будущее (24ч, 7д, 30д)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📈 ПРОГНОЗ КУРСА НА БУДУЩЕЕ (РЕГРЕССИЯ + ИНДИКАТОРЫ)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildForecastCard('Через 24ч', _forecast24hPrice, _forecast24hPct),
                        const SizedBox(width: 8),
                        _buildForecastCard('Через 7 дней', _forecast7dPrice, _forecast7dPct),
                        const SizedBox(width: 8),
                        _buildForecastCard('Через 30 дней', _forecast30dPrice, _forecast30dPct),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_to_home_screen),
                        label: Text('Закрепить ${_selectedCoin.symbol} в виджете Android'),
                        onPressed: () async {
                          await _updateAndroidHomeWidget();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Данные ${_selectedCoin.symbol} отправлены в виджет! Зажмите пустое место на рабочем столе Android -> Виджеты -> CryptoPulse.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Технические индикаторы
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ТЕХНИЧЕСКИЕ ИНДИКАТОРЫ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildIndTile('RSI (14)', _rsi.toStringAsFixed(1),
                            _rsi < 32 ? 'Перепродан' : (_rsi > 68 ? 'Перекуплен' : 'Норма')),
                        const SizedBox(width: 8),
                        _buildIndTile('EMA (9/21)', _ema9 >= _ema21 ? 'Бычий 📈' : 'Медвежий 📉',
                            'Пересечение'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildIndTile('Волатильность', '±${_volatilityPct.toStringAsFixed(2)}%', 'ATR 24ч'),
                        const SizedBox(width: 8),
                        _buildIndTile('Страх/Жадность', '$_fearGreed / 100', _fearGreedLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 5. Официальные новости и релизы
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ОФИЦИАЛЬНЫЕ НОВОСТИ И РЕЛИЗЫ (${_selectedCoin.symbol})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('Все', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'official', label: Text('Офиц. / GitHub', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'media', label: Text('СМИ', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {_newsFilter},
                      onSelectionChanged: (s) => setState(() => _newsFilter = s.first),
                    ),
                    const SizedBox(height: 12),
                    if (filteredNews.isEmpty)
                      const Text('Нет публикаций в выбранной вкладке.'),
                    ...filteredNews.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => launchUrl(Uri.parse(n.url), mode: LaunchMode.externalApplication),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withOpacity(0.25)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          n.source,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: cs.primary),
                                        ),
                                      ),
                                      Text(
                                        n.sentimentLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: n.sentimentDelta > 0
                                              ? Colors.green
                                              : (n.sentimentDelta < 0 ? Colors.red : Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(n.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(n.body, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBox(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastCard(String horizon, double price, double pct) {
    final isUp = pct >= 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(horizon, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(_fmtPrice(price),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 2),
            Text(
              '${isUp ? '+' : ''}${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUp ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndTile(String title, String val, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// Поиск по всем 15 000+ монетам CoinGecko
class _CoinSearchSheet extends StatefulWidget {
  final List<CoinModel> initialCoins;
  final ValueChanged<CoinModel> onSelect;

  const _CoinSearchSheet({required this.initialCoins, required this.onSelect});

  @override
  State<_CoinSearchSheet> createState() => _CoinSearchSheetState();
}

class _CoinSearchSheetState extends State<_CoinSearchSheet> {
  List<CoinModel> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _results = widget.initialCoins;
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = widget.initialCoins);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final res = await http.get(Uri.parse(
            'https://api.coingecko.com/api/v3/search?query=${Uri.encodeComponent(q.trim())}'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final List coins = data['coins'] ?? [];
          setState(() {
            _results = coins.take(30).map((c) => CoinModel(
              id: c['id'],
              symbol: (c['symbol'] ?? '').toString().toUpperCase(),
              name: c['name'] ?? '',
              rank: (c['market_cap_rank'] as num?)?.toInt() ?? 999,
            )).toList();
          });
        }
      } catch (_) {}
      if (mounted) setState(() => _searching = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Введите название или тикер (BTC, TON, Kaspa, Pepe...)',
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearch,
            ),
            if (_searching) const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final c = _results[i];
                  return ListTile(
                    title: Text('${c.symbol} — ${c.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('#${c.rank}'),
                    onTap: () => widget.onSelect(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

