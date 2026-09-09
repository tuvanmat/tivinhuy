import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tv_flutter_app/providers/movies_provider.dart';
import 'package:tv_flutter_app/providers/button_focus_provider.dart';
import 'package:tv_flutter_app/utils/labels.dart';

class CategoryPage extends StatefulWidget {
  final String title;
  final String type; // 'the-loai', 'quoc-gia' hoặc 'nam'

  const CategoryPage({super.key, required this.title, required this.type});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  bool _isSelecting = false;

  void _handleSelect(BuildContext context, String slug) async {
    if (_isSelecting) return;
    _isSelecting = true;

    // Đóng trang chọn danh mục trước
    Navigator.pop(context);

    // Cập nhật lại focus về bộ phim đầu tiên của trang chủ (${topMoviesItem}0) để không bị mất focus
    final buttonFocusProvider =
        Provider.of<ButtonFocusProvider>(context, listen: false);
    buttonFocusProvider.buttonFocusedLabel = "${topMoviesItem}0";
    buttonFocusProvider.lastButtonFocusedLabel = "${topMoviesItem}0";

    // Gọi API nạp dữ liệu phim theo thể loại/quốc gia/năm mới
    await Provider.of<MoviesProvider>(context, listen: false)
        .fetchMovies(type: '${widget.type}/$slug');
  }

  // Danh sách các cặp màu Gradient phong phú cho các ô thẻ
  final List<List<Color>> _gradientColors = [
    [const Color(0xFF4A569D), const Color(0xFFDC2430)], // Tím - Đỏ
    [const Color(0xFFF2994A), const Color(0xFFF2C94C)], // Cam - Vàng
    [const Color(0xFF56AB2F), const Color(0xFFA8E063)], // Xanh lá tươi
    [const Color(0xFF2193b0), const Color(0xFF6dd5ed)], // Xanh dương
    [const Color(0xFF8A2387), const Color(0xFFE94057)], // Hồng - Tím
    [const Color(0xFF134E5E), const Color(0xFF71B280)], // Xanh đậm - Xanh nhạt
    [const Color(0xFFFF5F6D), const Color(0xFFFFC371)], // Đỏ cam sáng
    [const Color(0xFF3A6073), const Color(0xFF16222A)], // Xanh than
  ];

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> categories = [
      {'name': 'Hành Động', 'slug': 'hanh-dong'},
      {'name': 'Phiêu Lưu', 'slug': 'phieu-luu'},
      {'name': 'Hoạt Hình', 'slug': 'hoat-hinh'},
      {'name': 'Phim Hài', 'slug': 'phim-hai'},
      {'name': 'Hình Sự', 'slug': 'hinh-su'},
      {'name': 'Tài Liệu', 'slug': 'tai-lieu'},
      {'name': 'Chính Kịch', 'slug': 'chinh-kich'},
      {'name': 'Gia Đình', 'slug': 'gia-dinh'},
      {'name': 'Giả Tưởng', 'slug': 'gia-tuong'},
      {'name': 'Lịch Sử', 'slug': 'lich-su'},
      {'name': 'Kinh Dị', 'slug': 'kinh-di'},
      {'name': 'Phim Nhạc', 'slug': 'phim-nhac'},
      {'name': 'Bí Ẩn', 'slug': 'bi-an'},
      {'name': 'Lãng Mạn', 'slug': 'lang-man'},
      {'name': 'Khoa Học Viễn Tưởng', 'slug': 'khoa-hoc-vien-tuong'},
      {'name': 'Gây Cấn', 'slug': 'gay-can'},
      {'name': 'Chiến Tranh', 'slug': 'chien-tranh'},
      {'name': 'Miền Tây', 'slug': 'mien-tay'},
      {'name': 'Cổ Trang', 'slug': 'co-trang'},
      {'name': 'Tâm Lý', 'slug': 'tam-ly'},
      {'name': 'Phim 18+', 'slug': 'phim-18'},
      {'name': 'Tình Cảm', 'slug': 'tinh-cam'},
    ];

