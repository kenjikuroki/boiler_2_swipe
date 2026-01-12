import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:google_fonts/google_fonts.dart'; // フォント追加
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:convert';
import 'widgets/ad_banner.dart';
import 'utils/ad_manager.dart';
import 'package:in_app_review/in_app_review.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  


  

  
  // 画面の向きを縦に固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// 1. Data Models & Helpers
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// 1. Data Models & Helpers
// -----------------------------------------------------------------------------
class Quiz {
  final String question;
  final bool isCorrect;
  final String explanation;
  final String? imagePath;

  Quiz({
    required this.question,
    required this.isCorrect,
    required this.explanation,
    this.imagePath,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      question: (json['question'] as String).replaceAll('\n', ''),
      isCorrect: json['isCorrect'] as bool,
      explanation: json['explanation'] as String,
      imagePath: json['imagePath'] as String?,
    );
  }
}

class PrefsHelper {
  static const String _keyWeakQuestions = 'weak_questions';
  static const String _keyAdCounter = 'ad_counter';
  static const String _keyQuizCompletionCount = 'quiz_completion_count';
  static const String _keyHasRequestedReview = 'has_requested_review';

  // インタースティシャル広告の表示判定 (3回に1回表示)
  static Future<bool> shouldShowInterstitial() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyAdCounter) ?? 0;
    current++;
    await prefs.setInt(_keyAdCounter, current);
    
    // 3回に1回表示 (1, 2, [3], 4, 5, [6]...)
    return (current % 3 == 0);
  }
  
  // ハイスコア保存 (Key: 'highscore_part1', etc.)
  static Future<void> saveHighScore(String categoryKey, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getInt(categoryKey) ?? 0;
    if (score > currentHigh) {
      await prefs.setInt(categoryKey, score);
    }
  }

  static Future<int> getHighScore(String categoryKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(categoryKey) ?? 0;
  }

  // 苦手リスト追加 (既に存在すれば追加しない)
  static Future<void> addWeakQuestions(List<String> questions) async {
    if (questions.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyWeakQuestions) ?? [];
    
    bool changed = false;
    for (final q in questions) {
      if (!current.contains(q)) {
        current.add(q);
        changed = true;
      }
    }
    
    if (changed) {
      await prefs.setStringList(_keyWeakQuestions, current);
    }
  }

  // 苦手リストから削除 (正解した場合など)
  static Future<void> removeWeakQuestions(List<String> questions) async {
    if (questions.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyWeakQuestions) ?? [];
    
    bool changed = false;
    for (final q in questions) {
       if (current.remove(q)) {
         changed = true;
       }
    }
    
    if (changed) {
      await prefs.setStringList(_keyWeakQuestions, current);
    }
  }

  // 苦手リスト取得
  // 苦手リスト取得
  static Future<List<String>> getWeakQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyWeakQuestions) ?? [];
  }

  // クイズ完了数をインクリメントし、レビューリクエストすべきか判定
  // 初回のみ、3回完了時に true を返す
  static Future<bool> incrementCompletionCountAndCheckReview() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 既にレビュー依頼済みなら false
    if (prefs.getBool(_keyHasRequestedReview) ?? false) {
      return false;
    }

    int count = (prefs.getInt(_keyQuizCompletionCount) ?? 0) + 1;
    await prefs.setInt(_keyQuizCompletionCount, count);

    if (count == 3) {
      await prefs.setBool(_keyHasRequestedReview, true);
      return true;
    }
    
    return false;
  }
}

class QuizData {
  static Map<String, List<Quiz>> _data = {};

