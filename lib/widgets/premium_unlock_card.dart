import 'package:flutter/material.dart';
import '../utils/purchase_manager.dart';

class PremiumUnlockCard extends StatelessWidget {
  const PremiumUnlockCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PurchaseManager.instance.isPremium,
      builder: (context, isPremium, child) {
        if (isPremium) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFDE047), // 黄色 (Yellow 300)
                Color(0xFFFACC15), // 黄色 (Yellow 400)
                Color(0xFFEAB308), // ゴールド (Yellow 600)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEAB308).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.5),
                blurRadius: 0,
                offset: const Offset(0, -2),
                spreadRadius: -1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => PurchaseManager.instance.buyUnlockB(),
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                   // 背景の装飾アイコン
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.star,
                      size: 120,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                    child: Row(
                      children: [
                        // アイコンコンテナ
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFF854D0E), // 濃いブラウン
                            size: 24, // 小さく
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'プレミアムアップグレード',
                                style: TextStyle(
                                  color: Color(0xFF854D0E), // 濃いブラウン
                                  fontSize: 18, // 小さく
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '広告を完全に非表示にして、\n学習効率を最大限に高めます。',
                                style: TextStyle(
                                  color: Color(0xFF92400E), // ブラウン
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFF854D0E),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
