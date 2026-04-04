import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/manga.dart';
import '../theme/app_theme.dart';
import '../screens/manga/manga_detail_screen.dart';

class MangaCard extends StatelessWidget {
  final Manga manga;
  final int index;

  const MangaCard({super.key, required this.manga, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MangaDetailScreen(manga: manga)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: CachedNetworkImage(
                imageUrl: manga.image,
                fit: BoxFit.cover,
                width: double.infinity,
                errorWidget: (c, url, err) => Container(
                  color: AppTheme.darkCard,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            manga.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (manga.rating != null) ...[
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 12.sp),
                SizedBox(width: 4.w),
                Text(
                  manga.rating!.toStringAsFixed(1),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
