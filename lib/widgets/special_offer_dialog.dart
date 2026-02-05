import 'package:flutter/material.dart';
import '../utils/purchase_manager.dart';

class SpecialOfferDialog extends StatelessWidget {
  const SpecialOfferDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SpecialOfferDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Area with Gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFDE047), // Yellow 300
                    Color(0xFFFACC15), // Yellow 400
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    child: const Text(
                      '限 定 オ フ ァ ー',
                      style: TextStyle(
                        color: Color(0xFF854D0E), // 濃いブラウン
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF854D0E), // 濃いブラウン
                    size: 48,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  const Text(
                    'プレミアムをお得に',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '今だけ！広告を完全に非表示にする\nプレミアム機能を特別価格で提供中です。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Price Comparison
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3), // 非常に薄い黄色
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¥390',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF9CA3AF),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward_rounded, color: Color(0xFFEAB308), size: 20),
                        ),
                        const Text(
                          '¥190',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF854D0E), // 濃いブラウン
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Buy Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        PurchaseManager.instance.buyUnlockB();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFACC15), // 黄色
                        foregroundColor: const Color(0xFF854D0E), // 濃いブラウン
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        '今すぐアップグレード',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '後で検討する',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
