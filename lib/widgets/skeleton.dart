import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.darkCardElev,
      highlightColor: AppTheme.darkBorder,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.darkCardElev,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class AnimeCardSkeleton extends StatelessWidget {
  const AnimeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkCardElev,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12.r),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 10.h),
                  SizedBox(height: 4.h),
                  SkeletonBox(width: 60.w, height: 8.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimeGridSkeleton extends StatelessWidget {
  final int count;
  const AnimeGridSkeleton({super.key, this.count = 9});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(12.w),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
      ),
      itemCount: count,
      itemBuilder: (_, _) => const AnimeCardSkeleton(),
    );
  }
}

class AnimeRowSkeleton extends StatelessWidget {
  const AnimeRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 12.h),
          child: SkeletonShimmer(
            child: SkeletonBox(width: 140.w, height: 18.h),
          ),
        ),
        SizedBox(
          height: 220.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: 6,
            itemBuilder: (_, _) => SizedBox(
              width: 130.w,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: const AnimeCardSkeleton(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnimeDetailSkeleton extends StatelessWidget {
  const AnimeDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: double.infinity, height: 240.h, radius: 0),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SkeletonBox(width: 110.w, height: 160.h, radius: 12),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: double.infinity, height: 20.h),
                        SizedBox(height: 8.h),
                        SkeletonBox(width: 180.w, height: 14.h),
                        SizedBox(height: 6.h),
                        SkeletonBox(width: 120.w, height: 14.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SkeletonBox(
                width: double.infinity,
                height: 48.h,
                radius: 12,
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in [60.0, 80.0, 50.0, 70.0, 55.0])
                    SkeletonBox(width: w.w, height: 26.h, radius: 20),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  SkeletonBox(width: double.infinity, height: 12.h),
                  SizedBox(height: 6.h),
                  SkeletonBox(width: double.infinity, height: 12.h),
                  SizedBox(height: 6.h),
                  SkeletonBox(width: 200.w, height: 12.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
