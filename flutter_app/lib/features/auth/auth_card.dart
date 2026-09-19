import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../widgets/app_top_bar.dart';

/// Web `.login-screen` + `.login-card`: centered card on `--bg`, brand row, title, description.
class AuthCard extends StatelessWidget {
  final String title;
  final String description;
  final String? error;
  final List<Widget> children;

  const AuthCard({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: Radii.lgAll,
                  border: Border.all(color: c.border),
                  boxShadow: c.shadowModal,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BrandLogo(size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  text: 'TaskFlow ',
                                  style: TextStyle(
                                    fontSize: rem(1.1),
                                    fontWeight: FontWeight.w600,
                                    color: c.text,
                                    height: 1.2,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Pro',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Enterprise Work Management',
                                style: TextStyle(
                                  fontSize: rem(0.72),
                                  color: c.text3,
                                  letterSpacing: 0.02 * rem(0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: rem(1.15),
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: rem(0.82),
                        color: c.text3,
                        height: 1.5,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Brand.dangerLight,
                          borderRadius: Radii.smAll,
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          error!,
                          style: TextStyle(
                            fontSize: rem(0.82),
                            fontWeight: FontWeight.w500,
                            color: Brand.danger,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