    final List<Map<String, String>> countries = [
      {'name': 'Âu Mỹ', 'slug': 'au-my'},
      {'name': 'Anh', 'slug': 'anh'},
      {'name': 'Trung Quốc', 'slug': 'trung-quoc'},
      {'name': 'Indonesia', 'slug': 'indonesia'},
      {'name': 'Việt Nam', 'slug': 'viet-nam'},
      {'name': 'Argentina', 'slug': 'argentina'},
      {'name': 'Áo', 'slug': 'ao'},
      {'name': 'Úc', 'slug': 'uc'},
      {'name': 'Bangladesh', 'slug': 'bangladesh'},
      {'name': 'Brazil', 'slug': 'brazil'},
      {'name': 'Bahamas', 'slug': 'bahamas'},
      {'name': 'Belarus', 'slug': 'belarus'},
      {'name': 'Canada', 'slug': 'canada'},
      {'name': 'Thụy Sĩ', 'slug': 'thuy-si'},
      {'name': 'Bờ Biển Ngà', 'slug': 'bo-bien-nga'},
      {'name': 'Chile', 'slug': 'chile'},
      {'name': 'Colombia', 'slug': 'colombia'},
      {'name': 'Costa Rica', 'slug': 'costa-rica'},
      {'name': 'Đức', 'slug': 'duc'},
      {'name': 'Đan Mạch', 'slug': 'dan-mach'},
      {'name': 'Tây Ban Nha', 'slug': 'tay-ban-nha'},
      {'name': 'Pháp', 'slug': 'phap'},
      {'name': 'Greenland', 'slug': 'greenland'},
      {'name': 'Hồng Kông', 'slug': 'hong-kong'},
      {'name': 'Hàn Quốc', 'slug': 'han-quoc'},
      {'name': 'Nhật Bản', 'slug': 'nhat-ban'},
      {'name': 'Thái Lan', 'slug': 'thai-lan'},
      {'name': 'Đài Loan', 'slug': 'dai-loan'},
      {'name': 'Nga', 'slug': 'nga'},
      {'name': 'Hà Lan', 'slug': 'ha-lan'},
      {'name': 'Quốc gia khác', 'slug': 'quoc-gia-khac'},
      {'name': 'Philippines', 'slug': 'philippines'},
      {'name': 'Ấn Độ', 'slug': 'an-do'},
    ];

    final List<Map<String, String>> years = [
      {'name': '2026', 'slug': '2026'},
      {'name': '2025', 'slug': '2025'},
      {'name': '2024', 'slug': '2024'},
      {'name': '2023', 'slug': '2023'},
      {'name': '2022', 'slug': '2022'},
      {'name': '2021', 'slug': '2021'},
      {'name': '2020', 'slug': '2020'},
      {'name': '2019', 'slug': '2019'},
      {'name': '2018', 'slug': '2018'},
      {'name': '2017', 'slug': '2017'},
      {'name': '2016', 'slug': '2016'},
      {'name': '2015', 'slug': '2015'},
    ];

    final listItems = widget.type == 'the-loai'
        ? categories
        : (widget.type == 'quoc-gia' ? countries : years);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            childAspectRatio: 1.35,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
          ),
          itemCount: listItems.length,
          itemBuilder: (context, index) {
            final name = listItems[index]['name']!;
            final slug = listItems[index]['slug']!;
            final colors = _gradientColors[index % _gradientColors.length];

            return _CategoryCard(
              name: name,
              colors: colors,
              autofocus: index == 0,
              onTap: () => _handleSelect(context, slug),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String name;
  final List<Color> colors;
  final bool autofocus;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name,
    required this.colors,
    required this.autofocus,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: _focusNode,
        builder: (context, child) {
          final isFocused = _focusNode.hasFocus;

          return InkWell(
            onTap: widget.onTap,
            onFocusChange: (hasFocus) {
              setState(() {});
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused ? Colors.amber : Colors.transparent,
                  width: isFocused ? 4.0 : 0.0,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : [
                        const BoxShadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
