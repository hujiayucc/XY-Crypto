import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Flutter equivalent of the original SplashActivity/activity_splash layout.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static const _copyright =
      '备案号: 蜀ICP备2021022209号–3A\nCopyright © 2022–2024 胡佳宇 - All rights reserved.';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Icon(
              Icons.favorite,
              size: 150,
              color: Color(0xFFFA2755),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20 + bottomInset,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'XY加密',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  _copyright,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 11,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
