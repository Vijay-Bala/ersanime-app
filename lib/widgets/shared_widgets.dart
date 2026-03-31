import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';

class MediaRowSkeleton extends StatelessWidget {
  const MediaRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 12.h),
          child: Container(
            width: 140.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: AppTheme.darkCardElev,
              borderRadius: BorderRadius.circular(6.r),
            ),
          ),
        ),
        SizedBox(
          height: 220.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: 5,
            itemBuilder: (_, _) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Container(
                width: 130.w,
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;
  const ErrorBody({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: AppTheme.textSecondary,
            size: 52.sp,
          ).animate().shake(),
          SizedBox(height: 14.h),
          Text(
            'Could not connect',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(delay: 100.ms),
          SizedBox(height: 6.h),
          Text(
            'Check your internet and try again',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.sp),
          ).animate().fadeIn(delay: 150.ms),
          SizedBox(height: 20.h),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class SectionRow extends StatelessWidget {
  final String title;
  final Color color;
  final int rowIndex;
  final Widget child;

  const SectionRow({
    super.key,
    required this.title,
    required this.color,
    required this.rowIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 12.h),
          child: Row(
            children: [
              Container(
                width: 4.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.r),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.6), blurRadius: 8),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(color: color.withOpacity(0.4), blurRadius: 12),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: (rowIndex * 80).ms).fadeIn().slideX(begin: -0.05),
        child,
      ],
    );
  }
}

class Badge extends StatelessWidget {
  final String label;
  final Color color;
  const Badge(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