  // アプリ起動時などに呼び出してデータをロードする
  static Future<void> load() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/quiz_data.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      _data = {};
      jsonData.forEach((key, value) {
        if (value is List) {
          _data[key] = value.map((q) => Quiz.fromJson(q)).toList();
        }
      });
    } catch (e) {
      debugPrint("Error loading quiz data: $e");
      // エラー時は空っぽなどで落ちないようにする
      _data = {};
    }
  }

  static List<Quiz> get part1 => _data['part1'] ?? [];
  static List<Quiz> get part2 => _data['part2'] ?? [];
  static List<Quiz> get part3 => _data['part3'] ?? [];
  static List<Quiz> get part4 => _data['part4'] ?? [];

  // 全問題からテキストで検索してQuizオブジェクトを返すユーティリティ
  static List<Quiz> getQuizzesFromTexts(List<String> texts) {
    // 全ロード済みリストを結合
    final allQuizzes = [
      ...part1,
      ...part2,
      ...part3,
    ];
    return allQuizzes.where((q) => texts.contains(q.question)).toList();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2級ボイラー',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        // アプリ全体のフォントを M PLUS Rounded 1c に変更
        textTheme: GoogleFonts.mPlusRounded1cTextTheme(
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Home Page
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _highScore1 = 0;
  int _highScore2 = 0;
  int _highScore3 = 0;
  int _weaknessCount = 0;
  bool _isLoading = true; // ローディング状態

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // 1. UI描画完了後、少し待ってからダイアログを表示する (ATT対策)
    await Future.delayed(const Duration(milliseconds: 1000));
    // 2. 同意フローの初期化 (完了を待つ)
    await AdManager.instance.initializeConsent();
    // 3. Mobile Ads SDKの初期化 & 広告ロード
    await MobileAds.instance.initialize();
    AdManager.instance.preloadAd('home');

    // データ初期ロード
    await QuizData.load();
    await _loadUserData();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadUserData() async {
    final s1 = await PrefsHelper.getHighScore('highscore_part1');
    final s2 = await PrefsHelper.getHighScore('highscore_part2');
    final s3 = await PrefsHelper.getHighScore('highscore_part3');
    final weakList = await PrefsHelper.getWeakQuestions();

    // 現在のクイズデータに存在する問題のみをカウントする（旧バージョンのデータを除外）
    final validWeakQuizzes = QuizData.getQuizzesFromTexts(weakList);

    if (mounted) {
      setState(() {
        _highScore1 = s1;
        _highScore2 = s2;
        _highScore3 = s3;
        _weaknessCount = validWeakQuizzes.length;
      });
    }
  }

  void _startQuiz(BuildContext context, List<Quiz> quizList, String categoryKey, {bool isRandom10 = true}) async {
    List<Quiz> questionsToUse = List<Quiz>.from(quizList);
    
    if (isRandom10) {
      questionsToUse.shuffle();
      if (questionsToUse.length > 10) {
        questionsToUse = questionsToUse.take(10).toList();
      }
    } else {
      // isRandom10 = false の場合はそのまま（現状の仕様では基本trueで呼ぶ）
      questionsToUse.shuffle();
    }
    
    // クイズ開始時に結果画面用の広告とインタースティシャル広告を先行読み込み
    AdManager.instance.preloadAd('result');
    AdManager.instance.preloadInterstitial();
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: questionsToUse,
          categoryKey: categoryKey,
          totalQuestions: isRandom10 ? 10 : questionsToUse.length, // totalQuestionsを渡す
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData(); // 戻ってきたらデータ更新
  }

  void _startWeaknessReview(BuildContext context) async {
    // Navigatorを先に取得してGap回避
    final navigator = Navigator.of(context);
    
    final weakTexts = await PrefsHelper.getWeakQuestions();
    if (!mounted) return;
    if (weakTexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("苦手な問題はまだありません")),
      );
      return;
    }

    final weakQuizzes = QuizData.getQuizzesFromTexts(weakTexts);
    
    // 復習モード開始
    AdManager.instance.preloadAd('result');
    AdManager.instance.preloadInterstitial();

    await navigator.push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: weakQuizzes,
          isWeaknessReview: true, // 復習モードフラグ
          totalQuestions: weakQuizzes.length,
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData(); // 戻ってきたらデータ更新
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 画面の中身 (body:)
    return Scaffold(
      backgroundColor: Colors.orange.shade50, // 1. 全体の背景色を薄いオレンジに
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 140, // 高さ調整
        title: Column(
          children: const [
             SizedBox(height: 20), // 上部間隔
             Text(
              '爆速',
              style: TextStyle(
                color: Colors.deepOrange, // ブランドカラーで強調
                fontWeight: FontWeight.bold,
                fontSize: 64, // さらに巨大化
                height: 1.0,
                letterSpacing: 4.0, // 文字間隔を広げて勢いを出す
                shadows: [
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4.0,
                    color: Colors.black12,
                  ),
                ],
              ),
            ),
             SizedBox(height: 8),
            Text(
              '2級ボイラー技士',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 24, // サブタイトルも大きく
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 40),
              
              // Part1: 構造
              _buildMenuButton(context, '1. ボイラーの構造', 'part1', Icons.settings),
              const SizedBox(height: 16),
              
              // Part2: 取扱い
              _buildMenuButton(context, '2. ボイラーの取扱い', 'part2', Icons.speed),
              const SizedBox(height: 16),
              
              // Part3: 燃料・燃焼
              _buildMenuButton(context, '3. 燃料および燃焼', 'part3', Icons.local_fire_department),
              const SizedBox(height: 16),
              
              // Part4: 関係法令
              _buildMenuButton(context, '4. 関係法令', 'part4', Icons.gavel),
              const SizedBox(height: 40),

               // 苦手克服ボタン (常に表示)
              SizedBox(
                  width: double.infinity,
                  height: 60, // 高さを揃えるか、目立たせるために少し大きくする
                  child: ElevatedButton.icon(
                    onPressed: () => _startWeaknessReview(context),
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    label: Text("苦手を復習する ($_weaknessCount問)"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // バナー広告
              const SizedBox(height: 20),
              const AdBanner(adKey: 'home'),
              const SizedBox(height: 20), // 下部パディング確保
            ],
          ),
        ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, String partKey, IconData icon) {
    return SizedBox(
      height: 70, // 高さ: 70px程度
      width: double.infinity, // 横幅いっぱい
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white, // 白い背景
          foregroundColor: Colors.black87,
          surfaceTintColor: Colors.white, // M3で色がつくのを防ぐ
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // 角丸
          ),
          elevation: 2, // 軽く浮き上がらせる
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: () {
          List<Quiz> quizzes;
          String highScoreKey;
          switch (partKey) {
            case 'part1':
              quizzes = QuizData.part1;
              highScoreKey = 'highscore_part1';
              break;
            case 'part2':
              quizzes = QuizData.part2;
              highScoreKey = 'highscore_part2';
              break;
            case 'part3':
              quizzes = QuizData.part3;
              highScoreKey = 'highscore_part3';
              break;
            case 'part4':
              quizzes = QuizData.part4;
              highScoreKey = 'highscore_part4';
              break;
            default:
              quizzes = [];
              highScoreKey = '';
          }

          if (quizzes.isNotEmpty) {
            _startQuiz(context, quizzes, highScoreKey);
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("問題データがありません")),
            );
          }
        },
        child: Row(
          children: [
            Icon(icon, color: Colors.deepOrange, size: 28), // アイコン
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey), // 右矢印
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Quiz Page
// -----------------------------------------------------------------------------

class QuizPage extends StatefulWidget {
  final List<Quiz> quizzes;
  final String? categoryKey; // ハイスコア保存用Key (復習モードの時はnull)
  final bool isWeaknessReview; // 復習モードかどうか
  final int totalQuestions; // 全問題数（分母）

  const QuizPage({
    super.key,
    required this.quizzes,
    this.categoryKey,
    this.isWeaknessReview = false,
    required this.totalQuestions,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final AppinioSwiperController controller = AppinioSwiperController();
  
  // スコア・履歴管理
  // スコア・履歴管理
  int _score = 0;
  int _currentIndex = 1; // 現在の問題番号
  final List<Quiz> _incorrectQuizzes = [];
  final List<Quiz> _correctQuizzesInReview = []; // 復習モードで正解した問題
  final List<Map<String, dynamic>> _answerHistory = [];

  // 背景色のアニメーション用
  Color _backgroundColor = const Color(0xFFF9F9F9);

  void _handleSwipeEnd(int previousIndex, int targetIndex, SwiperActivity activity) {
    if (activity is Swipe) {
      final quiz = widget.quizzes[previousIndex];
      bool userVal = (activity.direction == AxisDirection.right);
      bool isCorrect = (userVal == quiz.isCorrect);

      // 履歴保存
      _answerHistory.add({
        'quiz': quiz,
        'result': isCorrect,
      });

      setState(() {
        if (isCorrect) {
          _score++;
          _backgroundColor = Colors.green.withValues(alpha: 0.2);
          HapticFeedback.lightImpact();
          
          if (widget.isWeaknessReview) {
            _correctQuizzesInReview.add(quiz);
          }
        } else {
          _backgroundColor = Colors.red.withValues(alpha: 0.2);
          _incorrectQuizzes.add(quiz);
          HapticFeedback.heavyImpact();
        }
      });

      // 0.2秒後に背景を戻す
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _backgroundColor = const Color(0xFFF9F9F9);
          });
        }
      });

      // SnackBar
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 600),
          content: Text(
            isCorrect ? "正解！ ⭕" : "不正解... ❌",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: isCorrect ? Colors.green : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.5,
            left: 50,
            right: 50,
          ),
        ),
      );

      setState(() {
         // インデックスを進める（上限キャップ）
        if (_currentIndex < widget.totalQuestions) {
          _currentIndex++;
        }
      });

      // 全問終了チェック
      if (previousIndex == widget.quizzes.length - 1) {
        _finishQuiz();
      }
    }
  }

  Future<void> _finishQuiz() async {
    // データの永続化処理
    
    // 1. ハイスコア保存
    if (widget.categoryKey != null) {
      await PrefsHelper.saveHighScore(widget.categoryKey!, _score);
    }

    // 2. 苦手リストへの追加
    if (_incorrectQuizzes.isNotEmpty) {
      final incorrectTexts = _incorrectQuizzes.map((q) => q.question).toList();
      await PrefsHelper.addWeakQuestions(incorrectTexts);
    }

    // 3. 復習モードの場合、正解した問題を苦手リストから削除
    if (widget.isWeaknessReview && _correctQuizzesInReview.isNotEmpty) {
      final correctTexts = _correctQuizzesInReview.map((q) => q.question).toList();
      await PrefsHelper.removeWeakQuestions(correctTexts);
    }
    
    // 画面遷移
    // 画面遷移（3回に1回インタースティシャル広告を表示してから）
    if (mounted) {
      // 3回完了時のレビューリクエスト (ポップアップ)
      // インタースティシャル広告の前に表示する
      final bool shouldRequestReview = await PrefsHelper.incrementCompletionCountAndCheckReview();
      if (shouldRequestReview) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
        }
      }

      final shouldShow = await PrefsHelper.shouldShowInterstitial();
      
      if (shouldShow) {
        AdManager.instance.showInterstitial(
          onComplete: () {
            if (mounted) {
              _navigateToResult();
            }
          },
        );
      } else {
        _navigateToResult();
      }
    }
  }

  void _navigateToResult() {
    Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ResultPage(
                  score: _score,
                  total: widget.quizzes.length,
                  history: _answerHistory,
                  incorrectQuizzes: _incorrectQuizzes,
                  originalQuizzes: widget.quizzes,
                  categoryKey: widget.categoryKey,
                  isWeaknessReview: widget.isWeaknessReview,
                ),
              ),
            );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // プログレスバーをAppBarのタイトルとして配置する案もアリだが、
        // ユーザー指定「UIの上部（カードの上）」に従い、Bodyに配置する形にするためAppBarはシンプルに
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true, 
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: _backgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              // プログレスバーエリア
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "第$_currentIndex問",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "$_currentIndex / ${widget.totalQuestions}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _currentIndex / widget.totalQuestions,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppinioSwiper(
                  controller: controller,
                  cardCount: widget.quizzes.length,
                  loop: false,
                  backgroundCardCount: 2,
                  swipeOptions: const SwipeOptions.symmetric(horizontal: true, vertical: false),
                  onSwipeEnd: _handleSwipeEnd,
                  cardBuilder: (context, index) {
                    return _buildCard(widget.quizzes[index]);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.only(bottom: 40, top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        controller.unswipe();
                        setState(() {
                          if (_currentIndex > 1) {
                            _currentIndex--;
                          }
                          // 履歴とスコアのロールバック
                          if (_answerHistory.isNotEmpty) {
                            final last = _answerHistory.removeLast();
                            final bool wasCorrect = last['result'];
                            final Quiz quiz = last['quiz'];
                            
                            if (wasCorrect) {
                              _score--;
                              if (widget.isWeaknessReview) {
                                _correctQuizzesInReview.remove(quiz);
                              }
                            } else {
                              _incorrectQuizzes.remove(quiz);
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text("元に戻す"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Quiz quiz) {
    bool hasImage = quiz.imagePath != null;

    return Container(
      margin: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          if (hasImage) 
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: Image.asset(
                  quiz.imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text("Image not found", style: TextStyle(color: Colors.grey[600])),
                      ],
                    );
                  },
                ),
              ),
            )
          else 
            const Spacer(flex: 2),

          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           if (!hasImage)
                            const Text(
                              "Q.",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          if (!hasImage) const SizedBox(height: 20),

                          Text(
                            quiz.question,
                            style: TextStyle(
                              fontSize: hasImage ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
           const Padding(
            padding: EdgeInsets.only(left: 40.0, right: 40.0, bottom: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Icon(Icons.close, color: Colors.redAccent, size: 48),
                    Text("誤り", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.circle_outlined, color: Colors.green, size: 48),
                    Text("正しい", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          
          if (hasImage) const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Result Page
// -----------------------------------------------------------------------------

class ResultPage extends StatelessWidget {
  final int score;
  final int total;
  final List<Map<String, dynamic>> history;
  final List<Quiz> incorrectQuizzes;
  final List<Quiz> originalQuizzes;
  final String? categoryKey;
  final bool isWeaknessReview;

  const ResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.history,
    required this.incorrectQuizzes,
    required this.originalQuizzes,
    this.categoryKey,
    required this.isWeaknessReview,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("結果発表"),
        centerTitle: true,
        automaticallyImplyLeading: false, 
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "正解数",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                Text(
                  "$score / $total",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
                ),
                // 10問テストの判定コメント
                if (!isWeaknessReview && total >= 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      score >= 8 ? "合格圏内！素晴らしい！" : "あと少し！復習しよう",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: score >= 8 ? Colors.green : Colors.red,
                      ),
                    ),
                  )
                else if (score == total)
                   const Text(
                    "PERFECT! 🎉",
                    style: TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                
                if (isWeaknessReview && score > 0)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Text(
                      "$score個の苦手を克服しました！",
                      style: const TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                       ),
                   ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final Quiz quiz = item['quiz'];
                final bool isCorrect = item['result'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? Colors.green : Colors.red,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quiz.question,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  if (quiz.imagePath != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          Icon(Icons.image, size: 16, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text("画像問題", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "💡 ${quiz.explanation}",
                            style: TextStyle(color: Colors.blueGrey[700], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // バナー広告
          const AdBanner(adKey: 'result'),
          
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (incorrectQuizzes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (context) => QuizPage(
                                  quizzes: incorrectQuizzes,
                                  // 復習後の続けて復習は、ハイスコアモードではなく、かつ既に苦手克服ロジックが走った後なので
                                  // 実質「ただの復習」だが、ここでは simple に扱う。
                                  isWeaknessReview: true, 
                                  totalQuestions: incorrectQuizzes.length, // 残り全問
                                ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("苦手な問題だけ復習"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isWeaknessReview) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        return;
                      }

                      final shuffledAgain = List<Quiz>.from(originalQuizzes)..shuffle();
                       Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => QuizPage(
                            quizzes: shuffledAgain,
                            categoryKey: categoryKey,
                            totalQuestions: shuffledAgain.length, // シャッフルして同じ問題数
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                      elevation: 0,
                      side: const BorderSide(color: Colors.blueAccent, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: Text(isWeaknessReview ? "ホームに戻る" : "もう一度やる（シャッフル）"),
                  ),
                ),
                
                if (!isWeaknessReview) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text("ホームに戻る", style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
